# PastureStack Kubernetes Package

This repository builds a compact, auditable bundle of current upstream Kubernetes components. It is a source-built component image, not a complete Kubernetes distribution and not an in-place replacement for the historical Rancher 1.6 package.

PastureStack is an independent community project and is not affiliated with or endorsed by Rancher Labs or SUSE. The preserved upstream history and Apache-2.0 attribution remain intact.

The previous public Release, `v1.12.10-pasturestack.4`, is immutable historical
evidence for the retired compatibility package. The maintained component
bundle uses pure numeric coordinate `v1.36.4`; product identity and provenance
are carried by the package name, labels, SBOM, and attestations rather than a
text qualifier in the tag. This component image is still not an in-place
upgrade path for a legacy Rancher 1.6 cluster.

## Current payload

- Kubernetes `v1.36.4`, exact upstream commit `bb826b1d48562f110659e64e8ec444327433db95`.
- `kubeadm`, `kubelet`, `kube-proxy`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, and `kubectl` built from that source with Go `1.27.0`.
- CNI plug-ins `v1.9.1` loopback binary built from the vendored upstream source with Go `1.27.0`.
- Current dependency overrides: OpenTelemetry `v1.45.0`, OpenTelemetry gRPC instrumentation `v0.70.0`, gRPC-Go `v1.83.2`, `cel.dev/cel-go` `v0.32.0`, etcd `v3.7.1`, `go.etcd.io/raft/v3` `v3.7.0`, `x/crypto` `v0.56.0`, and `x/sys` `v0.47.0`.
- Statically linked component binaries in a `scratch` runtime with only the required CA bundle, licenses, and build evidence.

The image deliberately contains no Docker CLI, Azure CLI, Helm, Tiller, embedded cloud provider, legacy DNS add-on, dashboard, monitoring add-on, or Rancher metadata bootstrap logic.

## Usage

The image contains no shell or wrapper process. Its `PATH` exposes only the packaged component binaries:

```sh
docker run --rm local/pasturestack/kubernetes-package:v1.36.4 kubectl version --client=true --output=json
docker run --rm local/pasturestack/kubernetes-package:v1.36.4 kubeadm version -o short
```

Node and control-plane components normally require host networking, persistent state, device or cgroup access, certificates, a CRI endpoint, and root privileges. Those privileges are deployment decisions and are never added automatically by this image.

## Required external services

A real cluster must supply and validate these separately:

- a supported CRI runtime;
- etcd matching the Kubernetes support matrix;
- a complete CNI implementation in addition to loopback;
- CoreDNS or another supported cluster DNS deployment;
- external cloud-controller-manager and CSI drivers when cloud or persistent storage integration is required.

## Migration boundary

Legacy command-line flags, metadata endpoints, Docker-shim assumptions, in-tree cloud providers, Tiller release state, and old add-on manifests are not translated by this repository. Existing legacy clusters must be inventoried and migrated through a supported Kubernetes upgrade or replacement-cluster plan. See [COMPATIBILITY.md](COMPATIBILITY.md) for affected consumers and required tests.

## Validation

```sh
bash scripts/validate
SOURCE_REVISION=$(git rev-parse HEAD) TAG=v1.36.4 bash scripts/package
```

`scripts/package` builds the exact image, checks every packaged binary and label, compiles the CNI loopback test suite and exercises its unprivileged `VERSION` protocol, confirms the minimal root filesystem, scans every vulnerability severity and secrets, and emits raw plus VEX-aware Trivy JSON, a vulnerability-enriched CycloneDX SBOM, the rootfs inventory, and immutable evidence under `dist/`. The sole VEX statement is accepted only after the source package graph proves that all seven commands exclude the discontinued `x/crypto/openpgp` package. CNI `ADD`/`CHECK`/`DEL` tests require a privileged network namespace and belong to the target-node integration scope in `COMPATIBILITY.md`, not to a rootless image build.
