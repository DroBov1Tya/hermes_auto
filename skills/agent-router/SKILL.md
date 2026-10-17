---
name: agent-router
description: Route bounded tasks to the cheapest available worker model and reasoning effort that can reliably complete them. Use task-decompose for multi-step plans; escalate only after a demonstrated capability miss.
---

# Agent Router

Select the lowest-cost available model that is likely to meet the task's reasoning requirement. Select reasoning effort separately. Treat risk and verification as controls, not as automatic reasons to use the most capable model.

## 0. Preconditions

- For a multi-step task, use `task-decompose` first unless a scored plan already exists.
- A manager-only orchestrator delegates execution tasks at every level, including L1. It may do planning, routing, approval checks, and synthesis; it must not execute worker tasks inline.
- Check the tools and call schemas actually exposed by the active runtime. Never invent model names, agent types, effort values, per-task overrides, or tool parameters.
- If the runtime cannot select a model or effort per task, say so accurately. Use configured worker profiles or runtime settings when available; a prompt cannot create a routing control the API does not expose.

## 1. Resolve available tiers once

Inspect documented/runtime-listed options once per session and map them to relative tiers. Do not repeatedly rediscover the same model list. Do not assume that a provider's newest or most capable model is the default choice.

| Tier | Use when | Selection rule |
|---|---|---|
| **Fast** | L1–L2: deterministic tasks, bounded retrieval, mechanical edits, routine checks | Cheapest model that supports the required tools and output |
| **Balanced** | L3 and most L4 work: ordinary engineering, analysis, debugging, bounded security review | General model that meets the success criteria without unnecessary deep reasoning |
| **Frontier** | L5, or rare L4 task with demonstrated need for exceptional reasoning | Use only when the task meets explicit triggers below |

The tier names are relative labels, not model identifiers. Resolve them using the active harness's documented options and pricing/capability information. If no trustworthy ranking exists, do not guess from marketing names; use the currently configured general model and note the uncertainty.

Keep provider/model profiles in trusted runtime configuration. If an agent call accepts a verified per-task model argument, use the resolved profile. If it does not, do not pass a made-up argument or change shared global configuration while concurrent tasks are running.

## 2. Route from the complexity score

Use the `R/U/C` score from `task-decompose`:

| Level | Default tier | Override |
|---|---|---|
| L1 | No worker by default | Manager-only role: delegate to Fast if execution is needed |
| L2 | Fast | Balanced only when a concrete capability/tool constraint requires it |
| L3 | Balanced | Fast for a known, well-bounded subset; Frontier only after explicit trigger |
| L4 | Balanced | Frontier only when the hard-reasoning criteria below are present |
| L5 | Frontier | State the exceptional reasoning requirement; decompose further if possible |

Large scope should be split, bounded, or batched before raising the model tier. Multiple simple independent tasks can use multiple Fast workers when setup and aggregation cost are justified. Never create an agent solely to make a task appear more rigorous.

## 3. Escalate selectively to Frontier

Frontier is justified only when the task requires one or more capabilities that a lower tier has demonstrably failed to provide or that the task clearly demands:

- novel architecture or algorithm design with interacting constraints;
- subtle cross-system failure analysis after the relevant evidence is supplied;
- complex concurrency/distributed consistency reasoning;
- novel cryptographic protocol reasoning (routine use of a vetted library does not qualify);
- a security-critical judgment where plausible alternatives cannot be distinguished by routine evidence or established standards;
- one documented reasoning failure by a well-briefed Balanced worker, after correcting missing context and confirming tools and inputs work.

Do not use Frontier merely because a task is security-related, has high impact, involves many files, requests a review, or previously failed for environmental/briefing reasons. Use risk-based scope limits, an independent reviewer, established checklists, and explicit acceptance criteria instead.

## 4. Reasoning effort

Choose the lowest effort likely to satisfy the task. Start here:

| Level | Default effort |
|---|---|
| L1 | `none` or `low`, if supported |
| L2 | `low` |
| L3 | `medium` |
| L4 | `medium`; `high` only for the hard-reasoning triggers above |
| L5 | `high` or `xhigh`; `max` only when correctness clearly outweighs cost and the runtime supports it |

These are defaults. Use only effort names accepted by the current harness. Do not add effort bonuses for security, high impact, or difficult-to-verify outputs; handle those with review and verification. Frontier plus maximum effort is not a general-purpose “safe” setting.

## 5. Route by task kind

- **Research:** Fast for locating facts and bounded extraction. Use Balanced when interpreting ambiguous or conflicting evidence. Ask for source paths/citations and a concise synthesis.
- **Design:** Balanced for established patterns and bounded choices. Frontier only for a genuinely novel, high-consequence design that meets the criteria above.
- **Implementation:** Route from the affected behavior and reasoning, not file count. Give small, independent changes to Fast; use Balanced for routine multi-file work. Pair security-sensitive changes with a separate reviewer.
- **Review:** Reviewer must be a different agent from the author and receive the acceptance criteria, diff/artifacts, and known risks. Default to the author's tier or one lower for routine checks; never lower than needed to inspect the work. Frontier is reserved for review that itself requires exceptional reasoning. High-risk work always requires independent review, not necessarily Frontier.
- **Verification:** Fast/low for deterministic tests, formatting, and linters. Use Balanced or the author tier to diagnose non-obvious failures. Keep the test standard intact.

If the active agent can call a subagent but cannot select its model, state that the model is inherited/configured. Do not imply the intended tier was enforced when it was not.

## 6. Briefs and context budgets

Every delegated task gets a self-contained brief with objective, relevant verified context, scope, exclusions, skills, available tools, dependencies, acceptance criteria, limits, and return format. Give it only the parent context it needs. Prefer a fresh, concise brief over full transcript inheritance when the runtime supports that choice.

Keep task boundaries disjoint. Do not run parallel workers against shared mutable files, credentials, accounts, sessions, or rate-limited targets unless safe concurrency is established. Use one or two workers initially; expand only when tasks are independent and coordination overhead is justified. Respect configured hard limits and distinguish advisory limits from enforced limits.

Ask workers to return a compact report with evidence references, coverage, caveats, and actual usage metrics if exposed. Keep raw output in artifacts; do not copy large logs or tool outputs into the parent prompt. Consolidate related results before presenting them.

Before spawning, estimate whether the worker's expected token/tool spend and startup/context cost are justified by the task. For a tiny task in a manager-only workflow, use the cheapest worker available and a minimal brief. Never silently perform it in the manager.

## 7. Retry and escalation policy

1. **Missing or unclear brief:** correct the context, scope, and done criteria; retry once at the same tier.
2. **Tool, provider, permission, or environment failure:** fix or report the blocker. Do not raise model tier.
3. **Capability miss:** identify the specific reasoning error, provide missing evidence, and retry once at the same tier if a better brief may resolve it.
4. **Persistent capability miss:** promote by one tier for one retry, if the runtime supports it. Record why the lower tier failed.
5. **Still failing or already at Frontier:** stop, decompose the task, use an appropriate specialist, or report the unresolved issue. Never create an unbounded retry loop.

A request that returns a fluent but unsupported answer is a capability miss only after checking its sources and the quality of the brief. A timeout, transient API error, missing tool, rejected schema, or lack of authorization is not.

## 8. Learn from outcomes without overreacting

Record the selected tier/effort, task level, outcome, escalation reason, and reviewer corrections when this information is available. Adjust future routing only when repeated outcomes show a pattern. One successful task does not prove the tier was excessive; one failure does not prove the model was too weak.

Do not promise token or latency savings without comparable measurements. Count parent and worker usage, cached and uncached input, output/reasoning tokens, retries, tool calls, elapsed time, and result quality. Compare runs with the same scope and acceptance criteria.

## 9. Report routing decisions

For multi-step work, report:

| Task | Level | Tier/effort requested | Actually enforced? | Outcome |
|---|---|---|---|---|

Then summarize any escalation, missing per-task routing support, reviewer coverage, and unresolved risks. Omit the table for a single simple task.
