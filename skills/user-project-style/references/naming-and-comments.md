# Naming & Comments (house style)

## Naming conventions

| Thing | Convention | Examples |
|---|---|---|
| Functions | `snake_case`, verb first | `process_code`, `user_create`, `init_process`, `build_payload_online` |
| Structs | `PascalCase` | `MongoClient`, `AppArgs`, `ResultRecord`, `DashboardMsg`, `UserACL` |
| Fields | `snake_case` | `cnt_processed`, `total_estimate`, `seed_base`, `storage_conn` |
| Constants | `SCREAMING_SNAKE` | `TOTAL_SHARDS`, `MAX_RETRIES`, `RABBIT_HOST`, `MONGO_DSN`, `TIMEOUT_SECS` |
| Modules/dirs | `snake_case` | `storage`, `mq`, `adapters`, `client_builder` |
| MQ types | `Rx`/`Tx` prefix | `RxMessage`, `TxMessage` |
| Client wrappers | `<Db>Client` / `<Db>Connect` | `MongoClient`, `MongoConnect`, `RedisClient`, `DatabaseConnector` |
| Counters | `cnt_` prefix | `cnt_processed`, `cnt_success`, `cnt_found`, `cnt_errors` |
| Intentionally-dropped results | `_` prefix | `_start_consumer`, `_create_table`, `_increment_db_count` |
| Variant A/B copies | `_fork` suffix | `health_fork.rs`, `mac-test-fork` |
| Crate names | snake_case (old: CamelCase ok) | `tw_core`, `TW_offline`, `DB_uploader`, `PentaCore` |
| Author / clap | stale, kept | author `DroBoV1tya`; `Command::new("DBMorph")` |

## Kept typos (do NOT fix)

`inpun_file_type`, `check_max_collumns`, `maticore_send` (Manticore),
`ManticorehHit`, `enviropmets` (fn name), `DUBLICATES_DIR`, `is_buisiness`,
`sessin.json`, `succesful` (in `[+] Api service started succesful`),
`referal_pct`. Renaming causes churn the user deliberately avoids.

## Section comments

- **Box-drawing dividers** for big files / multi-service files:
  `// ─── User Service ──────────`, `// ── OSINT Tier S ──`.
- **Dashed dividers** in HTTP routers: `// ---------- health / rates (публичные) ----------`.
- **Emoji-section comments** inside data literals (mongo `doc!` builders,
  callback-data enums): `// 📌 Идентификация`, `// 📦 Содержимое`,
  `// 🔐 Доступ`, `// 💼 Служебные данные`, `// Общие`, `// Админ меню`.
- **Numbered RU steps** in sync `main`: `// 1. Первичные коннекторы: env файл при наличии.`, `// 2. Асинхронный фоновый поток:`.

## Doc comments (RU)

`///` on structs and public methods, in Russian:
`/// Менеджер состояния агента`, `/// Обёртка клиента ClickHouse: единственная
точка доступа к БД`, `/// Главный цикл выполнения агента`.
`//!` module-level RU doc comment describing the module's role (upwork_panel).

## Language of comments

- Russian is the default for inline comments (especially when porting from
  Python: `// отмечаем, что пачка в работе`, `// Вложенная модель контакта
  (как ContactData в Pydantic)`).
- English for: expect/panic messages in CLIs, `config.rs` const labels, the
  few "textbook" toys.
- Mixed RU/EN in a single log line is normal (see logging.md).

## Constants-as-data

Static lookup tables as `const`/`static`:
`const VALS: &[(&str, &[&str])]` (field-name alias normalization),
`static TARGETS: Lazy<Vec<Target>>`, `BAN_MARKERS: &[&str]`,
`TARGETS: [&str; 7]`. Regexes compiled once:
`lazy_static! { static ref IPV4_RE: Regex = ... }` / `OnceLock<Regex>` /
`std::sync::OnceLock`.
