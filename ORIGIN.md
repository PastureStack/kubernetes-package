# Origin and Attribution

This repository preserves the history of [`rancher/kubernetes-package`](https://github.com/rancher/kubernetes-package).

- Preserved upstream boundary: `613c7b8cabf3eded6bddfdea6712e0e60aa3c269`
- Boundary author: Alena Prokharchyk
- Boundary date: 2019-03-25
- Inherited license: Apache License 2.0

PastureStack claims only its later modifications and does not imply affiliation with the original maintainers, Rancher Labs, or SUSE.

## Current external sources

### Kubernetes

- Project: [`kubernetes/kubernetes`](https://github.com/kubernetes/kubernetes)
- Tag: `v1.36.4`
- Commit: `bb826b1d48562f110659e64e8ec444327433db95`
- Source archive SHA-256: `3c28f11492472df48e658551bf268fd92938b127b0f9dcef7090ac800318c821`
- License SHA-256: `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`
- Build-time dependency overrides: OpenTelemetry `v1.45.0`, OpenTelemetry gRPC instrumentation `v0.70.0`, gRPC-Go `v1.83.1`, `cel.dev/cel-go` `v0.32.0`, etcd `v3.7.1`, `go.etcd.io/raft/v3` `v3.7.0`, `x/crypto` `v0.55.0`, and `x/sys` `v0.47.0`

### CNI plug-ins

- Project: [`containernetworking/plugins`](https://github.com/containernetworking/plugins)
- Tag: `v1.9.1`
- Commit: `adc3e6b5b581638afbd194cf2e9319ecbb0151a1`
- Git tree: `91451a8931a305da27de4df81662ec08af58249e`
- License SHA-256: `b40930bbcf80744c86c46a12bc9da056641d722716c378f5659b9e555ef833e1`
- Dependency override: `x/sys` `v0.47.0`

The build pins Go by exact image digest and copies its CA bundle into a package-free `scratch` runtime. Trivy is installed and checksum-verified by the release workflow. Their upstream licenses remain authoritative.
