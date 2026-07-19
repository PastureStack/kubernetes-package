# Kubernetes compatibility patch

`kubernetes-v1.12.10-docker29-cgroupv2.patch` applies only to Kubernetes
`v1.12.10-rancher1`, commit
`71fde6aadce8b92456b88ee56c21e500f4919f0b`.

The upstream version suffix and commit identity are retained as source
provenance. The built kubelet reports the independent PastureStack maintenance
version configured by `KUBERNETES_BINARY_VERSION`.

The patch provides the minimum compatibility required by the validated
Ubuntu 26.04, Docker Engine 29, and cgroup v2 profile:

- Docker API negotiation starts at API 1.40.
- Linux pod sandboxes expose a shareable IPC namespace.
- cgroup v2 uses the unified hierarchy for startup discovery.

The cgroup v2 runtime profile disables per-QoS cgroup creation, node
allocatable enforcement, eviction thresholds, and local ephemeral-storage
capacity isolation. Those historical v1-only controls must not be presented as
active in this profile.
