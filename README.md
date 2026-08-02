# PastureStack Kubernetes Package

Kubernetes Package assembles the compatibility control-plane and node binaries, startup scripts, certificate bootstrap, and legacy add-on manifests into an Ubuntu 26.04 runtime image.

PastureStack is an independent community effort to preserve, audit, and modernize the Rancher 1.6 ecosystem. It is not affiliated with or endorsed by Rancher Labs or SUSE.

**Upstream:** [`rancher/kubernetes-package`](https://github.com/rancher/kubernetes-package). This GitHub fork preserves the upstream Git history, authorship, dates, tags, and license notices; PastureStack maintenance is consolidated into one commit after the preserved upstream boundary.

## Project status

The maintained candidate is `ghcr.io/pasturestack/kubernetes-package:v1.12.10-pasturestack.2`. It rebuilds the Kubernetes 1.12.10 kubelet with narrowly scoped Docker 29, cgroup v2, and sandbox IPC compatibility patches while retaining the verified upstream control-plane binaries. It also converges the Helm 2 compatibility server on `ghcr.io/pasturestack/tiller:v2.17.0-pasturestack.1` without deleting existing release records. Personal registry coordinates and inherited CI/CD have been removed.

The candidate has passed binary-version checks, shell validation, an Ubuntu 26.04 and Docker 29 static-Pod lifecycle test, HIGH/CRITICAL vulnerability blocking, secret scanning, private-data checks, and CycloneDX SBOM generation. A complete Catalog release remains gated on multi-service control-plane, worker, add-on, upgrade, and rollback testing.

The package still consumes historical Kubernetes and CNI compatibility artifacts. Their exact tags and protocol identifiers remain recorded as external compatibility inputs; they are not renamed to create misleading provenance.

## Build

Run from a Docker-capable Linux host:

```sh
make package \
  IMAGE_NAME=ghcr.io/pasturestack/kubernetes-package \
  TAG=v1.12.10-pasturestack.2 \
  KUBERNETES_BINARY_VERSION=v1.12.10-pasturestack.2
```

The command verifies the upstream server archive, applies the documented compatibility patch, builds the kubelet, creates a local image, and records its name in `dist/images`. It does not push the image.

[`tests/static-pod.yaml`](tests/static-pod.yaml) is the language-neutral workload used by the Docker 29 and cgroup v2 lifecycle gate.

## Localization

Set `PASTURESTACK_LOCALE=en-US` or `PASTURESTACK_LOCALE=zh-TW` for startup and wait-state messages. Kubernetes resources, kubeconfigs, API values, labels, and command output remain language-neutral.

See [COMPATIBILITY.md](COMPATIBILITY.md), [SECURITY.md](SECURITY.md), [RELEASE.md](RELEASE.md), and [ORIGIN.md](ORIGIN.md).

## License and attribution

The inherited packaging work remains licensed under [Apache License 2.0](LICENSE). Kubernetes, CNI, Ubuntu, Docker, add-on images, and other bundled components retain their own licenses and notices. PastureStack contributors claim authorship only for their own changes.
