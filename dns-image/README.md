# Cluster DNS image

This directory packages only the cluster DNS binary required by the maintained
Kubernetes 1.12 compatibility path. The build fetches the exact verified
Kubernetes DNS source revision recorded by `scripts/prepare-cluster-dns-source`,
removes the recorded unreachable parser dependency, compiles with the
repository's locked Go toolchain, and copies the binary into a non-root
distroless image. The image disables the client-go `WatchListClient` feature
gate because Kubernetes 1.12 predates the initial-event bookmark protocol; it
uses the supported list-then-watch path instead.
The image also carries the upstream project license and the complete vendored
source license and notice set recorded by the locked source revision.

The recorded source revision is the verified head of an upstream
dependency-update proposal. It is not represented as a Kubernetes project
release or as an upstream-approved PastureStack change.

The compatibility image is versioned `1.26.9`. It does not include the legacy
DNS cache or monitoring sidecars. Service discovery, readiness, metrics,
least-privilege access, and DNS answers are exercised against an isolated
Kubernetes 1.12 API before a release can be considered.

The review workflow creates this image only for validation. It does not push
the tag, create a release, or deploy a cluster.

The Kubernetes DNS source and its license remain owned by their respective
authors. PastureStack claims only the local compatibility and packaging changes.
