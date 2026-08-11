# Security Policy

## Supported state

The reviewed image is a compatibility candidate for isolated Catalog integration testing. It is not a general-purpose Kubernetes distribution. The image is highly privileged and must not be tested on a workstation or production host.

## Security boundaries

- Build only in the manually dispatched GitHub security gate or an isolated environment with disposable state.
- Verify every downloaded artifact by immutable version and checksum before publication.
- Block publication when the exact candidate contains an applicable HIGH or CRITICAL vulnerability or a detected secret. A scanner finding may be resolved only by a source-linked, machine-readable VEX statement with reproducible evidence.
- Do not commit API keys, certificates, kubeconfigs, bootstrap material, private registries, endpoints, or live metadata.
- Quote credentials and URLs, fail closed on HTTP errors, and keep certificate archives outside logs.
- Treat host mounts, cgroups, Docker socket access, kernel modules, firewall rules, and control-plane credentials as privileged interfaces.
- Review the exact final image filesystem, configuration, layers, SBOM, and third-party legal files before distribution.
- Require kubelet, kube-proxy, kube-apiserver, kube-controller-manager, kube-scheduler, and kubectl to be rebuilt from the locked compatibility source and to report the same numeric `v1.12.11` build version. Do not ship inherited branded version metadata.
- Rebuild the CNI plug-ins `v1.9.1` loopback executable twice from its checksum-locked official source commit with Go 1.26.5, require byte-identical output, and retain the verified Apache-2.0 license in the image. Reject the inherited prebuilt archive and unexpected compiler metadata.
- Run the Helm 2 compatibility server only as the dedicated UID and service account. Its compatibility role intentionally omits privilege-binding, escalation, impersonation, bulk deletion, certificate approval, and non-resource URL verbs. Charts can still create privileged workloads, so restrict Catalog authors and plan a separate Helm 3 migration.
- Never use `replace --force` or `helm init --upgrade` for the Tiller transition. Create and checksum an offline release-data bundle outside the source tree, use a rolling Deployment update, verify canonical record content, and roll back the Deployment revision on failure.
- Never grant a shared add-on service account `cluster-admin`. Kubernetes DNS uses the Kubernetes 1.12 bootstrap `system:kube-dns` role with the dedicated `kube-system/kube-dns` service account, preserves the existing Service cluster IP, refuses unrecognized or newer image replacement, and restores both the prior Deployment revision and Service routing on failure.
- Build the etcd integration image from its exact public source commit and Git tree in runner-temporary storage. Verify numeric version, source revision, upstream version, non-root identity, CycloneDX contents, and zero applicable HIGH/CRITICAL or secret findings before starting the Kubernetes API Server with `--storage-backend=etcd3`. Never substitute a floating image tag or treat this isolated test as live data-conversion evidence.
- Never automatically delete or force-replace historical Dashboard, Heapster, Grafana, or InfluxDB resources. Report them for an operator-controlled data and dependency review. Treat a pre-existing `addons-binding` as a high-priority manual access review.
- Treat every `scripts/tiller-release-backup` bundle as sensitive cluster data: keep its directory at mode `0700`, files at mode `0600`, store it offline with restricted access, and never commit or upload it. The tool deliberately provides no automatic restore operation.
- Keep the Azure CLI Python dependency set internally consistent. Azure CLI core 2.89.0 requires MSAL 1.36.0, and the supported MSAL and pyOpenSSL set requires `cryptography <49`. The image therefore installs checksum-verified `cryptography 48.0.1` and `pyOpenSSL 26.2.0` wheels without invoking a network package resolver. Exact distribution checks, `pip check`, advisory-range classification, reviewed vulnerable-API reachability checks, and the Azure command paths used by this package are release-blocking. Move to the fixed cryptography series only when a published Azure CLI dependency set supports it.

## Current vulnerability disposition

The runtime assessment is stored in [`security/openvex.json`](security/openvex.json). The build-environment assessment is generated deterministically from [`security/dapper-linux-libc-dev-reviewed-cves.txt`](security/dapper-linux-libc-dev-reviewed-cves.txt) and the exact Ubuntu package version in [`package/ubuntu-apt.lock`](package/ubuntu-apt.lock).

- `CVE-2026-69249` affects `cryptography <=48.0.0`; the first fixed version is 49.0.0. The exact installed `cryptography 48.0.1` is outside that affected range, so its VEX statement uses `vulnerable_code_not_present`. The release gate permits no scanner record for another package or version under this identifier and does not require an out-of-range scanner finding to exist.
- `CVE-2026-69247` affects PKCS#7 `EnvelopedData` decryption APIs. The image does not expose a PKCS#7 decryption service, and the same gate finds no external call to `pkcs7_decrypt_der`, `pkcs7_decrypt_pem`, or `pkcs7_decrypt_smime`.
- Ubuntu `linux-libc-dev` 7.0.0-29.29 is an exact, build-only dependency of the C toolchain. Its 46 reviewed HIGH/CRITICAL scanner records describe executable Linux kernel subsystems, while this package contains only development headers under `/usr/include` and documentation under `/usr/share/doc/linux-libc-dev`. The Dapper build verifies that path boundary, rejects executable header files, records the complete package path inventory, and contains no Ubuntu kernel binary or module. The generated OpenVEX document applies only to the exact Ubuntu package PURL and the explicitly reviewed CVE list.
- Every run retains both unfiltered and applicable scans and separately blocks applicable HIGH/CRITICAL findings after OpenVEX. It also requires every build-environment VEX entry to be present in the raw scan, so stale or newly reported findings stop the gate for review. If an affected call path appears, the package contents change, or a compatible fixed dependency set becomes available, replace the assessment instead of carrying it forward.
- The single cluster DNS candidate is built reproducibly and scanned independently from the package image. Publication is blocked unless its checksum-verified source and reviewed patch produce the recorded binary twice, it runs as non-root against the isolated Kubernetes 1.12 API, answers the test Service record, exposes readiness and metrics, stays within the bootstrap DNS authorization boundary, and has no HIGH/CRITICAL vulnerability or detected secret. No VEX exception is accepted for this image.

## Reporting

Report suspected vulnerabilities through this repository's private security advisory channel. Do not include live credentials, certificates, or cluster data in a public issue.
