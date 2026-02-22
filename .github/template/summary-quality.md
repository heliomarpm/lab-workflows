# 🔍 Quality Assurance Report

> **Run:** [#{{RUN_NUMBER}}](https://github.com/{{REPOSITORY}}/actions/runs/{{RUN_ID}}) &nbsp;·&nbsp; **Ref:** `{{REF}}` &nbsp;·&nbsp; **Actor:** `{{ACTOR}}`

## Overall Status: {{OVERALL_STATUS_BADGE}}

---

## 🔍 Stack

| Field | Value |
|---|---|
| Detected Stack | `{{STACK}}` |
| Source | {{STACK_SOURCE}} |

---

## 🧪 Tests

| Field | Value |
|---|---|
| Tests Found | {{TESTS_FOUND_ICON}} |
| Tests Passed | {{TESTS_PASSED_ICON}} |

---

## 📊 Coverage

| Field | Value |
|---|---|
| Current Coverage | {{COVERAGE_PCT}}% |
| Base Branch Coverage | {{BASE_COVERAGE_PCT}} |
| Minimum Required | {{COVERAGE_MIN}}% |
| Mode | `{{COVERAGE_MODE}}` |
| Status | {{COVERAGE_STATUS_ICON}} {{COVERAGE_STATUS_LABEL}} |

> {{COVERAGE_MESSAGE}}

---

## 📝 Conventional Commits

| Field | Value |
|---|---|
| All Commits Valid | {{COMMITS_VALID_ICON}} |
| Total Commits | {{COMMITS_TOTAL}} |
| Invalid Commits | {{COMMITS_INVALID_COUNT}} |
| Mode | `{{COMMITS_MODE}}` |

{{INVALID_COMMITS_SECTION}}

---

## 📦 Contract Artifact

Artifact `{{ARTIFACT_NAME}}` uploaded with the full JSON contract for downstream workflows.

<details>
<summary>View raw contract JSON</summary>

```json
{{CONTRACT_JSON}}
```

</details>