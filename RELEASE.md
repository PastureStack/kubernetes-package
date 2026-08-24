# Release Process

The repository never pushes an image, creates a tag, or deploys a cluster automatically.

A `v1.36.4` release candidate is acceptable only when:

1. the worktree is clean and the single annotated numeric tag at `HEAD` is `v1.36.4`;
2. `bash scripts/validate` passes with no active legacy path;
3. the official Kubernetes source archive and license match their committed SHA-256 values, while the CNI tag matches the committed Git commit, tree and license SHA-256;
4. every shipped Kubernetes component reports `v1.36.4` and every Go binary records Go `1.27.0`;
5. the `scratch` rootfs inventory contains only the intended payload and no shell, package manager, removed tool, or legacy server;
6. the exact image has zero actionable Trivy vulnerabilities at every severity and zero detected secrets; any VEX entry is backed by a build-time package-reachability proof and the raw result remains published;
7. the exact image inspect data, raw and VEX-aware Trivy JSON, OpenVEX statement, CycloneDX SBOM, rootfs inventory, source revision, image reference, and `SHA256SUMS` are retained together;
8. affected deployment paths listed in `COMPATIBILITY.md` pass their environment-specific tests before any registry promotion or cluster change.

Run the local release gate with:

```sh
bash scripts/release
```

Publishing and deployment remain separate explicitly authorized operations and must use the exact image digest produced from the accepted source revision.
