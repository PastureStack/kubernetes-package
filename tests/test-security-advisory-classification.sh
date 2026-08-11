#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_root}"

jq -e '
  .statements | length == 2 and
  ([.[].vulnerability.name] | sort == ["CVE-2026-69247", "CVE-2026-69249"]) and
  ([.[] | select(
    .vulnerability.name == "CVE-2026-69247" and
    .products == [{"@id": "pkg:pypi/cryptography@48.0.1"}] and
    .status == "not_affected" and
    .justification == "vulnerable_code_not_in_execute_path"
  )] | length == 1) and
  ([.[] | select(
    .vulnerability.name == "CVE-2026-69249" and
    .products == [{"@id": "pkg:pypi/cryptography@48.0.1"}] and
    .status == "not_affected" and
    .justification == "vulnerable_code_not_present" and
    (.impact_statement | contains("<=48.0.0")) and
    (.impact_statement | contains("48.0.1")) and
    (.impact_statement | contains("49.0.0"))
  )] | length == 1)
' security/openvex.json >/dev/null

grep -Fq 'CVE-2026-69249' SECURITY.md
grep -Fq '<=48.0.0' SECURITY.md
grep -Fq 'cryptography 48.0.1' SECURITY.md
grep -Fq 'vulnerable_code_not_present' SECURITY.md

grep -Fq 'CVE-2026-69247' package/verify-azure-python-security
if grep -Fq 'CVE-2026-69249' package/verify-azure-python-security; then
  echo "KUBERNETES_PACKAGE_OUT_OF_RANGE_ADVISORY_HAS_REACHABILITY_CHECK" >&2
  exit 1
fi

workflow=.github/workflows/security-release-gate.yml
grep -Fq 'scanner_out_of_range_findings' "${workflow}"
grep -Fq 'select(.VulnerabilityID == "CVE-2026-69249" and .PkgName == "cryptography" and .InstalledVersion == "48.0.1")' "${workflow}"
grep -Fq '.scanner_out_of_range_findings["CVE-2026-69249"].unexpected == 0' "${workflow}"
if grep -Fq '.reviewed_vulnerabilities["CVE-2026-69249"] >= 1' "${workflow}"; then
  echo "KUBERNETES_PACKAGE_OUT_OF_RANGE_ADVISORY_REQUIRED_IN_RAW_SCAN" >&2
  exit 1
fi

echo "KUBERNETES_PACKAGE_SECURITY_ADVISORY_CLASSIFICATION_OK"
