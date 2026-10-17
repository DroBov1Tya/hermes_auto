---
name: evidence-review
description: Independently evaluate findings, claims, and recommendations against primary evidence; use before accepting consequential conclusions, security findings, or delegated work.
metadata:
  hermes:
    tags: [review, evidence, verification, security]
    related_skills: [agent-router, task-decompose]
---

# Evidence Review

Assess whether a specific claim is supported by the available evidence. Review the underlying artifact or a precise excerpt when authorized; a worker's summary is a lead, not proof. Do not expand scope while reviewing.

## Review method

1. Convert each material conclusion into a testable claim. Separate observed facts, inference, and recommendation.
2. Locate the strongest available evidence for and against the claim. Prefer direct artifacts, reproducible outputs, primary sources, and current authoritative references. Preserve source, timestamp/version, location, and collection method.
3. Check that the evidence actually supports the claim at the stated scope. Look for missing preconditions, alternative explanations, stale versions, selection bias, and counterexamples.
4. Reproduce a claim only when the task is authorized, the needed tools are available, and reproduction adds value. Use the smallest safe reproduction. For security issues, follow the engagement scope and stop conditions; do not expand access or impact.
5. Assign a calibrated verdict: `confirmed`, `supported but not reproduced`, `partially supported`, `unsubstantiated`, `refuted`, or `inconclusive`. State confidence as `high`, `medium`, or `low` and explain the main limitation in one sentence.
6. Recommend acceptance, correction, additional evidence, or rejection. For a consequential claim, identify what evidence would change the verdict.

## Security findings

Verify the affected asset and component, required access/preconditions, actual behavior, and impact. Distinguish a theoretical weakness from an observed and reproducible vulnerability. Check counterevidence and existing controls. Use CWE when the weakness class is clear; use CVE only with matching published product/version evidence. Do not infer a CVSS score from severity labels alone; state the version and assumptions.

A review must be independent of the author. If the reviewer lacks access to primary artifacts, say so and limit the verdict to the supplied summary. Do not claim a finding is verified when only a report or screenshot was reviewed.

## Return format

For each claim, return:

| Claim | Verdict | Confidence | Evidence for / against | Limitation | Recommendation |
|---|---|---|---|---|---|

Include artifact references rather than copying long logs. Keep distinct findings separate. State which acceptance criteria passed, failed, or remain inconclusive.
