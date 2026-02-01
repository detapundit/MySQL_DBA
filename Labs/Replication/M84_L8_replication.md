# MySQL 8.4 Replication Setup Guide for Rocky Linux 8

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Architecture Setup](#architecture-setup)
4. [Method 1: GTID-Based Replication (Recommended)](#method-1-gtid-based-replication-recommended)
5. [Method 2: Traditional Binary Log Position-Based Replication](#method-2-traditional-binary-log-position-based-replication)
6. [Verification & Testing](#verification--testing)
7. [Monitoring & Maintenance](#monitoring--maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

---

## Overview

This guide covers setting up MySQL 8.4 replication on Rocky Linux 8. We'll focus on **GTID-based replication** (the modern, recommended approach) and also cover traditional binary log position-based replication for reference.

### What is MySQL Replication?

MySQL replication allows data from one MySQL server (the **source**) to be automatically copied to one or more MySQL servers (**replicas**). This provides:

- **High availability** - Replicas can take over if source fails
- **Read scalability** - Distribute read queries across replicas
- **Data backup** - Real-time data redundancy
- **Analytics** - Run heavy queries on replicas without impacting source

### GTID vs Traditional Replication

| Feature | GTID-Based | Traditional (Position-Based) |
|---------|-----------|------------------------------|
| **Setup Complexity** | Simpler | More complex |
| **Failover** | Automatic, easier | Manual, error-prone |
| **Position Tracking** | Automatic | Manual (log file + position) |
| **Consistency Check** | Built-in | Manual verification needed |
| **MySQL Version** | 5.6+ | All versions |
| **Recommendation** | ✅ Use this | Legacy systems only |

**Recommendation:** Use GTID-based replication for all new deployments. It's simpler, more robust, and easier to manage.

---

## Prerequisites

### System Requirements

- **Two Rocky Linux 8 servers** (minimum)
  - Source Server: Primary database server
  - Replica Server: Secondary database server
- **MySQL 8.4.x installed** on both servers ([Installation Guide](mysql_8.4_installation_rocky_linux_8.md))
- **Root or sudo access** on both servers
- **Network connectivity** between servers
- **Same MySQL version** on both servers (very important!)

### Network Setup Example

For this guide, we'll use the following example configuration:

```
Source Server (Primary):
  - Hostname: mysql-source
  - IP Address: 192.168.1.10
  - Server ID: 1

Replica Server (Secondary):
  - Hostname: mysql-replica
  - IP Address: 192.168.1.20
  - Server ID: 2
```

**Important:** Replace these IP addresses with your actual server IPs throughout the guide.

### Verify MySQL Installation

On both servers, verify MySQL is installed and running:

```bash
mysql --version
sudo systemctl status mysqld
```

---

## Architecture Setup

Before configuring replication, ensure both servers can communicate:

### 1. Configure Firewall (On Both Servers)

Allow MySQL traffic between servers:

```bash
# On Source Server (192.168.1.10)
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.20" port port="3306" protocol="tcp" accept'
sudo firewall-cmd --reload

# On Replica Server (192.168.1.20)
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.10" port port="3306" protocol="tcp" accept'
sudo firewall-cmd --reload
```

### 2. Test Network Connectivity

From replica server, test connection to source:

```bash
telnet 192.168.1.10 3306
# or
nc -zv 192.168.1.10 3306
```

If the connection is successful, you should see output confirming the connection.

---

## Method 1: GTID-Based Replication (Recommended)

Global Transaction Identifiers (GTIDs) provide a simpler, more reliable way to set up and manage replication.

### Step 1: Configure Source Server

#### 1.1 Edit MySQL Configuration

Edit the MySQL configuration file on the source server:

```bash
sudo vim /etc/my.cnf
```

Add the following under the `[mysqld]` section:

```ini
[mysqld]
# Server identification
server-id = 1

# Binary logging
log-bin = mysql-bin
binlog_format = ROW

# GTID Configuration
gtid_mode = ON
enforce-gtid-consistency = ON
log-replica-updates = ON

# Networking
bind-address = 192.168.1.10

# Optional: Binary log retention (7 days = 604800 seconds)
binlog_expire_logs_seconds = 604800

# Optional: Specific databases to replicate (comment out to replicate all)
# binlog-do-db = myapp_db
# binlog-do-db = another_db

# Optional: Databases to ignore
# binlog-ignore-db = mysql
# binlog-ignore-db = information_schema
```

**Configuration Explanation:**

- `server-id`: Unique identifier for this server (must be different on each server)
- `log-bin`: Enables binary logging with specified prefix
- `binlog_format = ROW`: Best for GTID replication (recommended by MySQL)
- `gtid_mode = ON`: Enables GTID-based replication
- `enforce-gtid-consistency = ON`: Ensures only GTID-safe statements are executed
- `log-replica-updates = ON`: Required for GTID replication, logs replicated events
- `bind-address`: IP address MySQL listens on (use 0.0.0.0 for all interfaces)
- `binlog_expire_logs_seconds`: Auto-purge old binary logs after specified seconds

#### 1.2 Restart MySQL on Source

```bash
sudo systemctl restart mysqld
sudo systemctl status mysqld
```

#### 1.3 Create Replication User

Login to MySQL on the source server:

```bash
mysql -u root -p
```

Create a dedicated user for replication:

```sql
-- Create replication user (replace IP with your replica's IP)
CREATE USER 'replicator'@'192.168.1.20' IDENTIFIED WITH mysql_native_password BY 'Strong_Repl1cation_P@ssw0rd';

-- Grant replication privileges
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'192.168.1.20';

-- Apply changes
FLUSH PRIVILEGES;

-- Verify user creation
SELECT user, host FROM mysql.user WHERE user = 'replicator';
```

**Security Note:** Use a strong password and restrict the user to the replica's IP address only.

#### 1.4 Verify Source Configuration

Check that GTID is enabled and binary logging is active:

```sql
-- Check GTID mode
SHOW VARIABLES LIKE 'gtid_mode';

-- Check binary logging
SHOW VARIABLES LIKE 'log_bin';

-- Check server UUID (note this down)
SHOW VARIABLES LIKE 'server_uuid';

-- Show binary log status
SHOW BINARY LOG STATUS;
```

Expected output for `SHOW BINARY LOG STATUS`:

```
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000001 |      157 |              |                  | <gtid-set>        |
+------------------+----------+--------------+------------------+-------------------+
```

**Note:** In MySQL 8.0.x, use `SHOW MASTER STATUS` instead of `SHOW BINARY LOG STATUS`.

Exit MySQL:

```sql
EXIT;
```

---

### Step 2: Configure Replica Server

#### 2.1 Edit MySQL Configuration

On the replica server, edit the configuration file:

```bash
sudo vim /etc/my.cnf
```

Add the following under `[mysqld]`:

```ini
[mysqld]
# Server identification (MUST be different from source)
server-id = 2

# Binary logging (required for GTID)
log-bin = mysql-bin
binlog_format = ROW

# GTID Configuration
gtid_mode = ON
enforce-gtid-consistency = ON
log-replica-updates = ON

# Prevent automatic replica start (safer for initial setup)
skip-replica-start = ON

# Networking
bind-address = 192.168.1.20

# Read-only mode (recommended for replicas)
read_only = ON
super_read_only = ON

# Relay log configuration
relay-log = mysql-relay-bin
relay-log-recovery = ON

# Optional: Parallel replication workers (improves performance)
replica_parallel_workers = 4
replica_parallel_type = LOGICAL_CLOCK
```

**Configuration Explanation:**

- `server-id = 2`: Different from source (very important!)
- `skip-replica-start = ON`: Prevents automatic replication start on server boot
- `read_only = ON`: Prevents writes to replica (except from replication thread and SUPER users)
- `super_read_only = ON`: Prevents even SUPER users from writing
- `relay-log`: Prefix for relay log files
- `relay-log-recovery = ON`: Automatic relay log recovery after crashes
- `replica_parallel_workers = 4`: Number of parallel threads for applying changes (4-8 is optimal)

#### 2.2 Restart MySQL on Replica

```bash
sudo systemctl restart mysqld
sudo systemctl status mysqld
```

#### 2.3 Configure Replication Connection

Login to MySQL on the replica server:

```bash
mysql -u root -p
```

Configure the replica to connect to the source:

```sql
-- Stop replica if it's running
STOP REPLICA;

-- Configure source connection with GTID auto-positioning
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = '192.168.1.10',
    SOURCE_USER = 'replicator',
    SOURCE_PASSWORD = 'Strong_Repl1cation_P@ssw0rd',
    SOURCE_PORT = 3306,
    SOURCE_AUTO_POSITION = 1,
    SOURCE_RETRY_COUNT = 3,
    SOURCE_CONNECT_RETRY = 10;

-- Start replication
START REPLICA;

-- Check replication status (use \G for vertical output)
SHOW REPLICA STATUS\G
```

**Important Parameters:**

- `SOURCE_AUTO_POSITION = 1`: Enables GTID auto-positioning (automatic transaction tracking)
- `SOURCE_RETRY_COUNT = 3`: Number of reconnection attempts if source becomes unavailable
- `SOURCE_CONNECT_RETRY = 10`: Seconds between reconnection attempts

**Note:** In MySQL 8.0.22 and earlier, use `SLAVE` instead of `REPLICA` in commands (e.g., `SHOW SLAVE STATUS`).

#### 2.4 Verify Replication Status

After starting replication, check the status:

```sql
SHOW REPLICA STATUS\G
```

**Key fields to check:**

```
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Last_Error: (should be empty)
Seconds_Behind_Source: 0 (or small number)
Retrieved_Gtid_Set: (should show GTIDs)
Executed_Gtid_Set: (should match source over time)
Auto_Position: 1
```

**Both `Replica_IO_Running` and `Replica_SQL_Running` MUST be `Yes` for replication to work!**

If there are errors, see the [Troubleshooting](#troubleshooting) section.

Exit MySQL:

```sql
EXIT;
```

---

### Step 3: (Optional) Initial Data Sync

If your source server already has data, you need to sync it to the replica before starting replication.

#### 3.1 Create a Backup on Source

On the source server:

```bash
# Create backup directory
sudo mkdir -p /backup

# Dump all databases with GTID information
sudo mysqldump -u root -p \
    --all-databases \
    --single-transaction \
    --triggers \
    --routines \
    --events \
    --set-gtid-purged=ON \
    > /backup/full_backup.sql

# Check backup file
ls -lh /backup/full_backup.sql
```

**Options explained:**

- `--all-databases`: Backup all databases
- `--single-transaction`: Consistent backup without locking tables (for InnoDB)
- `--triggers`, `--routines`, `--events`: Include stored procedures, triggers, and events
- `--set-gtid-purged=ON`: Include GTID information for replication

#### 3.2 Transfer Backup to Replica

```bash
# From source server, copy to replica
scp /backup/full_backup.sql root@192.168.1.20:/backup/

# Or from replica server, pull from source
scp root@192.168.1.10:/backup/full_backup.sql /backup/
```

#### 3.3 Restore on Replica

On the replica server:

```bash
# Stop replication
mysql -u root -p -e "STOP REPLICA;"

# Restore the backup
mysql -u root -p < /backup/full_backup.sql

# Start replication
mysql -u root -p -e "START REPLICA;"
```

The `--set-gtid-purged=ON` option in mysqldump automatically sets the correct GTID position on the replica.

---

## Method 2: Traditional Binary Log Position-Based Replication

This method is included for reference or for legacy systems. **GTID-based replication is recommended for new deployments.**

### Step 1: Configure Source Server

#### 1.1 Edit MySQL Configuration

```bash
sudo vim /etc/my.cnf
```

Add under `[mysqld]`:

```ini
[mysqld]
# Server identification
server-id = 1

# Binary logging
log-bin = mysql-bin
binlog_format = ROW

# Networking
bind-address = 192.168.1.10

# Optional: Binary log retention (7 days)
binlog_expire_logs_seconds = 604800
```

#### 1.2 Restart MySQL

```bash
sudo systemctl restart mysqld
```

#### 1.3 Create Replication User

```sql
CREATE USER 'replicator'@'192.168.1.20' IDENTIFIED WITH mysql_native_password BY 'Strong_Repl1cation_P@ssw0rd';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'192.168.1.20';
FLUSH PRIVILEGES;
```

#### 1.4 Get Binary Log Position

**CRITICAL STEP:** Note the binary log file and position.

```sql
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
```

Output example:

```
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000001 |      157 |              |                  |
+------------------+----------+--------------+------------------+
```

**Write down:** `File: mysql-bin.000001` and `Position: 157`

**DO NOT EXIT MySQL or unlock tables yet if you need to take a backup!**

---

### Step 2: (Optional) Take Backup for Initial Sync

While tables are still locked:

```bash
# In a new terminal session on source server
sudo mysqldump -u root -p \
    --all-databases \
    --single-transaction \
    --triggers \
    --routines \
    --events \
    > /backup/full_backup.sql
```

After backup completes, unlock tables in the MySQL session:

```sql
UNLOCK TABLES;
EXIT;
```

Transfer backup to replica (as shown in GTID method).

---

### Step 3: Configure Replica Server

#### 3.1 Edit MySQL Configuration

```bash
sudo vim /etc/my.cnf
```

Add under `[mysqld]`:

```ini
[mysqld]
server-id = 2
log-bin = mysql-bin
binlog_format = ROW
skip-replica-start = ON
bind-address = 192.168.1.20
read_only = ON
super_read_only = ON
relay-log = mysql-relay-bin
relay-log-recovery = ON
```

#### 3.2 Restart MySQL

```bash
sudo systemctl restart mysqld
```

#### 3.3 Restore Backup (if taken)

```bash
mysql -u root -p < /backup/full_backup.sql
```

#### 3.4 Configure Replication

Login to MySQL on replica:

```bash
mysql -u root -p
```

Configure the replication source with the **exact** binary log file and position from Step 1.4:

```sql
STOP REPLICA;

CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = '192.168.1.10',
    SOURCE_USER = 'replicator',
    SOURCE_PASSWORD = 'Strong_Repl1cation_P@ssw0rd',
    SOURCE_PORT = 3306,
    SOURCE_LOG_FILE = 'mysql-bin.000001',
    SOURCE_LOG_POS = 157;

START REPLICA;

SHOW REPLICA STATUS\G
```

**Critical:** The `SOURCE_LOG_FILE` and `SOURCE_LOG_POS` must match the values from `SHOW MASTER STATUS` on the source.

---

## Verification & Testing

### Test 1: Create Database on Source

On the source server:

```bash
mysql -u root -p
```

```sql
-- Create test database
CREATE DATABASE replication_test;

-- Use the database
USE replication_test;

-- Create a test table
CREATE TABLE test_table (
    id INT PRIMARY KEY AUTO_INCREMENT,
    message VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test data
INSERT INTO test_table (message) VALUES 
    ('Test message 1'),
    ('Test message 2'),
    ('Test message 3');

-- Verify data
SELECT * FROM test_table;
```

### Test 2: Verify on Replica

On the replica server:

```bash
mysql -u root -p
```

```sql
-- Check if database exists
SHOW DATABASES LIKE 'replication_test';

-- Use the database
USE replication_test;

-- Verify table exists
SHOW TABLES;

-- Verify data was replicated
SELECT * FROM test_table;
```

**Expected Result:** The database, table, and all three rows should be present on the replica.

### Test 3: Check Replication Lag

On the replica:

```sql
SHOW REPLICA STATUS\G
```

Check the `Seconds_Behind_Source` field:

- `0`: Replica is fully caught up
- `1-5`: Normal, acceptable lag
- `>10`: Investigate potential issues

### Test 4: Verify GTID Consistency (GTID Replication Only)

On both source and replica:

```sql
-- Show executed GTIDs
SHOW VARIABLES LIKE 'gtid_executed';
```

The replica's `gtid_executed` should be a subset of (or equal to) the source's `gtid_executed`.

---

## Monitoring & Maintenance

### Monitor Replication Status

Create a monitoring script `/usr/local/bin/check_replication.sh`:

```bash
#!/bin/bash

REPLICA_STATUS=$(mysql -u root -p'YourRootPassword' -e "SHOW REPLICA STATUS\G" 2>/dev/null)

IO_RUNNING=$(echo "$REPLICA_STATUS" | grep "Replica_IO_Running:" | awk '{print $2}')
SQL_RUNNING=$(echo "$REPLICA_STATUS" | grep "Replica_SQL_Running:" | awk '{print $2}')
SECONDS_BEHIND=$(echo "$REPLICA_STATUS" | grep "Seconds_Behind_Source:" | awk '{print $2}')
LAST_ERROR=$(echo "$REPLICA_STATUS" | grep "Last_Error:" | cut -d: -f2-)

echo "=== MySQL Replication Status ==="
echo "IO Thread: $IO_RUNNING"
echo "SQL Thread: $SQL_RUNNING"
echo "Seconds Behind Source: $SECONDS_BEHIND"

if [ "$IO_RUNNING" != "Yes" ] || [ "$SQL_RUNNING" != "Yes" ]; then
    echo "ERROR: Replication is not running!"
    echo "Last Error: $LAST_ERROR"
    exit 1
else
    echo "Replication is running normally."
    exit 0
fi
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/check_replication.sh
```

### Set Up Cron Job for Monitoring

```bash
sudo crontab -e
```

Add this line to check every 5 minutes:

```cron
*/5 * * * * /usr/local/bin/check_replication.sh >> /var/log/mysql_replication_check.log 2>&1
```

### Useful Monitoring Queries

On the replica server:

```sql
-- Check replication status
SHOW REPLICA STATUS\G

-- View relay log files
SHOW RELAYLOG EVENTS;

-- Check GTID execution progress
SELECT * FROM performance_schema.replication_connection_status\G
SELECT * FROM performance_schema.replication_applier_status\G

-- Monitor replication lag
SELECT 
    TIMESTAMPDIFF(SECOND, ts, NOW()) as seconds_behind
FROM 
    (SELECT NOW() as ts) AS current_time;
```

On the source server:

```sql
-- View binary log files
SHOW BINARY LOGS;

-- Show current binary log position
SHOW BINARY LOG STATUS;

-- View binary log events
SHOW BINLOG EVENTS IN 'mysql-bin.000001' LIMIT 10;

-- Show connected replicas
SHOW REPLICAS;
-- Or in older versions:
SHOW SLAVE HOSTS;
```

### Purge Old Binary Logs

Binary logs accumulate over time. Purge old logs to save disk space:

```sql
-- Show binary logs
SHOW BINARY LOGS;

-- Purge logs before a specific log file (keeping that file and newer)
PURGE BINARY LOGS TO 'mysql-bin.000010';

-- Purge logs older than 7 days
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);
```

**Warning:** Only purge logs after ensuring replicas have applied them!

---

## Troubleshooting

### Problem 1: Replica Threads Not Running

**Symptoms:**

```
Replica_IO_Running: No
Replica_SQL_Running: No
```

**Solution:**

1. Check error log:

```bash
sudo tail -100 /var/log/mysqld.log
```

2. Common issues:

   - **Firewall blocking connection:** Check firewall rules
   - **Wrong credentials:** Verify replication user and password
   - **Network issues:** Test connectivity with `telnet` or `nc`
   - **Source server down:** Check source server status

3. Restart replication:

```sql
STOP REPLICA;
START REPLICA;
SHOW REPLICA STATUS\G
```

### Problem 2: Replication Lag

**Symptoms:**

```
Seconds_Behind_Source: 100+ (or increasing)
```

**Causes & Solutions:**

1. **Heavy write load on source:**
   - Increase `replica_parallel_workers` on replica (4-8 workers)
   - Optimize queries on source

2. **Slow replica hardware:**
   - Upgrade replica server resources
   - Use faster storage (SSD)

3. **Large transactions:**
   - Break large transactions into smaller batches
   - Avoid long-running transactions on source

### Problem 3: Duplicate Key Errors

**Symptoms:**

```
Last_Error: Error 'Duplicate entry' on query
```

**Solution (GTID replication):**

```sql
-- Stop replica
STOP REPLICA;

-- Skip the problematic GTID
SET GTID_NEXT='<problematic-gtid>';
BEGIN;
COMMIT;
SET GTID_NEXT='AUTOMATIC';

-- Restart replica
START REPLICA;
```

**Solution (Position-based replication):**

```sql
STOP REPLICA;
SET GLOBAL sql_replica_skip_counter = 1;
START REPLICA;
```

**Prevention:** Ensure `read_only` and `super_read_only` are enabled on replicas.

### Problem 4: Replica Falls Too Far Behind

If the replica is too far behind to catch up:

1. **Take a fresh backup from source**
2. **Restore on replica**
3. **Reconfigure replication**

### Problem 5: Connection Issues

**Error:** `Can't connect to MySQL server on '192.168.1.10'`

**Checklist:**

- [ ] Firewall allows traffic
- [ ] MySQL is listening on correct IP (`bind-address`)
- [ ] Replication user exists with correct permissions
- [ ] Network connectivity between servers

### View Detailed Error Information

```sql
-- On replica
SHOW REPLICA STATUS\G

-- Look for these fields:
-- Last_IO_Error
-- Last_SQL_Error
-- Last_Error

-- Check error log
SELECT * FROM performance_schema.replication_connection_status\G
SELECT * FROM performance_schema.replication_applier_status_by_worker\G
```

---

## Best Practices

### Security Best Practices

1. **Use strong passwords** for replication user
2. **Restrict replication user** to specific IP addresses only
3. **Enable SSL/TLS** for replication traffic:

```sql
CHANGE REPLICATION SOURCE TO
    SOURCE_SSL = 1,
    SOURCE_SSL_CA = '/path/to/ca.pem',
    SOURCE_SSL_CERT = '/path/to/client-cert.pem',
    SOURCE_SSL_KEY = '/path/to/client-key.pem';
```

4. **Enable `read_only` on replicas** to prevent accidental writes

### Performance Best Practices

1. **Use row-based replication** (`binlog_format = ROW`)
   - More reliable and consistent
   - Required for some features

2. **Enable parallel replication:**

```ini
replica_parallel_workers = 4
replica_parallel_type = LOGICAL_CLOCK
```

3. **Use SSDs** for binary log and relay log storage

4. **Monitor replication lag** and set up alerts

5. **Optimize `binlog_expire_logs_seconds`:**
   - Don't keep logs forever (disk space)
   - Keep them long enough for replica recovery (7-14 days is common)

### Operational Best Practices

1. **Always use GTID** for new setups - it's simpler and more reliable

2. **Test failover procedures** regularly

3. **Document your replication topology** clearly

4. **Set up monitoring and alerting:**
   - Replication lag > 10 seconds
   - Replica threads stopped
   - Disk space for binary logs

5. **Regular backups** - replication is NOT a backup solution!

6. **Version compatibility:**
   - Keep all servers on the same MySQL version
   - Replicas can be same or newer version (not older)

7. **Use consistent configuration** across source and replicas where possible

### Maintenance Best Practices

1. **Regular health checks:**

```bash
# Add to cron
*/5 * * * * /usr/local/bin/check_replication.sh
```

2. **Purge old binary logs** regularly (but safely!)

3. **Monitor disk usage:**

```bash
df -h /var/lib/mysql
du -sh /var/lib/mysql/mysql-bin.*
```

4. **Keep documentation updated** with current topology, IP addresses, and procedures

---

## Advanced Topics

### Multi-Source Replication

MySQL 8.4 supports replicating from multiple sources to a single replica:

```sql
-- Configure first source
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = '192.168.1.10',
    SOURCE_USER = 'replicator1',
    SOURCE_PASSWORD = 'password1',
    SOURCE_AUTO_POSITION = 1
FOR CHANNEL 'source1';

-- Configure second source
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = '192.168.1.11',
    SOURCE_USER = 'replicator2',
    SOURCE_PASSWORD = 'password2',
    SOURCE_AUTO_POSITION = 1
FOR CHANNEL 'source2';

-- Start both channels
START REPLICA FOR CHANNEL 'source1';
START REPLICA FOR CHANNEL 'source2';
```

### Delayed Replication

Create a replica that lags behind by a specific time (useful for recovering from user errors):

```sql
CHANGE REPLICATION SOURCE TO
    SOURCE_DELAY = 3600;  -- 1 hour delay
```

### Semi-Synchronous Replication

Ensures at least one replica has received the transaction before source commits:

```sql
-- On source
INSTALL PLUGIN rpl_semi_sync_source SONAME 'semisync_source.so';
SET GLOBAL rpl_semi_sync_source_enabled = 1;

-- On replica
INSTALL PLUGIN rpl_semi_sync_replica SONAME 'semisync_replica.so';
SET GLOBAL rpl_semi_sync_replica_enabled = 1;
```

---

## Replication Topology Diagrams

### Simple Source-Replica Setup

```
┌─────────────────┐
│  Source Server  │
│  192.168.1.10   │
│   (Read/Write)  │
└────────┬────────┘
         │
         │ Replicates
         ▼
┌─────────────────┐
│ Replica Server  │
│  192.168.1.20   │
│   (Read Only)   │
└─────────────────┘
```

### Source with Multiple Replicas

```
                ┌─────────────────┐
                │  Source Server  │
                │  192.168.1.10   │
                │   (Read/Write)  │
                └────────┬────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌────────────────┐ ┌────────────┐ ┌────────────┐
│   Replica 1    │ │ Replica 2  │ │ Replica 3  │
│ 192.168.1.20   │ │192.168.1.21│ │192.168.1.22│
│  (Read Only)   │ │(Read Only) │ │(Read Only) │
└────────────────┘ └────────────┘ └────────────┘
```

---

## Quick Reference Commands

### Source Server Commands

```sql
-- Create replication user
CREATE USER 'replicator'@'replica_ip' IDENTIFIED BY 'password';
GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'replica_ip';

-- Check binary log status (MySQL 8.4)
SHOW BINARY LOG STATUS;

-- Check binary log status (MySQL 8.0)
SHOW MASTER STATUS;

-- Show connected replicas
SHOW REPLICAS;

-- Purge old binary logs
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 7 DAY);
```

### Replica Server Commands

```sql
-- Configure replication (GTID)
CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='source_ip',
    SOURCE_USER='replicator',
    SOURCE_PASSWORD='password',
    SOURCE_AUTO_POSITION=1;

-- Start/stop replication
START REPLICA;
STOP REPLICA;

-- Check replication status
SHOW REPLICA STATUS\G

-- Reset replication (careful!)
RESET REPLICA ALL;
```

### System Commands

```bash
# Restart MySQL
sudo systemctl restart mysqld

# Check MySQL status
sudo systemctl status mysqld

# View MySQL error log
sudo tail -f /var/log/mysqld.log

# Check MySQL process
ps aux | grep mysql

# Check MySQL port
sudo netstat -tlnp | grep 3306
```

---

## Verification Checklist

After setup, verify the following:

**On Source Server:**

- [ ] MySQL is running
- [ ] Binary logging is enabled (`SHOW VARIABLES LIKE 'log_bin';`)
- [ ] GTID is enabled (if using GTID) (`SHOW VARIABLES LIKE 'gtid_mode';`)
- [ ] Replication user exists and has correct privileges
- [ ] Firewall allows connections from replica

**On Replica Server:**

- [ ] MySQL is running
- [ ] GTID is enabled (if using GTID)
- [ ] Replication is configured (`SHOW REPLICA STATUS\G`)
- [ ] Both IO and SQL threads are running
- [ ] `Seconds_Behind_Source` is 0 or low
- [ ] `read_only` is enabled
- [ ] Test data appears on replica

**Network:**

- [ ] Replica can connect to source (telnet/nc test)
- [ ] Firewall rules are correct on both servers

---

## Conclusion

You now have a complete MySQL 8.4 replication setup on Rocky Linux 8!

**Key Takeaways:**

- **Use GTID-based replication** for all new deployments - it's simpler and more reliable
- **Monitor replication health** regularly with automated scripts
- **Test failover procedures** before you need them
- **Replicas are for availability and scaling, NOT backups** - maintain separate backups
- **Keep documentation updated** with current topology and procedures

For questions or additional help, consult:
- [MySQL 8.4 Replication Documentation](https://dev.mysql.com/doc/refman/8.4/en/replication.html)
- [MySQL 8.4 GTID Documentation](https://dev.mysql.com/doc/refman/8.4/en/replication-gtids.html)

**Happy Replicating! 🚀**
