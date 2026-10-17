# Build & Dependencies (house style, rust)

## Recurring dependency core (Cargo.toml)

```toml
[package]
name = "snake_case"          # old: CamelCase ok (DB_uploader, TW_offline)
version = "0.1.0"            # bumped per release; dev suffixes: v0.3.4-dev
edition = "2024"             # older repos 2021
authors = ["DroBoV1tya"]     # zenith uses ["Led Zeppelin"]

[dependencies]
anyhow = "1.0"
tokio = { version = "1.x", features = ["full"] }   # zenith pins exact features
tracing = "0.1"
tracing-subscriber = "0.3"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
reqwest = { version = "0.1x", features = ["json", "rustls-tls", "socks", "hickory-dns"] }
mongodb = "3.x"
redis = { version = "0.3x", features = ["aio", "tokio-comp"] }
sqlx = { version = "0.8", features = ["runtime-tokio-rustls", "postgres"] }
lapin = "3.0"                # RabbitMQ
clap = { version = "4.x" }   # BUILDER API, not derive
colored = "3.x"
obfstr = "0.4.4"             # in nearly every manifest (often unused in source)
rand = "0.x"
uuid = { version = "1.x", features = ["v4"] }
chrono = "0.4"
regex = "1.x"
rusqlite = { features = ["bundled"] }   # FTS5 dumps
ratatui = "0.30"             # TUI dashboards
indicatif = "0.17"           # progress bars
tabled = "0.x"               # preview tables
```

Domain extras: `matrix-sdk` + `matrix-sdk-sqlite`, `teloxide`,
`grammers-client`/`mtsender` (Telegram), `appium-client`, `pnet` (raw packets),
`fastembed`+`lancedb`+`arrow` (RAG), `scraper` (HTML), `chardetng`+`encoding_rs`
(encoding auto-detect), `fs2` (file locks), `dptree` (bot dialogues),
`moka` (rate-limit cache), `actix-web` vs `axum` (HTTP — both used; axum for
newer, actix for older services).

## jemalloc global allocator (data-heavy repos)

```rust
use tikv_jemallocator::Jemalloc;
#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;
```
or plain `jemallocator::Jemalloc`. Placed at the top of `main.rs` before `mod`
decls. Used in db_sync_manticore, tw_offline_*, tiktok_video, sarmat,
Html_converter, mac_test — NOT in upwork_panel/hackstorage.

## Release profile tuning (shipping binaries)

Size-optimized (zenith C2 agent):
```toml
[profile.release]
opt-level = "z"           # Оптимизация по размеру (z = extreme)
lto = "fat"               # Full Link Time Optimization
codegen-units = 1
strip = true
panic = "abort"
overflow-checks = false
debug = false
incremental = false
```
Speed-optimized (tempovault): same but `opt-level = 3`. Dev profile explicit:
`split-debuginfo = "unpacked"`, `incremental = true`. Russian comments explain
each flag. Most older repos have NO `[profile]` section.

## Secrets handling (pragmatic, not production-grade)

Order of preference seen, most → least common:
1. **Hardcoded consts in `config.rs`/`constants.rs`** with real values + LAN IPs
   (`192.168.20.x`): `const MONGO_DSN: &str = "mongodb://root:***@192.168.20.16";`
   Wrappers: `RabbitConfig { user: &'static str, ... }` + `impl new()`.
2. **`.env` + `dotenv::dotenv().ok()`** as the first line in main (hackstorage,
   upwork_panel, brutterogram). Typed env helpers in the most-engineered repo:
   `env_str(key, default)`, `env_u16`, `env_usize`, `env_bool`
   (`v == "1" || v.eq_ignore_ascii_case("true") || v.eq_ignore_ascii_case("yes")`),
   `env_parse::<T>`, `env_parse_or`; `OnceLock<Config>` + `config::cfg() -> &'static Config`.
3. **CLI flags for secrets** (tempovault): `-I API_ID`, `-H API_HASH`.
4. `obfstr::obfstr!("...")` for strings worth hiding in the agent.
No YAML/config-file loading anywhere (one empty `config/routing.yaml` placeholder
only). Secrets ARE committed to source — that is the norm here.

## Crate-root attributes

`#![recursion_limit = "512"]` (hackstorage, for axum/macro code).
