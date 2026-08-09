### Maintained add-on images

The package manages only the cluster services that remain necessary for the
recorded compatibility path:

- Kubernetes DNS:
  - `ghcr.io/pasturestack/cluster-dns:1.26.9`
- Helm 2 compatibility server:
  - `ghcr.io/pasturestack/tiller:v2.17.1`

The visible DNS reference uses a numeric semantic tag so the management
interface remains readable; immutable build and scan evidence stays outside
the user-facing value. The candidate is rebuilt from
[`kubernetes/dns`](https://github.com/kubernetes/dns) revision
`c3ddef3eb784fd06be17fd056acc79f2a6d709ce`, under Apache License 2.0, plus the
recorded compatibility patch. This revision is the verified head of an
upstream dependency-update proposal and is not represented as an upstream
release. The image contains only the cluster DNS binary and upstream license,
runs as non-root, and omits the legacy cache and monitoring sidecars. The
dedicated `kube-dns` service account uses the Kubernetes 1.12 bootstrap role to
list and watch only Services and Endpoints; it is not bound to `cluster-admin`.
This repository's review gate builds and validates the candidate but does not
publish it.

The host loopback plug-in is separately sourced from the official CNI plug-ins
`v1.9.1` release. Its release archive, source commit, and Apache-2.0 license are
checksum-locked and retained in the package image.

The current tree intentionally does not package or automatically deploy the
historical Dashboard, Heapster, Grafana, or InfluxDB manifests. Existing
resources are detected and preserved without mutation. Operators must review
their data, consumers, access controls, and replacement plan before removing
them manually. The updater also reports a pre-existing `addons-binding` so an
obsolete shared `cluster-admin` grant is not silently carried forward.

The Helm 2 compatibility path updates Tiller with a rolling Deployment and
verifies that every pre-existing ConfigMap or Secret release record remains
present. Its dedicated service account may create ordinary Kubernetes
resources for charts, but it is not granted `bind`, `escalate`, `impersonate`,
`deletecollection`, certificate approval, or non-resource URL permissions.
