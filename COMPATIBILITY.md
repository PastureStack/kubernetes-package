# Compatibility Contract

The migration preserves the Kubernetes 1.12-era binary layout, kubeconfig and certificate paths, metadata endpoints, API credentials, control-plane command arguments, add-on manifests, service-account and label identifiers, and host mount behavior required by recorded deployments.

Preferred settings and service names use `PLATFORM_*`, `metadata`, `kubernetes-authentication-bridge`, and the `pasturestack` image namespace. Historical `CATTLE_*`, `RANCHER_*`, `io.rancher.*`, `rancher-app`, service-account names, cloud-provider identifiers, internal DNS names, external artifact tags, and API resource names remain only where they are compatibility contracts.

Historical remote tags remain immutable provenance records, but the current build does not consume or display their branded suffixes as product versions. Compatibility source is identified by its numeric API baseline, immutable commit, release-asset ID, and checksum. Every PastureStack-built artifact uses a new numeric version with independently verified source and checksums.

Operator wait-state messages support `en-US` and `zh-TW`. Kubernetes YAML, API values, credentials, identifiers, labels, kubeconfigs, and command output are never translated.

Before release, validate every role, certificate flow, metadata lookup, authentication webhook, add-on rendering, Docker API compatibility override, cgroup and mount path, control-plane startup, worker join, upgrade, and rollback in an isolated VM.

The Helm 2 compatibility server and client are rebuilt from upstream v2.17.0
and aligned at numeric PastureStack build v2.17.1. The add-on
manager uses a rolling Deployment update, retains ConfigMap and Secret release
records, compares their canonical metadata and payload content, and restores
the previous Deployment revision when readiness or record verification fails.
Operators must also create and verify an offline bundle with
`scripts/tiller-release-backup` before any cluster upgrade. This path does not
run `helm init --upgrade`, restore or convert release storage, delete workloads,
or claim Helm 3 compatibility.

Kubernetes DNS remains exposed through the `kube-system/kube-dns` Service and
the configured cluster IP, so existing kubelet and workload resolver settings
do not change. The maintained `1.26.9` candidate runs the required DNS service
as one non-root container without the historical cache and monitoring
sidecars. It explicitly disables client-go `WatchListClient` because
Kubernetes 1.12 predates the initial-event bookmark protocol, and uses the
supported list-then-watch path without requiring a control-plane change. The
updater accepts an upgrade from the recorded `1.14.13`
deployment, refuses an unrecognized image version, does not downgrade a newer
semantic version, uses `kubectl apply` plus a rolling Deployment, and restores
the previous Deployment revision and Service routing if the rollout or exact
container-set verification fails. It requires the exact
Kubernetes 1.12 bootstrap `system:kube-dns` role and binding for the
`kube-system/kube-dns` service account. That role can list and watch only
Services and Endpoints; the service account cannot read Secrets, mutate
workloads, read Nodes, or bind privileges.

The release gate no longer uses the historical etcd 3.2 test image as evidence
for the maintained path. It fetches the exact reviewed `PastureStack/etcd-image`
source revision `24c626275522fbc3a4c9683cc90ff489b2b366de`, verifies Git tree
`9bbe6c138bd005fd2798d842ebfaae3aeac5579c`, then
builds numeric candidate `3.7.2` from official etcd `3.7.1`, scans that exact
local image, and starts the Kubernetes 1.12 API Server with
`--storage-backend=etcd3`. API discovery, DNS state, readiness, metrics, and
least-privilege checks must all pass. This proves client and storage-backend
compatibility only; it does not convert an existing etcd2 data directory or
authorize a live Catalog upgrade.

Historical Dashboard, Heapster, Grafana, and InfluxDB resources are outside
the maintained package boundary. Detection is read-only and existing objects
are preserved. No automatic cleanup is performed because removal can destroy
monitoring history or break consumers. A pre-existing `addons-binding` is
reported for explicit operator review rather than silently deleted.
