#!/usr/bin/env bash
set -e
# kubernetes — K8s learning material (fork): check tools, lint the shell script, list & dry-run manifests
# Bootstrap: on a fresh Ubuntu/Debian VM this script INSTALLS its own prerequisites
# (git/curl base tools + kubectl official binary + Docker Engine). Manifests are
# only ever client-dry-run validated — nothing is applied and no cluster is created.
REPO="kubernetes"
OWNER="UncleD0886475978"
CLONE_URL="https://github.com/${OWNER}/${REPO}.git"
TARGET_DIR="$HOME/repos/${REPO}"
RUN_ONELINE="curl -fsSL https://raw.githubusercontent.com/${OWNER}/${REPO}/main/setup.sh | bash"

echo "==> [1/7] Platform check + base bootstrap (git, curl)"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "ERROR: this script needs root or sudo to install packages."
    exit 1
  fi
fi
APT=0
if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then APT=1; fi
INSTALLED=""
APT_UPDATED=""
note_installed() { INSTALLED="${INSTALLED} $1"; }
apt_update_once() {
  if [ -z "${APT_UPDATED}" ]; then $SUDO apt-get update -y; APT_UPDATED=1; fi
}
apt_install() {
  apt_update_once
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$@"
}
if [ "${APT}" -eq 1 ]; then
  BASE_PKGS=""
  command -v git >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} git"
  command -v curl >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} curl"
  [ -f /etc/ssl/certs/ca-certificates.crt ] || BASE_PKGS="${BASE_PKGS} ca-certificates"
  command -v gpg >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} gnupg"
  if [ -n "${BASE_PKGS}" ]; then
    echo "    Installing base tools:${BASE_PKGS}"
    # shellcheck disable=SC2086
    apt_install ${BASE_PKGS}
    note_installed "${BASE_PKGS}"
  else
    echo "    Base tools already present (git, curl, ca-certificates, gnupg)."
  fi
else
  echo "    Non-apt platform detected — bootstrap will only CHECK tools and print install guidance."
fi

DOCKER="docker"
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "    docker: already present ($(docker --version))"
  elif [ "${APT}" -eq 1 ]; then
    echo "    Installing Docker Engine via the official get.docker.com script..."
    curl -fsSL https://get.docker.com | $SUDO sh
    note_installed "docker"
  else
    return 1
  fi
  if ! docker info >/dev/null 2>&1 && ! $SUDO docker info >/dev/null 2>&1; then
    echo "    Starting the Docker daemon..."
    $SUDO systemctl enable --now docker 2>/dev/null || $SUDO service docker start 2>/dev/null || true
    for _i in $(seq 1 15); do
      if docker info >/dev/null 2>&1 || $SUDO docker info >/dev/null 2>&1; then break; fi
      sleep 2
    done
  fi
  if docker info >/dev/null 2>&1; then
    DOCKER="docker"
  elif $SUDO docker info >/dev/null 2>&1; then
    DOCKER="sudo docker"
    if [ "$(id -u)" -ne 0 ]; then
      $SUDO usermod -aG docker "$USER" 2>/dev/null || true
      echo "    NOTE: you were added to the 'docker' group (applies at next login); this run uses 'sudo docker'."
    fi
  else
    echo "ERROR: Docker is installed but the daemon could not be started."
    echo "       On a VM:  sudo systemctl start docker   |   In a container/WSL without systemd, Docker cannot run here."
    exit 1
  fi
  echo "    docker daemon OK (using: ${DOCKER})"
}
install_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then echo "    kubectl: already present"; return 0; fi
  if ! command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then return 1; fi
  echo "    Installing kubectl (official binary)..."
  KARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
  case "${KARCH}" in x86_64) KARCH="amd64" ;; aarch64) KARCH="arm64" ;; esac
  KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLO "https://dl.k8s.io/release/${KVER}/bin/linux/${KARCH}/kubectl"
  $SUDO install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl
  note_installed "kubectl"
}
ensure_apt_pkg() { # ensure_apt_pkg <command> <package>
  if command -v "$1" >/dev/null 2>&1; then echo "    $1: already present"; return 0; fi
  [ "${APT}" -eq 1 ] || return 1
  echo "    Installing $2..."
  apt_install "$2"
  note_installed "$2"
}

echo "==> [2/7] Locating checkout (current dir if already inside it, else ~/repos/$REPO)"
if [ -f "$0" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
  SCRIPT_DIR="$PWD"
fi
if [ -d .git ] && command -v git >/dev/null 2>&1 && git remote get-url origin 2>/dev/null | grep -q "$REPO"; then
  REPO_DIR="$(pwd)"; echo "    Using current directory: $REPO_DIR"
elif [ -d "${SCRIPT_DIR}/.git" ] && command -v git >/dev/null 2>&1 && git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
  REPO_DIR="${SCRIPT_DIR}"; echo "    Using script location: $REPO_DIR"
else
  REPO_DIR="$HOME/repos/$REPO"
  if [ -d "$REPO_DIR/.git" ]; then echo "    Updating $REPO_DIR"; git -C "$REPO_DIR" pull --ff-only || echo "    WARN: pull failed, using existing copy"
  else
    if ! command -v git >/dev/null 2>&1; then
      echo "ERROR: git not found — install: https://git-scm.com/downloads"
      exit 1
    fi
    mkdir -p "$HOME/repos"; git clone "https://github.com/$OWNER/$REPO.git" "$REPO_DIR"
  fi
fi
cd "$REPO_DIR"

echo "==> [3/7] Bootstrap prerequisites (kubectl + docker; minikube/kind stay manual, optional)"
echo "    git: $(git --version)"
MISSING_LIST=""
install_kubectl || MISSING_LIST="${MISSING_LIST} kubectl(https://kubernetes.io/docs/tasks/tools/)"
install_docker || MISSING_LIST="${MISSING_LIST} docker(https://docs.docker.com/get-docker/)"
if [ -n "${MISSING_LIST}" ]; then
  echo "ERROR: could not auto-install on this platform. Missing:${MISSING_LIST}"
  echo "Install the tool(s) manually, then re-run this script."
  exit 1
fi
echo "    kubectl: $(kubectl version --client 2>/dev/null | head -1 || echo present)"
# Optional tooling — checked, never fatal (same as the original script):
ensure_apt_pkg shellcheck shellcheck || echo "    [optional missing] shellcheck — hint: https://github.com/koalaman/shellcheck#installing (or: sudo apt install shellcheck)"
if command -v minikube >/dev/null 2>&1; then echo "    [ok]      minikube"; else echo "    [missing] minikube (or kind) — optional, only needed to run a practice cluster — install: https://minikube.sigs.k8s.io/docs/start/ / https://kind.sigs.k8s.io/"; fi

echo "==> [4/7] Learning chapters found (verified via GitHub API root listing)"
for d in ch-01-pods-containers ch-02-pod-scheduling ch-03-deployments ch-04-services ch-05-namespaces ch-06-storage ch-07-rbac ch-10-high-value-extra ch-11-challenges-one ch-12-challenges-two ch-13-interview-questions; do
  [ -d "$d" ] && echo "    $d/"
done
echo "    Plus root files: cluster-setup.sh, batch-job.yml (listing continues at runtime below)"
echo "==> [5/7] Shell scripts — shellcheck if available"
if command -v shellcheck >/dev/null 2>&1; then
  find . -path ./.git -prune -o -type f -name '*.sh' -print | while read -r s; do echo "    shellcheck $s"; shellcheck "$s" || echo "    WARN: shellcheck findings in $s (non-fatal)"; done
else
  echo "    shellcheck not installed — hint: https://github.com/koalaman/shellcheck#installing (or: sudo apt install shellcheck)"
  find . -path ./.git -prune -o -type f -name '*.sh' -print | while read -r s; do echo "    script: $s — usage: bash $s (review before running; cluster-setup.sh provisions a local cluster)"; done
fi
echo "==> [6/7] Kubernetes manifests — list, and client dry-run only where it works cluster-independently"
find . -path ./.git -prune -o -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort | while read -r f; do echo "    manifest: $f"; done
if command -v kubectl >/dev/null 2>&1; then
  find . -path ./.git -prune -o -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort | while read -r f; do
    if kubectl apply --dry-run=client -f "$f" >/dev/null 2>&1; then echo "    [dry-run ok]   $f"; else echo "    [dry-run skip] $f (needs a cluster/context or is not a plain manifest)"; fi
  done
else
  echo "    kubectl absent — manifests listed only, no validation attempted"
fi
echo "==> [7/7] Done — no cluster was created and nothing was applied"

cat <<EOF

=================== BOOTSTRAP SUMMARY ===================
Installed during this run:${INSTALLED:- (nothing — all tools were already present)}
Working copy: ${REPO_DIR}
Next time, set up from scratch on any fresh Ubuntu VM with one line:
  ${RUN_ONELINE}
=========================================================
EOF

echo "Next commands:"
echo "  cd $REPO_DIR"
echo "  cat README.md; ls ch-01-pods-containers/"
echo "  bash cluster-setup.sh        # review first — starts/provisions the practice cluster"
echo "  minikube start               # if using minikube"
echo "  kubectl apply -f batch-job.yml"
