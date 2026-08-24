# Compatibility and Migration Boundary

This release intentionally ends compatibility with the historical Rancher 1.6-era Kubernetes package. It is not an in-place image swap for a legacy control plane.

## Removed interfaces

- Helm 2/Tiller client, server, manifests, release backup helper, and cluster-wide RBAC.
- kube-dns, Dashboard, Heapster, Grafana, InfluxDB, and add-on mutation scripts.
- embedded Azure CLI and Python cryptography stack.
- Docker CLI, Docker-shim, graph-driver and old cgroup compatibility patches.
- Rancher metadata polling, legacy certificate bootstrap, and legacy entry-script flag synthesis.
- in-tree cloud-provider behavior and deprecated Kubernetes API/flag compatibility.

## Supported interface

The image exposes only the exact component dispatcher documented in the README. Kubernetes configuration, feature gates, APIs, kubeadm configuration, CRI endpoints, CNI configuration, and certificates must conform to Kubernetes `v1.36.4`.

## Direct impact

| Consumer or area | Impact | Required evaluation |
| --- | --- | --- |
| `catalog-templates` Kubernetes templates | Historical compose templates pass removed flags and expect embedded add-ons | Retire those revisions or replace them with a separate supported cluster distribution; do not only change the image tag |
| Existing Rancher 1.6 clusters | No direct upgrade contract | Inventory workloads and data, then use a supported multi-version migration or replacement cluster |
| Control-plane automation | Legacy entry-script environment variables are gone | Generate explicit current component arguments and kubeconfig/certificate paths |
| Networking | Only CNI loopback is included | Select and test a maintained primary CNI compatible with Kubernetes `v1.36.4` |
| DNS and add-ons | No add-on mutation occurs | Deploy and test maintained CoreDNS, metrics, ingress, and dashboard components separately when needed |
| Cloud and storage | In-tree providers are not supplied | Test external CCM and CSI drivers for each actual provider |

## Minimum deployment test scope

Before production use, test cluster bootstrap, node join and restart, API health, scheduler/controller convergence, pod networking and DNS, service routing, storage attach/mount, admission and network policy, control-plane and etcd backup/restore, node drain, and rollback to the previous deployment artifact. Only provider-specific paths actually used by the target environment need provider integration tests.
