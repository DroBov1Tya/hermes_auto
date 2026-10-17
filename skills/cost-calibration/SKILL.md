---
name: cost-calibration
description: Measure and improve model routing using task outcomes, token usage, latency, and review quality; use when model tiers are often over-selected or routing policy needs evidence-based tuning.
metadata:
  hermes:
    tags: [routing, cost, evaluation, tokens]
    related_skills: [task-decompose, agent-router]
---

# Cost Calibration

Use observed task outcomes to tune model and reasoning-effort selection. Optimize for the lowest total cost that meets the agreed quality and coverage criteria, not for the lowest token count in isolation. Do not change provider settings or paid limits without user authorization.

## Collect comparable observations

For each completed task where metrics are available, capture a compact record:

- task class and `R/U/C` complexity level;
- requested and actually used model/provider and reasoning effort;
- input tokens, cached input tokens, output/reasoning tokens, retries, tool calls, cost, and elapsed time;
- acceptance result, reviewer corrections, material omissions, and whether escalation was necessary;
- scope/coverage indicator that makes the quality result interpretable.

Mark unavailable metrics as `unknown`. Do not estimate exact per-task cost from an aggregate total unless the accounting method supports that attribution. Do not store prompts, secrets, personal data, or full transcripts as calibration data.

## Compare safely

1. Group only similar tasks with comparable acceptance criteria and scope. Keep research, implementation, review, and tool-heavy automation separate.
2. Compare total cost and latency alongside quality: acceptance rate, substantive reviewer corrections, retries, and coverage. Cached and uncached tokens have different cost implications; use provider billing data when available.
3. Use enough repeated examples to identify a pattern. Treat one success or failure as a case to inspect, not a policy update. Exclude provider outages, missing permissions/tools, malformed briefs, and unrelated scope changes from model-capability conclusions.
4. Tune one routing decision at a time: model tier, effort, delegation count, context size, or output cap. Do not change several variables and then attribute the result to one of them.
5. Prefer a bounded, reversible pilot on representative tasks. Preserve required independent review and acceptance criteria. Stop if quality or coverage falls below the agreed threshold.
6. Recommend a routing change with the observed sample, comparison method, uncertainty, and rollback condition. Apply changes only through an authorized runtime configuration. A skill cannot enforce per-task model selection if the agent API does not expose it.

## Interpret failures correctly

- **Capability failure:** the model receives valid tools, sufficient context, and a clear brief but makes a material reasoning error. Consider one measured step up in tier or effort.
- **Brief/context failure:** missing or conflicting inputs, unclear success criteria, or oversized/inherited context. Fix the task contract before changing models.
- **Tool/environment failure:** unavailable tool, provider error, denied permission, timeout, or bad schema. Resolve or report the blocker; do not infer that a stronger model is needed.
- **Coordination failure:** duplicate work, too many workers, costly handoffs, or oversized summaries. Adjust decomposition and delegation before model tier.
- **Quality-control failure:** unsupported claims or missed counterevidence. Improve evidence requirements and review; do not automatically send all tasks to Frontier.

## Persist and report

Store aggregate patterns and approved routing decisions in the configured project memory/state store, if available. Keep per-run raw metrics in an approved local artifact or analytics store. If there is no reliable telemetry or state backend, provide a proposed measurement plan and do not claim savings.

Report the baseline, comparison window, task mix, model/effort changes, cost and latency, quality/coverage changes, sample limitations, and rollback trigger. Never promise savings before comparable measurements support them.
