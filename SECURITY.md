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

## Reporting

Report suspected vulnerabilities through this repository's private security advisory channel. Do not include live credentials, certificates, or cluster data in a public issue.
