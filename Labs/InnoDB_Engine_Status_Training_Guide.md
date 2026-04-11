# InnoDB Engine Status: Exhaustive Training Material
## Understanding `SHOW ENGINE INNODB STATUS` — Complete DBA Reference

> **How to Run:**
> ```sql
> SHOW ENGINE INNODB STATUS\G
> ```
> Output is limited to **1 MB** when run via SQL. For the full unbounded output, enable the InnoDB Monitor or check the MySQL error log.

---

## Table of Contents

1. [Overview & How to Read the Output](#1-overview--how-to-read-the-output)
2. [Header — Timing & Averages](#2-header--timing--averages)
3. [BACKGROUND THREAD](#3-background-thread)
4. [SEMAPHORES](#4-semaphores)
5. [LATEST FOREIGN KEY ERROR](#5-latest-foreign-key-error)
6. [LATEST DETECTED DEADLOCK](#6-latest-detected-deadlock)
7. [TRANSACTIONS](#7-transactions)
8. [FILE I/O](#8-file-io)
9. [INSERT BUFFER AND ADAPTIVE HASH INDEX](#9-insert-buffer-and-adaptive-hash-index)
10. [LOG](#10-log)
11. [BUFFER POOL AND MEMORY](#11-buffer-pool-and-memory)
12. [ROW OPERATIONS](#12-row-operations)
13. [Threshold Quick-Reference Table](#13-threshold-quick-reference-table)
14. [Monitoring Queries Cheat Sheet](#14-monitoring-queries-cheat-sheet)
15. [Alert & Escalation Runbook](#15-alert--escalation-runbook)

---

## 1. Overview & How to Read the Output

### 1.1 What Is SHOW ENGINE INNODB STATUS?

`SHOW ENGINE INNODB STATUS` is a diagnostic SQL statement that dumps a snapshot of the InnoDB storage engine's internal state. It is the **primary tool** for:

- Diagnosing lock contention and deadlocks
- Identifying buffer pool pressure
- Monitoring redo log and checkpoint health
- Understanding transaction activity and undo log growth
- Detecting I/O bottlenecks
- Tuning semaphore and mutex concurrency

The output is a **plain-text report** divided into labeled sections, each covering a specific subsystem. All rate statistics ("per second averages") are computed over the **sampling interval** shown in the header — not since server startup.

### 1.2 Complete Sample Output Structure

```
=====================================
2024-04-11 10:30:00 0x7f... INNODB MONITOR OUTPUT
=====================================
Per second averages calculated from the last 23 seconds
-----------------
BACKGROUND THREAD
-----------------
...
----------
SEMAPHORES
----------
...
------------------------
LATEST FOREIGN KEY ERROR
------------------------
...
------------------------
LATEST DETECTED DEADLOCK
------------------------
...
------------
TRANSACTIONS
------------
...
--------
FILE I/O
--------
...
-------------------------------------
INSERT BUFFER AND ADAPTIVE HASH INDEX
-------------------------------------
...
---
LOG
---
...
----------------------
BUFFER POOL AND MEMORY
----------------------
...
--------------
ROW OPERATIONS
--------------
...
----------------------------
END OF INNODB MONITOR OUTPUT
============================
```

### 1.3 Enabling Enhanced Output

```sql
-- Enable per-transaction lock detail (MySQL 5.6.16+)
SET GLOBAL innodb_status_output_locks = ON;

-- Enable periodic InnoDB monitor output to error log (every ~15 seconds)
SET GLOBAL innodb_status_output = ON;

-- Check current settings
SHOW VARIABLES LIKE 'innodb_status_output%';
```

> **Warning:** `innodb_status_output = ON` generates very large log files. Enable only during active troubleshooting, then disable promptly.

---

## 2. Header — Timing & Averages

### 2.1 Sample Output

```
=====================================
2024-04-11 10:30:00 0x7f93cc236700 INNODB MONITOR OUTPUT
=====================================
Per second averages calculated from the last 23 seconds
```

### 2.2 Field Explanations

| Field | Meaning |
|---|---|
| Timestamp | Server wall-clock time when the snapshot was taken |
| Thread ID (0x7f...) | OS thread ID of the thread that generated the output |
| `Per second averages calculated from the last N seconds` | **Sampling window** for all rate metrics in this report |

### 2.3 Key Insight

All "per second" values in the report (reads/s, writes/s, etc.) are **averages over the last N seconds**, not since server start. If N is very small (< 5 seconds), rates can be misleading due to short-term spikes. Collect multiple snapshots over time for accurate trending.

---

## 3. BACKGROUND THREAD

### 3.1 Sample Output

```
-----------------
BACKGROUND THREAD
-----------------
srv_master_thread loops: 152 srv_active, 0 srv_shutdown, 18340 srv_idle
srv_master_thread log flush and writes: 18340
```

### 3.2 Field Explanations

| Field | Meaning |
|---|---|
| `srv_active` | Number of times the master thread ran in active mode (server under load) |
| `srv_shutdown` | Number of times the master thread ran during shutdown |
| `srv_idle` | Number of times the master thread ran in idle mode (server quiet) |
| `log flush and writes` | Total log flush and write operations performed by master thread |

### 3.3 How to Interpret

The **master background thread** is InnoDB's central coordinator. It runs once per second and performs:
- Background table drops
- Change buffer merges (adaptive)
- Redo log flushes to disk
- Dictionary cache evictions
- Checkpoint triggering

**Healthy state:** `srv_idle` ≫ `srv_active` — server has capacity headroom.

**Under load:** `srv_active` ≫ `srv_idle` — master thread is continuously busy.

### 3.4 Thresholds & Troubleshooting

| Condition | Signal | Action |
|---|---|---|
| `srv_active` > 80% of total loops | Server under sustained load | Proceed to examine SEMAPHORES, TRANSACTIONS, I/O sections for the bottleneck |
| `log flush and writes` ≈ `srv_idle` count | Idle flushes dominating | Normal. Master thread spending time on log flushing during quiet periods |
| `srv_shutdown` > 0 during normal operation | Abnormal — shutdown in progress | Investigate unexpected MySQL restarts |

```sql
-- Cross-check master thread activity:
SHOW GLOBAL STATUS LIKE 'Innodb_master_thread%';
```

---

## 4. SEMAPHORES

### 4.1 Sample Output

```
----------
SEMAPHORES
----------
OS WAIT ARRAY INFO: reservation count 14215
OS WAIT ARRAY INFO: signal count 13887
RW-shared spins 0, rounds 0, OS waits 0
RW-excl spins 0, rounds 1, OS waits 1
RW-sx spins 0, rounds 0, OS waits 0
Spin rounds per wait: 0.00 RW-shared, 1.00 RW-excl, 0.00 RW-sx

-- Under contention (problematic example):
--Thread 3852 has waited at buf/buf0buf.cc line 4560 for 28.00 seconds
--  the semaphore:
--  S-lock on RW-latch at 0x... 'buf_pool->page_hash'
```

### 4.2 Field Explanations

| Field | Meaning |
|---|---|
| `OS WAIT ARRAY INFO: reservation count` | Total number of OS-level waits ever reserved (cumulative) |
| `OS WAIT ARRAY INFO: signal count` | Total number of OS wait signals sent (cumulative) |
| `RW-shared spins` | Total spin attempts on shared read-write latches |
| `RW-shared rounds` | Total spin loop iterations for shared latches (each "spin" can have multiple "rounds") |
| `RW-shared OS waits` | Times InnoDB gave up spinning and asked the OS to sleep — expensive context switches |
| `RW-excl spins/rounds/OS waits` | Same metrics for exclusive (write) latches |
| `RW-sx spins/rounds/OS waits` | Same metrics for shared-exclusive (intent) latches |
| `Spin rounds per wait` | Average spin rounds before an OS wait; higher = more CPU wasted spinning |
| `Thread X has waited at...` | Active thread stuck waiting for a semaphore (critical indicator) |

### 4.3 Understanding Spin Locks vs. OS Waits

InnoDB uses a **two-phase locking strategy** for concurrency control:

1. **Spin phase** — Thread rapidly polls (busy-waits) in a tight CPU loop, hoping the lock is released quickly. Controlled by `innodb_sync_spin_loops` (default: 30).
2. **OS wait phase** — If still not acquired after spinning, the thread yields to the OS (context switch). More expensive but frees CPU.

**The tradeoff:**
- High spin rounds → Wastes CPU cycles
- High OS waits → Causes expensive context switches and latency spikes

### 4.4 Thresholds & Troubleshooting

#### Threshold Table

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Active threads waiting | 0 | 1–3 | > 5 |
| `Spin rounds per wait` (shared) | < 5 | 5–20 | > 20 |
| OS waits per second | < 10 | 10–100 | > 100 |
| Thread wait time (`has waited at...`) | — | 1–5s | > 5s |

#### Investigation Steps

**Step 1: Identify where contention is occurring**

Look for `Thread X has waited at <file>:<line>` — the file/line tells you which InnoDB subsystem is contended:

| File Prefix | Subsystem | Typical Cause |
|---|---|---|
| `buf/buf0buf.cc` | Buffer pool page latch | High concurrent reads/writes to same pages |
| `btr/btr0cur.cc` | B-tree cursor | Hot index pages (e.g., monotonically increasing PK) |
| `btr/btr0sea.cc` | Adaptive hash index | AHI contention — consider disabling AHI |
| `log/log0log.cc` | Redo log | Checkpoint stalls, log write pressure |
| `trx/trx0trx.cc` | Transaction system | Very high transaction concurrency |

**Step 2: Check thread concurrency**

```sql
SHOW VARIABLES LIKE 'innodb_thread_concurrency';
-- Default: 0 (unlimited). Try setting to 2 * CPU_cores if contention is high.

SHOW GLOBAL STATUS LIKE 'Innodb_row_lock_waits';
SHOW GLOBAL STATUS LIKE 'Innodb_row_lock_time_avg';
```

**Step 3: Reduce spin loop CPU waste**

```sql
-- Reduce spin loops to avoid CPU waste (trade-off: more OS waits)
SET GLOBAL innodb_sync_spin_loops = 10;  -- Default: 30

-- Check current value
SHOW VARIABLES LIKE 'innodb_sync_spin_loops';
```

**Step 4: Address buffer pool page contention**

```sql
-- Increase buffer pool instances to reduce latch contention
-- (Requires restart — set in my.cnf)
-- innodb_buffer_pool_instances = 8  (1 per 1GB of buffer pool)

-- Check current instances
SHOW VARIABLES LIKE 'innodb_buffer_pool_instances';
```

**Step 5: Address hot B-tree index contention**

```sql
-- If contention is in btr0sea (Adaptive Hash Index):
SET GLOBAL innodb_adaptive_hash_index = OFF;
-- Monitor performance — AHI helps some workloads, hurts others with high concurrency

-- If hot row on auto-increment PK:
-- Consider partitioning the table or using UUID-based PKs
```

**Step 6: Set thread concurrency limit**

```sql
-- For high-concurrency OLTP, limit InnoDB thread concurrency:
SET GLOBAL innodb_thread_concurrency = 32;  -- 2 × CPU cores is a common starting point
SET GLOBAL innodb_thread_sleep_delay = 10000;  -- Microseconds to sleep before retry
```

---

## 5. LATEST FOREIGN KEY ERROR

### 5.1 Sample Output

```
------------------------
LATEST FOREIGN KEY ERROR
------------------------
2024-04-11 09:15:22 0x7f93... Error in foreign key constraint of table `appdb`.`orders`:
FOREIGN KEY (`customer_id`) REFERENCES `customers` (`id`)
Trying to add in child table, in index `customer_id` tuple:
DATA TUPLE: 2 fields;
 0: len 4; hex 80000064; asc    d;;
 1: len 4; hex 80000001; asc    ;;
But in parent table `customers`, in index `PRIMARY`,
the closest match we can find is record:
...
```

> This section **only appears** when a foreign key constraint error has occurred since the last server start.

### 5.2 Field Explanations

| Field | Meaning |
|---|---|
| Timestamp | When the FK violation occurred |
| Error description | Which table, which constraint, and what operation failed |
| Child/parent tuple info | Hex-encoded row data showing the violating key values |

### 5.3 Troubleshooting

**Step 1: Identify the violating statement**

```sql
-- Enable general log temporarily to capture the violating statement
SET GLOBAL general_log = ON;
SET GLOBAL general_log_file = '/var/log/mysql/general.log';
-- Reproduce the error, then check the log
SET GLOBAL general_log = OFF;
```

**Step 2: Check orphaned data**

```sql
-- Find child records with no matching parent:
SELECT child.*
FROM orders child
LEFT JOIN customers parent ON child.customer_id = parent.id
WHERE parent.id IS NULL;
```

**Step 3: Fix the data or application logic**

```sql
-- Option A: Fix the application to insert parent before child
-- Option B: Temporarily disable FK checks (use with extreme caution):
SET FOREIGN_KEY_CHECKS = 0;
-- ... fix data ...
SET FOREIGN_KEY_CHECKS = 1;

-- Option C: Add ON DELETE CASCADE / ON DELETE SET NULL to the constraint
ALTER TABLE orders
  DROP FOREIGN KEY fk_orders_customer,
  ADD CONSTRAINT fk_orders_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id)
    ON DELETE SET NULL;
```

**Step 4: Validate constraint integrity**

```sql
-- Full FK validation after data fix:
SELECT * FROM information_schema.REFERENTIAL_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'appdb';
```

---

## 6. LATEST DETECTED DEADLOCK

### 6.1 Sample Output

```
------------------------
LATEST DETECTED DEADLOCK
------------------------
2024-04-11 10:15:33 0x7f93...
*** (1) TRANSACTION:
TRANSACTION 4155568079, ACTIVE 2 sec starting index read
mysql tables in use 1, locked 1
LOCK WAIT 3 lock struct(s), heap size 1136, 2 row lock(s) undo log entries 1
MySQL thread id 345, OS thread handle 0x7f93..., query id 98723 localhost appuser
UPDATE orders SET status='shipped' WHERE id=1001

*** (1) HOLDS THE LOCK(S):
RECORD LOCKS space id 58 page no 7 n bits 72 index PRIMARY of table `appdb`.`orders`
trx id 4155568079 lock_mode X locks rec but not gap

*** (1) WAITING FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 59 page no 3 n bits 72 index PRIMARY of table `appdb`.`shipments`
trx id 4155568079 lock_mode X locks rec but not gap waiting

*** (2) TRANSACTION:
TRANSACTION 4155568080, ACTIVE 2 sec starting index read
...
UPDATE shipments SET dispatched=1 WHERE order_id=1001

*** (2) HOLDS THE LOCK(S):
RECORD LOCKS ... table `appdb`.`shipments` ... lock_mode X locks rec but not gap

*** (2) WAITING FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS ... table `appdb`.`orders` ... lock_mode X locks rec but not gap waiting

*** WE ROLL BACK TRANSACTION (1)
```

> This section **only appears** when a deadlock has been detected. Only the **most recent** deadlock is shown.

### 6.2 Field Explanations

| Field | Meaning |
|---|---|
| `TRANSACTION X, ACTIVE N sec` | Transaction ID and how long it has been active |
| `mysql tables in use N, locked N` | Tables involved and how many are locked |
| `LOCK WAIT N lock struct(s)` | Number of lock structures this transaction holds |
| `N row lock(s)` | Row locks held |
| `undo log entries N` | Number of undo log records (rows modified by this transaction) |
| `HOLDS THE LOCK(S)` | Locks this transaction is currently holding |
| `WAITING FOR THIS LOCK TO BE GRANTED` | Lock this transaction needs but cannot get |
| `WE ROLL BACK TRANSACTION (N)` | Which transaction InnoDB chose to abort (victim) |
| `lock_mode X` | Exclusive lock (write) |
| `lock_mode S` | Shared lock (read) |
| `locks rec but not gap` | Row-level lock (not a gap lock) |
| `locks gap before rec` | Gap lock (range protection) |
| `locks rec and gap` | Next-key lock (row + gap) |

### 6.3 Deadlock Root Cause Analysis

**Classic deadlock pattern (A→B, B→A):**

```
Transaction 1: Lock A → wait for B
Transaction 2: Lock B → wait for A
```

InnoDB detects the cycle and rolls back one transaction (the "victim" — usually the one with fewer undo log entries, i.e., less work done).

### 6.4 Thresholds & Troubleshooting

#### Threshold Table

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Deadlocks per hour | 0 | < 10 | > 10 |
| Deadlock victim frequency | — | Occasional | Same transaction repeatedly rolled back |
| Transaction active time in deadlock | < 1s | 1–10s | > 10s |

**Step 1: Enable deadlock logging**

```sql
-- Capture all deadlocks to the error log (not just the last one):
SET GLOBAL innodb_print_all_deadlocks = ON;

-- View the error log:
-- sudo tail -f /var/log/mysqld.log | grep -A 50 'DEADLOCK'
```

**Step 2: Identify the pattern**

```sql
-- Monitor deadlock frequency:
SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';

-- Find long-running transactions that may contribute:
SELECT trx_id, trx_state, trx_started, trx_wait_started,
       trx_mysql_thread_id, trx_query
FROM information_schema.INNODB_TRX
ORDER BY trx_started ASC;
```

**Step 3: Analyze the deadlock output**

Read the LATEST DETECTED DEADLOCK section carefully:
1. Note which **tables** are involved
2. Note the **lock types** (X = exclusive/write, S = shared/read)
3. Note the **lock order** — the classic A→B / B→A pattern reveals the fix

**Step 4: Application-level fixes**

```sql
-- Fix 1: Always acquire locks in the same order across all code paths
-- Bad:  Tx1 does: UPDATE orders, UPDATE shipments
--       Tx2 does: UPDATE shipments, UPDATE orders
-- Good: Both always do orders THEN shipments

-- Fix 2: Use SELECT ... FOR UPDATE to acquire locks upfront
START TRANSACTION;
SELECT * FROM orders WHERE id = 1001 FOR UPDATE;    -- Locks immediately
SELECT * FROM shipments WHERE order_id = 1001 FOR UPDATE;
UPDATE orders SET status='shipped' WHERE id=1001;
UPDATE shipments SET dispatched=1 WHERE order_id=1001;
COMMIT;

-- Fix 3: Use READ COMMITTED isolation (reduces gap locks, fewer deadlocks):
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Fix 4: Keep transactions short — fewer locks held simultaneously
```

**Step 5: Index optimization to reduce lock scope**

```sql
-- Missing indexes cause full table scans → more rows locked → more deadlock risk
EXPLAIN SELECT * FROM orders WHERE customer_id = 100 FOR UPDATE;
-- If type=ALL (full scan), add an index:
ALTER TABLE orders ADD INDEX idx_customer_id (customer_id);
```

**Step 6: Monitor via Performance Schema**

```sql
SELECT * FROM performance_schema.events_errors_summary_global_by_error
WHERE error_name = 'ER_LOCK_DEADLOCK';
```

---

## 7. TRANSACTIONS

### 7.1 Sample Output

```
------------
TRANSACTIONS
------------
Trx id counter 4155568100
Purge done for trx's n:o < 4155568050 undo n:o < 0 state: running
History list length 287
LIST OF TRANSACTIONS FOR EACH SESSION:
---TRANSACTION 421747401994584, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
---TRANSACTION 4155568099, ACTIVE 234 sec
4 lock struct(s), heap size 1136, 3 row lock(s), undo log entries 1450
MySQL thread id 1234, OS thread handle 0x7f93..., query id 99001 localhost appuser
UPDATE large_table SET col1='val' WHERE ...
```

### 7.2 Field Explanations

| Field | Meaning |
|---|---|
| `Trx id counter` | Next transaction ID to be assigned (monotonically increasing) |
| `Purge done for trx's n:o < X` | All undo records for transactions with ID < X have been purged |
| `undo n:o < Y` | Current undo log record being processed by the purge thread |
| `state: running` | Purge thread is actively running (`idle` = no work to do) |
| `History list length N` | **Number of undo log pages not yet purged** — one of the most critical InnoDB metrics |
| `TRANSACTION X, ACTIVE N sec` | A transaction that has been open for N seconds |
| `N lock struct(s)` | Number of lock data structures (each can cover multiple rows) |
| `heap size N` | Memory allocated for the lock heap |
| `N row lock(s)` | Number of individual row locks held |
| `undo log entries N` | Number of rows modified by this transaction (not yet committed) |
| `not started` | A session connection with no active transaction |

### 7.3 History List Length — Deep Dive

The **History List Length (HLL)** is the count of **undo log pages** that have been generated by committed transactions but not yet purged. It grows when:

- Long-running transactions prevent purge from advancing (MVCC snapshot prevents purge)
- Write throughput exceeds the purge thread's capacity

**Why it matters:**
- High HLL → InnoDB must traverse longer undo chains for MVCC visibility → **query slowdown**
- Very high HLL (> 1,000,000) → can cause severe performance degradation
- Extreme HLL → ibdata1 (system tablespace) or undo tablespace fills disk

### 7.4 Thresholds & Troubleshooting

#### Threshold Table — Transactions

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| History list length | < 1,000 | 1,000–100,000 | > 100,000 |
| Oldest active transaction age | < 60s | 60s–600s | > 600s (10 min) |
| Active transactions holding row locks | < 10 | 10–50 | > 50 |
| undo log entries per transaction | < 1,000 | 1,000–100,000 | > 100,000 |

#### Troubleshooting Steps

**Step 1: Find the oldest blocking transaction**

```sql
-- The oldest open transaction is what prevents purge from advancing
SELECT
  trx_id,
  trx_state,
  trx_started,
  TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS age_seconds,
  trx_isolation_level,
  trx_mysql_thread_id,
  LEFT(trx_query, 200) AS current_query
FROM information_schema.INNODB_TRX
ORDER BY trx_started ASC
LIMIT 10;
```

**Step 2: Find what the blocking thread is doing**

```sql
-- Get the processlist entry for the long-running transaction:
SELECT id, user, host, db, command, time, state, LEFT(info, 200) AS info
FROM information_schema.PROCESSLIST
WHERE id IN (
  SELECT trx_mysql_thread_id
  FROM information_schema.INNODB_TRX
  WHERE TIMESTAMPDIFF(SECOND, trx_started, NOW()) > 60
);
```

**Step 3: Kill the blocking transaction (if appropriate)**

```sql
-- Kill the session holding the long-running transaction:
KILL <thread_id>;  -- Kills both query and connection

-- Kill only the current query (keeps connection):
KILL QUERY <thread_id>;
```

**Step 4: Tune the purge system**

```sql
-- Increase purge threads to process undo logs faster:
SET GLOBAL innodb_purge_threads = 8;  -- Default: 4 (MySQL 8.0)

-- Increase purge batch size:
SET GLOBAL innodb_purge_batch_size = 300;  -- Default: 300

-- Check current purge thread count:
SHOW VARIABLES LIKE 'innodb_purge_threads';
```

**Step 5: Identify write-heavy tables contributing to undo growth**

```sql
SELECT object_schema, object_name, count_star AS total_ops,
       count_write AS writes
FROM performance_schema.table_io_waits_summary_by_table
ORDER BY count_write DESC
LIMIT 10;
```

**Step 6: Prevent long transactions at the application level**

```sql
-- Set a maximum transaction execution time (MySQL 5.7.4+):
SET GLOBAL innodb_lock_wait_timeout = 50;  -- Abort lock waits after 50 seconds

-- Set session-level transaction timeout via Performance Schema:
-- (Use application-level transaction timeouts in your ORM/framework)

-- Monitor for open transactions in monitoring dashboards
```

**Step 7: Check lock waits**

```sql
-- View current lock waits:
SELECT
  r.trx_id AS waiting_trx_id,
  r.trx_mysql_thread_id AS waiting_thread,
  r.trx_query AS waiting_query,
  b.trx_id AS blocking_trx_id,
  b.trx_mysql_thread_id AS blocking_thread,
  b.trx_query AS blocking_query
FROM information_schema.INNODB_LOCK_WAITS w
JOIN information_schema.INNODB_TRX b ON b.trx_id = w.blocking_trx_id
JOIN information_schema.INNODB_TRX r ON r.trx_id = w.requesting_trx_id;

-- MySQL 8.0+ (use performance_schema):
SELECT * FROM performance_schema.data_lock_waits\G
```

---

## 8. FILE I/O

### 8.1 Sample Output

```
--------
FILE I/O
--------
I/O thread 0 state: wait Windows aio (insert buffer thread)
I/O thread 1 state: wait Windows aio (log thread)
I/O thread 2 state: wait Windows aio (read thread)
I/O thread 3 state: wait Windows aio (read thread)
I/O thread 4 state: wait Windows aio (read thread)
I/O thread 5 state: wait Windows aio (write thread)
I/O thread 6 state: wait Windows aio (write thread)
Pending normal aio reads: [0, 0, 0, 0] , aio writes: [0, 0, 0, 0] ,
 ibuf aio reads:, log i/o's:, sync i/o's:
Pending flushes (fsync) log: 0; buffer pool: 0
109976 OS file reads, 1021254 OS file writes, 523345 OS fsyncs
0.00 reads/s, 0 avg bytes/read, 52.20 writes/s, 34.73 fsyncs/s
```

### 8.2 Field Explanations

| Field | Meaning |
|---|---|
| `I/O thread N state` | State of each dedicated InnoDB I/O background thread |
| `insert buffer thread` | Handles change buffer (insert buffer) merge I/O |
| `log thread` | Handles redo log I/O |
| `read thread` | Handles asynchronous data file reads |
| `write thread` | Handles asynchronous data file writes |
| `Pending normal aio reads: [N, N, ...]` | Pending async reads per read thread — non-zero = I/O queue building up |
| `Pending aio writes: [N, N, ...]` | Pending async writes per write thread |
| `ibuf aio reads` | Pending change buffer read-ahead requests |
| `log i/o's` | Pending log I/O operations |
| `sync i/o's` | Pending synchronous I/O (blocking) operations — should be near 0 |
| `Pending flushes log: N` | Pending fsync calls for the redo log — non-zero under flush pressure |
| `Pending flushes buffer pool: N` | Pending fsync calls for data files |
| `OS file reads` | Cumulative physical reads from disk (not from buffer pool) |
| `OS file writes` | Cumulative physical writes to disk |
| `OS fsyncs` | Cumulative fsync (flush) calls |
| `reads/s` | Current physical read rate |
| `avg bytes/read` | Average size of each physical read operation |
| `writes/s` | Current physical write rate |
| `fsyncs/s` | Current fsync rate |

### 8.3 I/O Thread States

| State | Meaning |
|---|---|
| `wait Windows aio` / `waiting for completed aio requests` | Idle — waiting for work (healthy) |
| `doing file read` | Actively reading a data page |
| `doing file write` | Actively writing a data page |
| `flush_dirty_pages_if_needed` | Flushing dirty pages to disk |
| `making checkpoint` | Writing a checkpoint to the redo log |

### 8.4 Thresholds & Troubleshooting

#### Threshold Table — File I/O

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Pending aio reads (any thread) | 0 | 1–5 | > 5 |
| Pending aio writes (any thread) | 0 | 1–5 | > 5 |
| Pending log flushes | 0 | 1–3 | > 3 |
| reads/s | Workload-dependent | — | Growing trend |
| fsyncs/s | < 100 | 100–1000 | > 1000 |
| avg bytes/read | 16 KB (one page) | > 16 KB (read-ahead) | Excessive read-ahead |

#### Troubleshooting Steps

**Step 1: Check OS-level I/O**

```bash
# Real-time disk I/O utilization
iostat -x 1 10
# Look for: %util (should be < 80%), await (should be < 10ms on SSD, < 20ms on HDD)

# Check I/O queue depth
iostat -xd 1 | grep -E 'Device|sda|nvme'
```

**Step 2: Tune asynchronous I/O threads**

```sql
-- Increase read/write I/O threads for high I/O workloads:
-- (Requires restart — set in my.cnf)
-- innodb_read_io_threads = 8    -- Default: 4
-- innodb_write_io_threads = 8   -- Default: 4

SHOW VARIABLES LIKE 'innodb_%io_threads';
```

**Step 3: Tune the I/O capacity**

```sql
-- Tell InnoDB how many IOPS your storage can handle:
SET GLOBAL innodb_io_capacity = 2000;         -- Default: 200 (HDD); 2000+ for SSD
SET GLOBAL innodb_io_capacity_max = 4000;     -- Peak IOPS during checkpoint flush

-- Check current setting:
SHOW VARIABLES LIKE 'innodb_io_capacity%';
```

**Step 4: Diagnose read-heavy I/O (low buffer pool hit rate)**

```sql
-- If reads/s is high, the buffer pool may be too small (see Section 11):
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read_requests';

-- Calculate hit rate:
SELECT
  (1 - (
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
    (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests')
  )) * 100 AS buffer_pool_hit_pct;
-- Target: > 99%
```

**Step 5: Diagnose write-heavy I/O (checkpoint pressure)**

```sql
-- High writes/s + high fsyncs/s → checkpoint under pressure
-- Tune checkpoint aggressiveness:
SET GLOBAL innodb_max_dirty_pages_pct = 75;          -- Default: 90
SET GLOBAL innodb_max_dirty_pages_pct_lwm = 10;      -- Start flushing at 10% dirty
SET GLOBAL innodb_adaptive_flushing = ON;             -- Enable adaptive flush rate
SET GLOBAL innodb_adaptive_flushing_lwm = 10;         -- Low water mark for adaptive flushing

-- Check dirty pages:
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages_dirty';
```

**Step 6: Tune fsync behavior**

```sql
-- innodb_flush_method affects how InnoDB writes and syncs data:
SHOW VARIABLES LIKE 'innodb_flush_method';

-- Recommended for Linux:
-- innodb_flush_method = O_DIRECT     -- Bypasses OS buffer cache for data files
--                                    -- Reduces double-buffering
-- innodb_flush_method = O_DIRECT_NO_FSYNC  -- For some cloud storage setups

-- For NVMe SSD with battery-backed write cache:
-- innodb_flush_log_at_trx_commit = 2  -- Flush to OS buffer each commit, sync each second
--                                      (slight durability risk but much faster)
```

---

## 9. INSERT BUFFER AND ADAPTIVE HASH INDEX

### 9.1 Sample Output

```
-------------------------------------
INSERT BUFFER AND ADAPTIVE HASH INDEX
-------------------------------------
Ibuf: size 1, free list len 0, seg size 2, 0 merges
merged operations:
 insert 0, delete mark 0, delete 0
discarded operations:
 insert 0, delete mark 0, delete 0
Hash table size 34673, node heap has 1 buffer(s)
Hash table size 34673, node heap has 0 buffer(s)
0.00 hash searches/s, 0.00 non-hash searches/s
```

### 9.2 What Is the Change Buffer (Insert Buffer)?

The **Change Buffer** (historically called "Insert Buffer") is an InnoDB optimization. When secondary index pages are NOT in the buffer pool, instead of immediately reading them from disk to update the index, InnoDB stores the pending changes in the change buffer. Later, when those pages are naturally read into the buffer pool, the buffered changes are **merged** (applied). This converts random I/O into sequential I/O — a huge benefit for HDD workloads.

### 9.3 What Is the Adaptive Hash Index (AHI)?

InnoDB builds an **in-memory hash table** automatically for frequently accessed index pages. Hash lookups are O(1) vs. B-tree's O(log n). AHI is built dynamically and maintained automatically. It can be disabled if it causes contention.

### 9.4 Field Explanations

| Field | Meaning |
|---|---|
| `Ibuf: size N` | Number of pages currently used by the change buffer |
| `free list len N` | Number of free pages in the change buffer |
| `seg size N` | Total segment size of the change buffer (pages) |
| `N merges` | Total number of change buffer merge operations performed |
| `merged operations: insert N, delete mark N, delete N` | Breakdown of merged operation types |
| `discarded operations` | Change buffer entries discarded (e.g., table was dropped before merge) |
| `Hash table size N` | Number of hash table cells in the AHI (per partition) |
| `node heap has N buffer(s)` | Memory pages used by AHI nodes |
| `N hash searches/s` | Queries using the Adaptive Hash Index (fast path) |
| `N non-hash searches/s` | Queries falling back to B-tree lookup (slower path) |

### 9.5 Thresholds & Troubleshooting

#### Change Buffer

| Metric | Healthy | Warning | Action Required |
|---|---|---|---|
| Change buffer size | Small relative to ibuf max size | Growing unbounded | Check if secondary index pages are never read |
| `discarded operations` > 0 | Normal if tables dropped | Frequent discards | Investigate table drops or corruption |
| Merge rate low | Normal on SSD | — | On SSD: consider disabling change buffer |

```sql
-- Check change buffer configuration:
SHOW VARIABLES LIKE 'innodb_change_buffering';
-- Values: none, inserts, deletes, changes, purges, all (default)

-- For SSD-only workloads, change buffer is less beneficial:
SET GLOBAL innodb_change_buffering = 'none';
-- Or reduce max change buffer size:
SHOW VARIABLES LIKE 'innodb_change_buffer_max_size';
-- Default: 25 (% of buffer pool). Reduce to 10 for SSD:
-- innodb_change_buffer_max_size = 10
```

#### Adaptive Hash Index

| Metric | Healthy | Warning | Action |
|---|---|---|---|
| `hash searches/s` ≫ `non-hash searches/s` | Excellent AHI effectiveness | — | No action needed |
| `hash searches/s` ≈ `non-hash searches/s` | AHI marginal benefit | — | Consider disabling |
| Semaphore waits in `btr0sea.cc` | None | Any | Disable AHI |
| High CPU with AHI enabled | — | Suspicious | Benchmark with AHI ON vs OFF |

```sql
-- If AHI is causing semaphore contention, disable it:
SET GLOBAL innodb_adaptive_hash_index = OFF;

-- Increase AHI partitions to reduce latch contention (MySQL 5.7+):
-- innodb_adaptive_hash_index_parts = 8  -- Default: 8; increase for high concurrency

-- Verify AHI status:
SHOW VARIABLES LIKE 'innodb_adaptive_hash_index%';
```

---

## 10. LOG

### 10.1 Sample Output

```
---
LOG
---
Log sequence number          86973775046
Log buffer assigned up to    86973775046
Log buffer completed up to   86973775046
Log written up to            86973775046
Log flushed up to            86973765122
Added dirty pages up to      86973775046
Pages flushed up to          86973765122
Last checkpoint at           86973755190
Log minimum file lsn (inlog) 86973565190
Log maximum file lsn         87173565190
Max checkpoint age           200000000
Checkpoint age target        167000000
Modified age                 19856
Checkpoint age               19856
2 log i/o's done, 0.20 log i/o's/second
```

### 10.2 Understanding the Redo Log

The **redo log** (Write-Ahead Log / WAL) is InnoDB's durability mechanism. Every data modification is first written to the redo log before being applied to the actual data pages. On crash, InnoDB replays the redo log from the last checkpoint to recover all committed but not-yet-flushed changes.

```
[Transaction Commit] → [Write to Redo Log] → [fsync if sync_commit=1] → [Apply to Buffer Pool Pages] → [Flush to Disk at Checkpoint]
```

### 10.3 LSN (Log Sequence Number)

An **LSN** is a monotonically increasing 8-byte integer that represents a position in the redo log stream. Every byte written to the redo log advances the LSN by 1.

### 10.4 Field Explanations

| Field | Meaning |
|---|---|
| `Log sequence number` | Current LSN — where new log records will be written |
| `Log buffer assigned up to` | LSN up to which redo log buffer space has been assigned (may be ahead of written) |
| `Log buffer completed up to` | LSN up to which all data has been written into the log buffer |
| `Log written up to` | LSN up to which data has been written from the buffer to the log file (not necessarily fsynced) |
| `Log flushed up to` | LSN up to which the redo log has been **fsynced to disk** — this is the durability guarantee |
| `Added dirty pages up to` | LSN of the newest dirty page added to the flush list |
| `Pages flushed up to` | LSN up to which dirty pages have been flushed to data files |
| `Last checkpoint at` | LSN of the **last completed checkpoint** — InnoDB can recover from here after crash |
| `Log minimum file lsn` | Oldest LSN still needed in the redo log (due to dirty pages not yet flushed) |
| `Log maximum file lsn` | Maximum LSN the redo log files can hold |
| `Max checkpoint age` | Maximum allowed gap between current LSN and last checkpoint (= redo log capacity) |
| `Checkpoint age target` | Target checkpoint age (usually ~85% of max) |
| `Modified age` | `Log sequence number` - `Pages flushed up to` — unflushed dirty page span |
| `Checkpoint age` | `Log sequence number` - `Last checkpoint at` — distance from last checkpoint |
| `log i/o's done` | Cumulative log I/O operations |
| `log i/o's/second` | Current log I/O rate |

### 10.5 Critical Calculation: Checkpoint Age

```
Checkpoint Age = Log Sequence Number - Last Checkpoint At
```

When **Checkpoint Age** approaches **Max Checkpoint Age**, InnoDB must do an emergency checkpoint (synchronous flush of all dirty pages) which causes a **write stall**. This is one of the most common causes of MySQL latency spikes.

### 10.6 Thresholds & Troubleshooting

#### Threshold Table — LOG

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Checkpoint Age / Max Checkpoint Age | < 50% | 50–80% | > 80% |
| Log flushed up to lag (behind Log sequence) | < 1 MB | 1–10 MB | > 10 MB |
| Modified age (dirty page span) | < 20% of redo log | 20–50% | > 50% |

**Step 1: Calculate checkpoint age percentage**

```sql
SELECT
  (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_redo_log_checkpoint_lsn') AS checkpoint_lsn,
  (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_redo_log_current_lsn') AS current_lsn;

-- The gap = current_lsn - checkpoint_lsn should be well below redo log capacity
```

**Step 2: Increase redo log size (most common fix)**

```sql
-- MySQL 5.7 and below (requires restart):
-- innodb_log_file_size = 2G        -- Default: 48M (far too small for most production)
-- innodb_log_files_in_group = 2    -- Total redo log = log_file_size × log_files_in_group

-- MySQL 8.0.30+ (dynamic, no restart needed):
SET GLOBAL innodb_redo_log_capacity = 4294967296;  -- 4GB in bytes
-- Or: innodb_redo_log_capacity = 4G in my.cnf

-- Verify current redo log size:
SHOW VARIABLES LIKE 'innodb_log_file%';
SHOW VARIABLES LIKE 'innodb_redo_log_capacity';
```

**Step 3: Tune checkpoint aggressiveness**

```sql
-- These settings control how aggressively InnoDB flushes dirty pages:
SET GLOBAL innodb_max_dirty_pages_pct = 75;          -- Default: 90; reduce to flush earlier
SET GLOBAL innodb_adaptive_flushing = ON;             -- Let InnoDB adaptively flush
SET GLOBAL innodb_adaptive_flushing_lwm = 10;         -- Start adaptive flush at 10% redo log fill
SET GLOBAL innodb_io_capacity = 2000;                 -- Must accurately reflect storage IOPS
SET GLOBAL innodb_io_capacity_max = 10000;
SET GLOBAL innodb_flushing_avg_loops = 30;            -- How far back to average flush rate (default: 30)
```

**Step 4: Tune commit flushing**

```sql
-- innodb_flush_log_at_trx_commit controls fsync behavior:
SHOW VARIABLES LIKE 'innodb_flush_log_at_trx_commit';
-- 1 = fsync on every COMMIT (fully ACID; slowest; default)
-- 2 = write to OS buffer on COMMIT, fsync every second (1-second data loss risk)
-- 0 = write+fsync every second only (highest performance; up to 1s data loss)

-- For most production: keep at 1
-- For write-heavy workloads where you accept 1-second risk: set to 2
```

**Step 5: Monitor via Performance Schema**

```sql
SELECT * FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
  'Innodb_redo_log_current_lsn',
  'Innodb_redo_log_checkpoint_lsn',
  'Innodb_redo_log_capacity',
  'Innodb_os_log_written',
  'Innodb_os_log_fsyncs'
);
```

---

## 11. BUFFER POOL AND MEMORY

### 11.1 Sample Output

```
----------------------
BUFFER POOL AND MEMORY
----------------------
Total large memory allocated 2198863872
Dictionary memory allocated 776332
Buffer pool size   131072
Free buffers       124908
Database pages     5765
Old database pages 2116
Modified db pages  910
Pending reads      0
Pending writes: LRU 0, flush list 0, single page 0
Pages made young 4, not young 0
0.10 youngs/s, 0.00 non-youngs/s
Pages read 197, created 5765, written 239
0.00 reads/s, 0.00 creates/s, 0.19 writes/s
Buffer pool hit rate 1000 / 1000, young-making rate 0 / 1000 not 0 / 1000
Pages read ahead 0.00/s, evicted without access 0.00/s, Random read ahead 0.00/s
LRU len: 5765, unzip_LRU len: 0
I/O sum[0]:cur[0], unzip sum[0]:cur[0]
```

### 11.2 The Buffer Pool Architecture

The buffer pool is organized as an **LRU (Least Recently Used) list** with a **midpoint insertion** strategy to protect the "hot" sublist from being evicted by bulk scans:

```
  HEAD (New/Young Sublist — ~62%)          TAIL (Old Sublist — ~38%)
  ┌─────────────────────────────────┬─────────────────────────────────┐
  │  Frequently accessed pages      │  Newly loaded / aging pages     │
  │  (promoted to head on access)   │  (start here, evicted from tail)│
  └─────────────────────────────────┴─────────────────────────────────┘
                            ↑ innodb_old_blocks_pct = 37 (midpoint)
```

### 11.3 Field Explanations

| Field | Meaning |
|---|---|
| `Total large memory allocated` | Total memory allocated by InnoDB (bytes) |
| `Dictionary memory allocated` | Memory used by InnoDB data dictionary |
| `Buffer pool size` | Total buffer pool size **in pages** (multiply by page size, usually 16KB) |
| `Free buffers` | Number of **empty pages** available for new data |
| `Database pages` | Number of pages holding actual data/index data |
| `Old database pages` | Pages in the **old sublist** (recently loaded, not yet promoted to "young") |
| `Modified db pages` | **Dirty pages** — pages changed in memory but not yet written to disk |
| `Pending reads` | Physical disk reads currently queued |
| `Pending writes: LRU N` | Pages waiting to be evicted from LRU and written to disk |
| `Pending writes: flush list N` | Pages queued for checkpoint flush |
| `Pending writes: single page N` | Single-page flush requests (urgent flush) |
| `Pages made young N` | Pages moved from old → new sublist (promoted to "hot") |
| `Pages not young N` | Page accesses that did NOT result in promotion (second access was too soon) |
| `youngs/s` | Rate at which pages are being promoted (young-making rate) |
| `non-youngs/s` | Rate at which page accesses didn't promote pages |
| `Pages read/created/written` | Cumulative page operations since server start |
| `reads/s, creates/s, writes/s` | Current page operation rates |
| `Buffer pool hit rate N / 1000` | **Cache hit ratio** — 1000/1000 = 100% hit rate |
| `young-making rate N / 1000` | Rate of pages being made young (1000 = all accesses promote pages) |
| `not N / 1000` | Rate of accesses not making pages young |
| `Pages read ahead N/s` | Linear (sequential) read-ahead rate |
| `evicted without access N/s` | Pages loaded but never accessed before eviction — read-ahead waste |
| `Random read ahead N/s` | Random read-ahead rate |
| `LRU len N` | Total pages in the LRU list (should ≈ buffer pool size) |
| `unzip_LRU len N` | Compressed pages in the LRU (for compressed tables) |
| `I/O sum[N]:cur[N]` | Scheduled I/O operations: sum over past 50 seconds, current second |

### 11.4 The Buffer Pool Hit Rate Formula

The hit rate shown (`N / 1000`) is computed over the last sampling interval:

```
Hit Rate = (Pages served from buffer pool) / (Total page requests) × 1000
```

As a percentage: `Hit Rate % = (hit_rate_display / 1000) × 100`

| Display | Actual Hit Rate |
|---|---|
| 1000 / 1000 | 100% — perfect |
| 999 / 1000 | 99.9% — excellent |
| 990 / 1000 | 99.0% — acceptable |
| 950 / 1000 | 95.0% — concerning |
| 900 / 1000 | 90.0% — critical |

### 11.5 Thresholds & Troubleshooting

#### Threshold Table — Buffer Pool

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Buffer pool hit rate | 1000/1000 (100%) | 990–999/1000 | < 990/1000 |
| Free buffers | > 5% of pool | 1–5% | < 1% (pool pressure) |
| Modified db pages (dirty) | < 75% of pool | 75–90% | > 90% |
| Pending reads | 0 | 1–10 | > 10 |
| Pending writes (LRU) | 0 | 1–5 | > 5 |
| `evicted without access/s` | 0 | > 0 | Rising trend |

**Step 1: Measure precise hit rate over time**

```sql
-- Snapshot-based hit rate (more accurate than the display value):
SELECT
  ROUND(
    (1 - (
      (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
      NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 0)
    )) * 100, 4
  ) AS buffer_pool_hit_rate_pct;
-- Target: > 99.0%
```

**Step 2: Check current pool size and working set**

```sql
-- How big is the current buffer pool?
SHOW VARIABLES LIKE 'innodb_buffer_pool_size';

-- How big is your actual working dataset?
SELECT
  ROUND(SUM(data_length + index_length) / 1024 / 1024 / 1024, 2) AS total_data_gb
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema','mysql','performance_schema','sys');
```

**Step 3: Increase buffer pool size (most impactful fix)**

```sql
-- MySQL 5.7.5+: online resize (no restart required):
SET GLOBAL innodb_buffer_pool_size = 8589934592;  -- 8GB in bytes

-- Verify resize is complete:
SHOW STATUS LIKE 'Innodb_buffer_pool_resize_status';
-- Wait until: 'Completed resizing buffer pool'

-- In my.cnf for persistence:
-- innodb_buffer_pool_size = 8G

-- Rule of thumb: 60–80% of available RAM on a dedicated DB server
```

**Step 4: Increase buffer pool instances**

```sql
-- More instances = less mutex contention on multi-core servers
-- Requires restart:
-- innodb_buffer_pool_instances = 8  (default: 1 if pool < 1GB, 8 if pool >= 1GB)
-- Rule: 1 instance per 1GB of buffer pool, maximum 64

SHOW VARIABLES LIKE 'innodb_buffer_pool_instances';
```

**Step 5: Fix "evicted without access" (read-ahead waste)**

```sql
-- High "evicted without access/s" = read-ahead pages being evicted before use
-- Common cause: full table scans or mysqldump polluting the buffer pool

-- Protect hot pages from scan pollution:
SET GLOBAL innodb_old_blocks_pct = 37;          -- Default: 37% in old sublist
SET GLOBAL innodb_old_blocks_time = 1000;       -- 1000ms: page must stay in old sublist
                                                 -- before being promoted to young

-- Disable linear read-ahead if causing excessive eviction:
SET GLOBAL innodb_read_ahead_threshold = 56;    -- Default: 56 (pages in extent before read-ahead)
                                                 -- Set to 0 to disable
```

**Step 6: Diagnose dirty page pressure**

```sql
-- Check dirty page count:
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages_dirty';
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages_total';

-- If dirty pages > 75% of pool, checkpoint is falling behind:
-- Increase io_capacity (Step 3 in FILE I/O section)
-- Or reduce innodb_max_dirty_pages_pct

-- Check wait_free counter (pages needed but no clean page available):
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_wait_free';
-- Non-zero = critical: pool is unable to evict pages fast enough
```

**Step 7: Use Performance Schema for deep analysis**

```sql
-- View buffer pool stats from information_schema:
SELECT * FROM information_schema.INNODB_BUFFER_POOL_STATS\G

-- Top tables occupying buffer pool:
SELECT
  table_name,
  index_name,
  COUNT(*) AS pages_in_buffer,
  SUM(data_size) / 1024 / 1024 AS data_mb
FROM information_schema.INNODB_BUFFER_PAGE
GROUP BY table_name, index_name
ORDER BY pages_in_buffer DESC
LIMIT 20;
```

---

## 12. ROW OPERATIONS

### 12.1 Sample Output

```
--------------
ROW OPERATIONS
--------------
0 queries inside InnoDB, 0 queries in queue
3 read views open inside InnoDB
2 RW transactions active inside InnoDB
---OLDEST VIEW---
Read view low limit trx n:o 4155568078
Trx read view will not see trx with id >= 4155568078, sees < 4155561707
Read view individually stored trx ids:
 Read view trx id 4155561707
 Read view trx id 4155567631
-----------------
Process ID=24767, Main thread ID=140449197762304, state: sleeping
Number of rows inserted 74837634891, updated 494442761, deleted 60577147, read 64714676372399
11061.76 inserts/s, 65.84 updates/s, 0.08 deletes/s, 8205091.56 reads/s
```

### 12.2 Field Explanations

| Field | Meaning |
|---|---|
| `N queries inside InnoDB` | Queries currently executing inside the InnoDB engine |
| `N queries in queue` | Queries waiting to enter InnoDB (throttled by `innodb_thread_concurrency`) |
| `N read views open inside InnoDB` | Active MVCC snapshots — transactions that haven't committed yet and may be reading old data |
| `N RW transactions active inside InnoDB` | Transactions actively reading or writing |
| `Read view low limit trx n:o` | Transactions with ID ≥ this value are invisible to this read view |
| `Trx read view will not see trx with id >= X, sees < Y` | This read view's visibility window |
| `Process ID` | mysqld OS process ID |
| `Main thread state` | Current state of the InnoDB master thread (`sleeping` = idle, healthy) |
| `Number of rows inserted/updated/deleted/read` | Cumulative row operation counts since server start |
| `inserts/s, updates/s, deletes/s, reads/s` | Current DML operation rates over the sampling interval |

### 12.3 Understanding MVCC Read Views

Each `SELECT` in a repeatable-read or serializable transaction opens a **read view** — a snapshot of the database state at transaction start time. InnoDB uses these read views plus the undo log to serve consistent reads without locking.

**Problem:** Long-running read views prevent purge from advancing → History List Length grows.

### 12.4 Thresholds & Troubleshooting

#### Threshold Table — Row Operations

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Queries in queue | 0 | 1–5 | > 5 |
| Read views open | 1–5 | 5–20 | > 20 |
| RW transactions active | < 50 | 50–200 | > 200 |
| Main thread state | `sleeping` | `doing checkpoint` | `waiting for server activity` |

**Step 1: Identify queries queued in InnoDB**

```sql
-- "Queries in queue" > 0 means thread_concurrency throttling is active
SHOW VARIABLES LIKE 'innodb_thread_concurrency';
-- Default: 0 (unlimited). If set too low, queries queue up here.

-- If queuing is intentional (preventing CPU overload):
-- innodb_thread_concurrency = 2 × CPU_cores  is a starting point

-- Check active threads:
SHOW GLOBAL STATUS LIKE 'Innodb_thread_concurrency';
```

**Step 2: Address too many open read views**

```sql
-- Many open read views = many long-running transactions
-- Find them:
SELECT
  trx_id,
  trx_state,
  TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS age_sec,
  trx_isolation_level,
  trx_mysql_thread_id
FROM information_schema.INNODB_TRX
WHERE trx_state = 'RUNNING'
ORDER BY trx_started ASC;

-- Each long-lived read view prevents purge from reclaiming undo log space
-- Kill long-running idle transactions:
KILL <thread_id>;
```

**Step 3: Monitor and alert on DML rates**

```sql
-- Capture baseline DML rates:
SELECT
  VARIABLE_NAME,
  VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
  'Innodb_rows_inserted',
  'Innodb_rows_updated',
  'Innodb_rows_deleted',
  'Innodb_rows_read'
);

-- High reads/s with low buffer pool hit rate = I/O pressure
-- High writes/s = check redo log and dirty page metrics
```

**Step 4: Tune thread concurrency**

```sql
-- If queries are queuing (queries in queue > 0):
-- Option 1: Increase concurrency limit
SET GLOBAL innodb_thread_concurrency = 64;

-- Option 2: Tune sleep delay for queued threads:
SET GLOBAL innodb_thread_sleep_delay = 10000;  -- Microseconds to sleep before retry (default: 10000)
SET GLOBAL innodb_concurrency_tickets = 5000;  -- Operations a thread can do before re-checking (default: 5000)
```

---

## 13. Threshold Quick-Reference Table

A consolidated view of all critical thresholds across every section:

| Section | Metric | Healthy | Warning | Critical | Primary Fix |
|---|---|---|---|---|---|
| **Background Thread** | srv_active dominance | Low | >50% of loops | >80% | Investigate bottleneck sections |
| **Semaphores** | Active threads waiting | 0 | 1–3 | >5 | Reduce thread_concurrency, AHI, buffer pool instances |
| **Semaphores** | Spin rounds per wait | <5 | 5–20 | >20 | Tune innodb_sync_spin_loops |
| **Semaphores** | OS waits/s | <10 | 10–100 | >100 | Tune concurrency, add buffer pool instances |
| **Deadlocks** | Deadlocks/hour | 0 | <10 | >10 | Fix lock order, add indexes, shorten transactions |
| **Transactions** | History list length | <1K | 1K–100K | >100K | Kill long transactions, tune purge threads |
| **Transactions** | Oldest transaction age | <60s | 60–600s | >600s | Kill idle transactions, set lock_wait_timeout |
| **File I/O** | Pending aio reads/writes | 0 | 1–5 | >5 | Tune io_capacity, add I/O threads |
| **File I/O** | Pending log flushes | 0 | 1–3 | >3 | Increase redo log size, tune flush_method |
| **Change Buffer** | Ibuf size | Small | Growing | Unbounded | Tune change_buffering, consider disabling |
| **AHI** | Non-hash vs hash searches | Non-hash << Hash | Approaching parity | Non-hash > Hash | Evaluate disabling AHI |
| **LOG** | Checkpoint age % | <50% | 50–80% | >80% | Increase innodb_redo_log_capacity / log_file_size |
| **LOG** | Log flushed lag | <1MB | 1–10MB | >10MB | Increase redo log size, tune io_capacity |
| **Buffer Pool** | Hit rate | 1000/1000 | 990–999/1000 | <990/1000 | Increase innodb_buffer_pool_size |
| **Buffer Pool** | Free buffers | >5% pool | 1–5% | <1% | Increase pool size |
| **Buffer Pool** | Dirty pages | <75% pool | 75–90% | >90% | Tune io_capacity, max_dirty_pages_pct |
| **Buffer Pool** | wait_free counter | 0 | Any >0 | Rising | Critical: increase pool size immediately |
| **Buffer Pool** | Evicted without access/s | 0 | >0 | Rising | Tune old_blocks_time, disable read-ahead |
| **Row Operations** | Queries in queue | 0 | 1–5 | >5 | Tune innodb_thread_concurrency |
| **Row Operations** | Read views open | <5 | 5–20 | >20 | Kill long transactions |

---

## 14. Monitoring Queries Cheat Sheet

### 14.1 Complete Health Dashboard — Single Query Block

```sql
-- Run this block to get an instant InnoDB health snapshot:

SELECT '=== BUFFER POOL ===' AS section;
SELECT
  ROUND(bp.POOL_SIZE * 16 / 1024, 0) AS pool_size_mb,
  ROUND(bp.FREE_BUFFERS * 16 / 1024, 0) AS free_mb,
  ROUND(bp.DATABASE_PAGES * 16 / 1024, 0) AS data_pages_mb,
  ROUND(bp.MODIFIED_DATABASE_PAGES * 16 / 1024, 0) AS dirty_pages_mb,
  ROUND(bp.HIT_RATE / 10.0, 2) AS hit_rate_pct,
  ROUND(bp.MODIFIED_DATABASE_PAGES / bp.DATABASE_PAGES * 100, 2) AS dirty_pct
FROM information_schema.INNODB_BUFFER_POOL_STATS bp\G

SELECT '=== TRANSACTION HEALTH ===' AS section;
SELECT
  COUNT(*) AS total_transactions,
  SUM(CASE WHEN trx_state = 'LOCK WAIT' THEN 1 ELSE 0 END) AS lock_wait_count,
  MAX(TIMESTAMPDIFF(SECOND, trx_started, NOW())) AS oldest_trx_age_sec
FROM information_schema.INNODB_TRX\G

SELECT '=== LOCK WAITS ===' AS section;
SELECT COUNT(*) AS active_lock_waits
FROM performance_schema.data_lock_waits\G  -- MySQL 8.0+

SELECT '=== ROW LOCKS ===' AS section;
SELECT
  VARIABLE_NAME, VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
  'Innodb_row_lock_waits',
  'Innodb_row_lock_time_avg',
  'Innodb_row_lock_current_waits'
)\G

SELECT '=== REDO LOG ===' AS section;
SELECT
  VARIABLE_NAME, VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
  'Innodb_redo_log_current_lsn',
  'Innodb_redo_log_checkpoint_lsn',
  'Innodb_os_log_written',
  'Innodb_os_log_fsyncs'
)\G

SELECT '=== DEADLOCKS ===' AS section;
SELECT VARIABLE_VALUE AS total_deadlocks
FROM performance_schema.global_status
WHERE VARIABLE_NAME = 'Innodb_deadlocks'\G
```

### 14.2 Long-Running Transaction Finder

```sql
SELECT
  t.trx_id,
  t.trx_state,
  TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) AS age_seconds,
  t.trx_mysql_thread_id,
  t.trx_isolation_level,
  t.trx_rows_locked,
  t.trx_rows_modified,
  LEFT(t.trx_query, 200) AS current_query,
  p.user,
  p.host,
  p.command
FROM information_schema.INNODB_TRX t
JOIN information_schema.PROCESSLIST p ON t.trx_mysql_thread_id = p.id
WHERE TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) > 30
ORDER BY t.trx_started ASC;
```

### 14.3 History List Length Monitor

```sql
-- Run every 30 seconds to track HLL trend:
SELECT
  NOW() AS sample_time,
  (SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(STATUS, 'History list length ', -1), '\n', 1)
   FROM information_schema.ENGINES WHERE ENGINE = 'InnoDB') AS history_list_estimate;

-- More reliable via status variable (MySQL 8.0):
SHOW GLOBAL STATUS LIKE 'Innodb_history_list_length';
```

### 14.4 Buffer Pool Hit Rate Monitor

```sql
-- Real-time hit rate:
SELECT
  NOW() AS ts,
  ROUND(
    (1 - (
      (SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads') /
      NULLIF((SELECT VARIABLE_VALUE FROM performance_schema.global_status WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'), 0)
    )) * 100, 4
  ) AS hit_rate_pct;
```

### 14.5 Top Blocking Queries

```sql
-- MySQL 8.0+: Find what is blocking whom:
SELECT
  dl.OBJECT_SCHEMA AS locked_schema,
  dl.OBJECT_NAME AS locked_table,
  dl.INDEX_NAME AS locked_index,
  dl.LOCK_TYPE,
  dl.LOCK_MODE,
  dl.LOCK_STATUS,
  t.trx_mysql_thread_id AS holder_thread_id,
  LEFT(t.trx_query, 200) AS holder_query,
  TIMESTAMPDIFF(SECOND, t.trx_started, NOW()) AS holder_age_sec
FROM performance_schema.data_locks dl
JOIN information_schema.INNODB_TRX t ON dl.ENGINE_TRANSACTION_ID = t.trx_id
WHERE dl.LOCK_STATUS = 'GRANTED'
ORDER BY holder_age_sec DESC
LIMIT 20;
```

### 14.6 Dirty Page Monitor

```sql
SELECT
  VARIABLE_NAME,
  VARIABLE_VALUE,
  CASE VARIABLE_NAME
    WHEN 'Innodb_buffer_pool_pages_dirty' THEN 'Dirty pages (modified in memory, not flushed)'
    WHEN 'Innodb_buffer_pool_pages_total' THEN 'Total pages in buffer pool'
    WHEN 'Innodb_buffer_pool_pages_free' THEN 'Free (empty) pages'
    WHEN 'Innodb_buffer_pool_pages_data' THEN 'Pages holding actual data'
  END AS description
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
  'Innodb_buffer_pool_pages_dirty',
  'Innodb_buffer_pool_pages_total',
  'Innodb_buffer_pool_pages_free',
  'Innodb_buffer_pool_pages_data'
);
```

---

## 15. Alert & Escalation Runbook

### 15.1 Severity Levels

| Level | Icon | Description | Response Time |
|---|---|---|---|
| INFO | 📘 | Normal operation, metric trending | Monitor; no action |
| WARNING | ⚠️ | Metric crossing threshold; investigate | Within 30 minutes |
| CRITICAL | 🔴 | Active performance impact; user-facing | Within 5 minutes |
| EMERGENCY | 🚨 | Service degradation or outage risk | Immediate |

---

### 15.2 Runbook: High History List Length

**Trigger:** HLL > 10,000 (Warning), > 100,000 (Critical), > 1,000,000 (Emergency)

```bash
# Step 1: Confirm the HLL value
mysql -u root -p -e "SHOW ENGINE INNODB STATUS\G" | grep "History list length"
mysql -u root -p -e "SHOW GLOBAL STATUS LIKE 'Innodb_history_list_length';"

# Step 2: Find the oldest blocking transaction
mysql -u root -p -e "
SELECT trx_id, trx_mysql_thread_id,
       TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS age_sec,
       trx_state, LEFT(trx_query,200)
FROM information_schema.INNODB_TRX
ORDER BY trx_started LIMIT 5\G"

# Step 3: Kill the oldest transactions if HLL > 100,000
# mysql -u root -p -e "KILL <thread_id>;"

# Step 4: Tune purge threads
mysql -u root -p -e "SET GLOBAL innodb_purge_threads = 8;"
mysql -u root -p -e "SET GLOBAL innodb_purge_batch_size = 1000;"

# Step 5: Monitor HLL decline
watch -n 5 'mysql -u root -p"password" -e "SHOW GLOBAL STATUS LIKE '"'"'Innodb_history_list_length'"'"';"'
```

---

### 15.3 Runbook: Buffer Pool Hit Rate Degraded

**Trigger:** Hit rate < 99% (Warning), < 95% (Critical)

```bash
# Step 1: Confirm hit rate
mysql -u root -p -e "
SELECT ROUND((1 - (
  SELECT VARIABLE_VALUE FROM performance_schema.global_status
  WHERE VARIABLE_NAME='Innodb_buffer_pool_reads'
) / (
  SELECT VARIABLE_VALUE FROM performance_schema.global_status
  WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests'
)) * 100, 4) AS hit_rate_pct;"

# Step 2: Check current pool size vs working set size
mysql -u root -p -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';"
mysql -u root -p -e "
SELECT ROUND(SUM(data_length+index_length)/1024/1024/1024,2) AS working_set_gb
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema','mysql','performance_schema','sys');"

# Step 3: Increase buffer pool (online in MySQL 5.7.5+)
mysql -u root -p -e "SET GLOBAL innodb_buffer_pool_size = <new_size_in_bytes>;"

# Step 4: Monitor resize completion
mysql -u root -p -e "SHOW STATUS LIKE 'Innodb_buffer_pool_resize_status';"
```

---

### 15.4 Runbook: Checkpoint Age Critical

**Trigger:** Checkpoint Age > 80% of Max Checkpoint Age

```bash
# Step 1: Capture LOG section
mysql -u root -p -e "SHOW ENGINE INNODB STATUS\G" 2>/dev/null | \
  awk '/^---$/{found=1} found{print} /^---$/ && found && NR>1{exit}'

# Step 2: Check redo log capacity (MySQL 8.0.30+)
mysql -u root -p -e "SHOW VARIABLES LIKE 'innodb_redo_log_capacity';"
# Or for older versions:
mysql -u root -p -e "SHOW VARIABLES LIKE 'innodb_log_file%';"

# Step 3: Increase io_capacity to flush dirty pages faster
mysql -u root -p -e "SET GLOBAL innodb_io_capacity = 4000;"
mysql -u root -p -e "SET GLOBAL innodb_io_capacity_max = 10000;"
mysql -u root -p -e "SET GLOBAL innodb_max_dirty_pages_pct = 50;"

# Step 4: Schedule redo log resize for next maintenance window
# In my.cnf:
# innodb_redo_log_capacity = 8589934592  # 8GB
# Or for MySQL 5.7/8.0 < 30:
# innodb_log_file_size = 2G
# innodb_log_files_in_group = 2
```

---

### 15.5 Runbook: Deadlock Storm

**Trigger:** > 10 deadlocks/hour

```bash
# Step 1: Enable all deadlock logging
mysql -u root -p -e "SET GLOBAL innodb_print_all_deadlocks = ON;"

# Step 2: Monitor deadlock rate
watch -n 60 'mysql -u root -p"password" -e \
  "SHOW GLOBAL STATUS LIKE '"'"'Innodb_deadlocks'"'"';"'

# Step 3: Analyze the pattern from error log
sudo grep -A 100 "LATEST DETECTED DEADLOCK" /var/log/mysqld.log | head -200

# Step 4: Switch to READ COMMITTED (reduces gap locks)
# Add to my.cnf: transaction_isolation = READ-COMMITTED
# Or per-session:
# mysql -u root -p -e "SET GLOBAL transaction_isolation = 'READ-COMMITTED';"

# Step 5: Add missing indexes (full scans lock too many rows)
# Identify queries in the deadlock output and run EXPLAIN on them
```

---

### 15.6 Runbook: Semaphore Waits Spike

**Trigger:** Multiple threads shown waiting ("Thread X has waited at...")

```bash
# Step 1: Capture the full SEMAPHORES section
mysql -u root -p -e "SHOW ENGINE INNODB STATUS\G" | \
  awk '/SEMAPHORES/,/TRANSACTIONS/'

# Step 2: Identify which subsystem (file name in the wait)
# buf0buf = buffer pool → increase buffer pool instances
# btr0sea = AHI → disable AHI
# log0log = redo log → tune redo log
# trx0trx = transaction system → reduce concurrency

# Step 3: Buffer pool contention fix
# mysql -u root -p -e "SET GLOBAL innodb_buffer_pool_instances = 16;"
# (requires restart)

# Step 4: AHI contention fix (immediate, no restart)
mysql -u root -p -e "SET GLOBAL innodb_adaptive_hash_index = OFF;"
# Monitor: if performance improves, leave OFF; if degrades, re-enable

# Step 5: Reduce thread concurrency
mysql -u root -p -e "SET GLOBAL innodb_thread_concurrency = 32;"
mysql -u root -p -e "SET GLOBAL innodb_sync_spin_loops = 10;"
```

---

## Key Takeaways

> **🔑 The 5 Most Critical Metrics in SHOW ENGINE INNODB STATUS**
>
> 1. **History List Length** — above 100K means undo accumulation and MVCC slowdown
> 2. **Buffer Pool Hit Rate** — below 99% means your data doesn't fit in RAM
> 3. **Checkpoint Age %** — above 80% means write stalls are imminent
> 4. **Active Threads Waiting (Semaphores)** — any thread waiting > 5s is an emergency
> 5. **Oldest Transaction Age** — transactions open > 10 minutes are almost always a bug

> **🔑 Golden Rules for InnoDB Health**
>
> - Never leave `autocommit=OFF` without explicit `COMMIT` in application code
> - Always acquire locks in the same order across all code paths
> - Set `innodb_redo_log_capacity` to at least 2× your peak write throughput per second
> - Size `innodb_buffer_pool_size` to hold your entire working dataset
> - Always run `innodb_flush_method = O_DIRECT` on Linux with a dedicated buffer pool
> - Enable `innodb_print_all_deadlocks = ON` permanently in production

---

*Document Version: 1.0 | Covers MySQL 5.7, 8.0, 8.4 | Last Updated: April 2026*
