# Release Review

This migration repository does not contain CI/CD or automatic release behavior. Candidate artifacts may be published only after the exact image passes the package gates below. A Catalog release remains blocked until the integration gates also pass.

## Package gates

1. Every downloaded Kubernetes, CNI, Docker, and add-on artifact used by the package has a verified upstream source, immutable version, checksum, and license record.
2. The exact image has a CycloneDX SBOM and reviewed third-party notice inventory.
3. Two network-isolated builds from the same reviewed source, version file, source date, and immutable compiler image produce byte-identical kubelet binaries.
4. Static shell validation, image build, binary version checks, and blocking HIGH/CRITICAL vulnerability and secret scans pass.
5. The kubelet creates, runs, logs, stops, and removes the supplied static Pod on the supported Docker and cgroup environment without restarts; direct loopback CNI `ADD`/`DEL` also succeeds.
6. CPU, memory, I/O, and writable-layer statistics become meaningful within the bounded observation window and agree with Docker for the same workload. The gate must also reproduce the known failure on the previous release.
7. No personal registry, workstation path, credential, private endpoint, or staging namespace appears in the image configuration, filesystem, SBOM, documentation, or repository tree.
8. The operator has created and verified an offline Helm 2 release-data bundle, compared it with the live cluster immediately before the change, and recorded only the non-sensitive checksum and record counts in private release evidence.

## Catalog integration gates

1. Control-plane, worker, certificate, metadata, and authentication-bridge services pass in the isolated VM environment.
2. Required add-ons have verified images, provenance, licenses, and runtime tests.
3. Installation, host join, restart, upgrade, rollback, and complete deletion pass through the Catalog UI and API.
4. The Catalog uses a semantic image tag only; immutable digests remain in private release evidence and never appear in the UI value.

The historical release procedure remains available in preserved upstream Git history. It is not copied into the current tree because its repositories, image names, and automation are not valid PastureStack release instructions.
