#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_root}"

review_expires='2026-09-15T00:00:00Z'
test "$(date -u +%s)" -lt "$(date -u -d "${review_expires}" +%s)"

jq -e --arg expires "${review_expires}" '
  .["x-pasturestack-expires"] == $expires and
  (.statements | length == 2) and
  ([.statements[].vulnerability.name] | sort == ["CVE-2026-69247", "CVE-2026-69249"]) and
  ([.statements[] | select(
    .vulnerability.name == "CVE-2026-69247" and
    .products == [{"@id": "pkg:pypi/cryptography@48.0.1"}] and
    .status == "not_affected" and
    .justification == "vulnerable_code_not_in_execute_path"
  )] | length == 1) and
  ([.statements[] | select(
    .vulnerability.name == "CVE-2026-69249" and
    .products == [{"@id": "pkg:pypi/cryptography@48.0.1"}] and
    .status == "not_affected" and
    .justification == "vulnerable_code_not_in_execute_path" and
    (.impact_statement | contains("<49.0.0")) and
    (.impact_statement | contains("48.0.1")) and
    (.impact_statement | contains("PolicyBuilder")) and
    (.impact_statement | contains("2026-09-15"))
  )] | length == 1)
' security/openvex.json >/dev/null

grep -Fq 'CVE-2026-69249' SECURITY.md
grep -Fq '<49.0.0' SECURITY.md
grep -Fq 'cryptography 48.0.1' SECURITY.md
grep -Fq 'vulnerable_code_not_in_execute_path' SECURITY.md
grep -Fq '2026-09-15T00:00:00Z' SECURITY.md

grep -Fq 'CVE-2026-69247' package/verify-azure-python-security
grep -Fq 'CVE-2026-69249' package/verify-azure-python-security
grep -Fq 'VEX_REVIEW_EXPIRES_UTC' package/verify-azure-python-security
grep -Fq 'VEX_REVIEW_EXPIRES = "2026-09-15T00:00:00Z"' package/verify-azure-python-security
grep -Fq 'cryptography.x509.verification' package/verify-azure-python-security
grep -Fq 'build_server_verifier' package/verify-azure-python-security

workflow=.github/workflows/security-release-gate.yml
grep -Fq 'reviewed_69249_exact' "${workflow}"
grep -Fq 'unexpected_reviewed_vulnerability_findings' "${workflow}"
grep -Fq '.unexpected_reviewed_vulnerability_findings["CVE-2026-69249"] == 0' "${workflow}"
grep -Fq '(.reviewed_vulnerabilities | has("CVE-2026-69249"))' "${workflow}"
if grep -Fq 'scanner_out_of_range_findings' "${workflow}"; then
  echo "KUBERNETES_PACKAGE_STALE_OUT_OF_RANGE_CLASSIFICATION_PRESENT" >&2
  exit 1
fi

echo "KUBERNETES_PACKAGE_SECURITY_ADVISORY_CLASSIFICATION_OK"
