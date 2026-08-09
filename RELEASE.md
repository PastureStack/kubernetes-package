# Release Review

This repository has no automatic publishing behavior. The manually dispatched security release gate builds and scans candidate `v1.12.11`, retains its evidence for seven days, and never pushes an image, creates a tag, or deploys a service. Candidate artifacts may be published only after the exact image passes the package gates below. A Catalog release remains blocked until the integration gates also pass.

## Package gates

1. Every downloaded Kubernetes, CNI, Docker, Azure CLI, Python wheel, and add-on source or artifact used by the package has a verified upstream source, immutable version, checksum, and license record. Ubuntu packages resolve through snapshot `20260808T000000Z` with every direct package at an exact version.
2. The exact image has a CycloneDX SBOM and reviewed third-party notice inventory.
3. Two clean output builds from the same reviewed source, version file, source date, and immutable compiler image produce byte-identical kubelet, kube-proxy, kube-apiserver, kube-controller-manager, kube-scheduler, and kubectl binaries, all reporting the same numeric build version. Two Go 1.26.5 builds from the locked CNI source commit also produce one byte-identical loopback executable.
4. Static shell validation, image build, binary version and compiler-metadata checks, secret scanning, raw vulnerability reports, and the blocking applicable HIGH/CRITICAL scans pass for both the candidate and its Dapper build environment. Each VEX entry must match the exact package, remain present in the raw scan, and have a release-blocking reachability or package-boundary test.
5. The kubelet creates, runs, logs, stops, and removes the supplied static Pod on the supported Docker and cgroup environment without restarts; direct loopback CNI `ADD`/`DEL` also succeeds.
6. CPU, memory, I/O, and writable-layer statistics become meaningful within the bounded observation window and agree with Docker for the same workload. The gate must also reproduce the known failure on the previous release.
7. No personal registry, workstation path, credential, private endpoint, or staging namespace appears in the image configuration, filesystem, SBOM, documentation, or repository tree.
8. The operator has created and verified an offline Helm 2 release-data bundle, compared it with the live cluster immediately before the change, and recorded only the non-sensitive checksum and record counts in private release evidence.
9. The cluster DNS `1.26.9` candidate is rebuilt twice from the checksum-verified source revision and reviewed patch with byte-identical output. Its single non-root image must pass independent HIGH/CRITICAL and secret scans without VEX, Kubernetes 1.12 API discovery, DNS resolution, readiness, metrics, exact bootstrap-role authorization checks, rolling upgrade, rollback, and Service cluster-IP preservation.
10. The current image contains no Dashboard, Heapster, Grafana, or InfluxDB deployment template and the updater proves that detected historical resources are not deleted or force-replaced.

## Catalog integration gates

1. Control-plane, worker, certificate, metadata, and authentication-bridge services pass in the isolated VM environment.
2. Required add-ons have verified images, provenance, licenses, and runtime tests.
3. Installation, host join, restart, upgrade, rollback, and complete deletion pass through the Catalog UI and API.
4. The Catalog uses a semantic image tag only; immutable digests remain in private release evidence and never appear in the UI value.

The historical release procedure remains available in preserved upstream Git history. It is not copied into the current tree because its repositories, image names, and automation are not valid PastureStack release instructions.
