# PastureStack Kubernetes Package

Kubernetes Package assembles the compatibility control-plane and node binaries, startup scripts, certificate bootstrap, and legacy add-on manifests into an Ubuntu 26.04 runtime image.

PastureStack is an independent community effort to preserve, audit, and modernize the Rancher 1.6 ecosystem. It is not affiliated with or endorsed by Rancher Labs or SUSE.

**Upstream:** [`rancher/kubernetes-package`](https://github.com/rancher/kubernetes-package). This GitHub fork preserves the upstream Git history, authorship, dates, tags, and license notices; PastureStack maintenance is consolidated into one commit after the preserved upstream boundary.

## Project status

The reviewed source now produces the numeric-version candidate `v1.12.11`. It rebuilds kubelet, kube-proxy, kube-apiserver, kube-controller-manager, kube-scheduler, and kubectl from the immutable Kubernetes 1.12.10 compatibility source commit with narrowly scoped Docker 29, cgroup v2, containerd snapshotter, sandbox IPC, and Go 1.26 patches. Every rebuilt executable reports `v1.12.11`; no branded suffix is used as a PastureStack version. Package builds default to `v1.12.11` and reject Git-derived, branded, maintenance-counter, architecture-suffixed, or development image tags. On a unified cgroup v2 host the kubelet reports CPU, memory, I/O, and writable-layer usage without reading the removed graphdriver `layerdb`. The package also converges Kubernetes DNS and the Helm 2 compatibility server with rolling updates and rollback checks. This candidate is not published by the source review itself; publication remains a separate, explicit release decision.

The package pins Ubuntu 26.04 to one dated snapshot, locks every direct APT package, installs Azure CLI 2.89.0 from a checksum-verified immutable package, and overlays checksum-verified cryptography 48.0.1 and pyOpenSSL 26.2.0 wheels without a network resolver. This is the latest mutually compatible set: Azure CLI core requires MSAL 1.36.0, while MSAL and pyOpenSSL require cryptography below 49. The release gate preserves raw and applicable scanner findings, blocks every unreviewed HIGH/CRITICAL issue, verifies the documented cryptography advisory ranges and reachable APIs, verifies the build-only Linux header package boundary, applies exact-package OpenVEX assessments, scans secrets and private data, and emits a CycloneDX SBOM. A complete Catalog release remains gated on multi-service control-plane, worker, add-on, upgrade, and rollback testing.

The gate also fetches the exact `PastureStack/etcd-image` source revision `24c626275522fbc3a4c9683cc90ff489b2b366de`, verifies Git tree `9bbe6c138bd005fd2798d842ebfaae3aeac5579c`, and locally rebuilds numeric candidate `3.7.2` from official etcd `3.7.1`. The exact local image is rescanned and used to start the Kubernetes 1.12 API Server with `--storage-backend=etcd3` before DNS, API discovery, readiness, metrics, and least-privilege checks run. This is an isolated compatibility test; it neither publishes the etcd image nor converts a live etcd2 data directory.

The Kubernetes compatibility payload is pinned by numeric API baseline, immutable source commit, GitHub repository and release-asset IDs, and archive checksum. The loopback plug-in is rebuilt twice from the immutable official CNI plug-ins `v1.9.1` source commit with Go 1.26.5; the source archive and license have independent checksums, and byte-identical output is required. The inherited upstream prebuilt binary is not shipped. Source provenance is never represented as a PastureStack release claim.

## Add-on safety boundary

The package prepares the numeric-version cluster DNS candidate `1.26.9` and
preserves the existing `kube-dns` Service address. The candidate is rebuilt
from one checksum-verified Kubernetes DNS source revision with a narrow patch
that removes an unreachable parser dependency; it does not contain the legacy
DNS cache or monitoring sidecars. DNS uses the Kubernetes 1.12 bootstrap
`system:kube-dns` role and the
dedicated `kube-system/kube-dns` service account, never the shared
`cluster-admin` access used by the historical add-on bundle. The release gate
checks reproducibility, provenance, the exact Kubernetes 1.12 API interaction,
DNS answers, readiness, metrics, RBAC allow and deny boundaries, secrets, and
unreviewed HIGH or CRITICAL vulnerabilities before publication. Source review
does not publish the image.

Dashboard, Heapster, Grafana, and InfluxDB are not built, mirrored, packaged,
created, force-replaced, or deleted by the current updater. If historical
resources or the old `addons-binding` are found, the updater reports them and
leaves them unchanged. Retire them only after separately reviewing stored
data, dependent workloads, replacement monitoring, and access controls.

## Helm 2 release-data preflight

Before changing Kubernetes or the Helm 2 compatibility server, create an
operator-held backup outside the source tree and verify it:

```sh
scripts/tiller-release-backup snapshot --output /secure/offline/helm2-release-backup
scripts/tiller-release-backup verify --input /secure/offline/helm2-release-backup
scripts/tiller-release-backup compare --input /secure/offline/helm2-release-backup
```

The tool uses the current `kubectl` context and requires `kubectl`, `jq`, and
GNU checksum/sort utilities. It stores complete Helm 2 ConfigMap and Secret
records, a canonical comparison file, the Tiller Deployment, Kubernetes
version metadata, and checksums. The bundle is mode `0700` with mode `0600`
files and may contain credentials or chart values. Never commit, upload, or
attach it to a public issue. `compare` is read-only and exits with status 3 if
records are missing, added, or changed; it does not restore or migrate data.

The add-on update independently compares canonical release-record content
before and after the rolling Tiller update. Any content drift or rollout
failure restores the previous Deployment revision. DNS uses its own rolling
Deployment and restores both the prior Deployment revision and Service routing
on failure, so DNS and Tiller can be disabled and validated independently.
These are compatibility safeguards, not a supported Helm 3
migration path or an automatic retirement tool for historical add-ons.

## Build

Run from a Docker-capable Linux host:

```sh
make package \
  IMAGE_NAME=ghcr.io/pasturestack/kubernetes-package \
  TAG=v1.12.11 \
  KUBERNETES_BINARY_VERSION=v1.12.11
```

The command verifies the compatibility server archive, extracts it into the legacy `k8s.io/kubernetes` GOPATH layout required by Kubernetes 1.12, applies the documented compatibility patches, and rebuilds all six shipped Kubernetes executables with `-trimpath` and numeric version `v1.12.11`. It also rebuilds the single CNI loopback plug-in twice from the locked source commit with Go 1.26.5 and rejects non-identical output or unexpected compiler metadata. It creates a local image and records its name in `dist/images`. The build rejects any executable that embeds its randomized temporary build directory so independent builds can be compared by digest. Both build and runtime stages use a reviewed Ubuntu 26.04 amd64 digest and the dated snapshot in [`package/ubuntu-apt.lock`](package/ubuntu-apt.lock). A checksum-locked Docker CLI image donates only the initial CA bundle; all Ubuntu packages then come from HTTPS, are resolved at that snapshot, and use exact direct-package versions. The command does not push the image.

[`tests/static-pod.yaml`](tests/static-pod.yaml) is the language-neutral workload used by the Docker 29 and cgroup v2 lifecycle gate.

## Localization

Set `PASTURESTACK_LOCALE=en-US` or `PASTURESTACK_LOCALE=zh-TW` for startup and wait-state messages. Kubernetes resources, kubeconfigs, API values, labels, and command output remain language-neutral.

See [COMPATIBILITY.md](COMPATIBILITY.md), [SECURITY.md](SECURITY.md), [RELEASE.md](RELEASE.md), and [ORIGIN.md](ORIGIN.md).

## License and attribution

The inherited packaging work remains licensed under [Apache License 2.0](LICENSE). Kubernetes, CNI, Ubuntu, Docker, add-on images, and other bundled components retain their own licenses and notices. PastureStack contributors claim authorship only for their own changes.
