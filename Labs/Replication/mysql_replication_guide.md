# MySQL 8.0.45 Replication Setup Guide for Rocky Linux 8

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Part 1: Master Server Configuration](#part-1-master-server-configuration)
- [Part 2: Slave Server Configuration](#part-2-slave-server-configuration)
- [Part 3: Verification and Testing](#part-3-verification-and-testing)
- [Part 4: Detailed Filter Examples](#part-4-detailed-filter-examples)
- [Part 5: Firewall Configuration](#part-5-firewall-configuration)
- [Part 6: Monitoring Commands](#part-6-monitoring-commands)
- [Part 7: Important Filter Rules and Warnings](#part-7-important-filter-rules-and-warnings)
- [Part 8: Troubleshooting](#part-8-troubleshooting)

---

## Architecture Overview

- **Master Server**: Source database server
- **Slave Server**: Replica database server

---

## Part 1: Master Server Configuration

### Step 1: Configure MySQL on Master

Edit the MySQL configuration file:

```bash
sudo vi /etc/my.cnf
```

Add the following under `[mysqld]` section:

```ini
[mysqld]
# Server identification
server-id = 1
log-bin = /var/lib/mysql/mysql-bin
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 100M

# Binlog Filters (applied on MASTER during binary log writing)
# These determine what gets written to the binary log

# Example 1: Only log specific databases to binlog
binlog-do-db = production_db
binlog-do-db = sales_db

# Example 2: Exclude databases from binlog (DON'T use with binlog-do-db)
# binlog-ignore-db = test
# binlog-ignore-db = temp_db
# binlog-ignore-db = mysql
# binlog-ignore-db = information_schema
# binlog-ignore-db = performance_schema

# GTID Configuration (recommended for MySQL 8.0)
gtid_mode = ON
enforce_gtid_consistency = ON

# Binary log settings
sync_binlog = 1
binlog_expire_logs_seconds = 604800
```

**Important Notes on Binlog Filters:**
- `binlog-do-db`: Only these databases are logged to binary log
- `binlog-ignore-db`: These databases are NOT logged to binary log
- **Don't mix binlog-do-db and binlog-ignore-db** - use one approach or the other
- Binlog filters can cause issues with cross-database queries

### Step 2: Restart MySQL on Master

```bash
sudo systemctl restart mysqld
```

### Step 3: Create Replication User on Master

Login to MySQL:

```bash
mysql -u root -p
```

Create the replication user:

```sql
-- Create replication user
CREATE USER 'replication_user'@'%' IDENTIFIED WITH mysql_native_password BY 'StrongPassword123!';

-- Grant replication privileges
GRANT REPLICATION SLAVE ON *.* TO 'replication_user'@'%';

-- Flush privileges
FLUSH PRIVILEGES;

-- Check user creation
SELECT user, host FROM mysql.user WHERE user = 'replication_user';
```

### Step 4: Get Master Status

```sql
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
```

**Record the output** - you'll need:
- `File`: (e.g., mysql-bin.000001)
- `Position`: (e.g., 156)

Example output:
```
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000001 |      156 | production_db|                  |
+------------------+----------+--------------+------------------+
```

### Step 5: Backup Data (if you have existing data)

Open another terminal and create a backup:

```bash
mysqldump -u root -p --all-databases --master-data=2 --single-transaction > master_backup.sql
```

Or for specific databases:

```bash
mysqldump -u root -p --databases production_db sales_db --master-data=2 --single-transaction > master_backup.sql
```

Back in MySQL, unlock tables:

```sql
UNLOCK TABLES;
```

---

## Part 2: Slave Server Configuration

### Step 1: Transfer Backup to Slave (if applicable)

```bash
scp master_backup.sql root@slave_server_ip:/tmp/
```

### Step 2: Configure MySQL on Slave

Edit the MySQL configuration file:

```bash
sudo vi /etc/my.cnf
```

Add the following under `[mysqld]` section:

```ini
[mysqld]
# Server identification (MUST be different from master)
server-id = 2
log-bin = /var/lib/mysql/mysql-bin
binlog_format = ROW
relay-log = /var/lib/mysql/relay-bin
relay-log-index = /var/lib/mysql/relay-bin.index
read_only = 1

# Replication Filters (applied on SLAVE during replay)
# These determine what gets replicated on the slave

# DATABASE-LEVEL FILTERS

# Example 1: Only replicate specific databases
replicate-do-db = production_db
replicate-do-db = sales_db

# Example 2: Ignore specific databases (DON'T use with replicate-do-db)
# replicate-ignore-db = test
# replicate-ignore-db = temp_db
# replicate-ignore-db = mysql

# TABLE-LEVEL FILTERS

# Example 3: Replicate only specific tables
# replicate-do-table = production_db.customers
# replicate-do-table = production_db.orders
# replicate-do-table = sales_db.transactions

# Example 4: Ignore specific tables
# replicate-ignore-table = production_db.logs
# replicate-ignore-table = production_db.temp_data
# replicate-ignore-table = sales_db.cache

# WILDCARD FILTERS

# Example 5: Replicate tables matching pattern
# replicate-wild-do-table = production_db.prod_%
# replicate-wild-do-table = sales_db.sales_%

# Example 6: Ignore tables matching pattern
# replicate-wild-ignore-table = %.temp_%
# replicate-wild-ignore-table = %.cache_%
# replicate-wild-ignore-table = test.%

# REWRITE FILTERS

# Example 7: Rewrite database names during replication
# replicate-rewrite-db = source_db->target_db
# replicate-rewrite-db = old_sales->new_sales

# GTID Configuration
gtid_mode = ON
enforce_gtid_consistency = ON

# Relay log settings
sync_relay_log = 1
relay_log_recovery = 1
```

### Step 3: Restart MySQL on Slave

```bash
sudo systemctl restart mysqld
```

### Step 4: Restore Backup on Slave (if applicable)

```bash
mysql -u root -p < /tmp/master_backup.sql
```

### Step 5: Configure Replication on Slave

Login to MySQL on slave:

```bash
mysql -u root -p
```

Configure the slave connection:

```sql
-- Stop slave if running
STOP SLAVE;

-- Configure master connection (without GTID)
CHANGE MASTER TO
    MASTER_HOST='master_server_ip',
    MASTER_USER='replication_user',
    MASTER_PASSWORD='StrongPassword123!',
    MASTER_LOG_FILE='mysql-bin.000001',  -- From SHOW MASTER STATUS
    MASTER_LOG_POS=156;                   -- From SHOW MASTER STATUS

-- OR with GTID (recommended for MySQL 8.0)
-- CHANGE MASTER TO
--     MASTER_HOST='master_server_ip',
--     MASTER_USER='replication_user',
--     MASTER_PASSWORD='StrongPassword123!',
--     MASTER_AUTO_POSITION=1;

-- Start replication
START SLAVE;

-- Check slave status
SHOW SLAVE STATUS\G
```

---

## Part 3: Verification and Testing

### Step 1: Check Slave Status

```sql
SHOW SLAVE STATUS\G
```

Look for:
- `Slave_IO_Running: Yes`
- `Slave_SQL_Running: Yes`
- `Seconds_Behind_Master: 0` (or small number)
- `Last_Error:` (should be empty)

### Step 2: Test Replication

On **Master**:

```sql
-- Create test database
CREATE DATABASE test_replication;
USE test_replication;

-- Create test table
CREATE TABLE test_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test data
INSERT INTO test_table (data) VALUES ('Test data 1');
INSERT INTO test_table (data) VALUES ('Test data 2');
```

On **Slave**:

```sql
-- Check if database exists
SHOW DATABASES LIKE 'test_replication';

-- Check table and data
USE test_replication;
SELECT * FROM test_table;
```

---

## Part 4: Detailed Filter Examples

### Example Scenario 1: Replicate Only Production Databases

**Master** (`/etc/my.cnf`):
```ini
binlog-do-db = production_db
binlog-do-db = customer_db
```

**Slave** (`/etc/my.cnf`):
```ini
replicate-do-db = production_db
replicate-do-db = customer_db
```

### Example Scenario 2: Replicate All Except Test/Temp Data

**Master** (`/etc/my.cnf`):
```ini
binlog-ignore-db = test
binlog-ignore-db = temp
binlog-ignore-db = mysql
binlog-ignore-db = information_schema
binlog-ignore-db = performance_schema
binlog-ignore-db = sys
```

**Slave** (`/etc/my.cnf`):
```ini
replicate-ignore-db = test
replicate-ignore-db = temp
```

### Example Scenario 3: Replicate Specific Tables Only

**Slave** (`/etc/my.cnf`):
```ini
# Replicate only important tables
replicate-do-table = ecommerce.orders
replicate-do-table = ecommerce.customers
replicate-do-table = ecommerce.products
replicate-do-table = ecommerce.payments
replicate-ignore-table = ecommerce.sessions
replicate-ignore-table = ecommerce.logs
```

### Example Scenario 4: Use Wildcards for Table Patterns

**Slave** (`/etc/my.cnf`):
```ini
# Replicate all tables starting with "prod_"
replicate-wild-do-table = mydb.prod_%

# Ignore all temporary and cache tables
replicate-wild-ignore-table = %.tmp_%
replicate-wild-ignore-table = %.cache_%
replicate-wild-ignore-table = %_temp
```

### Example Scenario 5: Database Name Rewriting

**Slave** (`/etc/my.cnf`):
```ini
# Rename databases during replication
replicate-rewrite-db = production->production_replica
replicate-rewrite-db = sales->sales_backup
```

### Example Scenario 6: Complex Multi-Filter Setup

**Master** (`/etc/my.cnf`):
```ini
# Only log specific databases
binlog-do-db = ecommerce
binlog-do-db = analytics
binlog-do-db = crm
```

**Slave** (`/etc/my.cnf`):
```ini
# Replicate specific databases
replicate-do-db = ecommerce
replicate-do-db = analytics

# But ignore certain tables
replicate-ignore-table = ecommerce.sessions
replicate-ignore-table = ecommerce.cache
replicate-ignore-table = analytics.temp_calculations

# And replicate specific pattern tables
replicate-wild-do-table = ecommerce.archive_%
```

### Example Scenario 7: Selective Table Replication with Wildcards

**Slave** (`/etc/my.cnf`):
```ini
# Only replicate production tables
replicate-wild-do-table = %.prod_%
replicate-wild-do-table = %.production_%

# Exclude all log and temporary tables
replicate-wild-ignore-table = %._log
replicate-wild-ignore-table = %._logs
replicate-wild-ignore-table = %.tmp_%
replicate-wild-ignore-table = %.temp_%
```

---

## Part 5: Firewall Configuration

### Allow MySQL Port on Both Servers

```bash
# Check if firewalld is running
sudo systemctl status firewalld

# Allow MySQL port
sudo firewall-cmd --permanent --add-port=3306/tcp

# Reload firewall
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-all
```

### Allow Specific IP Addresses (Recommended)

On **Master** - allow slave IP:
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="SLAVE_IP_ADDRESS" port protocol="tcp" port="3306" accept'
sudo firewall-cmd --reload
```

On **Slave** - allow master IP:
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="MASTER_IP_ADDRESS" port protocol="tcp" port="3306" accept'
sudo firewall-cmd --reload
```

### SELinux Configuration (if enabled)

```bash
# Check SELinux status
sestatus

# If enforcing, allow MySQL network connections
sudo setsebool -P mysql_connect_any 1

# Or configure specific port
sudo semanage port -a -t mysqld_port_t -p tcp 3306
```

---

## Part 6: Monitoring Commands

### Check Replication Status

```sql
-- On Slave - Comprehensive status
SHOW SLAVE STATUS\G

-- Key fields to monitor:
-- Slave_IO_Running: Should be "Yes"
-- Slave_SQL_Running: Should be "Yes"
-- Seconds_Behind_Master: Should be 0 or low number
-- Last_IO_Error: Should be empty
-- Last_SQL_Error: Should be empty
```

### Using Performance Schema (MySQL 8.0)

```sql
-- Check IO thread status
SELECT 
    SERVICE_STATE as Slave_IO_Running,
    LAST_ERROR_MESSAGE,
    LAST_ERROR_NUMBER
FROM performance_schema.replication_connection_status;

-- Check SQL thread status
SELECT 
    SERVICE_STATE as Slave_SQL_Running,
    LAST_ERROR_MESSAGE,
    LAST_ERROR_NUMBER
FROM performance_schema.replication_applier_status_by_worker;

-- Check replication lag
SELECT 
    CHANNEL_NAME,
    COUNT_TRANSACTIONS_IN_QUEUE as Pending_Transactions
FROM performance_schema.replication_connection_status;
```

### Check Binary Log Status

On **Master**:
```sql
-- Show all binary logs
SHOW BINARY LOGS;

-- Show current master status
SHOW MASTER STATUS;

-- Check binary log events
SHOW BINLOG EVENTS IN 'mysql-bin.000001' LIMIT 10;
```

On **Slave**:
```sql
-- Show relay logs
SHOW RELAYLOGS;

-- Show slave hosts
SHOW SLAVE HOSTS;
```

### Monitor Replication Lag

```sql
-- On Slave
SHOW SLAVE STATUS\G

-- Look at these fields:
-- Seconds_Behind_Master: Lag in seconds
-- Relay_Log_Space: Size of relay logs
-- Exec_Master_Log_Pos: Position being executed
```

### Check Replication Filters

```sql
-- On Slave - show active filters
SHOW SLAVE STATUS\G

-- Look at these fields:
-- Replicate_Do_DB
-- Replicate_Ignore_DB
-- Replicate_Do_Table
-- Replicate_Ignore_Table
-- Replicate_Wild_Do_Table
-- Replicate_Wild_Ignore_Table
```

### Monitor System Resources

```bash
# Check MySQL process
ps aux | grep mysqld

# Check disk usage
df -h

# Check MySQL data directory size
du -sh /var/lib/mysql/

# Check binary log size
du -sh /var/lib/mysql/mysql-bin.*

# Monitor real-time MySQL activity
mysqladmin -u root -p processlist

# Extended status
mysqladmin -u root -p extended-status | grep -i repl
```

---

## Part 7: Important Filter Rules and Warnings

### Filter Priority Order (on Slave)

Filters are evaluated in this order:

1. `replicate-do-db` / `replicate-ignore-db`
2. `replicate-do-table` / `replicate-ignore-table`
3. `replicate-wild-do-table` / `replicate-wild-ignore-table`
4. `replicate-rewrite-db`

### Filter Types Comparison

| Filter Type | Scope | Applied On | Best For |
|-------------|-------|------------|----------|
| `binlog-do-db` | Database | Master | Reducing master I/O |
| `binlog-ignore-db` | Database | Master | Excluding from binlog |
| `replicate-do-db` | Database | Slave | Selective replication |
| `replicate-ignore-db` | Database | Slave | Excluding from slave |
| `replicate-do-table` | Table | Slave | Specific tables |
| `replicate-ignore-table` | Table | Slave | Excluding tables |
| `replicate-wild-do-table` | Pattern | Slave | Pattern matching |
| `replicate-wild-ignore-table` | Pattern | Slave | Pattern exclusion |
| `replicate-rewrite-db` | Database | Slave | Renaming databases |

### Critical Warnings

#### ⚠️ WARNING 1: Don't Mix DO and IGNORE Filters

**BAD - Don't do this:**
```ini
# This creates unpredictable behavior
binlog-do-db = db1
binlog-ignore-db = db2
```

**GOOD - Use one approach:**
```ini
# Either whitelist
binlog-do-db = db1
binlog-do-db = db2

# OR blacklist
binlog-ignore-db = test
binlog-ignore-db = temp
```

#### ⚠️ WARNING 2: Database-Level Filters and Cross-Database Queries

Database-level filters are context-dependent:

```ini
# Configuration:
replicate-do-db = production_db
```

```sql
-- This query WON'T replicate (wrong context):
USE test;
INSERT INTO production_db.table1 VALUES (1);

-- This query WILL replicate (correct context):
USE production_db;
INSERT INTO table1 VALUES (1);

-- This query WILL replicate (fully qualified):
INSERT INTO production_db.table1 VALUES (1);
```

**Solution**: Use table-level or wildcard filters instead:
```ini
replicate-wild-do-table = production_db.%
```

#### ⚠️ WARNING 3: Wildcard Pattern Matching

Wildcards match at the character level:

```ini
# This matches: users_temp, user_tmp, temp_users
replicate-wild-ignore-table = %.%temp%

# This only matches: anything ending in _temp
replicate-wild-ignore-table = %._temp

# Be specific to avoid unintended matches
```

#### ⚠️ WARNING 4: GTID and Replication Filters

When using GTID mode, filters can cause issues:

- Skipped transactions still consume GTID numbers
- This can create gaps in GTID sets
- Can complicate failover scenarios

**Recommendation**: Use filters sparingly with GTID, prefer application-level filtering.

#### ⚠️ WARNING 5: Statement-Based Replication (SBR) Caveats

With `binlog_format = STATEMENT`:

```sql
-- This won't replicate correctly with database filters:
USE db1;
UPDATE db2.table1 SET col = 'value';
```

**Solution**: Use `binlog_format = ROW` (recommended for MySQL 8.0)

### Best Practices

1. **Prefer table-level filters over database-level** for better control
2. **Use wildcard filters** for flexible pattern matching
3. **Test filters thoroughly** before production deployment
4. **Document your filter configuration** clearly
5. **Monitor filtered replication** regularly
6. **Use ROW-based replication** with filters
7. **Avoid mixing filter types** at the same level
8. **Consider application-level filtering** as an alternative

---

## Part 8: Troubleshooting

### Issue 1: Slave Not Connecting to Master

**Symptoms:**
- `Slave_IO_Running: Connecting`
- Connection errors in `SHOW SLAVE STATUS\G`

**Diagnosis:**

```bash
# Test network connectivity
ping MASTER_IP_ADDRESS

# Test MySQL port
telnet MASTER_IP_ADDRESS 3306
# OR
nc -zv MASTER_IP_ADDRESS 3306

# Check firewall on master
sudo firewall-cmd --list-all

# Check SELinux on master
sudo getenforce
```

**Solutions:**

```bash
# On Master - allow slave IP
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="SLAVE_IP" port protocol="tcp" port="3306" accept'
sudo firewall-cmd --reload

# Check MySQL is listening on correct interface
sudo netstat -tlnp | grep 3306
# OR
sudo ss -tlnp | grep 3306

# Edit /etc/my.cnf on master if needed
bind-address = 0.0.0.0
# Then restart MySQL
sudo systemctl restart mysqld
```

**Verify replication user:**

```sql
-- On Master
SELECT user, host FROM mysql.user WHERE user = 'replication_user';
SHOW GRANTS FOR 'replication_user'@'%';

-- Test connection from slave
mysql -h MASTER_IP -u replication_user -p
```

### Issue 2: Slave IO Running but SQL Thread Stopped

**Symptoms:**
- `Slave_IO_Running: Yes`
- `Slave_SQL_Running: No`
- Error in `Last_SQL_Error`

**Diagnosis:**

```sql
-- On Slave
SHOW SLAVE STATUS\G

-- Look at:
-- Last_SQL_Error
-- Last_SQL_Errno
```

**Common Errors and Solutions:**

#### Error 1062: Duplicate Entry

```sql
-- Check the conflicting data
-- Option 1: Skip this error (use carefully)
STOP SLAVE;
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;

-- Option 2: Delete duplicate on slave
STOP SLAVE;
-- Delete the conflicting row manually
DELETE FROM database.table WHERE primary_key = 'value';
START SLAVE;

-- Option 3: Use idempotent recovery (MySQL 8.0)
STOP SLAVE;
SET GLOBAL slave_exec_mode = 'IDEMPOTENT';
START SLAVE;
-- Monitor and set back to STRICT later
```

#### Error 1032: Cannot Find Record

```sql
-- The row doesn't exist on slave but master tries to update/delete it
-- Option 1: Skip the error
STOP SLAVE;
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;

-- Option 2: Insert missing row
-- Find the data from master and insert on slave
```

#### Error 1146: Table Doesn't Exist

```sql
-- Create the missing table
-- Get table structure from master
-- On Master:
SHOW CREATE TABLE database.table_name;

-- On Slave:
CREATE TABLE database.table_name (...);
START SLAVE;
```

### Issue 3: Replication Lag

**Symptoms:**
- `Seconds_Behind_Master` is high (> 60 seconds)

**Diagnosis:**

```sql
-- Check current lag
SHOW SLAVE STATUS\G

-- Check slave performance
SHOW PROCESSLIST;

-- Check if slave is applying transactions
SELECT * FROM performance_schema.replication_applier_status_by_worker;
```

**Solutions:**

```sql
-- Enable parallel replication (MySQL 8.0)
STOP SLAVE SQL_THREAD;
SET GLOBAL slave_parallel_workers = 4;
SET GLOBAL slave_parallel_type = 'LOGICAL_CLOCK';
START SLAVE SQL_THREAD;

-- Increase relay log size
SET GLOBAL max_relay_log_size = 1073741824; -- 1GB

-- Check system resources
```

```bash
# Check disk I/O
iostat -x 1

# Check CPU usage
top

# Check MySQL slow queries
mysql -u root -p -e "SHOW FULL PROCESSLIST;" | grep -v Sleep
```

**On Master - reduce binlog size:**

```sql
-- Purge old binary logs
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 3 DAY);

-- Or purge to specific log
PURGE BINARY LOGS TO 'mysql-bin.000010';
```

### Issue 4: Replication Stopped After Server Restart

**Diagnosis:**

```bash
# Check MySQL error log
sudo tail -100 /var/log/mysqld.log

# Check slave status
mysql -u root -p -e "SHOW SLAVE STATUS\G"
```

**Solution:**

```sql
-- Start slave if not running
START SLAVE;

-- If relay logs are corrupted
STOP SLAVE;
RESET SLAVE;

-- Reconfigure from current master position
SHOW MASTER STATUS; -- Run on Master

-- On Slave
CHANGE MASTER TO
    MASTER_HOST='MASTER_IP',
    MASTER_USER='replication_user',
    MASTER_PASSWORD='password',
    MASTER_LOG_FILE='mysql-bin.XXXXXX',
    MASTER_LOG_POS=XXXXX;

START SLAVE;
```

### Issue 5: Binary Log File Not Found

**Symptoms:**
- `Last_IO_Error: Got fatal error 1236`
- `Error reading packet from server: Could not find first log file name in binary log index file`

**Cause:**
- Master's binary logs were purged
- Slave is too far behind

**Solution:**

```sql
-- Option 1: Resync from current master position
-- On Master
SHOW MASTER STATUS;

-- On Slave
STOP SLAVE;
CHANGE MASTER TO
    MASTER_LOG_FILE='current_binlog_file',
    MASTER_LOG_POS=current_position;
START SLAVE;

-- Option 2: Full resync (if data consistency is critical)
```

```bash
# On Master - backup
mysqldump -u root -p --all-databases --master-data=2 --single-transaction > full_backup.sql

# Transfer to slave
scp full_backup.sql root@SLAVE_IP:/tmp/

# On Slave - restore
mysql -u root -p < /tmp/full_backup.sql

# Configure replication from backup position
# (Check the CHANGE MASTER TO command in the backup file)
```

### Issue 6: GTID Errors

**Symptoms:**
- `Got fatal error 1236 from master when reading data from binary log: 'The slave is connecting using GTID protocol, but the master has purged binary logs containing GTIDs'`

**Solution:**

```sql
-- On Master - check GTID executed
SHOW MASTER STATUS;
SELECT @@GLOBAL.GTID_EXECUTED;

-- On Slave - check GTID retrieved
SHOW SLAVE STATUS\G
SELECT @@GLOBAL.GTID_EXECUTED;

-- Option 1: Inject empty transactions for missing GTIDs
SET GTID_NEXT='missing-uuid:transaction-number';
BEGIN;
COMMIT;
SET GTID_NEXT='AUTOMATIC';

-- Option 2: Reset slave and resync
STOP SLAVE;
RESET MASTER;
RESET SLAVE;

-- Restore from master backup
-- Then configure with MASTER_AUTO_POSITION=1
```

### Issue 7: Filters Not Working

**Diagnosis:**

```sql
-- Check active filters
SHOW SLAVE STATUS\G

-- Look at:
-- Replicate_Do_DB
-- Replicate_Ignore_DB
-- Replicate_Do_Table
-- Replicate_Ignore_Table
-- Replicate_Wild_Do_Table
-- Replicate_Wild_Ignore_Table
```

**Solutions:**

```bash
# Verify configuration file
cat /etc/my.cnf | grep -i replicate

# Ensure filters are under [mysqld] section
# Restart MySQL after changes
sudo systemctl restart mysqld
```

**Test filters:**

```sql
-- On Master
USE test_db;
CREATE TABLE test_table (id INT);
INSERT INTO test_table VALUES (1);

-- On Slave - check if replicated
SHOW DATABASES LIKE 'test_db';
SELECT * FROM test_db.test_table;
```

### Issue 8: High Relay Log Disk Usage

**Diagnosis:**

```bash
# Check relay log size
du -sh /var/lib/mysql/relay-bin.*

# Check total disk usage
df -h
```

**Solution:**

```sql
-- Purge relay logs
-- On Slave
STOP SLAVE SQL_THREAD;
PURGE RELAY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 1 DAY);
START SLAVE SQL_THREAD;

-- Or automatic purging
-- In /etc/my.cnf
relay_log_purge = 1
relay_log_recovery = 1
```

### Useful Diagnostic Queries

```sql
-- Check replication status summary
SELECT 
    CHANNEL_NAME,
    SERVICE_STATE,
    LAST_ERROR_NUMBER,
    LAST_ERROR_MESSAGE,
    LAST_ERROR_TIMESTAMP
FROM performance_schema.replication_connection_status
UNION ALL
SELECT 
    CHANNEL_NAME,
    SERVICE_STATE,
    LAST_ERROR_NUMBER,
    LAST_ERROR_MESSAGE,
    LAST_ERROR_TIMESTAMP
FROM performance_schema.replication_applier_status_by_worker;

-- Check replication lag in detail
SELECT 
    CHANNEL_NAME,
    COUNT_TRANSACTIONS_IN_QUEUE as Pending,
    COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE as Queued
FROM performance_schema.replication_connection_status;

-- Monitor slave threads
SELECT * FROM performance_schema.replication_applier_status_by_worker;
```

### Emergency Procedures

#### Complete Replication Reset

```sql
-- On Slave
STOP SLAVE;
RESET SLAVE ALL;

-- Clean up
RESET MASTER;

-- Reconfigure from scratch
CHANGE MASTER TO
    MASTER_HOST='MASTER_IP',
    MASTER_USER='replication_user',
    MASTER_PASSWORD='password',
    MASTER_LOG_FILE='mysql-bin.XXXXXX',
    MASTER_LOG_POS=XXXXX;

START SLAVE;
```

#### Force Resync from Master

```bash
# Full backup and restore procedure
# 1. On Master
mysqldump -u root -p --all-databases --master-data=2 --single-transaction --flush-logs > master_full.sql

# 2. Transfer to slave
scp master_full.sql root@SLAVE_IP:/tmp/

# 3. On Slave - stop replication
mysql -u root -p -e "STOP SLAVE; RESET SLAVE;"

# 4. Restore backup
mysql -u root -p < /tmp/master_full.sql

# 5. Extract CHANGE MASTER command from backup
head -50 /tmp/master_full.sql | grep "CHANGE MASTER"

# 6. Configure and start replication
mysql -u root -p
# Run the CHANGE MASTER TO command
START SLAVE;
SHOW SLAVE STATUS\G
```

---

## Quick Reference Commands

### Master Commands

```bash
# Check master status
mysql -u root -p -e "SHOW MASTER STATUS;"

# Check binary logs
mysql -u root -p -e "SHOW BINARY LOGS;"

# Check connected slaves
mysql -u root -p -e "SHOW SLAVE HOSTS;"

# Purge old binary logs
mysql -u root -p -e "PURGE BINARY LOGS BEFORE NOW() - INTERVAL 3 DAY;"
```

### Slave Commands

```bash
# Check slave status
mysql -u root -p -e "SHOW SLAVE STATUS\G"

# Start/Stop slave
mysql -u root -p -e "START SLAVE;"
mysql -u root -p -e "STOP SLAVE;"

# Reset slave
mysql -u root -p -e "RESET SLAVE;"

# Check replication lag
mysql -u root -p -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master
```

### System Commands

```bash
# Check MySQL status
sudo systemctl status mysqld

# Restart MySQL
sudo systemctl restart mysqld

# Check MySQL error log
sudo tail -f /var/log/mysqld.log

# Check disk usage
df -h
du -sh /var/lib/mysql/

# Check open connections
sudo netstat -tlnp | grep 3306
```

---

## Conclusion

This guide covers comprehensive MySQL replication setup with detailed filter examples. Key takeaways:

1. **Choose the right filter type** for your use case
2. **Test filters thoroughly** before production
3. **Monitor replication regularly** 
4. **Use ROW-based replication** for better consistency
5. **Enable GTID** for easier failover
6. **Document your configuration** clearly
7. **Set up alerts** for replication issues
8. **Regular backups** are still essential

For production deployments, consider:
- Setting up monitoring (Prometheus, Nagios, etc.)
- Implementing automated failover
- Regular testing of disaster recovery procedures
- Multi-slave setups for high availability

---

## Additional Resources

- MySQL Official Documentation: https://dev.mysql.com/doc/refman/8.0/en/replication.html
- MySQL Replication Filters: https://dev.mysql.com/doc/refman/8.0/en/replication-options-replica.html
- GTID Replication: https://dev.mysql.com/doc/refman/8.0/en/replication-gtids.html
- Performance Schema: https://dev.mysql.com/doc/refman/8.0/en/performance-schema.html
