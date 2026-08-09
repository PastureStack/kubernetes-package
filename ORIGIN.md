# Origin and Attribution

This repository is a GitHub fork of `https://github.com/rancher/kubernetes-package`.

- Preserved upstream boundary: `613c7b8cabf3eded6bddfdea6712e0e60aa3c269`
- Boundary author: Alena Prokharchyk
- Boundary date: 2019-03-25
- Migration model: unchanged upstream history followed by one PastureStack maintenance commit

The original commit identifiers, authors, dates, tags, copyright notices, and root Apache-2.0 license remain authoritative for inherited work. External Kubernetes, CNI, Ubuntu, Docker, Helm, and add-on components retain their own provenance and legal terms. PastureStack claims only its subsequent modifications and does not imply affiliation with the original maintainers.

The cluster DNS `1.26.9` candidate is derived from the Kubernetes project
repository [`kubernetes/dns`](https://github.com/kubernetes/dns), exact revision
`c3ddef3eb784fd06be17fd056acc79f2a6d709ce`, under Apache License 2.0. That
revision is the verified head of an upstream dependency-update proposal, not a
Kubernetes project release tag or an assertion of upstream acceptance. The
build verifies the source archive and license checksums, applies the recorded
PastureStack compatibility patch, compiles twice with the locked toolchain, and
packages only the cluster DNS binary and upstream license in a non-root image.
PastureStack claims only its patch and packaging work. Historical Dashboard,
Heapster, Grafana, InfluxDB, DNS cache, and DNS monitoring-sidecar templates
remain available in preserved Git history but are deliberately absent from the
maintained tree.
