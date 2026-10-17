# Project Structure (house style)

> Language-agnostic invariants are in SKILL.md. This file: concrete layouts.
> Marked `rust` where it is Rust-specific.

## Default: single-crate binary (90% of repos)

No workspace, no `lib.rs`. One `src/main.rs` + flat concern modules:

```
repo/
  Cargo.toml            # rust: edition 2024, name = snake_case (older: CamelCase ok)
  src/
    main.rs             # thin orchestrator, ≤ 40 lines
    config.rs           # init_logger() + (optional) Config struct / env helpers
    args.rs             # clap builder API -> parse_args() -> AppArgs
    constants.rs        # SCREAMING_SNAKE magic numbers + hardcoded secrets
    app.rs              # Application/Runner { build() -> Self, run() }
    app/                # app.rs submodules: logic.rs, common.rs, structs.rs, progress.rs
    storage/            # one subfolder per DB (see below)
    mq/                 # rabbit consumer/producer/types/utils   (only if MQ)
    bridge.rs           # façade between UI/bot and storage/network (only if needed)
    core/               # business logic (dispatcher, routing, permissions) (only if needed)
    utils/              # logger, sender (webhook), output_format, cli_prompt
```

Module style: a directory uses `mod.rs`; a "barrel" is a bare `mod_name.rs`
containing only `pub mod sub;` lines (older repos). Both are acceptable —
pick one per project, don't mix.

### main.rs canonical shape

```rust
mod app;      // rust: declare mods at top
mod args;
mod config;
mod constants;

#[tokio::main]
async fn main() -> Result<()> {        // anyhow in new; Box<dyn Error> in old
    config::init_logger();             // ALWAYS the first call
    let args = args::parse_args();
    let app = app::Application::build(args).await?;
    app.run().await?;
    Ok(())
}
```

No logic in `main` — it only wires layers. When there are two long-lived
things (bot + server, pipeline + consumer), use `tokio::try_join!(...)` in
main and share state via a cloned `Arc`.

## Layering (dependency order, top = depends on bottom)

```
app / agent        orchestration, build()/run(), shutdown ceremony
core / services    business logic (takes pool: &PgPool / &MongoClient)
mq / bridge        fan-in (consumer) / fan-out (producer) / DB-network façade
storage            one init.rs per database, tiny client wrappers
config / constants / args
```

- `storage/<db>/init.rs` exposes `MongoClient::new() -> Result<MongoClient, Box<dyn Error>>`.
  Wrapper is minimal: `pub struct MongoClient { pub conn: mongodb::Client }`.
- A single DB can have two clients if there are two DSNs (e.g. `storage_conn`
  + `meta_conn`) bundled in one struct: `MongoClients { storage_conn, meta_conn }`
  with `#[derive(Clone)]`.
- `bridge/` = one thin async fn per operation that opens the connector and
  delegates: `bridge::user_create(user, conn)` → `database::user_create(...)`.

## Workspaces (rare — multi-service)

`zenith` is the model. `[workspace] resolver = "3"`, members under `src/`
(each its own crate with `src/main.rs`): `src/agent`, `src/server`,
`src/operator`, `src/common`, `src/test`. Shared deps in
`[workspace.dependencies]` with Russian category comments. `tempovault` is
the opposite: a monorepo of sibling service crates with NO root manifest —
each service copy-pastes its own `main/args/config/app` skeleton.

## Bot / agent architecture (matrix, telegram)

Hexagonal-ish, reused verbatim across db_observer/db_notificator/tw_matrix:

```
agent/
  app.rs                  # init_matrix_client / run_bot
  components/
    client_builder.rs     # build_client_and_login(url)
    auth/{login.rs, session.rs, verification.rs}
  features/{router.rs, commands/}
  support/{generators.rs, text.rs}
```

Event handlers registered as SDK closures; per-event work is
`tokio::spawn`'d. `tokio::try_join!(bot, server)` when a bot shares a
`Arc<matrix_sdk::Client>` with an HTTP server.

## Skeleton-first

Create the full tree up front; unimplemented files may be 0 bytes / one blank
line. Leave commented-out route/fn blocks where the next feature goes:
`// .route("/intelx/{type}", ...)`. Crate + clap names are often copied from a
prior project and left stale (`Command::new("DBMorph").author("DroBoV1tya")`)
— acceptable, do not "correct" them unless asked.
