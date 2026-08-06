# Security Policy

## Supported state

The published image is a compatibility candidate for isolated Catalog integration testing. It is not a general-purpose Kubernetes distribution. The image is highly privileged and must not be tested on a workstation or production host.

## Security boundaries

- Build only in the isolated VM environment with disposable state.
- Verify every downloaded artifact by immutable version and checksum before publication.
- Block publication when the exact candidate contains an applicable HIGH or CRITICAL vulnerability or a detected secret. A scanner finding may be resolved only by a source-linked, machine-readable VEX statement with reproducible evidence.
- Do not commit API keys, certificates, kubeconfigs, bootstrap material, private registries, endpoints, or live metadata.
- Quote credentials and URLs, fail closed on HTTP errors, and keep certificate archives outside logs.
- Treat host mounts, cgroups, Docker socket access, kernel modules, firewall rules, and control-plane credentials as privileged interfaces.
- Review the exact final image filesystem, configuration, layers, SBOM, and third-party legal files before distribution.
- Run the Helm 2 compatibility server only as the dedicated UID and service account. Its compatibility role intentionally omits privilege-binding, escalation, impersonation, bulk deletion, certificate approval, and non-resource URL verbs. Charts can still create privileged workloads, so restrict Catalog authors and plan a separate Helm 3 migration.
- Never use `replace --force` or `helm init --upgrade` for the Tiller transition. Create and checksum an offline release-data bundle outside the source tree, use a rolling Deployment update, verify canonical record content, and roll back the Deployment revision on failure.
- Treat every `scripts/tiller-release-backup` bundle as sensitive cluster data: keep its directory at mode `0700`, files at mode `0600`, store it offline with restricted access, and never commit or upload it. The tool deliberately provides no automatic restore operation.
- Keep the Azure CLI Python dependency set internally consistent. Azure CLI 2.89.0 pins MSAL 1.36.0, which requires `cryptography <49`, so the image pins `cryptography 48.0.1` with `pyOpenSSL 26.2.0` and makes `pip check` a release-blocking build step. Do not override those constraints without a supported Azure CLI release and Azure integration tests.

## Current VEX review

The release-specific machine-readable assessment is stored in [`security/openvex.json`](security/openvex.json).

- `CVE-2026-69249` does not affect the packaged `cryptography 48.0.1`; the reviewed GitHub advisory defines the affected range as `<=48.0.0`. A scanner that reports 48.0.1 is using an overbroad affected range.
- `CVE-2026-69247` affects the PKCS#7 `EnvelopedData` decryption APIs. The compatibility image does not expose a PKCS#7 decryption service, and an exact-filesystem search confirms that Azure CLI, MSAL, and all other packaged Python consumers have no calls to `pkcs7_decrypt_der`, `pkcs7_decrypt_pem`, or `pkcs7_decrypt_smime` outside the `cryptography` package itself.
- Re-run the raw vulnerability scan and the same scan with `--vex security/openvex.json` for every rebuilt image. If a new caller appears or Azure CLI adopts a compatible fixed dependency set, this assessment must be replaced rather than carried forward unchanged.

## Reporting

Report suspected vulnerabilities through this repository's private security advisory channel. Do not include live credentials, certificates, or cluster data in a public issue.
