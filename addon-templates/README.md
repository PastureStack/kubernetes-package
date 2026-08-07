### Addon Images

The following images are used by kubernetes addons:
- Kubernetes dashboard:
    - kubernetes-dashboard-amd64:v1.8.3
- Kube-dns:
    - k8s-dns-kube-dns-amd64:1.14.13
    - k8s-dns-dnsmasq-nanny-amd64:1.14.13
    - k8s-dns-sidecar-amd64:1.14.13
- Heapster:
    - heapster-grafana-amd64:v4.4.3
    - heapster-amd64:v1.5.4
    - heapster-influxdb-amd64:v1.3.3
- Helm:
    - ghcr.io/pasturestack/tiller:v2.17.0-pasturestack.2

The Helm 2 compatibility path updates Tiller with a rolling Deployment and
verifies that every pre-existing ConfigMap or Secret release record remains
present. Its dedicated service account may create ordinary Kubernetes
resources for charts, but it is not granted `bind`, `escalate`, `impersonate`,
`deletecollection`, certificate approval, or non-resource URL permissions.
