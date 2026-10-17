# Logging (house style)

## Two regimes

1. **Emoji-tag Russian** — dominant, in services/bots/scrapers. `tracing`
   (`info!/warn!/error!`) or `println!`/`eprintln!`.
2. **Clean English** — toys, CLI tools, the one "textbook" repo (no emoji,
   plain `println!` with `[+]`/`[*]` markers).
3. **Structured tracing fields** — the single most "engineered" repo
   (upwork_panel): `tracing::info!(host = %cfg.host, port = cfg.port, "starting")`,
   no emoji. Use only if the user wants observability-grade logging.

## Emoji tag system (the signature)

| Emoji | Meaning |
|---|---|
| ✅ | success / done |
| ❌ | error / failure |
| ⚠️ | warning |
| ℹ️ | info / already-exists |
| 🔄 | in progress / updated |
| 🟢 | ready / waiting |
| 📦 | batch / payload |
| 🚀 | starting application |
| 🔧 | building application |
| 📞 | request / call made |
| 📱 / 📨 | device / message |
| 🔐 / ⚠️ | key present / key missing |
| 🔴 | task-level error |
| 🧹 | cleanup |
| ⏳ | shutting down (countdown) |
| ☑️ | shutdown complete |
| 📊 | stats / result count |
| 🔍 | searching |
| 🔘 | callback |
| 💀 / 🚨 / 🔥 | stop / alarm / critical |
| ▶️ | step started |

## The RU structured template

The recurring message format is:

```
<EMOJI> <Действие|Инициализация>: <what> | Статус: <result>
<EMOJI> <Действие>: <what>, Результат: <Успешно|Провал>, <ids>
```

Real lines:
```rust
info!("✅ Инициализация: Подключение к MongoDB клиенту | Статус: Успешно");
error!("❌ Инициализация: Ошибка подключения к MongoDB | Статус: {}", e);
warn!("⚠️ Действие: Проверка прав доступа | Статус: Доступ ограничен для user_id={}", msg.user_id);
info!("✅ Действие: Создание пользователя, Результат: Успешно, tg_id: {}", tg_id);
error!("❌ Действие: Синхронизация id для users, Результат: Провал, Ошибка: {}", e);
info!("✅ Пользователь TG_ID={} успешно зарегистрирован", user.tg_id);
info!("ℹ️ Пользователь TG_ID={} уже существует");
info!("🔄 Роуты обновлены");
info!("🟢 Ожидание сообщений...");
eprintln!("❌ Ошибка обработки: {:?}", e);
```

ID interpolation is inline (`TG_ID={}`, `user_id={}`, `{udid}`).

## Colored `println!` tags (CLI tools, `colored` crate)

```rust
println!("{} SQLite batch size: {}", "⚠️ [WARN]".yellow().bold(), size);
println!("{}", "✅ [DB]".green().bold());
println!("{}", "🔄 [PROCESSING]".bold().cyan());
println!("{}", "🚫 [ERROR]".red().bold());
println!("{}", "✅ [INFO]".cyan().bold());
```

Tag bracket labels: `[INFO]`, `[DB]`, `[БД]`, `[Ввод]`, `[Информация]`,
`[PROCESSING]`, `[WARN]`, `[ERROR]`.

## Banner / progress

- Startup banner art with version + author (DBMorph `output_format::started_text()`):
  `▶ DB_uploader v0.4.0-dev запущен` between `===` lines.
- HTTP startup line (kept typo): `[+] Api service started succesful on port: 8000`.
- `\r`-based progress bar: `print!("\r{} {}/{}", spinner, pos, len); io::stdout().flush();`
  and `indicatif` with emoji template:
  `"{spinner} ⚡ {percent}% [{bar:35.blue/black}] ⚙️ {pos}/{len} | ⚡ ETA: {eta_precise} • {per_sec}"`.
- `tabled::Builder` for preview tables.

## Logger init (see scaffolds.md)

- Bots: `tracing_subscriber::fmt::init();`
- Scrapers/tools: `FmtSubscriber::builder().with_max_level(Level::INFO).init();`
- Env-filtered: `EnvFilter::try_from_default_env().unwrap_or_else(|_| "crate=info".into())`.
- Custom colored `FormatEvent` + daily file (xbot): console ANSI via owo-colors,
  rolling `logs/app.log` via `tracing_appender` non_blocking, guard kept in main.
  `EnvFilter` default `warn,xbot=info,teloxide=warn`; `APP_ENV=dev` → debug.
- Outlier (tw_serialize): `env_logger::init_from_env(Env::new().default_filter_or("info"))`.
