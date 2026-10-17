# Concurrency (house style)

> All Rust + tokio. The same five idioms recur across every data-heavy repo.

## 1. Semaphore + per-item `tokio::spawn` (the brute-force fan-out)

The signature pattern for scrapers / batch pipelines — unbounded loop, a
permits-bounded worker pool:

```rust
let sem = Arc::new(Semaphore::new(constants::MAX_CONCURRENT_TASKS)); // 15 / 120 / 200 / 10000
for item in 0..total {
    let permit = sem.clone().acquire_owned().await.unwrap();
    let client = client.clone();          // clone every Arc before spawn
    let tx = tx.clone();
    tokio::spawn(async move {
        let _p = permit;                  // keep permit alive for task duration
        process_code(&client, item).await;
    });
}
```
Variant with explicit drop: `tokio::spawn(async move { ...; drop(permit); })`.
To drain in-flight tasks at the end: `sem.acquire_many(N).await`.

## 2. `JoinSet` two-level fan-out (databases × collections)

```rust
let mut set = JoinSet::new();
let db_count = Arc::new(Mutex::new(0));
for db in databases {
    set.spawn(async move {
        let _permit = sem_db.acquire_owned().await?;
        for coll in db.collections {
            let _permit = sem_coll.acquire_owned().await?;
            process(coll).await;
        }
    });
}
while let Some(res) = set.join_next().await {
    if let Err(e) = res { error!("Task panicked: {:?}", e); }
}
```
Counters shared as `Arc<Mutex<i64>>` (old) or `Arc<AtomicU64>` +
`Ordering::Relaxed` (newer): `cp.fetch_add(1, Ordering::Relaxed)`.
Batch flush: `std::mem::take(&mut bulk_tank)`; yield every N docs:
`task::yield_now().await` (every 5000); periodic memory check every 30 s via
`Instant` window (`ram_module::log_memory_usage()`).
Shard-bucket: `i % total_shards` into per-shard buffers/tables.

## 3. Background interval-loop workers

A `tokio::spawn`ed task that ticks on an interval and refreshes shared state
under a write lock, or runs a periodic job:

```rust
tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_secs(10));
    loop {
        interval.tick().await;
        match routing::load_routes(&mongo).await {
            Ok(r) => { *routes_map.write().await = r; info!("🔄 Роуты обновлены"); }
            Err(e) => { error!("❌ ...: {:?}", e); }
        }
    }
});
```
Used for: route reload (10 s), sessions refresh (10 s), bot-manager diff (30 s),
rate refresh (hourly, `ticker.tick().await; // первый тик мгновенен`), TUI stats
push (250 ms). Plain polling loops (no tokio) for filesystem watchers (5 s / 30 s).

## 4. Channels

- `mpsc::channel::<T>(10000)` — results pipe to a spawned file-writer (JSONL,
  `while let Some(record) = rx.recv().await`).
- `mpsc::channel(1)` — shutdown signal (zenith).
- `broadcast::channel(1)` — global shutdown signal (tempovault, phones_api);
  `shutdown_tx.send(())` on ctrl_c.
- `mpsc::channel(100)` — TUI dashboard stats feed.

## 5. Graceful shutdown ceremony

`tokio::select!` the work against ctrl_c, then a VISIBLE 5-second countdown,
then cleanup:

```rust
tokio::select! {
    result = server_handle => { result?; }
    _ = tokio::signal::ctrl_c() => {
        warn!("⚠️  Received Ctrl+C");
        for s in (0..5).rev() {
            print!("\r⏳ [Shutting down] {}s", s); // colored, cyan bold
            tokio::time::sleep(Duration::from_secs(1)).await;
        }
        shutdown_tx.send(()).ok();
    }
}
// cleanup: remove socket file, "🧹 Cleaned up socket: {}"
// "☑️ Shutdown complete" green bold
```

## Shared state threading

`Arc<PgPool>` / `Arc<mongodb::Client>` / `Arc<reqwest::Client>` (one reqwest
client per CPU core, `num_cpus::get()`, each with per-domain DNS `.resolve()`
pre-pinned). Clone the Arc before every spawn. Mutex-guarded pool:
`db.lock().await.get_conn().await.clone()`.

## Postgres optimistic job queue (appium_phones)

```sql
UPDATE phones SET status='processing'
WHERE id = (SELECT id FROM phones WHERE status='not_ready'
            ORDER BY id LIMIT 1)
FOR UPDATE SKIP LOCKED
```

## Exponential backoff (Matrix room join)

```rust
let mut delay = 2;
while let Err(err) = room.join().await {
    warn!("join: {err:?}, retry in {}s", delay);
    sleep(Duration::from_secs(delay)).await;
    delay *= 2;
    if delay > 3600 { break; }
}
```
