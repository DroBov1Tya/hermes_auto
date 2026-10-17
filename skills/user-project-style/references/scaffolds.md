# Scaffolds (copy-paste blocks)

Verbatim recurring scaffolds. Copy and adapt — do not reinvent.

## Logger init

Bots:
```rust
tracing_subscriber::fmt::init();
```
Scrapers / tools (`config.rs`):
```rust
use tracing_subscriber::FmtSubscriber;
pub fn init_logger() {
    FmtSubscriber::builder()
        .with_max_level(tracing::Level::INFO)
        .init();
}
```
Env-filtered:
```rust
tracing_subscriber::fmt()
    .with_env_filter(EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| "crate_name=info".into()))
    .init();
```

## Application build/run (the orchestration pattern)

```rust
pub struct Application { cfg: Arc<Config>, db: Arc<MongoClient> }

impl Application {
    pub async fn build(args: AppArgs) -> Result<Self> {
        info!("🔧 Building application...");
        let db = Arc::new(MongoClient::new().await?);
        info!("✅ Building successful");
        Ok(Self { cfg: Arc::new(Config::from(args)), db })
    }

    pub async fn run(self) -> Result<()> {
        info!("🚀 Starting application...");
        let server = tokio::spawn(run_server(self.db.clone()));
        tokio::select! {
            r = server => r??,
            _ = tokio::signal::ctrl_c() => {
                warn!("⚠️  Received Ctrl+C");
                for s in (0..5).rev() {
                    print!("\r⏳ [Shutting down] {}s", s);
                    tokio::time::sleep(Duration::from_secs(1)).await;
                }
                println!("{}", "☑️ Shutdown complete".bold().green());
            }
        }
        Ok(())
    }
}
```

## clap builder API args (NOT derive)

```rust
use clap::{Arg, Command, value_parser};

#[derive(Debug)]
pub struct AppArgs { pub shards: u32, pub threads: u32 }

pub fn parse_args() -> AppArgs {
    let m = Command::new("DBMorph")            // stale name ok
        .version("0.0.1")
        .author("DroBoV1tya")
        .about("TipTop")
        .arg(Arg::new("shards").short('s').value_name("SHARDS")
            .help("...").required(false).default_value("1")
            .num_args(1).value_parser(value_parser!(u32).range(1..)))
        .arg(Arg::new("threads").short('t').value_name("COUNT")
            .help("...").required(false).default_value("1")
            .num_args(1).value_parser(value_parser!(u32).range(1..)))
        .get_matches();
    let shards  = m.get_one::<u32>("shards").copied()
        .expect("'shards' argument has a default and is parsed by clap.");
    let threads = m.get_one::<u32>("threads").copied()
        .expect("'threads' argument has a default and is parsed by clap.");
    AppArgs { shards, threads }
}
```

## Storage client init (one per DB)

```rust
pub struct MongoClient { pub conn: mongodb::Client }

impl MongoClient {
    pub async fn new() -> Result<Self, Box<dyn Error + Send + Sync>> {
        let opts = ClientOptions::parse(
            format!("mongodb://{}:{}@{}", user, pass, dsn_host)).await?;
        let client = Client::with_options(opts).unwrap();
        client.database("db_name");
        Ok(Self { conn: client })
    }
}
```
Two-DSN bundle: `pub struct MongoClients { pub storage_conn, pub meta_conn: mongodb::Client }` + `#[derive(Clone)]`.

## Postgres connector

```rust
pub struct DatabaseConnector { conn: PgPool }
impl DatabaseConnector {
    pub async fn new() -> Result<Self, Box<dyn Error>> {
        let conn = PgPool::connect_with(Opts { max_connections: 50, ... }).await?;
        Ok(Self { conn })
    }
    pub fn get_conn(&self) -> PgPool { self.conn.clone() }
}
```
Raw SQL: `r#"INSERT INTO users (tg_id) VALUES ($1) RETURNING true;"#`.
3-branch result pattern: `Ok(Some(_)) => { info!("✅..."); Ok(true) } Ok(None) => { info!("ℹ️..."); Ok(false) } Err(e) => { error!("❌..."); Err(e.into()) }`.

## RabbitMQ consumer / producer (lapin)

```rust
let mut consumer = channel.basic_consume("tw", "tw.offline.manticore.query",
    BasicProperties::default(), false).await?;
while let Some(delivery) = consumer.next().await {
    match delivery {
        Ok(d) => { handle_message(channel.clone(), d, mongo.clone()).await.unwrap(); }
        Err(e) => eprintln!("❌ Ошибка приема сообщения: {:?}", e),
    }
}
```
Producer: build `amqp://{}:{}@{}:{}/%2f`, `BasicProperties` with AMQP `FieldTable`
LongString headers (`request_id`/`user_id`/`sender`), `delivery_mode: 2` (persistent),
`delivery.ack(BasicAckOptions::default())`.

## Fire-and-forget webhook (utils/sender.rs)

At the end of a pipeline, POST stats to a local actix server, ignore the result:
```rust
let _ = reqwest::Client::new()
    .post("http://localhost:8000/send_notification")
    .json(&json!({ "db_count": n, "doc_count": m }))
    .send().await;
```

## jemalloc (data-heavy)

```rust
use tikv_jemallocator::Jemalloc;
#[global_allocator]
static GLOBAL: Jemalloc = Jemalloc;
```

## FTS5 dump (rusqlite, sync)

```rust
CREATE VIRTUAL TABLE IF NOT EXISTS main USING fts5 (
  FULL_NAME, PHONES, EMAILS, CAR_VIN, ... );   // RU-domain column names
let tx = conn.transaction()?;
// ... inserts with params![...] ...
tx.commit()?;
```
