# Function Style (house style)

> How individual functions are written. Rust-specific examples shown.

## Error handling — the default ladder

1. **Leaf functions**: propagate with `?`.
2. **Orchestration / init functions**: verbose `match` with a log line in each arm (this is the signature style — do NOT replace with `?` in the init path):

```rust
let mongo_client = match MongoClient::new().await {
    Ok(c) => {
        info!("✅ Инициализация: Подключение к MongoDB | Статус: Успешно");
        c
    }
    Err(e) => {
        error!("❌ Инициализация: Ошибка подключения к MongoDB | Статус: {}", e);
        return Err(e);
    }
};
```

3. **Error type choice**:
   - `Box<dyn Error>` / `Box<dyn Error + Send + Sync>` — the universal boundary type (older + infra code).
   - `anyhow::Result` / `anyhow::Context` — newer code, in async tasks and main.
   - `thiserror` enum — at most ONE per domain, e.g. `SearchError { ManticoreRequest(#[from] reqwest::Error), ... }`. Do not build error hierarchies.
   - Errors as string literals are fine: `return Err("Пользователь не найден в базе данных".into());`

## unwrap / expect policy

- **Free** at: startup, clap `get_one(...).expect("has a default")`, semaphore
  permits (`acquire_owned().await.unwrap()`), fire-and-forget sends, "cannot
  fail" conversions.
- **With a message** at: file I/O, network, parsing — `expect("Интерфейс не найден")`.
- **Swallowed** in hot paths: `let _ = ...;` / `if let Ok(x) = ...` /
  `let _x =` underscore-prefix for intentionally-dropped results
  (`let _start_consumer = ...`, `let _create_table = ...`).
- Never `panic!` in a hot loop for an expected condition (one sarmat outlier does).

## Early returns over nesting

Handlers/guards use chained early returns:
```rust
if event.sender == client.user_id().unwrap() { return; }
if room.state() != RoomState::Joined { return; }
let MessageType::Text(m) = &event.content.msgtype else { return; };
```

## Function length & shape

- **Long orchestration functions are normal** (a ~200-line `dispatch_message`
  or ~90-line `Runner::build` doing all wiring). Do not reflexively split.
- **Small pure helpers** at the bottom of the file: `build_payload_online(msg)`,
  `format_with_separator`, `sql_clean()`, `load_domains(path)`.
- **16-parameter functions are acceptable** (`mongodb_processing(...)`); prefer
  passing a `Config`/struct for new code, but don't refactor existing.
- Constructors: `impl X { pub fn new() -> Self }` (sync) or
  `pub async fn new(...) -> Result<Self>` (async). `Application::build()` /
  `Runner::build()` for the heavyweight wiring.
- Verb-noun free functions: `user_create`, `ban_user`, `process_code`,
  `fetch_document_from_mongo`.

## Parameters & types

- `&String` is kept where it exists (`get_sha256(data: &String)`) — don't
  normalize to `&str` without asking (part of the kept-typo tolerance).
- `.to_string().clone()` chains appear; fine.
- Raw SQL as `r#"...$1...#"` strings with positional binds, `RETURNING true;`.
- `json!({...})` literals for payloads; `serde_json::to_vec(&payload)?`.
- `type Doc = HashMap<String, Value>` aliases for ad-hoc documents.

## Timing bookends

CLI/one-shot tools time themselves: `let start = Instant::now();` ...
`println!("Execution time: {:?}", start.elapsed());` (and
`format!("{:.2}", elapsed.as_secs_f64())` injected as a `seconds_took` field
into API responses).
