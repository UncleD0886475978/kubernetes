# kubernetes — BUILD

- Repo: UncleD0886475978/kubernetes
- Visibility/fork: public FORK — "Additional learning material on kubernetes" (per sweep brief), Shell
- Docs-only: NO
- Stack/content actually found (GitHub API root listing, 2026-11-09; listing was long/truncated): `README.md` (129 B), `batch-job.yml` (707 B), `cluster-setup.sh` (1,633 B), and chapter dirs `ch-01-pods-containers`, `ch-02-pod-scheduling`, `ch-03-deployments`, `ch-04-services`, `ch-05-namespaces`, `ch-06-storage`, `ch-07-rbac`, `ch-10-high-value-extra`, `ch-11-challenges-one`, `ch-12-challenges-two`, `ch-13-interview-questions`. Chapter contents / full file list and README body could not be read before a GitHub API HTTP 429 rate-limit stopped further inspection — setup.sh therefore discovers manifests/scripts at runtime.
## One-line install (fresh Ubuntu/Debian VM)

```bash
curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/kubernetes/main/setup.sh | bash
```

The script installs its own prerequisites — git/curl base tools via apt, kubectl as the official binary, and Docker Engine via the official get.docker.com script (later docker calls go through `${DOCKER}`, which falls back to `sudo docker` when needed) — then locates/clones the repo and validates the learning material. Alternative: clone the repo yourself and run `./setup.sh` from its root, as described below.

- What setup.sh does: platform/base bootstrap first, then uses current checkout or clones/pulls into `~/repos/kubernetes`, bootstraps kubectl + Docker (minikube/kind and shellcheck stay optional checks — shellcheck is apt-installed when possible), shellchecks shell scripts if shellcheck exists (else prints install hint + usage), lists all YAML manifests, and runs `kubectl apply --dry-run=client` per manifest only where it succeeds cluster-independently — never applies for real.
- Issue it prevents: Blind-applying learning/challenge manifests to a real cluster, or running cluster-setup.sh, without tool checks and a dry-run first.
