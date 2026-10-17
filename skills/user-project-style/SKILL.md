---
name: user-project-style
description: Write projects and READMEs in the user's house style.
version: 0.1.0
author: duck (DroBoV1tya), Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [style, rust, architecture, conventions, scaffolding]
    related_skills: []
---

# User Project Style Skill

Codified house style extracted from ~38 hand-written Rust projects
(`~/Documents/Work/projects/rust/{.out,SMK}`: TW_* services, tiktok_*,
xbot, zenith, hackstorage/PentaCore, db_* pipeline, matrix bots, scrapers).
Applies beyond Rust — the rules below are language-agnostic; Rust-specific
glue (deps, profiles, crate layout) is marked `rust`.

## When to Use
- Writing ANY new project, service, CLI, scraper, bot, or data pipeline for this user.
- Reviewing code for conformance to the user's style.
- Scaffolding a repo from scratch (copy the skeleton in `references/scaffolds.md`).

Don't use for: library/SDK design for other people, academic/CS-thesis code,
or when the user explicitly asks for "textbook/idiomatic" (then prefer
`?`-propagation, thiserror, no emoji logs — the user's cleanest toy
`perlin_demo` is the model).

## Module Map (load what you need)
| Concern | File |
|---|---|
| Project/crate layout, module layers, main.rs shape, config/args/constants triad | `references/project-structure.md` |
| Function style: error handling, unwrap policy, early returns, long orchestration fns | `references/function-style.md` |
| Naming conventions, section comments, kept typos | `references/naming-and-comments.md` |
| Logging: emoji tag system, RU "Действие/Статус/Результат" template, banner art | `references/logging.md` |
| Concurrency: Semaphore+spawn fan-out, JoinSet, channels, select! ctrl_c, graceful shutdown | `references/concurrency.md` |
| Build profiles, jemalloc/obfstr, dep versions, secrets handling | `references/build-and-deps.md` |
| Copy-paste scaffolds: logger, Application::build/run, storage init, MQ consumer, clap args | `references/scaffolds.md` |

Load a module with `skill_view(name='user-project-style', file_path='references/<file>.md')`.

## Core Invariants (always in effect, language-agnostic)
1. **Thin orchestrator `main`.** 10–40 lines: init logger → parse args → build app → run. All logic delegated to one `Application`/`Runner`/`start()` entry. Rust: `#[tokio::main] async fn main() -> Result<()>` (or `Box<dyn Error>` in older style).
2. **`config.rs` / `args.rs` / `constants.rs` triad.** `config::init_logger()` is the FIRST call in main. `constants.rs` holds SCREAMING_SNAKE magic numbers + hardcoded infra secrets (LAN DSNs, tokens). `args.rs` = CLI parse, free fn `parse_args()` returning a struct.
3. **Strict concern separation into named layers.** Typical: `config` → `storage` (one `init.rs` per DB) → `mq`/`bridge` (fan-in/out) → `core`/`services` (business) → `app`/`agent` (orchestration). Modules are directories with `mod.rs`, or a bare `mod_name.rs` barrel + subfiles. A `bridge/` module is the façade between UI/bot and DB/network.
4. **Shared state as `Arc<T>` threaded through layers.** Clone before every `tokio::spawn`. Client wrappers are tiny structs: `MongoClient { pub conn }` exposing the raw client.
5. **Copy-paste reuse over abstraction.** Reused blocks (logger, DB connector, config secrets, clap command) are copied verbatim between projects; crate/clap names often stay stale (`DBMorph`, `brutter`, author `DroBoV1tya`). Known typos are kept as-is (`inpun_file_type`, `maticore_send`, `enviropmets`, `succesful`) — don't rename without asking.
6. **Skeleton-first.** Start with the full module tree; empty stub files (0 bytes / blank) are acceptable placeholders. Commented-out code blocks are left in place as future work.
7. **Pragmatic, not production-grade, hardening.** Secrets committed in consts; `unwrap()`/`expect()` accepted at startup and fire-and-forget sites; `obfstr` + jemalloc declared as planned binary hardening.

## Rust Quick Stack (the recurring Cargo.toml core)
```
anyhow, tokio { full }, tracing, tracing-subscriber,
serde { derive }, serde_json, reqwest { json, rustls|socks },
mongodb, redis { aio, tokio-comp }, sqlx { postgres }, lapin (RabbitMQ),
clap (builder API, NOT derive), colored, obfstr = "0.4.4", rand,
uuid { v4 }, chrono, regex, rusqlite (FTS5), ratatui (TUI), jemallocator
```
Edition 2024 for new work (older repos 2021). See `references/build-and-deps.md` for release-profile tuning and version pins.

## New-Project Procedure
1. `skill_view` `references/project-structure.md` + `references/scaffolds.md`.
2. Copy the skeleton tree and the matching scaffold (logger, `Application`, clap args).
3. Fill layers in dependency order: constants → config → storage init → bridge/mq → core → app.
4. Load `references/function-style.md` + `references/logging.md` while writing functions.
5. Load `references/concurrency.md` for any fan-out / worker / shutdown logic.
6. Verify against the Core Invariants above; keep naming per `references/naming-and-comments.md`.

## Public README / docs style
Write GitHub READMEs in English (GitHub convention) even when chatting in Russian. No AI-slop: no marketing adjectives, no emoji headings, no badges unless CI/releases actually exist (fake badges are the slop tell). Structure that matches the community-approved models (standard-readme, mhucka/readmine, matiassingers/awesome-readme): 1–2 sentence honest intro → quickstart within the first screen → features → architecture as ASCII diagram + component table → config/env table → an honest "Limitations and honest caveats" section → license. Symbols are human-readable Unicode used only where they carry meaning (→, ─, │, — inside diagrams/tables), never emoji walls. Ground every claim in the repo — grep routes, CLI flags and env defaults before writing; never invent features, screenshots or stats. Offer a Russian variant only if asked.

## Pitfalls
- Don't over-engineer: no custom error enum hierarchies, no trait-object service registries, no `thiserror` across the board (one `SearchError`-style enum per domain at most), no config-file/YAML loading — consts are the idiom.
- Don't "fix" kept typos, stale crate names, or commented-out blocks — they are intentional in this style.
- Rust: use clap's **builder API** (`.arg(Arg::new(...))`), not `#[derive(Parser)]`.
- Don't add CI/linting/Docker unless asked (only `rust_cicd` + `appium_phones` have them, and the CI is the whole point there).

## Verification
- `cargo build` passes; `main.rs` ≤ 40 lines and calls `config::init_logger()` first.
- Every new file sits in a named concern layer (no logic in `main.rs`).
- Log lines follow the emoji tag + RU template (or clean English for toys).
- Reused scaffolds match `references/scaffolds.md` verbatim.
