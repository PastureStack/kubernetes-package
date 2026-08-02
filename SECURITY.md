# Security Policy

## Supported state

The published image is a compatibility candidate for isolated Catalog integration testing. It is not a general-purpose Kubernetes distribution. The image is highly privileged and must not be tested on a workstation or production host.

## Security boundaries

- Build only in the isolated VM environment with disposable state.
- Verify every downloaded artifact by immutable version and checksum before publication.
- Block publication when the exact candidate contains a HIGH or CRITICAL vulnerability or a detected secret.
- Do not commit API keys, certificates, kubeconfigs, bootstrap material, private registries, endpoints, or live metadata.
- Quote credentials and URLs, fail closed on HTTP errors, and keep certificate archives outside logs.
- Treat host mounts, cgroups, Docker socket access, kernel modules, firewall rules, and control-plane credentials as privileged interfaces.
- Review the exact final image filesystem, configuration, layers, SBOM, and third-party legal files before distribution.
- Run the Helm 2 compatibility server only as the dedicated UID and service account. Its compatibility role intentionally omits privilege-binding, escalation, impersonation, bulk deletion, certificate approval, and non-resource URL verbs. Charts can still create privileged workloads, so restrict Catalog authors and plan a separate Helm 3 migration.
- Never use `replace --force` or `helm init --upgrade` for the Tiller transition. Snapshot release objects first, use a rolling Deployment update, verify the preserved record set, and roll back the Deployment revision on failure.
- Keep the Azure CLI Python dependency set internally consistent. The current MSAL release requires `cryptography <49`, so the image pins `cryptography 48.0.1` with `pyOpenSSL 26.2.0` and makes `pip check` a release-blocking build step.

## Reporting

Report suspected vulnerabilities through this repository's private security advisory channel. Do not include live credentials, certificates, or cluster data in a public issue.
