# Kubernetes compatibility patch

The patches in this directory apply only to Kubernetes `v1.12.10-rancher1`,
commit
`71fde6aadce8b92456b88ee56c21e500f4919f0b`.

The upstream version suffix and commit identity are retained as source
provenance. The built kubelet reports the independent PastureStack maintenance
version configured by `KUBERNETES_BINARY_VERSION`.

The patch provides the minimum compatibility required by the validated
Ubuntu 26.04, Docker Engine 29, and cgroup v2 profile:

- Docker API negotiation starts at API 1.40.
- Linux pod sandboxes expose a shareable IPC namespace.
- cgroup v2 uses the unified hierarchy for startup discovery.
- cAdvisor reads unified CPU, memory, and I/O counters directly from cgroup v2.
- Docker's containerd snapshotter is detected from daemon metadata, and
  writable-layer usage is collected through the Docker API instead of the
  removed graphdriver `layerdb`.

The cgroup v2 runtime profile disables per-QoS cgroup creation, node
allocatable enforcement, eviction thresholds, and local ephemeral-storage
capacity isolation. Those historical v1-only controls must not be presented as
active in this profile.

`kubernetes-v1.12.10-go1.26.patch` replaces the vendored codec generator's
ambiguous historical Base64 alphabet with the collision-free Base32 identifier
encoding used by current codec releases. Go 1.26 rejects duplicate alphabet
symbols during package initialization, so this source-only compatibility patch
is required before the legacy kubelet can be compiled with the maintained Go
toolchain. It does not alter kubelet runtime data or network behavior.
