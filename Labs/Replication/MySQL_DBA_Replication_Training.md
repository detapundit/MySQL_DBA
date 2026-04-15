# MySQL DBA Training Material
## Topic: Group Replication & GTID-Based Replication
### Platform: MySQL 8.0 | Rocky Linux 8/9 | Red Hat Enterprise Linux 8/9

---

> **Trainer Notes:**  
> This material is designed for DBAs who have basic MySQL and Linux administration experience. Each section builds on the previous. Students should complete all lab exercises in sequence. All commands are tested on MySQL 8.0.x running on Rocky Linux 8/9 and RHEL 8/9.

---

# Table of Contents

1. [Module 1: MySQL GTID Replication](#module-1-mysql-gtid-replication)
   - 1.1 [What is GTID?](#11-what-is-gtid)
   - 1.2 [How GTIDs Work Internally](#12-how-gtids-work-internally)
   - 1.3 [GTID Variables and System Tables](#13-gtid-variables-and-system-tables)
   - 1.4 [Lab Environment Setup](#14-lab-environment-setup)
   - 1.5 [Lab 1: Implementing GTID Replication from Scratch](#15-lab-1-implementing-gtid-replication-from-scratch)
   - 1.6 [Lab 2: Converting Traditional Replication to GTID](#16-lab-2-converting-traditional-replication-to-gtid)
   - 1.7 [Lab 3: GTID Replication Monitoring & Troubleshooting](#17-lab-3-gtid-replication-monitoring--troubleshooting)
   - 1.8 [GTID Edge Cases and Pitfalls](#18-gtid-edge-cases-and-pitfalls)
   - 1.9 [Practice Exercises - GTID](#19-practice-exercises---gtid)

2. [Module 2: MySQL Group Replication](#module-2-mysql-group-replication)
   - 2.1 [What is Group Replication?](#21-what-is-group-replication)
   - 2.2 [Architecture Deep Dive](#22-architecture-deep-dive)
   - 2.3 [Single-Primary vs Multi-Primary Mode](#23-single-primary-vs-multi-primary-mode)
   - 2.4 [Certification and Conflict Detection](#24-certification-and-conflict-detection)
   - 2.5 [Lab Environment Setup](#25-lab-environment-setup)
   - 2.6 [Lab 4: Single-Primary Group Replication Setup](#26-lab-4-single-primary-group-replication-setup)
   - 2.7 [Lab 5: Multi-Primary Group Replication Setup](#27-lab-5-multi-primary-group-replication-setup)
   - 2.8 [Lab 6: Group Replication Monitoring](#28-lab-6-group-replication-monitoring)
   - 2.9 [Lab 7: Failure Simulation and Recovery](#29-lab-7-failure-simulation-and-recovery)
   - 2.10 [Lab 8: Adding a New Member to an Existing Group](#210-lab-8-adding-a-new-member-to-an-existing-group)
   - 2.11 [Practice Exercises - Group Replication](#211-practice-exercises---group-replication)

3. [Appendix](#appendix)

---

# Module 1: MySQL GTID Replication

---

## 1.1 What is GTID?

### Definition

A **Global Transaction Identifier (GTID)** is a unique identifier automatically created and associated with every committed transaction on a MySQL server. GTIDs allow MySQL to track which transactions have been applied on each server in a replication topology, making replication management significantly simpler and more reliable.

Before GTIDs, traditional (file-position-based) replication required DBAs to track binary log file names and byte offsets — a fragile approach where a single mistake during failover could corrupt replication or cause data loss.

### Why GTIDs Were Introduced

| Problem with File-Position Replication | How GTIDs Solve It |
|---|---|
| Replica must know exact binary log file and position | GTIDs are globally unique; replica auto-tracks what it has applied |
| Manual CHANGE SOURCE TO requires precise binlog coordinates | Just use `GTID_MODE=ON`; MySQL figures out where to start |
| Failover is risky and error-prone | Automatic failover tools (MHA, Orchestrator) work reliably |
| Hard to verify replica completeness | Compare `gtid_executed` sets between servers |
| Skip errors required knowing exact position | Skip using GTID injection instead |

### GTID Format

A GTID has the following format:

```
source_id:transaction_id
```

- **source_id**: The `server_uuid` of the originating MySQL instance (a UUID generated at first start and stored in `auto.cnf`)
- **transaction_id**: A sequential integer starting from 1, assigned in commit order

**Example GTID:**
```
3E11FA47-71CA-11E1-9E33-C80AA9429562:23
```

**A GTID Set** (multiple transactions from one or more sources):
```
3E11FA47-71CA-11E1-9E33-C80AA9429562:1-23,
5E11FA47-71CA-11E1-9E33-C80AA9429562:1-5
```

The colon-separated range `1-23` means transactions 1 through 23 have been executed from that server.

---

## 1.2 How GTIDs Work Internally

### GTID Lifecycle

```
Transaction begins on Primary
        |
        v
MySQL assigns: GTID = <server_uuid>:<next_seq_no>
        |
        v
GTID written to Binary Log before the transaction data
        |
        v
Transaction commits; GTID added to gtid_executed
        |
        v
Replica I/O Thread reads binary log, sends to Relay Log
        |
        v
Replica SQL Thread checks: "Is this GTID in my gtid_executed?"
        |
    YES |          | NO
        v          v
    Skip it     Apply it, add to gtid_executed
```

### Key GTID Sets Explained

MySQL maintains several GTID-related system variables that every DBA must understand:

| Variable | Description |
|---|---|
| `gtid_executed` | Set of all GTIDs that have been executed (committed) on this server |
| `gtid_purged` | Set of GTIDs that existed in binary logs but have been purged; always a subset of `gtid_executed` |
| `gtid_owned` | GTIDs currently being processed (in-flight transactions) |
| `Executed_Gtid_Set` (SHOW REPLICA STATUS) | GTIDs executed on the replica |
| `Retrieved_Gtid_Set` (SHOW REPLICA STATUS) | GTIDs received in the replica's relay log |

### Binary Log and GTID

When `gtid_mode=ON`, every transaction in the binary log is preceded by a `Gtid_log_event`:

```sql
-- What mysqlbinlog shows:
# at 194
#230915 10:15:23 server id 1  end_log_pos 259 CRC32 0x...
# GTID last committed=0 sequence_number=1 rbr_only=no
SET @@SESSION.GTID_NEXT='3E11FA47-71CA-11E1-9E33-C80AA9429562:1'/*!*/;
# at 259
BEGIN
/*!*/;
-- ... actual DML follows
```

### GTID Auto-Positioning

With GTIDs, the replica tells the primary: **"I have already executed this set of GTIDs — send me everything else."**

This is the `CHANGE REPLICATION SOURCE TO ... SOURCE_AUTO_POSITION=1` feature. The primary examines its binary logs, computes the difference between what it has and what the replica reports, and starts sending from exactly the right point — no manual file/offset needed.

---

## 1.3 GTID Variables and System Tables

### Important System Variables

```sql
-- Check current GTID mode
SHOW VARIABLES LIKE 'gtid_mode';

-- Check gtid_executed (all transactions applied on this server)
SHOW VARIABLES LIKE 'gtid_executed';
-- Or use performance_schema:
SELECT * FROM performance_schema.global_variables WHERE VARIABLE_NAME = 'gtid_executed'\G

-- Check gtid_purged
SHOW VARIABLES LIKE 'gtid_purged';

-- Enforce gtid consistency (recommended ON)
SHOW VARIABLES LIKE 'enforce_gtid_consistency';

-- Check binlog format (must be ROW when GTIDs are used with group replication)
SHOW VARIABLES LIKE 'binlog_format';
```

### mysql.gtid_executed Table

MySQL 8.0 stores GTID information persistently in the `mysql.gtid_executed` table. This is used when binary logging is disabled (e.g., on replicas where you don't need their own binlogs):

```sql
SELECT * FROM mysql.gtid_executed;
-- Example output:
-- +--------------------------------------+----------------+--------------+
-- | source_uuid                          | interval_start | interval_end |
-- +--------------------------------------+----------------+--------------+
-- | 3e11fa47-71ca-11e1-9e33-c80aa9429562|              1 |           23 |
-- +--------------------------------------+----------------+--------------+
```

---

## 1.4 Lab Environment Setup

### Infrastructure Requirements

For GTID Replication labs, you need **2 virtual machines** (can be on the same host using different ports, or separate VMs):

| Role | Hostname | IP Address | MySQL Port |
|---|---|---|---|
| Primary (Source) | mysql-primary | 192.168.56.10 | 3306 |
| Replica | mysql-replica | 192.168.56.20 | 3306 |

> **Note:** Adjust IP addresses to match your actual lab environment. If using a single machine with multiple MySQL instances, use ports 3306 and 3307.

### Step 1: Install MySQL 8.0 on Both Servers

Perform the following on **BOTH servers** (mysql-primary and mysql-replica):

```bash
# ---- Rocky Linux 8/9 and RHEL 8/9 ----

# Step 1: Install MySQL 8.0 repository
sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el8-9.noarch.rpm

# If on RHEL/Rocky 9, use:
sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm

# Step 2: Disable the default MySQL module (RHEL/Rocky 8)
sudo dnf module disable mysql -y

# Step 3: Install MySQL Community Server
sudo dnf install mysql-community-server -y

# Step 4: Verify installation
mysql --version
# Expected: mysql  Ver 8.0.xx  Distrib 8.0.xx, for Linux (x86_64)

# Step 5: Start MySQL service
sudo systemctl start mysqld
sudo systemctl enable mysqld
sudo systemctl status mysqld

# Step 6: Retrieve temporary root password
sudo grep 'temporary password' /var/log/mysqld.log

# Step 7: Secure MySQL installation
sudo mysql_secure_installation
# When prompted:
#   - Enter temporary password
#   - Set new root password (use something like: MySQL@Root123!)
#   - Remove anonymous users: YES
#   - Disallow root login remotely: NO (for lab purposes)
#   - Remove test database: YES
#   - Reload privileges: YES
```

### Step 2: Configure Firewall

Perform on **BOTH servers**:

```bash
# Allow MySQL port through firewall
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

### Step 3: Configure SELinux (if enforcing)

```bash
# Check SELinux status
getenforce

# If Enforcing, allow MySQL networking
sudo setsebool -P mysql_connect_any 1

# Verify MySQL can connect on the network ports
sudo semanage port -l | grep mysql
```

### Step 4: Verify Connectivity Between Servers

```bash
# From mysql-primary, test connectivity to replica
ping 192.168.56.20
telnet 192.168.56.20 3306

# From mysql-replica, test connectivity to primary
ping 192.168.56.10
telnet 192.168.56.10 3306
```

### Step 5: Set Hostnames (Optional but Recommended)

```bash
# On primary:
sudo hostnamectl set-hostname mysql-primary

# On replica:
sudo hostnamectl set-hostname mysql-replica

# Add to /etc/hosts on BOTH servers:
sudo tee -a /etc/hosts <<EOF
192.168.56.10   mysql-primary
192.168.56.20   mysql-replica
EOF
```

---

## 1.5 Lab 1: Implementing GTID Replication from Scratch

### Objective
Set up a working MySQL GTID-based replication topology with one Primary and one Replica from scratch.

### Architecture
```
[mysql-primary:3306] ----binlog----> [mysql-replica:3306]
   gtid_mode=ON                         gtid_mode=ON
   server_id=1                          server_id=2
```

---

### PART A: Configure the Primary Server

**On mysql-primary**, edit `/etc/my.cnf`:

```bash
sudo cp /etc/my.cnf /etc/my.cnf.bak   # Take a backup first
sudo vi /etc/my.cnf
```

Add the following configuration:

```ini
[mysqld]
# ============================================================
# Basic Settings
# ============================================================
server_id                = 1
datadir                  = /var/lib/mysql
socket                   = /var/lib/mysql/mysql.sock
log_error                = /var/log/mysqld.log
pid_file                 = /var/run/mysqld/mysqld.pid

# ============================================================
# Binary Logging (Required for replication)
# ============================================================
log_bin                  = /var/lib/mysql/mysql-bin
binlog_format            = ROW
binlog_row_image         = FULL
expire_logs_days         = 7
max_binlog_size          = 100M
sync_binlog              = 1

# ============================================================
# GTID Settings
# ============================================================
gtid_mode                = ON
enforce_gtid_consistency = ON

# ============================================================
# Replication Settings
# ============================================================
log_replica_updates      = ON
replica_preserve_commit_order = ON

# ============================================================
# InnoDB Settings (for durability)
# ============================================================
innodb_flush_log_at_trx_commit = 1
```

Restart MySQL on the primary:

```bash
sudo systemctl restart mysqld
sudo systemctl status mysqld
```

Verify GTID settings are active:

```bash
mysql -uroot -p -e "SHOW VARIABLES LIKE 'gtid_mode';"
mysql -uroot -p -e "SHOW VARIABLES LIKE 'enforce_gtid_consistency';"
mysql -uroot -p -e "SHOW VARIABLES LIKE 'server_id';"
mysql -uroot -p -e "SHOW VARIABLES LIKE 'server_uuid';"
```

Expected output:
```
+-------------------------+-------+
| Variable_name           | Value |
+-------------------------+-------+
| gtid_mode               | ON    |
+-------------------------+-------+

+---------------------------+-------+
| Variable_name             | Value |
+---------------------------+-------+
| enforce_gtid_consistency  | ON    |
+---------------------------+-------+
```

---

### PART B: Configure the Replica Server

**On mysql-replica**, edit `/etc/my.cnf`:

```bash
sudo cp /etc/my.cnf /etc/my.cnf.bak
sudo vi /etc/my.cnf
```

```ini
[mysqld]
# ============================================================
# Basic Settings
# ============================================================
server_id                = 2
datadir                  = /var/lib/mysql
socket                   = /var/lib/mysql/mysql.sock
log_error                = /var/log/mysqld.log
pid_file                 = /var/run/mysqld/mysqld.pid

# ============================================================
# Binary Logging (Optional on replica, but good practice)
# ============================================================
log_bin                  = /var/lib/mysql/mysql-bin
binlog_format            = ROW
binlog_row_image         = FULL
expire_logs_days         = 7
max_binlog_size          = 100M
sync_binlog              = 1

# ============================================================
# GTID Settings
# ============================================================
gtid_mode                = ON
enforce_gtid_consistency = ON

# ============================================================
# Replication Settings
# ============================================================
log_replica_updates      = ON
relay_log                = /var/lib/mysql/mysql-relay-bin
replica_preserve_commit_order = ON

# ============================================================
# Replica-Specific: Make replica read-only
# ============================================================
read_only                = ON
super_read_only          = ON

# ============================================================
# InnoDB Settings
# ============================================================
innodb_flush_log_at_trx_commit = 1
```

Restart MySQL on the replica:

```bash
sudo systemctl restart mysqld
sudo systemctl status mysqld
```

Verify settings:

```bash
mysql -uroot -p -e "SHOW VARIABLES LIKE 'gtid_mode';"
mysql -uroot -p -e "SHOW VARIABLES LIKE 'read_only';"
mysql -uroot -p -e "SHOW VARIABLES LIKE 'server_id';"
```

---

### PART C: Create Replication User on Primary

**On mysql-primary**, connect to MySQL and create the replication user:

```sql
mysql -uroot -p

-- Create a dedicated replication user
CREATE USER 'repl_user'@'192.168.56.20' IDENTIFIED WITH mysql_native_password BY 'Repl@User123!';

-- Grant replication slave privilege
GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'192.168.56.20';

-- Also allow from any host (useful in flexible lab setups)
-- CREATE USER 'repl_user'@'%' IDENTIFIED WITH mysql_native_password BY 'Repl@User123!';
-- GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';

FLUSH PRIVILEGES;

-- Verify the user
SELECT user, host, plugin FROM mysql.user WHERE user = 'repl_user';

-- Check current GTID state (should be empty or minimal on fresh install)
SHOW VARIABLES LIKE 'gtid_executed';
```

---

### PART D: Create Initial Data Snapshot (for a fresh server, this is simple)

Since this is a fresh setup, both servers have no user data. However, in a real scenario you must copy data from primary to replica. We will create some test data:

**On mysql-primary:**

```sql
mysql -uroot -p

-- Create test database and tables
CREATE DATABASE gtid_test;
USE gtid_test;

CREATE TABLE employees (
    emp_id      INT AUTO_INCREMENT PRIMARY KEY,
    emp_name    VARCHAR(100) NOT NULL,
    department  VARCHAR(50),
    salary      DECIMAL(10,2),
    hire_date   DATE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE departments (
    dept_id     INT AUTO_INCREMENT PRIMARY KEY,
    dept_name   VARCHAR(100) NOT NULL,
    manager     VARCHAR(100),
    budget      DECIMAL(15,2)
) ENGINE=InnoDB;

-- Insert sample data
INSERT INTO departments (dept_name, manager, budget) VALUES
('Engineering', 'Alice Johnson', 500000.00),
('Marketing', 'Bob Smith', 300000.00),
('HR', 'Carol White', 200000.00),
('Finance', 'David Brown', 400000.00);

INSERT INTO employees (emp_name, department, salary, hire_date) VALUES
('John Doe', 'Engineering', 85000.00, '2020-01-15'),
('Jane Smith', 'Marketing', 72000.00, '2019-06-01'),
('Mike Johnson', 'Engineering', 90000.00, '2018-03-20'),
('Sarah Lee', 'HR', 65000.00, '2021-09-10'),
('Tom Wilson', 'Finance', 78000.00, '2020-11-05');

-- Verify data
SELECT * FROM departments;
SELECT * FROM employees;

-- Check GTID executed after creating data
SHOW VARIABLES LIKE 'gtid_executed';
```

---

### PART E: Take Backup and Restore on Replica

**On mysql-primary**, take a consistent backup using mysqldump with GTID options:

```bash
# Take a full backup with GTID info
mysqldump -uroot -p \
  --all-databases \
  --single-transaction \
  --master-data=2 \
  --triggers \
  --routines \
  --events \
  --set-gtid-purged=ON \
  > /tmp/full_backup_with_gtid.sql

# Verify the backup file has GTID info
head -50 /tmp/full_backup_with_gtid.sql | grep -E "GTID|gtid"
# You should see: SET @@GLOBAL.gtid_purged='+<gtid_set>';
```

**Transfer backup to replica:**

```bash
# On mysql-primary, copy backup to replica
scp /tmp/full_backup_with_gtid.sql root@192.168.56.20:/tmp/

# Alternative: use rsync
rsync -avz /tmp/full_backup_with_gtid.sql root@192.168.56.20:/tmp/
```

**On mysql-replica**, restore the backup:

```bash
# Restore backup to replica
mysql -uroot -p < /tmp/full_backup_with_gtid.sql

# Verify data was restored
mysql -uroot -p -e "SELECT * FROM gtid_test.employees;"

# Check gtid_executed and gtid_purged on replica
mysql -uroot -p -e "SHOW VARIABLES LIKE 'gtid_executed';"
mysql -uroot -p -e "SHOW VARIABLES LIKE 'gtid_purged';"
```

---

### PART F: Start Replication on Replica

**On mysql-replica**, configure the replication connection:

```sql
mysql -uroot -p

-- Stop any existing replication (just in case)
STOP REPLICA;

-- Configure the replication source with AUTO_POSITION
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST     = '192.168.56.10',
    SOURCE_PORT     = 3306,
    SOURCE_USER     = 'repl_user',
    SOURCE_PASSWORD = 'Repl@User123!',
    SOURCE_AUTO_POSITION = 1;

-- Start replication
START REPLICA;

-- Check replication status (the most important command)
SHOW REPLICA STATUS\G
```

**What to look for in SHOW REPLICA STATUS:**

```
Replica_IO_Running: Yes          <-- IO thread fetching from primary is running
Replica_SQL_Running: Yes         <-- SQL thread applying relay log is running
Seconds_Behind_Source: 0         <-- Replica is caught up (0 = in sync)
Last_IO_Error:                   <-- Empty = no errors
Last_SQL_Error:                  <-- Empty = no errors
Executed_Gtid_Set: 3E11...:1-10  <-- GTIDs applied on replica
Retrieved_Gtid_Set: 3E11...:1-10 <-- GTIDs received from primary
```

---

### PART G: Verify Replication is Working

**On mysql-primary**, insert new data:

```sql
mysql -uroot -p

USE gtid_test;

-- Insert a new employee
INSERT INTO employees (emp_name, department, salary, hire_date)
VALUES ('Diana Prince', 'Engineering', 95000.00, '2023-01-10');

-- Check current GTID
SHOW VARIABLES LIKE 'gtid_executed';

-- Note the transaction GTID
SELECT * FROM employees WHERE emp_name = 'Diana Prince';
```

**On mysql-replica**, verify the data replicated:

```sql
mysql -uroot -p

-- Should see Diana Prince
SELECT * FROM gtid_test.employees WHERE emp_name = 'Diana Prince';

-- Check replica status - Seconds_Behind_Source should be 0
SHOW REPLICA STATUS\G

-- Compare GTID sets between primary and replica
SHOW VARIABLES LIKE 'gtid_executed';
```

---

### PART H: Monitor and Verify GTID Replication Health

```sql
-- On REPLICA: Check if replica is fully in sync with primary
-- This query shows if there's any lag

-- Method 1: Check Seconds_Behind_Source
SHOW REPLICA STATUS\G

-- Method 2: Compare GTIDs (run on replica)
-- Computes what transactions the replica is MISSING compared to primary
-- First, note the primary's gtid_executed, then on replica:
SELECT GTID_SUBTRACT('<primary_gtid_executed>', @@GLOBAL.gtid_executed) AS missing_gtids;

-- Example:
SELECT GTID_SUBTRACT(
    '3E11FA47-71CA-11E1-9E33-C80AA9429562:1-10',
    @@GLOBAL.gtid_executed
) AS missing_gtids;
-- Empty result = replica is fully caught up

-- Method 3: Performance Schema (MySQL 8.0)
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    RECEIVED_TRANSACTION_SET,
    LAST_ERROR_MESSAGE
FROM performance_schema.replication_connection_status\G

SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    APPLYING_TRANSACTION,
    LAST_APPLIED_TRANSACTION,
    LAST_ERROR_MESSAGE
FROM performance_schema.replication_applier_status_by_worker\G
```

---

## 1.6 Lab 2: Converting Traditional Replication to GTID

### Objective
Convert an existing file-position-based replication setup to GTID-based replication **without downtime** using the online method introduced in MySQL 5.7.6+.

### Understanding GTID_MODE Transitions

GTID mode cannot be switched directly from OFF to ON. You must go through intermediate states:

```
OFF --> OFF_PERMISSIVE --> ON_PERMISSIVE --> ON
```

| State | Non-GTID Transactions | GTID Transactions | Description |
|---|---|---|---|
| `OFF` | Allowed | Not allowed | Traditional replication |
| `OFF_PERMISSIVE` | Allowed | Allowed (logged without GTID) | Transition step 1 |
| `ON_PERMISSIVE` | Allowed | Required for new transactions | Transition step 2 |
| `ON` | Not allowed | Required | Full GTID mode |

### Prerequisites

Assume you have a running traditional replication:
- Primary: binlog enabled, server_id=1
- Replica: configured with CHANGE MASTER TO FILE/POSITION

### Step 1: Prepare Both Servers' Configuration Files

**On BOTH servers**, add to `/etc/my.cnf` (but do NOT restart yet):

```ini
# Add these lines to [mysqld] section
enforce_gtid_consistency = ON
```

Restart both servers to enforce GTID consistency (this is safe — it just prevents non-GTID-safe statements):

```bash
# On primary first, then replica
sudo systemctl restart mysqld
```

Verify:
```sql
SHOW VARIABLES LIKE 'enforce_gtid_consistency';
-- Should show: ON
```

### Step 2: Enable OFF_PERMISSIVE on All Servers

**On ALL servers** (primary first, then replicas), execute online:

```sql
-- This can be set dynamically without restart
SET @@GLOBAL.GTID_MODE = OFF_PERMISSIVE;

-- Verify
SHOW VARIABLES LIKE 'gtid_mode';
-- Should show: OFF_PERMISSIVE
```

### Step 3: Enable ON_PERMISSIVE on All Servers

**On ALL servers** (primary first):

```sql
SET @@GLOBAL.GTID_MODE = ON_PERMISSIVE;

-- Verify
SHOW VARIABLES LIKE 'gtid_mode';
```

Now wait until all anonymous (non-GTID) transactions have been applied everywhere:

```sql
-- On REPLICA: Check if any anonymous transactions are in progress
SHOW STATUS LIKE 'Ongoing_anonymous_transaction_count';
-- Wait until this is 0

-- Also check:
SHOW REPLICA STATUS\G
-- Wait for Executing_Gtid_Set to include all transactions
```

### Step 4: Enable Full GTID Mode

**On ALL servers** (primary first):

```sql
SET @@GLOBAL.GTID_MODE = ON;

-- Verify
SHOW VARIABLES LIKE 'gtid_mode';
-- Should show: ON
```

### Step 5: Update my.cnf to Persist the Change

**On BOTH servers**, add to `/etc/my.cnf`:

```ini
gtid_mode                = ON
enforce_gtid_consistency = ON
```

This ensures GTIDs survive a server restart.

### Step 6: Switch Replica to Auto-Positioning

**On mysql-replica:**

```sql
-- Stop the replica
STOP REPLICA;

-- Switch to GTID auto-positioning
CHANGE REPLICATION SOURCE TO SOURCE_AUTO_POSITION = 1;

-- Start the replica
START REPLICA;

-- Verify
SHOW REPLICA STATUS\G
-- Look for: Auto_Position: 1
```

---

## 1.7 Lab 3: GTID Replication Monitoring & Troubleshooting

### Monitoring Queries

```sql
-- ============================================================
-- 1. Complete Replica Status
-- ============================================================
SHOW REPLICA STATUS\G

-- ============================================================
-- 2. Check replication lag in seconds
-- ============================================================
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    LAST_ERROR_NUMBER,
    LAST_ERROR_MESSAGE,
    LAST_ERROR_TIMESTAMP
FROM performance_schema.replication_applier_status;

-- ============================================================
-- 3. Check individual worker threads (parallel replication)
-- ============================================================
SELECT
    WORKER_ID,
    SERVICE_STATE,
    LAST_APPLIED_TRANSACTION,
    APPLYING_TRANSACTION,
    LAST_ERROR_MESSAGE
FROM performance_schema.replication_applier_status_by_worker\G

-- ============================================================
-- 4. Check IO thread status
-- ============================================================
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    LAST_QUEUED_TRANSACTION,
    LAST_ERROR_MESSAGE,
    SOURCE_UUID,
    SOURCE_SERVER_ID
FROM performance_schema.replication_connection_status\G

-- ============================================================
-- 5. GTID consistency check between primary and replica
-- ============================================================
-- Run on REPLICA, passing in primary's gtid_executed value:
SELECT
    @@GLOBAL.gtid_executed AS replica_gtid_executed,
    GTID_SUBTRACT('PRIMARY_GTID_EXECUTED_HERE', @@GLOBAL.gtid_executed) AS missing_from_replica,
    GTID_SUBTRACT(@@GLOBAL.gtid_executed, 'PRIMARY_GTID_EXECUTED_HERE') AS extra_on_replica;

-- ============================================================
-- 6. Find the current binary log position
-- ============================================================
SHOW BINARY LOG STATUS;  -- MySQL 8.2+
-- or
SHOW MASTER STATUS;      -- MySQL 8.0 (deprecated in 8.2)
```

### Troubleshooting Common Issues

#### Issue 1: Duplicate GTID / Replication Stops

**Symptom:**
```
Last_SQL_Error: Error 'Duplicate entry' for key 'PRIMARY'
```

**Cause:** A transaction with the same GTID was applied twice, or the replica has local writes that conflict.

**Resolution using GTID skip:**

```sql
-- On REPLICA: Get the problematic GTID
SHOW REPLICA STATUS\G
-- Note the value in: Executed_Gtid_Set and find the gap

-- Inject an empty transaction to skip that GTID
-- Example: skip GTID 3E11FA47-71CA-11E1-9E33-C80AA9429562:5

STOP REPLICA;

-- Tell MySQL: next transaction should be this specific GTID
SET GTID_NEXT = '3E11FA47-71CA-11E1-9E33-C80AA9429562:5';

-- Execute a fake empty transaction
BEGIN;
COMMIT;

-- Reset GTID_NEXT to automatic
SET GTID_NEXT = 'AUTOMATIC';

-- Restart replication
START REPLICA;

-- Verify
SHOW REPLICA STATUS\G
```

#### Issue 2: Replica Can't Connect to Primary

**Symptom:**
```
Last_IO_Error: error connecting to master 'repl_user@192.168.56.10:3306'
```

**Diagnosis steps:**

```bash
# Test connectivity from replica OS
telnet 192.168.56.10 3306
# or
nc -zv 192.168.56.10 3306

# Test MySQL login from replica
mysql -urepl_user -p'Repl@User123!' -h 192.168.56.10 -P 3306 -e "SELECT 1;"

# Check firewall on primary
sudo firewall-cmd --list-all

# Check MySQL error log
sudo tail -100 /var/log/mysqld.log
```

```sql
-- On PRIMARY: Check if replication user exists and has correct grants
SELECT user, host, plugin FROM mysql.user WHERE user = 'repl_user';
SHOW GRANTS FOR 'repl_user'@'192.168.56.20';
```

#### Issue 3: @@GLOBAL.GTID_PURGED Conflict During Setup

**Symptom when restoring backup:**
```
ERROR 1840 (HY000): @@GLOBAL.GTID_PURGED can only be set when @@GLOBAL.GTID_EXECUTED is empty.
```

**Resolution:**

```sql
-- On REPLICA: Reset the executed GTID set
RESET REPLICA ALL;
RESET BINARY LOGS AND GTIDS;   -- MySQL 8.0+
-- or
RESET MASTER;  -- deprecated in MySQL 8.0

-- Verify gtid_executed is now empty
SHOW VARIABLES LIKE 'gtid_executed';

-- Now restore the backup again
```

#### Issue 4: enforce_gtid_consistency Violations

**Symptom:**
```
ERROR 1745 (HY000): CREATE TABLE ... SELECT is forbidden when @@GLOBAL.ENFORCE_GTID_CONSISTENCY = ON.
```

**Explanation:** Certain SQL patterns are not GTID-safe:
- `CREATE TABLE ... SELECT`
- Transactions that update both transactional and non-transactional tables
- `CREATE TEMPORARY TABLE` inside a transaction

**Resolution:** Rewrite the offending SQL:

```sql
-- NOT GTID-safe:
CREATE TABLE new_employees SELECT * FROM employees WHERE department = 'Engineering';

-- GTID-safe alternative:
CREATE TABLE new_employees LIKE employees;
INSERT INTO new_employees SELECT * FROM employees WHERE department = 'Engineering';
```

---

## 1.8 GTID Edge Cases and Pitfalls

### 1. Errant Transactions

An **errant transaction** is a GTID that exists in a replica's `gtid_executed` but does NOT exist in the primary's `gtid_executed`. This typically happens when someone writes directly to a replica (ignoring `read_only`).

**Detecting errant transactions:**

```sql
-- On REPLICA:
-- Errant = what replica has EXECUTED that primary doesn't
SELECT GTID_SUBTRACT(@@GLOBAL.gtid_executed, 'PRIMARY_GTID_EXECUTED') AS errant_transactions;
```

**Resolving errant transactions:**

```sql
-- On PRIMARY: Inject an empty transaction with the errant GTID
-- This "legitimizes" the GTID on the primary side

STOP REPLICA;  -- if primary is also a replica

SET GTID_NEXT = '<errant_gtid_value>';
BEGIN;
COMMIT;
SET GTID_NEXT = 'AUTOMATIC';
```

### 2. gtid_purged Cannot Be Reduced

Once GTIDs are purged from binary logs, `gtid_purged` can only grow, never shrink. If you need a replica to start from a very old point, you must keep enough binary logs on the primary.

```sql
-- Check oldest available binary log
SHOW BINARY LOGS;

-- Adjust binary log retention
SET GLOBAL binlog_expire_logs_seconds = 604800;  -- 7 days
-- or
SET GLOBAL expire_logs_days = 7;
```

### 3. GTID and mysqldump Best Practices

```bash
# Always include --set-gtid-purged=ON when dumping for replica setup
mysqldump -uroot -p \
  --all-databases \
  --single-transaction \
  --set-gtid-purged=ON \
  > backup.sql

# Use --set-gtid-purged=OFF if you want to dump without GTID info
# (useful for partial backups, one-time data moves)
mysqldump -uroot -p \
  --databases mydb \
  --single-transaction \
  --set-gtid-purged=OFF \
  > partial_backup.sql
```

---

## 1.9 Practice Exercises - GTID

### Exercise 1: Basic GTID Understanding
1. On your primary server, execute 5 separate INSERT statements into `gtid_test.employees`. After each INSERT, note the GTID that was generated using `SHOW VARIABLES LIKE 'gtid_executed'`. Document the pattern of how GTIDs are assigned sequentially.

2. On the replica, run `SHOW REPLICA STATUS\G` and compare the `Retrieved_Gtid_Set` and `Executed_Gtid_Set`. Explain what each value represents.

### Exercise 2: Simulate and Fix Replication Failure
1. On the **replica**, temporarily stop the SQL thread: `STOP REPLICA SQL_THREAD;`
2. On the **primary**, insert 10 new rows into `gtid_test.employees`.
3. Check how many transactions the replica is behind using the GTID_SUBTRACT function.
4. Start the SQL thread again: `START REPLICA SQL_THREAD;`
5. Watch the replica catch up using `SHOW REPLICA STATUS\G` and confirm `Seconds_Behind_Source` returns to 0.

### Exercise 3: Test GTID Safety
1. Try to execute `CREATE TABLE gtid_test.test_select SELECT * FROM gtid_test.employees;` on the primary.
2. Observe the error message.
3. Rewrite the statement in a GTID-safe manner and execute it successfully.
4. Verify it replicated to the replica.

### Exercise 4: errant Transaction Simulation
1. On the replica, temporarily disable read_only: `SET GLOBAL read_only = OFF;`
2. Insert a row directly into the replica: `INSERT INTO gtid_test.employees (emp_name, department, salary, hire_date) VALUES ('Replica Only', 'Ghost', 1.00, '2024-01-01');`
3. Re-enable read_only: `SET GLOBAL read_only = ON;`
4. Using GTID_SUBTRACT, detect this errant transaction.
5. Resolve it on the primary side.

### Exercise 5: GTID-Based Backup and Restore
1. Take a mysqldump of `gtid_test` database from the primary with `--set-gtid-purged=ON`.
2. Create a new test database `gtid_restored` on the replica.
3. Restore the backup and check if GTID information was preserved.
4. Explain the difference between `--set-gtid-purged=ON` and `--set-gtid-purged=OFF` and when you would use each.

---

# Module 2: MySQL Group Replication

---

## 2.1 What is Group Replication?

### Definition

**MySQL Group Replication (MGR)** is a plugin-based, distributed database replication mechanism that provides fault-tolerant, automatic, and multi-master replication within a cluster of MySQL servers.

Group Replication builds on top of GTID-based replication and adds a **distributed consensus layer** (based on the Paxos protocol) that ensures all group members agree on which transactions are committed and in what order.

### Why Use Group Replication?

| Feature | Traditional Replication | Group Replication |
|---|---|---|
| Failover | Manual | Automatic |
| Write nodes | 1 (Primary only) | 1 or All (multi-primary) |
| Conflict detection | None | Automatic, built-in |
| Data consistency guarantee | Eventual (can lose data) | Strong (by consensus) |
| Split-brain protection | None | Built-in quorum system |
| Self-healing | No | Yes (auto member management) |

### Where Group Replication Fits

```
                    ┌──────────────────────────────────┐
                    │      MySQL InnoDB Cluster         │
                    │  (MySQL Shell + MySQL Router)     │
                    │                                  │
                    │  ┌────────────────────────────┐  │
                    │  │   Group Replication Plugin  │  │
                    │  │  (Consensus + Replication)  │  │
                    │  └────────────────────────────┘  │
                    └──────────────────────────────────┘
```

Group Replication is the core replication engine that powers **MySQL InnoDB Cluster** (the full HA solution from Oracle/MySQL). You can use MGR standalone or as part of InnoDB Cluster.

---

## 2.2 Architecture Deep Dive

### Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      MySQL Group                                 │
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │
│  │    Member 1     │  │    Member 2     │  │    Member 3    │  │
│  │  (Primary)      │  │  (Secondary)    │  │  (Secondary)   │  │
│  │                 │  │                 │  │                │  │
│  │  ┌───────────┐  │  │  ┌───────────┐ │  │ ┌───────────┐ │  │
│  │  │ GR Plugin │◄─┼──┼──►GR Plugin ◄─┼──┼─► GR Plugin │ │  │
│  │  └─────┬─────┘  │  │  └─────┬─────┘ │  │ └─────┬─────┘ │  │
│  │        │        │  │        │        │  │       │        │  │
│  │  ┌─────▼─────┐  │  │  ┌─────▼─────┐ │  │ ┌─────▼─────┐ │  │
│  │  │ Paxos/GCS │◄─┼──┼──►Paxos/GCS ◄─┼──┼─►Paxos/GCS  │ │  │
│  │  │(Consensus)│  │  │  │(Consensus)│ │  │ │(Consensus)│ │  │
│  │  └───────────┘  │  │  └───────────┘ │  │ └───────────┘ │  │
│  └─────────────────┘  └─────────────────┘  └───────────────┘  │
│                                                                  │
│     ◄────── Group Communication System (GCS/XCom) ──────►       │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

**1. Group Communication System (GCS)**
- Based on the **Paxos** distributed consensus algorithm
- Implemented as **XCom** (eXtended Communication)
- All members communicate through GCS for transaction ordering
- Ensures all members agree on the same transaction order

**2. Group Replication Plugin**
- Intercepts each transaction at commit time
- Sends the transaction's write-set to all members for certification
- Only commits after receiving consensus from a quorum

**3. Certification Process**
- Before a transaction commits, its write-set (the rows it modified) is sent to all members
- All members check for conflicts (did another transaction modify the same rows?)
- If no conflicts: transaction commits on all members
- If conflict: the later transaction is rolled back (conflict detection)

### Transaction Flow in Group Replication

```
Application sends COMMIT to MySQL
         │
         ▼
Transaction write-set captured
(which rows were read/written)
         │
         ▼
Write-set broadcast to ALL group members via GCS (Paxos)
         │
         ▼
All members independently perform certification
(Does this write-set conflict with any concurrent transaction?)
         │
    ┌────┴────┐
    │         │
    ▼         ▼
NO CONFLICT  CONFLICT DETECTED
    │         │
    ▼         ▼
COMMIT on   ROLLBACK the
all members   conflicting tx
```

### Quorum and Fault Tolerance

Group Replication requires a **majority quorum** to make progress:

| Total Members | Majority Required | Max Failures Tolerated |
|---|---|---|
| 1 | 1 | 0 |
| 2 | 2 | 0 |
| 3 | 2 | 1 |
| 5 | 3 | 2 |
| 7 | 4 | 3 |

> **Rule of thumb:** Use an **odd number** of members (3, 5, 7) to maximize fault tolerance.

With 3 members, the group can survive 1 member failure and continue operating automatically.

---

## 2.3 Single-Primary vs Multi-Primary Mode

### Single-Primary Mode (Default)

```
                        ┌─────────────────┐
  Application Writes ──►│   Primary (RW)  │
                        └────────┬────────┘
                                 │ Replication
                    ┌────────────┼────────────┐
                    ▼            ▼            ▼
             ┌──────────┐ ┌──────────┐ ┌──────────┐
             │Secondary1│ │Secondary2│ │Secondary3│
             │  (RO)    │ │  (RO)    │ │  (RO)    │
             └──────────┘ └──────────┘ └──────────┘
                    ◄─── Reads can go here ───►
```

**Characteristics:**
- Only one member accepts writes at a time (the **Primary**)
- All other members are read-only Secondaries
- When primary fails, the group automatically elects a new primary
- No write conflicts possible (only one writer)
- Recommended for most production workloads

**Primary election algorithm in MySQL 8.0:**
1. Member with lowest `member_weight` (higher weight wins, default=50)
2. If tie: member with highest server_version
3. If tie: member with lexicographically smallest server_uuid

### Multi-Primary Mode

```
       ┌─────────┐    ┌─────────┐    ┌─────────┐
Writes►│Primary 1│◄──►│Primary 2│◄──►│Primary 3│◄ Writes
       │  (RW)   │    │  (RW)   │    │  (RW)   │
       └─────────┘    └─────────┘    └─────────┘
```

**Characteristics:**
- ALL members accept writes simultaneously
- Conflict detection handles concurrent modifications
- Higher throughput for write-heavy workloads
- More complex; conflicts can cause rollbacks
- Requires careful application design to minimize conflicts

**Conflicts in Multi-Primary:**
When two members concurrently modify the same row, the one that commits first "wins" and the other is rolled back. The application must handle `ERROR 1180 (HY000): Got error 149 during COMMIT` (deadlock-like error).

---

## 2.4 Certification and Conflict Detection

### How Certification Works

Every transaction in Group Replication carries a **write-set** — a compact representation of every row (by primary key) that was modified.

During certification:

```sql
-- Thread 1 on Member1 modifies:
UPDATE products SET price = 100 WHERE id = 5;
-- Write-set: {products:id=5}

-- Thread 2 on Member2 (concurrently) modifies:
UPDATE products SET price = 110 WHERE id = 5;
-- Write-set: {products:id=5}

-- Both send to GCS at roughly the same time
-- GCS orders them: Thread1 first, Thread2 second
-- Thread1 certifies OK --> commits
-- Thread2 certifies: conflict with Thread1! --> ROLLBACK
```

### Certification Database

Each member maintains an in-memory **certification database** that tracks:
- Which rows were modified by which transactions (by snapshot version)
- Used to detect conflicts during the certification phase
- Periodically garbage-collected after all members apply old transactions

### Flow Control

Group Replication has a **flow control** mechanism to prevent fast members from getting too far ahead of slow members:

```sql
-- Check flow control status
SELECT * FROM performance_schema.replication_group_member_stats\G

-- Relevant variable:
SHOW VARIABLES LIKE 'group_replication_flow_control_mode';
-- QUOTA (default) or DISABLED
```

---

## 2.5 Lab Environment Setup

### Infrastructure Requirements

For Group Replication, you need **minimum 3 servers**:

| Role | Hostname | IP Address | MySQL Port | Group Port |
|---|---|---|---|---|
| Member 1 (Initial Primary) | mgr-node1 | 192.168.56.10 | 3306 | 33061 |
| Member 2 | mgr-node2 | 192.168.56.20 | 3306 | 33061 |
| Member 3 | mgr-node3 | 192.168.56.30 | 3306 | 33061 |

### Step 1: Install MySQL 8.0 on All Three Servers

Perform on **ALL THREE servers**:

```bash
# Install MySQL 8.0 repository (Rocky/RHEL 8)
sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el8-9.noarch.rpm

# For Rocky/RHEL 9:
sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm

# Disable default MySQL module (RHEL/Rocky 8)
sudo dnf module disable mysql -y

# Install MySQL
sudo dnf install mysql-community-server -y

# Start MySQL
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Get temporary root password
sudo grep 'temporary password' /var/log/mysqld.log

# Secure MySQL
sudo mysql_secure_installation
```

### Step 2: Configure Firewall on ALL Servers

```bash
# Allow MySQL data port
sudo firewall-cmd --permanent --add-port=3306/tcp

# Allow Group Replication communication port
sudo firewall-cmd --permanent --add-port=33061/tcp

sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

### Step 3: Generate a Group Name (UUID)

Group Replication requires a unique group UUID. Generate one:

```bash
# On any server (or your laptop)
python3 -c "import uuid; print(str(uuid.uuid4()))"
# Example output: aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
# Use this UUID in group_replication_group_name
```

Or use MySQL's UUID() function:

```sql
SELECT UUID();
-- Note this value; you'll use it for all members
```

**For this lab, we'll use:** `aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb`

### Step 4: Configure /etc/hosts on ALL Servers

```bash
sudo tee -a /etc/hosts <<EOF
192.168.56.10   mgr-node1
192.168.56.20   mgr-node2
192.168.56.30   mgr-node3
EOF
```

---

## 2.6 Lab 4: Single-Primary Group Replication Setup

### Objective
Deploy a 3-member MySQL Group Replication cluster in Single-Primary mode.

---

### PART A: Configure my.cnf on ALL Three Members

**On mgr-node1** (`/etc/my.cnf`):

```ini
[mysqld]
# ============================================================
# Basic Settings
# ============================================================
server_id            = 1
datadir              = /var/lib/mysql
socket               = /var/lib/mysql/mysql.sock
log_error            = /var/log/mysqld.log
pid_file             = /var/run/mysqld/mysqld.pid

# ============================================================
# Binary Logging (REQUIRED for Group Replication)
# ============================================================
log_bin              = /var/lib/mysql/mysql-bin
binlog_format        = ROW
binlog_row_image     = FULL
log_replica_updates  = ON
expire_logs_days     = 7
sync_binlog          = 1

# ============================================================
# GTID (REQUIRED for Group Replication)
# ============================================================
gtid_mode                = ON
enforce_gtid_consistency = ON

# ============================================================
# Replication Settings
# ============================================================
replica_preserve_commit_order = ON

# ============================================================
# InnoDB (REQUIRED settings for Group Replication)
# ============================================================
innodb_flush_log_at_trx_commit = 1

# Transaction write-set extraction (REQUIRED)
transaction_write_set_extraction = XXHASH64

# ============================================================
# Group Replication Plugin Settings
# ============================================================

# The group's unique identifier (SAME on all members)
loose-group_replication_group_name = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"

# This is the LOCAL member's communication endpoint
# Format: <this_server_IP>:<group_replication_port>
loose-group_replication_local_address = "192.168.56.10:33061"

# Comma-separated list of ALL group members' communication endpoints
# (seeds used to join/bootstrap the group)
loose-group_replication_group_seeds = "192.168.56.10:33061,192.168.56.20:33061,192.168.56.30:33061"

# IMPORTANT: Bootstrap is used ONLY for the first start of the group
# Set to OFF after initial bootstrap!
loose-group_replication_bootstrap_group = OFF

# Single primary mode (ON = single primary, OFF = multi-primary)
loose-group_replication_single_primary_mode = ON

# When single_primary_mode=ON, enforce it
loose-group_replication_enforce_update_everywhere_checks = OFF

# Plugin installation
loose-group_replication_start_on_boot = OFF
```

**On mgr-node2** (`/etc/my.cnf`):

Same as mgr-node1 except change these lines:

```ini
server_id = 2
loose-group_replication_local_address = "192.168.56.20:33061"
```

(All other Group Replication settings including `group_replication_group_name` and `group_replication_group_seeds` remain the same)

**On mgr-node3** (`/etc/my.cnf`):

Same as mgr-node1 except:

```ini
server_id = 3
loose-group_replication_local_address = "192.168.56.30:33061"
```

### PART B: Restart MySQL on All Nodes

```bash
# On each node:
sudo systemctl restart mysqld
sudo systemctl status mysqld
```

Verify basic settings:

```sql
-- On each node:
SHOW VARIABLES LIKE 'server_id';
SHOW VARIABLES LIKE 'gtid_mode';
SHOW VARIABLES LIKE 'binlog_format';
SHOW VARIABLES LIKE 'transaction_write_set_extraction';
```

### PART C: Install Group Replication Plugin on All Nodes

**On ALL THREE nodes:**

```sql
mysql -uroot -p

-- Install the Group Replication plugin
INSTALL PLUGIN group_replication SONAME 'group_replication.so';

-- Verify plugin is installed and active
SHOW PLUGINS;
-- Look for: | group_replication | ACTIVE | GROUP REPLICATION | group_replication.so | GPL

-- Or query directly:
SELECT PLUGIN_NAME, PLUGIN_STATUS FROM information_schema.PLUGINS
WHERE PLUGIN_NAME = 'group_replication';
```

### PART D: Create Replication User on All Nodes

**On ALL THREE nodes:**

```sql
mysql -uroot -p

-- Disable binary logging for these admin statements
SET SQL_LOG_BIN = 0;

-- Create the group replication recovery user
CREATE USER 'gr_repl'@'%' IDENTIFIED WITH mysql_native_password BY 'GRRepl@123!';
GRANT REPLICATION SLAVE ON *.* TO 'gr_repl'@'%';
GRANT BACKUP_ADMIN ON *.* TO 'gr_repl'@'%';
FLUSH PRIVILEGES;

-- Re-enable binary logging
SET SQL_LOG_BIN = 1;

-- Configure the recovery channel credentials
CHANGE REPLICATION SOURCE TO
    SOURCE_USER = 'gr_repl',
    SOURCE_PASSWORD = 'GRRepl@123!'
    FOR CHANNEL 'group_replication_recovery';
```

> **Why `SET SQL_LOG_BIN=0`?** The user creation and GRANT statements should not be written to binary logs for the recovery channel, because all members will independently create this user.

### PART E: Bootstrap the Group from Node 1

**ONLY on mgr-node1** (the first/bootstrap node):

```sql
mysql -uroot -p

-- Enable bootstrap mode ONLY on the first node and ONLY for initial setup
SET GLOBAL group_replication_bootstrap_group = ON;

-- Start Group Replication
START GROUP_REPLICATION;

-- Immediately disable bootstrap (important!)
SET GLOBAL group_replication_bootstrap_group = OFF;

-- Verify this node is now in the group as Primary
SELECT * FROM performance_schema.replication_group_members\G
```

Expected output:

```
CHANNEL_NAME: group_replication_applier
   MEMBER_ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
 MEMBER_HOST: mgr-node1
 MEMBER_PORT: 3306
MEMBER_STATE: ONLINE
 MEMBER_ROLE: PRIMARY
MEMBER_VERSION: 8.0.xx
```

### PART F: Join Node 2 to the Group

**On mgr-node2:**

```sql
mysql -uroot -p

-- Start Group Replication (no bootstrap needed for joining members)
START GROUP_REPLICATION;

-- Verify both nodes are now in the group
SELECT * FROM performance_schema.replication_group_members\G
```

Expected output (2 members):

```
CHANNEL_NAME: group_replication_applier
   MEMBER_ID: aaaaa...
 MEMBER_HOST: mgr-node1
 MEMBER_STATE: ONLINE
 MEMBER_ROLE: PRIMARY

CHANNEL_NAME: group_replication_applier
   MEMBER_ID: bbbbb...
 MEMBER_HOST: mgr-node2
 MEMBER_STATE: ONLINE
 MEMBER_ROLE: SECONDARY
```

### PART G: Join Node 3 to the Group

**On mgr-node3:**

```sql
mysql -uroot -p

START GROUP_REPLICATION;

-- Verify all three nodes are online
SELECT * FROM performance_schema.replication_group_members\G
```

All three nodes should show `MEMBER_STATE: ONLINE`.

### PART H: Test Data Replication

**On the PRIMARY (mgr-node1):**

```sql
mysql -uroot -p

-- Create test database and tables
CREATE DATABASE mgr_test;
USE mgr_test;

CREATE TABLE orders (
    order_id     INT AUTO_INCREMENT PRIMARY KEY,
    customer     VARCHAR(100) NOT NULL,
    product      VARCHAR(100) NOT NULL,
    quantity     INT NOT NULL,
    unit_price   DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    order_date   DATETIME DEFAULT CURRENT_TIMESTAMP,
    status       ENUM('pending','processing','shipped','delivered') DEFAULT 'pending'
) ENGINE=InnoDB;

CREATE TABLE products (
    product_id   INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category     VARCHAR(50),
    stock        INT DEFAULT 0,
    price        DECIMAL(10,2) NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Insert test products
INSERT INTO products (product_name, category, stock, price) VALUES
('Laptop Pro 15', 'Electronics', 50, 1299.99),
('Wireless Mouse', 'Accessories', 200, 29.99),
('USB-C Hub 7-in-1', 'Accessories', 150, 49.99),
('4K Monitor 27"', 'Electronics', 30, 449.99),
('Mechanical Keyboard', 'Accessories', 75, 129.99);

-- Insert test orders
INSERT INTO orders (customer, product, quantity, unit_price, status) VALUES
('Alice Thompson', 'Laptop Pro 15', 1, 1299.99, 'delivered'),
('Bob Martinez', 'Wireless Mouse', 2, 29.99, 'shipped'),
('Carol Singh', '4K Monitor 27"', 1, 449.99, 'processing'),
('David Kim', 'USB-C Hub 7-in-1', 3, 49.99, 'pending'),
('Eve Chen', 'Mechanical Keyboard', 1, 129.99, 'delivered');

SELECT * FROM products;
SELECT * FROM orders;
```

**On mgr-node2 (Secondary), verify data replicated:**

```sql
mysql -uroot -p

SELECT * FROM mgr_test.products;
SELECT * FROM mgr_test.orders;

-- This should work (read from secondary):
SELECT COUNT(*) FROM mgr_test.orders;

-- This should FAIL (secondary is read-only):
INSERT INTO mgr_test.products (product_name, category, stock, price) VALUES ('Test', 'Test', 1, 1.00);
-- ERROR 1290: The MySQL server is running with the --super-read-only option...
```

**On mgr-node3 (Secondary), also verify:**

```sql
mysql -uroot -p

SELECT * FROM mgr_test.products;
SELECT COUNT(*) FROM mgr_test.orders WHERE status = 'delivered';
```

---

### PART I: Test Automatic Failover

This is the most critical test — what happens when the primary fails?

**First, note the current primary:**

```sql
-- On any node:
SELECT MEMBER_HOST, MEMBER_ROLE
FROM performance_schema.replication_group_members
WHERE MEMBER_ROLE = 'PRIMARY';
-- Expected: mgr-node1 is PRIMARY
```

**Simulate primary failure — on mgr-node1:**

```bash
# Simulate crash by stopping MySQL
sudo systemctl stop mysqld
```

**On mgr-node2, check group status:**

```sql
mysql -uroot -p

-- Check group members (should show only 2 members, one as new PRIMARY)
SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE
FROM performance_schema.replication_group_members;
```

Expected:
```
MEMBER_HOST  MEMBER_STATE  MEMBER_ROLE
mgr-node2    ONLINE        PRIMARY     <-- Auto-elected!
mgr-node3    ONLINE        SECONDARY
```

**Verify you can now write to mgr-node2 (new primary):**

```sql
-- On mgr-node2 (now primary):
USE mgr_test;
INSERT INTO products (product_name, category, stock, price) VALUES
('After Failover Product', 'Test', 10, 9.99);

SELECT * FROM products WHERE product_name = 'After Failover Product';
```

**Restore mgr-node1 and rejoin the group:**

```bash
# On mgr-node1:
sudo systemctl start mysqld
```

```sql
-- On mgr-node1:
mysql -uroot -p

-- Rejoin the group (it will become a secondary now)
START GROUP_REPLICATION;

-- Verify all 3 members are online
SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE
FROM performance_schema.replication_group_members;
```

The group should now have all 3 members, with mgr-node2 remaining as primary (unless you switch it back manually).

**Manually switch primary back to mgr-node1 (optional):**

```sql
-- On any node (or specifically on current primary):
SELECT group_replication_set_as_primary('mgr-node1-uuid-here');

-- To get the UUID of mgr-node1:
SELECT MEMBER_ID, MEMBER_HOST
FROM performance_schema.replication_group_members
WHERE MEMBER_HOST = 'mgr-node1';

-- Then:
SELECT group_replication_set_as_primary('<mgr-node1-member-id>');
```

---

## 2.7 Lab 5: Multi-Primary Group Replication Setup

### Objective
Convert the existing Single-Primary cluster to Multi-Primary mode, or set up a fresh multi-primary cluster.

### Option A: Convert Existing Single-Primary to Multi-Primary

**On the CURRENT PRIMARY, run:**

```sql
mysql -uroot -p

-- Switch to multi-primary mode online
SELECT group_replication_switch_to_multi_primary_mode();

-- Verify
SELECT MEMBER_HOST, MEMBER_ROLE
FROM performance_schema.replication_group_members;
-- All members should now show ROLE = 'PRIMARY'
```

### Option B: Set Up Fresh Multi-Primary from Scratch

**Configuration changes** — on ALL nodes, in `/etc/my.cnf`:

```ini
# Change these two settings:
loose-group_replication_single_primary_mode         = OFF
loose-group_replication_enforce_update_everywhere_checks = ON
```

Restart and bootstrap as before (same steps as Lab 4).

### Testing Multi-Primary: Concurrent Writes

**On mgr-node1:**

```sql
mysql -uroot -p

USE mgr_test;
INSERT INTO products (product_name, category, stock, price)
VALUES ('Node1 Product', 'Test', 100, 19.99);
SELECT * FROM products WHERE product_name = 'Node1 Product';
```

**On mgr-node2 (simultaneously):**

```sql
mysql -uroot -p

USE mgr_test;
INSERT INTO products (product_name, category, stock, price)
VALUES ('Node2 Product', 'Test', 200, 29.99);
SELECT * FROM products WHERE product_name = 'Node2 Product';
```

**On mgr-node3, verify both products appeared:**

```sql
mysql -uroot -p

SELECT * FROM mgr_test.products WHERE category = 'Test';
-- Should see BOTH Node1 Product and Node2 Product
```

### Simulating a Write Conflict in Multi-Primary

```sql
-- Preparation: Create a conflict scenario
-- Session 1 (on mgr-node1), do NOT commit yet:
START TRANSACTION;
UPDATE mgr_test.products SET price = 999.99 WHERE product_id = 1;
-- Do NOT commit yet

-- Session 2 (on mgr-node2), update the SAME row:
START TRANSACTION;
UPDATE mgr_test.products SET price = 888.88 WHERE product_id = 1;
COMMIT;  -- This commits first

-- Back to Session 1, now try to commit:
COMMIT;
-- ERROR 1180 (HY000): Got error 149 during COMMIT
-- The transaction was rolled back due to conflict!
```

The later transaction (from mgr-node1 in this example) is rolled back because mgr-node2 committed first and the certification detected the conflict.

---

## 2.8 Lab 6: Group Replication Monitoring

### Complete Monitoring Queries

```sql
-- ============================================================
-- 1. GROUP MEMBER STATUS (most important query)
-- ============================================================
SELECT
    MEMBER_ID,
    MEMBER_HOST,
    MEMBER_PORT,
    MEMBER_STATE,
    MEMBER_ROLE,
    MEMBER_VERSION
FROM performance_schema.replication_group_members
ORDER BY MEMBER_ROLE DESC;

-- ============================================================
-- 2. GROUP STATISTICS (per member stats)
-- ============================================================
SELECT
    MEMBER_ID,
    COUNT_TRANSACTIONS_IN_QUEUE,
    COUNT_TRANSACTIONS_CHECKED,
    COUNT_CONFLICTS_DETECTED,
    COUNT_TRANSACTIONS_ROWS_VALIDATING,
    TRANSACTIONS_COMMITTED_ALL_MEMBERS,
    LAST_CONFLICT_FREE_TRANSACTION
FROM performance_schema.replication_group_member_stats\G

-- ============================================================
-- 3. REPLICATION APPLIER STATUS
-- ============================================================
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    REMAINING_DELAY,
    COUNT_TRANSACTIONS_RETRIES
FROM performance_schema.replication_applier_status;

-- ============================================================
-- 4. RECOVERY CHANNEL STATUS (used during member joining)
-- ============================================================
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    RECEIVED_TRANSACTION_SET,
    LAST_ERROR_MESSAGE
FROM performance_schema.replication_connection_status
WHERE CHANNEL_NAME LIKE 'group_replication%'\G

-- ============================================================
-- 5. CHECK TRANSACTION QUEUE DEPTH (flow control indicator)
-- ============================================================
SELECT
    MEMBER_HOST,
    COUNT_TRANSACTIONS_IN_QUEUE AS tx_queue_depth,
    COUNT_TRANSACTIONS_CHECKED AS tx_certified,
    COUNT_CONFLICTS_DETECTED AS conflicts
FROM performance_schema.replication_group_member_stats
JOIN performance_schema.replication_group_members USING (MEMBER_ID);

-- ============================================================
-- 6. WHO IS THE PRIMARY? (Quick lookup)
-- ============================================================
SELECT
    MEMBER_HOST,
    MEMBER_PORT,
    MEMBER_ROLE
FROM performance_schema.replication_group_members
WHERE MEMBER_ROLE = 'PRIMARY';

-- Alternatively (returns the primary's server UUID):
SELECT group_replication_primary_member();
-- Or in MySQL 8.0.22+:
SELECT MEMBER_ID, MEMBER_HOST
FROM performance_schema.replication_group_members
WHERE MEMBER_ID = (
    SELECT VARIABLE_VALUE
    FROM performance_schema.global_status
    WHERE VARIABLE_NAME = 'group_replication_primary_member_uuid'
);

-- ============================================================
-- 7. GLOBAL STATUS VARIABLES FOR GROUP REPLICATION
-- ============================================================
SHOW GLOBAL STATUS LIKE 'group_replication%';

-- Key status variables:
-- group_replication_primary_member_uuid  : UUID of current primary
-- group_replication_group_name           : current group name

-- ============================================================
-- 8. CHECK APPLIER WORKER THREADS
-- ============================================================
SELECT
    CHANNEL_NAME,
    WORKER_ID,
    SERVICE_STATE,
    LAST_APPLIED_TRANSACTION,
    APPLYING_TRANSACTION,
    LAST_ERROR_MESSAGE
FROM performance_schema.replication_applier_status_by_worker
WHERE CHANNEL_NAME = 'group_replication_applier'\G
```

### Monitoring Shell Script

Create `/usr/local/bin/mgr_status.sh`:

```bash
#!/bin/bash
# MySQL Group Replication Health Check Script
# Usage: ./mgr_status.sh [mysql_user] [mysql_password]

MYSQL_USER=${1:-root}
MYSQL_PASS=${2:-''}
MYSQL_CMD="mysql -u${MYSQL_USER} -p${MYSQL_PASS} -e"

echo "============================================="
echo "MySQL Group Replication Status"
echo "Date: $(date)"
echo "Host: $(hostname)"
echo "============================================="

echo ""
echo "--- GROUP MEMBERS ---"
${MYSQL_CMD} "
SELECT
    MEMBER_HOST AS Host,
    MEMBER_PORT AS Port,
    MEMBER_STATE AS State,
    MEMBER_ROLE AS Role,
    MEMBER_VERSION AS Version
FROM performance_schema.replication_group_members
ORDER BY MEMBER_ROLE DESC;" 2>/dev/null

echo ""
echo "--- TRANSACTION STATS ---"
${MYSQL_CMD} "
SELECT
    m.MEMBER_HOST AS Host,
    s.COUNT_TRANSACTIONS_IN_QUEUE AS Queue,
    s.COUNT_CONFLICTS_DETECTED AS Conflicts,
    s.LAST_CONFLICT_FREE_TRANSACTION AS Last_OK_TX
FROM performance_schema.replication_group_member_stats s
JOIN performance_schema.replication_group_members m USING(MEMBER_ID);" 2>/dev/null

echo ""
echo "--- PRIMARY MEMBER ---"
${MYSQL_CMD} "
SELECT MEMBER_HOST, MEMBER_PORT
FROM performance_schema.replication_group_members
WHERE MEMBER_ROLE = 'PRIMARY';" 2>/dev/null

echo ""
echo "--- REPLICATION CHANNEL STATUS ---"
${MYSQL_CMD} "
SELECT CHANNEL_NAME, SERVICE_STATE, LAST_ERROR_MESSAGE
FROM performance_schema.replication_connection_status;" 2>/dev/null
```

```bash
chmod +x /usr/local/bin/mgr_status.sh
/usr/local/bin/mgr_status.sh root 'your_password'
```

---

## 2.9 Lab 7: Failure Simulation and Recovery

### Scenario 1: Planned Primary Stop

```sql
-- Step 1: Check current state
SELECT MEMBER_HOST, MEMBER_ROLE FROM performance_schema.replication_group_members;

-- Step 2: Stop GR gracefully on primary before shutting down
STOP GROUP_REPLICATION;

-- Step 3: Shut down (or restart) the server
-- systemctl stop mysqld (from OS)
```

On remaining members:
```sql
-- Verify automatic failover occurred
SELECT MEMBER_HOST, MEMBER_ROLE FROM performance_schema.replication_group_members;
-- A new primary is elected from the remaining 2 members
```

### Scenario 2: Unplanned Member Failure (crash)

```bash
# Simulate crash: kill MySQL process
sudo kill -9 $(pidof mysqld)
```

On surviving members, the group detects the failure after the timeout (`group_replication_member_expel_timeout`, default 5 seconds) and removes the failed member.

```sql
-- Check group without the failed member
SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE
FROM performance_schema.replication_group_members;
-- Failed member should be gone
```

### Scenario 3: Network Partition / Split-Brain

If a minority partition (1 of 3 members) loses network to the other two, it enters **ERROR** state automatically because it loses quorum.

```sql
-- On the isolated member, after network is restored:
STOP GROUP_REPLICATION;
START GROUP_REPLICATION;
-- It will rejoin the group and sync data from other members
```

### Scenario 4: Rejoin a Failed Member

```bash
# Restart MySQL on the failed node
sudo systemctl start mysqld
```

```sql
-- Rejoin the group
mysql -uroot -p

START GROUP_REPLICATION;

-- Monitor the joining process (may take time if data catch-up needed)
SELECT MEMBER_HOST, MEMBER_STATE FROM performance_schema.replication_group_members;
-- MEMBER_STATE will go through: RECOVERING --> ONLINE
```

### Monitor the Recovery Process

```sql
-- Watch recovery progress on the joining node:
SHOW REPLICA STATUS FOR CHANNEL 'group_replication_recovery'\G

-- Check from performance_schema:
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    RECEIVED_TRANSACTION_SET,
    LAST_QUEUED_TRANSACTION
FROM performance_schema.replication_connection_status
WHERE CHANNEL_NAME = 'group_replication_recovery'\G
```

---

## 2.10 Lab 8: Adding a New Member to an Existing Group

### Objective
Add a 4th member (mgr-node4, 192.168.56.40) to an already-running 3-member group.

### Step 1: Install MySQL on mgr-node4

```bash
# Follow the same installation steps as Lab 4 setup
sudo rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el8-9.noarch.rpm
sudo dnf module disable mysql -y
sudo dnf install mysql-community-server -y
sudo systemctl start mysqld
sudo mysql_secure_installation
```

### Step 2: Configure my.cnf on mgr-node4

```ini
[mysqld]
server_id            = 4
datadir              = /var/lib/mysql
socket               = /var/lib/mysql/mysql.sock
log_error            = /var/log/mysqld.log
pid_file             = /var/run/mysqld/mysqld.pid

log_bin              = /var/lib/mysql/mysql-bin
binlog_format        = ROW
binlog_row_image     = FULL
log_replica_updates  = ON
expire_logs_days     = 7
sync_binlog          = 1

gtid_mode                = ON
enforce_gtid_consistency = ON
replica_preserve_commit_order = ON
innodb_flush_log_at_trx_commit = 1
transaction_write_set_extraction = XXHASH64

loose-group_replication_group_name       = "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb"
loose-group_replication_local_address    = "192.168.56.40:33061"
loose-group_replication_group_seeds      = "192.168.56.10:33061,192.168.56.20:33061,192.168.56.30:33061"
loose-group_replication_bootstrap_group  = OFF
loose-group_replication_single_primary_mode = ON
loose-group_replication_enforce_update_everywhere_checks = OFF
loose-group_replication_start_on_boot    = OFF
```

### Step 3: Open Firewall on mgr-node4

```bash
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --permanent --add-port=33061/tcp
sudo firewall-cmd --reload
```

### Step 4: Update /etc/hosts on ALL servers including mgr-node4

```bash
# On ALL servers (including existing 3 members):
echo "192.168.56.40   mgr-node4" | sudo tee -a /etc/hosts
```

### Step 5: Update group_seeds on Existing Members

```sql
-- On each existing member, add node4 to the group seeds:
SET GLOBAL group_replication_group_seeds = "192.168.56.10:33061,192.168.56.20:33061,192.168.56.30:33061,192.168.56.40:33061";
```

> Also update the `my.cnf` file on all existing members to persist this change.

### Step 6: Install Plugin and Create Replication User on mgr-node4

```sql
mysql -uroot -p

-- Install plugin
INSTALL PLUGIN group_replication SONAME 'group_replication.so';

-- Create replication user
SET SQL_LOG_BIN = 0;
CREATE USER 'gr_repl'@'%' IDENTIFIED WITH mysql_native_password BY 'GRRepl@123!';
GRANT REPLICATION SLAVE ON *.* TO 'gr_repl'@'%';
GRANT BACKUP_ADMIN ON *.* TO 'gr_repl'@'%';
FLUSH PRIVILEGES;
SET SQL_LOG_BIN = 1;

-- Configure recovery channel
CHANGE REPLICATION SOURCE TO
    SOURCE_USER = 'gr_repl',
    SOURCE_PASSWORD = 'GRRepl@123!'
    FOR CHANNEL 'group_replication_recovery';
```

### Step 7: Join mgr-node4 to the Group

```sql
-- On mgr-node4:
START GROUP_REPLICATION;

-- Monitor the RECOVERING state (it will sync all data from existing members)
SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE
FROM performance_schema.replication_group_members;

-- When MEMBER_STATE becomes ONLINE, node4 is fully synced
```

### Step 8: Verify node4 has All Data

```sql
-- On mgr-node4:
SHOW DATABASES;
SELECT * FROM mgr_test.products;
SELECT * FROM mgr_test.orders;
-- All data should be present
```

---

## 2.11 Practice Exercises - Group Replication

### Exercise 1: Group Replication Fundamentals
1. List all members in your group replication cluster and identify the current primary using Performance Schema queries (not just `SHOW REPLICA STATUS`).
2. Explain in your own words what happens at the network level when a transaction is committed on the primary in single-primary mode.
3. How many members can fail in a 5-member group before the group stops accepting writes? Justify your answer using the quorum formula.

### Exercise 2: Failover Testing
1. Insert 100 rows into `mgr_test.orders` on the primary using a loop or script.
2. While the insert is running, stop the primary MySQL service (simulate crash).
3. Observe which member becomes the new primary and how long failover takes.
4. Verify that all committed rows exist on the new primary.
5. Document any rows that were in-flight during the crash and whether they were committed or rolled back.

### Exercise 3: Read Load Distribution
1. Write a shell script that runs 1000 SELECT queries distributed across all secondary nodes.
2. Measure total query throughput with reads going to secondaries vs. all reads going to the primary.
3. Configure MySQL Router (if available) or write your own round-robin connection logic to distribute reads.

### Exercise 4: Multi-Primary Conflict Resolution
1. Convert your cluster to multi-primary mode using `group_replication_switch_to_multi_primary_mode()`.
2. Write a script that concurrently updates the same row from two different nodes.
3. Observe and document the error received by the losing transaction.
4. Implement retry logic in your script to handle the conflict error gracefully.
5. Switch back to single-primary mode using `group_replication_switch_to_single_primary_mode()`.

### Exercise 5: Group Replication Recovery
1. Stop Group Replication on all 3 members: `STOP GROUP_REPLICATION;` on each.
2. Start them back up (without bootstrap) and observe what happens — does the group form automatically? Why or why not?
3. Bootstrap the group correctly from one member.
4. Have the other two members rejoin.
5. Explain what `group_replication_bootstrap_group` does and why it should ALWAYS be set to OFF after the initial startup.

### Exercise 6: Monitoring and Alerting
1. Create a stored procedure that checks group health and sends an email alert (or writes to a log table) if:
   - Any member is not in ONLINE state
   - The number of ONLINE members drops below 2
   - `COUNT_CONFLICTS_DETECTED` exceeds 10 in a 5-minute window
2. Schedule this procedure to run every minute using MySQL Event Scheduler.

---

# Appendix

## A. Quick Reference: Key Configuration Parameters

### GTID Parameters

| Parameter | Description | Recommended Value |
|---|---|---|
| `gtid_mode` | Enable/disable GTID | `ON` |
| `enforce_gtid_consistency` | Prevent non-GTID-safe statements | `ON` |
| `log_bin` | Binary log location | `/var/lib/mysql/mysql-bin` |
| `binlog_format` | Binary log format | `ROW` |
| `log_replica_updates` | Replica logs applied transactions | `ON` |
| `sync_binlog` | Sync binlog on every commit | `1` |

### Group Replication Parameters

| Parameter | Description | Recommended Value |
|---|---|---|
| `group_replication_group_name` | Unique UUID for the group | A valid UUID |
| `group_replication_local_address` | Local GCS endpoint | `<ip>:33061` |
| `group_replication_group_seeds` | All member GCS endpoints | Comma-separated |
| `group_replication_bootstrap_group` | Enable bootstrap (first node only) | `OFF` (runtime only) |
| `group_replication_single_primary_mode` | Single vs multi-primary | `ON` |
| `group_replication_member_expel_timeout` | Seconds before expelling non-responsive member | `5` |
| `group_replication_flow_control_mode` | Flow control | `QUOTA` |

## B. Troubleshooting Checklist

### GTID Replication Issues

- [ ] `SHOW REPLICA STATUS\G` — check `Last_IO_Error` and `Last_SQL_Error`
- [ ] Check `Seconds_Behind_Source` — 0 means in sync
- [ ] Verify `gtid_mode = ON` on both primary and replica
- [ ] Confirm `server_id` is unique across all servers
- [ ] Check replication user permissions: `SHOW GRANTS FOR 'repl_user'@'...';`
- [ ] Verify firewall allows port 3306 between servers
- [ ] Check MySQL error log: `sudo tail -200 /var/log/mysqld.log`

### Group Replication Issues

- [ ] Check all members show `MEMBER_STATE = ONLINE`
- [ ] Verify port 33061 is open on all servers
- [ ] Ensure all members have the same `group_replication_group_name`
- [ ] Check `group_replication_bootstrap_group = OFF` (except during initial setup)
- [ ] Verify replication user exists and has correct grants on ALL nodes
- [ ] Check `transaction_write_set_extraction = XXHASH64`
- [ ] Ensure `binlog_format = ROW` on all nodes
- [ ] Check for quorum: at least ceil(N/2)+1 members must be online

## C. Common Error Messages and Solutions

| Error | Cause | Solution |
|---|---|---|
| `ERROR 1840: @@GLOBAL.GTID_PURGED can only be set when...` | Replica has non-empty `gtid_executed` | Run `RESET BINARY LOGS AND GTIDS;` first |
| `ERROR 1745: forbidden when ENFORCE_GTID_CONSISTENCY = ON` | Non-GTID-safe SQL | Rewrite SQL (see Section 1.8) |
| `ERROR 3098: The replication channel already exists` | Trying to reconfigure existing channel | Run `STOP REPLICA; RESET REPLICA ALL;` first |
| `ERROR 3092: The server is not configured properly to be member of a group` | Missing required settings | Check all Group Replication prerequisites |
| `ERROR 1180: Got error 149 during COMMIT` | Conflict in multi-primary mode | Add retry logic in application |
| `Member was expelled from the group` | Network timeout exceeded | Check network, adjust `member_expel_timeout` |

## D. Useful OS-Level Commands

```bash
# Check MySQL is running
sudo systemctl status mysqld

# View MySQL error log in real-time
sudo tail -f /var/log/mysqld.log

# Check which port MySQL is listening on
sudo ss -tlnp | grep mysql
sudo netstat -tlnp | grep 3306

# Check firewall rules
sudo firewall-cmd --list-all

# Check SELinux is not blocking MySQL
sudo ausearch -c mysqld --raw | audit2why

# Monitor network connectivity to group port
sudo ss -tlnp | grep 33061

# Check MySQL process
ps aux | grep mysqld

# Monitor MySQL binary logs
ls -lh /var/lib/mysql/mysql-bin.*

# Decode binary log (for debugging replication)
mysqlbinlog --base64-output=DECODE-ROWS -v /var/lib/mysql/mysql-bin.000001 | head -100
```

## E. Sample Test Data Setup Script

Save as `/tmp/setup_test_data.sql` and run on primary:

```sql
-- ============================================================
-- Complete Test Data Setup for Lab Exercises
-- Run on PRIMARY server only
-- ============================================================

-- Create databases
CREATE DATABASE IF NOT EXISTS gtid_test;
CREATE DATABASE IF NOT EXISTS mgr_test;

-- GTID test tables
USE gtid_test;

DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
    emp_id      INT AUTO_INCREMENT PRIMARY KEY,
    emp_name    VARCHAR(100) NOT NULL,
    department  VARCHAR(50),
    salary      DECIMAL(10,2),
    hire_date   DATE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_department (department),
    INDEX idx_hire_date (hire_date)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS departments;
CREATE TABLE departments (
    dept_id     INT AUTO_INCREMENT PRIMARY KEY,
    dept_name   VARCHAR(100) NOT NULL,
    manager     VARCHAR(100),
    budget      DECIMAL(15,2),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Insert 20 departments
INSERT INTO departments (dept_name, manager, budget) VALUES
('Engineering',    'Alice Johnson',   500000.00),
('Marketing',      'Bob Smith',       300000.00),
('HR',             'Carol White',     200000.00),
('Finance',        'David Brown',     400000.00),
('Sales',          'Eve Davis',       350000.00),
('Product',        'Frank Miller',    450000.00),
('Design',         'Grace Wilson',    250000.00),
('Legal',          'Henry Taylor',    300000.00),
('Operations',     'Iris Anderson',   500000.00),
('Customer Success','Jack Thomas',    200000.00);

-- Insert 50 employees
INSERT INTO employees (emp_name, department, salary, hire_date) VALUES
('John Doe',        'Engineering',    85000.00, '2020-01-15'),
('Jane Smith',      'Marketing',      72000.00, '2019-06-01'),
('Mike Johnson',    'Engineering',    90000.00, '2018-03-20'),
('Sarah Lee',       'HR',             65000.00, '2021-09-10'),
('Tom Wilson',      'Finance',        78000.00, '2020-11-05'),
('Diana Prince',    'Engineering',    95000.00, '2022-01-10'),
('Clark Kent',      'Sales',          68000.00, '2021-04-15'),
('Bruce Wayne',     'Finance',        110000.00,'2017-08-01'),
('Natasha Romanoff','Product',        88000.00, '2020-07-20'),
('Tony Stark',      'Engineering',    120000.00,'2016-01-01'),
('Steve Rogers',    'Operations',     75000.00, '2019-11-11'),
('Peter Parker',    'Engineering',    70000.00, '2022-06-15'),
('Wanda Maximoff',  'Design',         72000.00, '2021-03-01'),
('Vision',          'Engineering',    92000.00, '2020-09-30'),
('T-Challa',        'Operations',     98000.00, '2018-10-15'),
('Sam Wilson',      'Sales',          65000.00, '2022-01-20'),
('Bucky Barnes',    'Operations',     73000.00, '2021-07-04'),
('Nick Fury',       'Legal',          105000.00,'2015-05-01'),
('Maria Hill',      'HR',             80000.00, '2018-02-14'),
('Phil Coulson',    'Customer Success',70000.00,'2019-03-20');

-- MGR test tables
USE mgr_test;

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;

CREATE TABLE products (
    product_id   INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category     VARCHAR(50),
    stock        INT DEFAULT 0,
    price        DECIMAL(10,2) NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_category (category)
) ENGINE=InnoDB;

CREATE TABLE orders (
    order_id     INT AUTO_INCREMENT PRIMARY KEY,
    customer     VARCHAR(100) NOT NULL,
    product_id   INT,
    quantity     INT NOT NULL,
    unit_price   DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    order_date   DATETIME DEFAULT CURRENT_TIMESTAMP,
    status       ENUM('pending','processing','shipped','delivered','cancelled') DEFAULT 'pending',
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

INSERT INTO products (product_name, category, stock, price) VALUES
('Laptop Pro 15',        'Electronics',  50,  1299.99),
('Wireless Mouse',       'Accessories', 200,    29.99),
('USB-C Hub 7-in-1',     'Accessories', 150,    49.99),
('4K Monitor 27"',       'Electronics',  30,   449.99),
('Mechanical Keyboard',  'Accessories',  75,   129.99),
('Webcam HD 1080p',      'Electronics',  80,    79.99),
('Noise-Cancelling Headphones','Electronics',60,249.99),
('Ergonomic Chair',      'Furniture',    20,   599.99),
('Standing Desk',        'Furniture',    15,   799.99),
('Monitor Stand',        'Accessories', 100,    59.99);

INSERT INTO orders (customer, product_id, quantity, unit_price, status) VALUES
('Alice Thompson',   1, 1, 1299.99, 'delivered'),
('Bob Martinez',     2, 2,   29.99, 'shipped'),
('Carol Singh',      4, 1,  449.99, 'processing'),
('David Kim',        3, 3,   49.99, 'pending'),
('Eve Chen',         5, 1,  129.99, 'delivered'),
('Frank Nguyen',     7, 1,  249.99, 'shipped'),
('Grace Liu',        6, 2,   79.99, 'delivered'),
('Henry Patel',      8, 1,  599.99, 'processing'),
('Iris Johnson',     9, 1,  799.99, 'pending'),
('Jack Wilson',     10, 2,   59.99, 'delivered');

SELECT 'Setup complete!' AS Status;
SELECT 'gtid_test.employees:' AS '', COUNT(*) AS row_count FROM gtid_test.employees;
SELECT 'gtid_test.departments:' AS '', COUNT(*) AS row_count FROM gtid_test.departments;
SELECT 'mgr_test.products:' AS '', COUNT(*) AS row_count FROM mgr_test.products;
SELECT 'mgr_test.orders:' AS '', COUNT(*) AS row_count FROM mgr_test.orders;
```

---

*End of Training Material*

---

**Document Information**

| Field | Value |
|---|---|
| Version | 1.0 |
| MySQL Version | 8.0.x |
| OS Platform | Rocky Linux 8/9, RHEL 8/9 |
| Topics Covered | GTID Replication, Group Replication |
| Labs | 8 Lab Exercises |
| Practice Exercises | 11 Student Exercises |
| Estimated Study Time | 16–20 hours |
