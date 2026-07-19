# Release Review

This migration repository does not contain CI/CD or automatic release behavior. Candidate artifacts may be published only after the exact image passes the package gates below. A Catalog release remains blocked until the integration gates also pass.

## Package gates

1. Every downloaded Kubernetes, CNI, Docker, and add-on artifact used by the package has a verified upstream source, immutable version, checksum, and license record.
2. The exact image has a CycloneDX SBOM and reviewed third-party notice inventory.
3. Static shell validation, image build, binary version checks, and blocking HIGH/CRITICAL vulnerability and secret scans pass.
4. The kubelet creates, runs, logs, stops, and removes the supplied static Pod on the supported Docker and cgroup environment without restarts.
5. No personal registry, workstation path, credential, private endpoint, or staging namespace appears in the image configuration, filesystem, SBOM, documentation, or repository tree.

## Catalog integration gates

1. Control-plane, worker, certificate, metadata, and authentication-bridge services pass in the isolated VM environment.
2. Required add-ons have verified images, provenance, licenses, and runtime tests.
3. Installation, host join, restart, upgrade, rollback, and complete deletion pass through the Catalog UI and API.
4. The Catalog uses a semantic image tag only; immutable digests remain in private release evidence and never appear in the UI value.

The historical release procedure remains available in preserved upstream Git history. It is not copied into the current tree because its repositories, image names, and automation are not valid PastureStack release instructions.
