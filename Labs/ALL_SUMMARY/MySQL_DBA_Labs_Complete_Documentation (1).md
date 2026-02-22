# MySQL DBA Training Labs - Complete Documentation

## 📚 Table of Contents

1. [Lab 1: Basic SQL Operations](#lab-1-basic-sql-operations)
2. [Lab 2: Binary Log Formats](#lab-2-binary-log-formats)
3. [Lab 3: MySQL Logs Management](#lab-3-mysql-logs-management)
4. [Lab 4: User Management and Security](#lab-4-user-management-and-security)
5. [Lab 5: Point-in-Time Recovery (PITR)](#lab-5-point-in-time-recovery-pitr)
6. [Lab 6: MySQL Replication](#lab-6-mysql-replication)
7. [Lab 7: Installation Labs](#lab-7-installation-labs)

---

# Lab 1: Basic SQL Operations

## 🎯 Objectives
- Understand fundamental database and table operations
- Learn about constraints and keys
- Master table structure inspection commands

## 📖 Theory

### Database Concepts

A **database** is a container for organizing related tables. MySQL uses the concept of schemas, where each database is a separate namespace for tables.

### Key Constraints

1. **PRIMARY KEY**: Uniquely identifies each row in a table
   - Cannot contain NULL values
   - Only one PRIMARY KEY per table
   - Automatically creates a unique index

2. **UNIQUE KEY**: Ensures all values in a column are different
   - Can have multiple UNIQUE keys per table
   - Can contain NULL values (one NULL per column)

3. **FOREIGN KEY**: Links two tables together
   - References a PRIMARY KEY in another table
   - Enforces referential integrity
   - Prevents orphaned records

4. **INDEX (KEY)**: Improves query performance
   - Speeds up data retrieval
   - Slows down INSERT/UPDATE/DELETE operations slightly

## 💻 Practical Steps

### Step 1: Create a Database

```sql
-- Create a new database
CREATE DATABASE database_name;
```

**Explanation**: Creates a new database namespace where you can store tables.

**Use Case**: Create separate databases for different applications (e.g., `ecommerce_db`, `hr_db`)

---

### Step 2: View and Select Databases

```sql
-- List all databases
SHOW DATABASES;

-- Switch to a specific database
USE database_name;

-- Check currently selected database
SELECT DATABASE();
```

**Explanation**:
- `SHOW DATABASES`: Displays all databases you have access to
- `USE`: Sets the active database for subsequent queries
- `SELECT DATABASE()`: Shows which database is currently active

---

### Step 3: Display Tables

```sql
-- Must select a database first
USE database_name;

-- List all tables in current database
SHOW TABLES;
```

**Explanation**: After selecting a database, this shows all tables within it.

---

### Step 4: Inspect Table Structure

```sql
-- Method 1: Detailed CREATE statement
SHOW CREATE TABLE table_name;

-- Method 2: Column details
DESC table_name;
-- or
DESCRIBE table_name;
```

**Explanation**:
- `SHOW CREATE TABLE`: Shows complete SQL to recreate the table (includes indexes, constraints, engine)
- `DESC`: Shows columns, data types, NULL allowance, keys, defaults

**Example Output**:
```
+------------+--------------+------+-----+---------+----------------+
| Field      | Type         | Null | Key | Default | Extra          |
+------------+--------------+------+-----+---------+----------------+
| emp_no     | int          | NO   | PRI | NULL    | auto_increment |
| first_name | varchar(14)  | NO   |     | NULL    |                |
+------------+--------------+------+-----+---------+----------------+
```

---

### Step 5: Identify Primary Keys

```sql
-- View primary key definition
SHOW CREATE TABLE table_name;
```

**Explanation**: Primary keys are shown in the CREATE TABLE output with `PRIMARY KEY (column_name)`

---

### Step 6: Create Table with PRIMARY KEY

```sql
CREATE TABLE employees (
    emp_no INT NOT NULL,              -- Employee number
    birth_date DATE NOT NULL,         -- Birth date
    first_name VARCHAR(14) NOT NULL,  -- First name
    last_name VARCHAR(16) NOT NULL,   -- Last name
    gender ENUM('M','F') NOT NULL,    -- Gender
    hire_date DATE NOT NULL,          -- Hire date
    PRIMARY KEY (emp_no)              -- Primary key constraint
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

**Theory Breakdown**:

**Data Types**:
- `INT`: 4-byte integer (-2,147,483,648 to 2,147,483,647)
- `DATE`: Date in 'YYYY-MM-DD' format
- `VARCHAR(n)`: Variable-length string, max n characters
- `ENUM('M','F')`: Only allows listed values

**NOT NULL**: Column cannot contain NULL values

**PRIMARY KEY**: 
- Uniquely identifies each employee
- Automatically indexed for fast lookups
- Cannot be NULL or duplicate

**ENGINE=InnoDB**:
- Supports ACID transactions
- Row-level locking
- Foreign key constraints
- Crash recovery

**CHARSET and COLLATION**:
- `utf8mb4`: Full Unicode support (4-byte, includes emojis)
- `utf8mb4_0900_ai_ci`: 
  - `0900`: Unicode 9.0 standard
  - `ai`: Accent-insensitive
  - `ci`: Case-insensitive

---

### Step 7: Create Table with UNIQUE KEY

```sql
CREATE TABLE departments (
    dept_no CHAR(4) NOT NULL,         -- Department number (fixed 4 chars)
    dept_name VARCHAR(40) NOT NULL,   -- Department name
    PRIMARY KEY (dept_no),            -- Primary key
    UNIQUE KEY dept_name (dept_name)  -- Unique constraint on name
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

**Theory**:

**CHAR vs VARCHAR**:
- `CHAR(4)`: Fixed-length, always uses 4 bytes (padded with spaces)
- `VARCHAR(40)`: Variable-length, uses 1-40 bytes + length byte

**UNIQUE KEY**:
- Prevents duplicate department names
- Creates automatic index for performance
- Different from PRIMARY KEY (can have multiple UNIQUE keys)

**When to Use UNIQUE**:
- Email addresses
- Phone numbers
- Product codes
- Any field that must be unique but isn't the primary identifier

---

### Step 8: Create Table with FOREIGN KEY

```sql
CREATE TABLE salaries (
    emp_no INT NOT NULL,                    -- References employees
    salary INT NOT NULL,                    -- Salary amount
    from_date DATE NOT NULL,                -- Start date
    to_date DATE NOT NULL,                  -- End date
    PRIMARY KEY (emp_no, from_date),        -- Composite primary key
    CONSTRAINT salaries_ibfk_1              -- Foreign key constraint name
        FOREIGN KEY (emp_no)                -- Column in this table
        REFERENCES employees (emp_no)       -- Column in parent table
        ON DELETE CASCADE                   -- Delete behavior
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

**Theory**:

**Composite Primary Key**:
- Combination of `emp_no` and `from_date` must be unique
- Allows multiple salary records per employee (different dates)
- Both columns required to uniquely identify a row

**FOREIGN KEY**:
- `emp_no` must exist in `employees` table
- Cannot insert salary for non-existent employee
- Enforces referential integrity

**ON DELETE CASCADE**:
- If employee is deleted, all their salary records are automatically deleted
- Other options:
  - `RESTRICT`: Prevent deletion of employee if salaries exist
  - `SET NULL`: Set salary.emp_no to NULL (not applicable here as it's NOT NULL)
  - `NO ACTION`: Same as RESTRICT

**Real-World Example**:
```
employees                   salaries
emp_no: 1001     ←------→  emp_no: 1001, from_date: 2020-01-01
                           emp_no: 1001, from_date: 2021-01-01
```

If you delete employee 1001, both salary records are automatically deleted.

---

### Step 9: Create Table with INDEX

```sql
CREATE TABLE employees (
    emp_no INT NOT NULL,
    birth_date DATE NOT NULL,
    first_name VARCHAR(14) NOT NULL,
    last_name VARCHAR(16) NOT NULL,
    gender ENUM('M','F') NOT NULL,
    hire_date DATE NOT NULL,
    PRIMARY KEY (emp_no),
    KEY idx_fname (first_name)         -- Index on first_name
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

**Theory**:

**INDEX (KEY)**:
- Creates B-tree structure for fast lookups
- Without index: Full table scan (checks every row)
- With index: Logarithmic time lookup

**Performance Impact**:
- **SELECT**: Much faster (10x - 1000x)
- **INSERT/UPDATE/DELETE**: Slightly slower (index must be updated)

**When to Create Indexes**:
- Columns frequently used in WHERE clauses
- Columns used in JOIN conditions
- Columns used in ORDER BY
- Columns used in GROUP BY

**When NOT to Create Indexes**:
- Small tables (< 1000 rows)
- Columns with low cardinality (few unique values)
- Columns rarely queried
- Tables with frequent writes and rare reads

**Example Performance**:
```sql
-- Without index on first_name: 
-- Scans all 300,000 employees (slow)
SELECT * FROM employees WHERE first_name = 'John';

-- With index on first_name:
-- Uses index to find ~1,000 Johns (fast)
SELECT * FROM employees WHERE first_name = 'John';
```

---

## 🧪 Practice Exercises

### Exercise 1: Create a Complete Database Schema

```sql
-- Create database
CREATE DATABASE company;
USE company;

-- Create departments table
CREATE TABLE departments (
    dept_id INT AUTO_INCREMENT PRIMARY KEY,
    dept_name VARCHAR(50) NOT NULL UNIQUE,
    location VARCHAR(100)
);

-- Create employees table
CREATE TABLE employees (
    emp_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    dept_id INT,
    hire_date DATE NOT NULL,
    salary DECIMAL(10,2),
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
        ON DELETE SET NULL,
    INDEX idx_email (email),
    INDEX idx_name (last_name, first_name)
);

-- Insert sample data
INSERT INTO departments (dept_name, location) VALUES
('Engineering', 'Building A'),
('Sales', 'Building B'),
('HR', 'Building C');

INSERT INTO employees (first_name, last_name, email, dept_id, hire_date, salary) VALUES
('John', 'Doe', 'john.doe@company.com', 1, '2020-01-15', 85000.00),
('Jane', 'Smith', 'jane.smith@company.com', 1, '2019-03-20', 92000.00),
('Bob', 'Johnson', 'bob.j@company.com', 2, '2021-06-10', 75000.00);
```

### Exercise 2: Query Practice

```sql
-- Find all employees in Engineering
SELECT e.first_name, e.last_name, d.dept_name
FROM employees e
JOIN departments d ON e.dept_id = d.dept_id
WHERE d.dept_name = 'Engineering';

-- Find employees hired in 2020
SELECT * FROM employees
WHERE YEAR(hire_date) = 2020;

-- Count employees per department
SELECT d.dept_name, COUNT(e.emp_id) as employee_count
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_name;
```

---

## 📊 Summary

| Concept | Purpose | Example |
|---------|---------|---------|
| **PRIMARY KEY** | Unique row identifier | emp_id |
| **UNIQUE KEY** | Prevent duplicates | email |
| **FOREIGN KEY** | Link tables | dept_id → departments |
| **INDEX** | Speed up queries | idx_name |
| **COMPOSITE KEY** | Multi-column uniqueness | (emp_id, project_id) |

---

# Lab 2: Binary Log Formats

## 🎯 Objectives
- Understand binary logging in MySQL
- Compare STATEMENT vs ROW-based replication
- Choose appropriate binlog format for your use case

## 📖 Theory

### What are Binary Logs?

**Binary logs (binlogs)** record all changes to the database in a binary format. They serve two critical purposes:

1. **Replication**: Replicas read binlogs from the primary to stay synchronized
2. **Point-in-Time Recovery (PITR)**: Restore database to specific moment using backup + binlogs

### Binary Log Formats

MySQL supports three binlog formats:

1. **STATEMENT**: Logs SQL statements
2. **ROW**: Logs actual row changes
3. **MIXED**: Automatically switches between STATEMENT and ROW

---

## 💻 Format Comparison

### 1. STATEMENT-Based Replication (SBR)

#### How It Works

```sql
-- Master executes:
UPDATE employees 
SET salary = salary + 1000 
WHERE department = 'IT';
```

**Binlog Entry**:
```
UPDATE employees SET salary = salary + 1000 WHERE department = 'IT';
```

**Process**:
1. Master logs the SQL statement exactly as executed
2. Statement is sent to replica
3. Replica re-executes the same SQL statement

#### Advantages ✅

**1. Smaller Binlog Size**
```
One UPDATE statement affecting 10,000 rows = One binlog entry
```

**2. Less Disk I/O**
- Smaller log files
- Faster to write
- Less network bandwidth for replication

**3. Easier to Audit**
- Human-readable SQL statements
- Easy to understand what changed

#### Disadvantages ❌

**1. Non-Deterministic Functions**

```sql
-- Problem: NOW() gives different times on master vs replica
INSERT INTO audit_log (timestamp, action) 
VALUES (NOW(), 'User login');

-- Master at 10:00:00
-- Replica replays at 10:00:05
-- Data inconsistency!
```

**2. LIMIT Without ORDER BY**

```sql
-- Which 10 rows are deleted? Order is undefined!
DELETE FROM logs LIMIT 10;

-- Master might delete rows: 1, 5, 8, ...
-- Replica might delete rows: 2, 7, 9, ...
-- DATA CORRUPTION!
```

**3. Stored Procedures with Complex Logic**

```sql
-- If SP uses RAND(), UUID(), etc.
DELIMITER //
CREATE PROCEDURE random_discount()
BEGIN
    UPDATE products 
    SET discount = RAND() * 10 
    WHERE category = 'Electronics';
END //
DELIMITER ;

-- Each execution gives different discounts!
```

#### Real-World Issues

**Example 1: Timezone Problems**
```sql
-- Master in UTC, Replica in EST
INSERT INTO events (event_time) VALUES (NOW());

-- Master stores: 2024-12-25 15:00:00 UTC
-- Replica stores: 2024-12-25 10:00:00 EST
-- 5 hour difference!
```

**Example 2: Auto-Increment Gaps**
```sql
-- With concurrent inserts
INSERT INTO orders (customer_id) VALUES (1001);

-- Master assigns order_id = 500
-- Replica might assign order_id = 501 if IDs were generated differently
```

---

### 2. ROW-Based Replication (RBR)

#### How It Works

```sql
-- Master executes:
UPDATE employees 
SET salary = salary + 1000 
WHERE department = 'IT';  -- Affects 2 rows
```

**Binlog Entry** (conceptual):
```
Row 1: emp_id=101, salary changed 50000 → 51000
Row 2: emp_id=205, salary changed 60000 → 61000
```

**Process**:
1. Master records before/after image of each changed row
2. Row images sent to replica
3. Replica applies exact row changes (no SQL re-execution)

#### Advantages ✅

**1. Deterministic Replication**

```sql
-- Same result every time
INSERT INTO audit_log VALUES (NOW());

-- Binlog contains actual timestamp value
-- Replica gets exact same timestamp
```

**2. Works with All Functions**

```sql
-- RAND(), UUID(), USER() all work correctly
UPDATE products SET code = UUID();

-- Each row's UUID is logged
-- Replica gets exact same UUIDs
```

**3. Safer for Complex Queries**

```sql
-- No ambiguity
DELETE FROM logs LIMIT 10;

-- Exact rows deleted are logged by ID
-- Replica deletes same rows
```

**4. Better for Triggers and Stored Procedures**

```sql
-- Trigger outcome is logged, not trigger execution
CREATE TRIGGER update_audit 
AFTER UPDATE ON employees
FOR EACH ROW
    INSERT INTO audit_log VALUES (NOW(), USER());

-- Audit log entries are in binlog
-- Replica doesn't re-execute trigger
```

#### Disadvantages ❌

**1. Larger Binlog Size**

```sql
-- Update 100,000 rows
UPDATE employees SET salary = salary * 1.1;

-- STATEMENT: One small SQL statement
-- ROW: 100,000 row images (before/after)
-- Could be 100x - 1000x larger!
```

**2. More Disk I/O**
- Larger files to write
- More space required
- Longer to transfer over network

**3. Harder to Audit**

Binlog contains binary row data, not readable SQL:
```
### UPDATE `mydb`.`employees`
### WHERE
###   @1=1001
###   @2='John'
###   @3=50000
### SET
###   @1=1001
###   @2='John'
###   @3=55000
```

---

### 3. MIXED Format

#### How It Works

MySQL automatically chooses:
- **STATEMENT**: For safe statements
- **ROW**: For non-deterministic statements

```sql
-- Uses STATEMENT (safe)
UPDATE employees SET salary = 75000 WHERE emp_id = 1001;

-- Uses ROW (non-deterministic)
INSERT INTO logs VALUES (NOW(), UUID());
```

#### Advantages ✅

- Best of both worlds
- Smaller binlogs than pure ROW
- Safer than pure STATEMENT

#### Disadvantages ❌

- Mixed behavior can be confusing
- Hard to predict binlog size
- Some edge cases still problematic

---

## ⚙️ Configuration

### Setting Binlog Format

#### In Configuration File (`/etc/my.cnf`)

```ini
[mysqld]
# Choose one:
binlog_format = STATEMENT
binlog_format = ROW
binlog_format = MIXED
```

#### At Runtime (Session or Global)

```sql
-- Session level (current connection only)
SET SESSION binlog_format = 'ROW';

-- Global level (all new connections)
SET GLOBAL binlog_format = 'ROW';

-- Check current setting
SHOW VARIABLES LIKE 'binlog_format';
```

---

## 📊 Format Comparison Table

| Feature | STATEMENT | ROW | MIXED |
|---------|-----------|-----|-------|
| **Binlog Size** | Small ✅ | Large ❌ | Medium |
| **Deterministic** | No ❌ | Yes ✅ | Yes ✅ |
| **NOW(), RAND()** | Unsafe ❌ | Safe ✅ | Safe ✅ |
| **Human Readable** | Yes ✅ | No ❌ | Partial |
| **Network I/O** | Low ✅ | High ❌ | Medium |
| **Recommended for** | Read-heavy, simple queries | Write-heavy, complex queries | General purpose |

---

## 🎯 Choosing the Right Format

### Use STATEMENT When:
- Mostly simple UPDATE/INSERT/DELETE statements
- No non-deterministic functions
- Limited disk space
- Bandwidth is a concern
- Need human-readable logs

### Use ROW When:
- Using stored procedures, triggers, functions
- Statements with LIMIT without ORDER BY
- Using non-deterministic functions (NOW(), RAND(), UUID())
- Data consistency is critical
- Need audit trail of exact changes

### Use MIXED When:
- General-purpose applications
- Want automatic optimization
- Mix of simple and complex queries

---

## 💡 Best Practices

1. **Production Recommendation**: Use **ROW** format
   - Safer and more consistent
   - Disk space is cheap
   - Prevents data corruption

2. **Enable Binary Logging**:
```sql
-- In /etc/my.cnf
log_bin = /var/lib/mysql/mysql-bin
binlog_format = ROW
expire_logs_days = 7  -- Auto-delete after 7 days
max_binlog_size = 100M  -- Rotate at 100MB
```

3. **Monitor Binlog Growth**:
```sql
-- Check binlog size
SHOW BINARY LOGS;

-- Purge old logs
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 3 DAY);
```

4. **Test Before Changing Format**:
```sql
-- Check current replication status
SHOW SLAVE STATUS\G

-- Change format on non-production first
SET GLOBAL binlog_format = 'ROW';

-- Monitor for issues
```

---

## 🧪 Practical Example

### Testing Binlog Formats

```sql
-- 1. Create test table
CREATE TABLE test_binlog (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Set STATEMENT format
SET binlog_format = 'STATEMENT';

-- 3. Insert with NOW()
INSERT INTO test_binlog (data) VALUES ('Test 1');

-- 4. Check binlog
SHOW BINLOG EVENTS IN 'mysql-bin.000001';

-- 5. Switch to ROW format
SET binlog_format = 'ROW';

-- 6. Insert again
INSERT INTO test_binlog (data) VALUES ('Test 2');

-- 7. Compare binlog entries
SHOW BINLOG EVENTS IN 'mysql-bin.000001';
```

### View Binlog Content

```bash
# View statement-based binlog
mysqlbinlog /var/lib/mysql/mysql-bin.000001

# View row-based binlog (verbose mode shows row data)
mysqlbinlog --verbose /var/lib/mysql/mysql-bin.000001

# Filter by database
mysqlbinlog --database=mydb /var/lib/mysql/mysql-bin.000001
```

---

## 🔍 Troubleshooting

### Issue: Binlog Growing Too Fast

**Diagnosis**:
```sql
SHOW BINARY LOGS;
```

**Solutions**:
```sql
-- Purge old logs
PURGE BINARY LOGS TO 'mysql-bin.000010';

-- Set auto-expiration
SET GLOBAL expire_logs_days = 3;

-- Consider STATEMENT format for write-heavy apps (if safe)
SET GLOBAL binlog_format = 'STATEMENT';
```

### Issue: Replication Inconsistency

**Symptoms**: Master and slave data doesn't match

**Check**:
```sql
-- On Master
CHECKSUM TABLE employees;

-- On Slave
CHECKSUM TABLE employees;
```

**Solution**: Switch to ROW format
```sql
SET GLOBAL binlog_format = 'ROW';
```

---

## 📚 Summary

- **STATEMENT**: Small logs, unsafe with functions
- **ROW**: Large logs, safe and deterministic
- **MIXED**: Automatic switching, best of both worlds
- **Recommendation**: Use **ROW** for production

**Key Takeaway**: Data consistency > Disk space savings

---

# Lab 3: MySQL Logs Management

## 🎯 Objectives
- Understand different MySQL log types
- Configure and manage MySQL logs
- Use logs for troubleshooting and auditing

## 📖 Theory

MySQL maintains several types of logs for different purposes:

| Log Type | Purpose | Default State |
|----------|---------|---------------|
| **Error Log** | Server errors, warnings, startup/shutdown | Always ON |
| **General Query Log** | All client connections and queries | OFF (performance impact) |
| **Slow Query Log** | Queries exceeding threshold | OFF |
| **Binary Log** | Database changes for replication/recovery | ON (MySQL 8.0+) |
| **Relay Log** | Replication events on replica | Automatic |

---

## 1. Error Log

### Theory

The **error log** contains messages about:
- Server startup and shutdown
- Critical errors
- Warnings
- Notable events (crash recovery, plugin loading)

### Location

**Default**: `/var/log/mysqld.log` or `/var/log/mysql/error.log`

**Check Location**:
```sql
SHOW VARIABLES LIKE 'log_error';
```

### Configuration

```ini
# In /etc/my.cnf
[mysqld]
log_error = /var/log/mysql/error.log
log_error_verbosity = 3  # 1=Errors only, 2=+Warnings, 3=+Notes
```

### Viewing Error Log

```bash
# View entire log
less /var/log/mysqld.log

# View last 50 lines
tail -50 /var/log/mysqld.log

# Follow log in real-time
tail -f /var/log/mysqld.log

# Search for errors
grep -i error /var/log/mysqld.log

# Search for recent errors
grep -i error /var/log/mysqld.log | tail -20
```

### Common Error Patterns

**1. Connection Errors**:
```
[ERROR] Aborted connection 123 to db: 'mydb' user: 'app_user' host: '192.168.1.100'
```
**Cause**: Client disconnected without closing connection properly

**2. Disk Space Issues**:
```
[ERROR] Disk is full writing '/var/lib/mysql/binlog.000045' (Errcode: 28 - No space left on device)
```
**Solution**: Free up disk space or increase partition size

**3. Lock Wait Timeout**:
```
[ERROR] InnoDB: Lock wait timeout exceeded; try restarting transaction
```
**Solution**: Optimize queries, increase `innodb_lock_wait_timeout`

---

## 2. General Query Log

### Theory

Records **all** client activity:
- Connections and disconnections
- Every SQL query executed
- Failed login attempts

**⚠️ WARNING**: Significant performance impact! Use only for debugging.

### Configuration

**Check Status**:
```sql
SHOW VARIABLES LIKE 'general_log%';
```

**Enable/Disable**:
```sql
-- Enable (runtime)
SET GLOBAL general_log = 'ON';
SET GLOBAL general_log_file = '/var/lib/mysql/general.log';

-- Disable
SET GLOBAL general_log = 'OFF';
```

**Permanent Configuration** (`/etc/my.cnf`):
```ini
[mysqld]
general_log = 1
general_log_file = /var/lib/mysql/general.log
```

### Viewing General Log

```bash
# View log
tail -f /var/lib/mysql/general.log

# Search for specific query
grep "SELECT" /var/lib/mysql/general.log

# Find all queries by specific user
grep "app_user" /var/lib/mysql/general.log
```

### Use Cases

**1. Debugging Application Queries**:
```bash
# Enable logging
mysql> SET GLOBAL general_log = 'ON';

# Run application
# Check what queries it's sending
tail -f /var/lib/mysql/general.log

# Disable after debugging
mysql> SET GLOBAL general_log = 'OFF';
```

**2. Security Audit**:
```bash
# Find failed login attempts
grep "Access denied" /var/lib/mysql/general.log

# Find DROP/DELETE statements
grep -E "(DROP|DELETE)" /var/lib/mysql/general.log
```

---

## 3. Slow Query Log

### Theory

Records queries that take longer than specified threshold to execute.

**Purpose**:
- Identify performance bottlenecks
- Find queries needing optimization
- Monitor application performance

### Configuration

**Check Status**:
```sql
SHOW VARIABLES LIKE 'slow_query%';
SHOW VARIABLES LIKE 'long_query_time';
```

**Enable**:
```sql
-- Enable slow query log
SET GLOBAL slow_query_log = 'ON';

-- Set threshold (seconds)
SET GLOBAL long_query_time = 2;  -- Log queries > 2 seconds

-- Log queries without indexes
SET GLOBAL log_queries_not_using_indexes = 'ON';

-- Check log file location
SHOW VARIABLES LIKE 'slow_query_log_file';
```

**Permanent Configuration** (`/etc/my.cnf`):
```ini
[mysqld]
slow_query_log = 1
slow_query_log_file = /var/lib/mysql/slow-query.log
long_query_time = 2
log_queries_not_using_indexes = 1
```

### Analyzing Slow Queries

**View Log Directly**:
```bash
tail -100 /var/lib/mysql/slow-query.log
```

**Use mysqldumpslow Tool**:
```bash
# Summary of slow queries
mysqldumpslow /var/lib/mysql/slow-query.log

# Top 10 slowest queries
mysqldumpslow -s t -t 10 /var/lib/mysql/slow-query.log

# Queries with most time spent
mysqldumpslow -s at -t 10 /var/lib/mysql/slow-query.log

# Options:
# -s: Sort order (t=time, at=average time, c=count)
# -t: Show top N queries
# -g: Filter by pattern
```

### Example Output

```
# Time: 2024-12-25T10:30:45.123456Z
# User@Host: app_user[app_user] @ localhost []
# Query_time: 5.234567  Lock_time: 0.000123 Rows_sent: 1000  Rows_examined: 1000000
SET timestamp=1703502645;
SELECT * FROM orders WHERE customer_id = 1001 AND order_date > '2024-01-01';
```

**Analysis**:
- Query took 5.23 seconds
- Examined 1 million rows to return 1000
- Likely missing index on (customer_id, order_date)

### Optimization Process

**1. Identify Slow Query**:
```bash
mysqldumpslow -s t -t 1 /var/lib/mysql/slow-query.log
```

**2. Analyze with EXPLAIN**:
```sql
EXPLAIN SELECT * FROM orders 
WHERE customer_id = 1001 AND order_date > '2024-01-01';
```

**3. Add Index**:
```sql
CREATE INDEX idx_customer_date ON orders(customer_id, order_date);
```

**4. Verify Improvement**:
```sql
EXPLAIN SELECT * FROM orders 
WHERE customer_id = 1001 AND order_date > '2024-01-01';
-- Should now show "Using index"
```

---

## 4. Binary Log

### Theory

Binary logs record all database changes in binary format.

**Purposes**:
1. **Replication**: Replicas read binlogs from primary
2. **Point-in-Time Recovery**: Restore to specific moment
3. **Audit**: Track all data modifications

### Configuration

**Check Status**:
```sql
SHOW VARIABLES LIKE 'log_bin%';
SHOW VARIABLES LIKE 'binlog%';
```

**Enable** (`/etc/my.cnf`):
```ini
[mysqld]
log_bin = /var/lib/mysql/mysql-bin
binlog_format = ROW
expire_logs_days = 7  # Auto-delete after 7 days
max_binlog_size = 100M  # Rotate at 100MB
```

### Managing Binary Logs

**List Binary Logs**:
```sql
SHOW BINARY LOGS;
```

**Output**:
```
+------------------+-----------+
| Log_name         | File_size |
+------------------+-----------+
| mysql-bin.000001 |  10485760 |
| mysql-bin.000002 |   5242880 |
| mysql-bin.000003 |    524288 |
+------------------+-----------+
```

**Purge Old Logs**:
```sql
-- Delete logs before specific binlog
PURGE BINARY LOGS TO 'mysql-bin.000014';

-- Delete logs older than date
PURGE BINARY LOGS BEFORE '2024-12-20 00:00:00';

-- Delete logs older than 3 days
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 3 DAY);
```

### Viewing Binary Log Contents

**Using mysqlbinlog Utility**:

```bash
# Basic view
mysqlbinlog /var/lib/mysql/mysql-bin.000001

# Verbose (shows row data for ROW format)
mysqlbinlog --verbose /var/lib/mysql/mysql-bin.000001

# Specific database only
mysqlbinlog --database=mydb /var/lib/mysql/mysql-bin.000001

# Specific time range
mysqlbinlog --start-datetime="2024-12-25 10:00:00" \
            --stop-datetime="2024-12-25 11:00:00" \
            /var/lib/mysql/mysql-bin.000001

# Specific position range
mysqlbinlog --start-position=123 \
            --stop-position=456 \
            /var/lib/mysql/mysql-bin.000001

# Output to file
mysqlbinlog /var/lib/mysql/mysql-bin.000001 > binlog_dump.sql
```

### Common Use Cases

**1. Extract Events for Specific Database**:
```bash
mysqlbinlog --database=production_db /var/lib/mysql/mysql-bin.000001 > prod_events.txt
```

**2. Find Specific Event** (e.g., accidental DELETE):
```bash
mysqlbinlog --verbose /var/lib/mysql/mysql-bin.000002 | grep -i "DELETE"
```

**3. Replay Binary Logs** (Recovery):
```bash
# Replay up to specific time
mysqlbinlog --stop-datetime="2024-12-25 10:30:00" \
            /var/lib/mysql/mysql-bin.000001 | mysql -u root -p

# Replay multiple binlogs
mysqlbinlog /var/lib/mysql/mysql-bin.000001 \
            /var/lib/mysql/mysql-bin.000002 | mysql -u root -p
```

**4. Extract from Specific Position**:
```bash
# Start from position 123
mysqlbinlog --start-position=123 /var/lib/mysql/mysql-bin.000002 > from-123.sql

# Stop at position 219
mysqlbinlog --stop-position=219 /var/lib/mysql/mysql-bin.000001 > upto-219.sql
```

### Binlog Position Tracking

```sql
-- Current binlog position
SHOW MASTER STATUS;

-- Output:
+------------------+----------+--------------+------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+----------+--------------+------------------+
| mysql-bin.000003 |     1234 |              |                  |
+------------------+----------+--------------+------------------+
```

---

## 📊 Log Management Best Practices

### 1. Log Rotation

**Automatic Binlog Rotation**:
```ini
[mysqld]
max_binlog_size = 100M  # Rotate when file reaches 100MB
```

**Logrotate for Error/Slow Logs** (`/etc/logrotate.d/mysql`):
```
/var/log/mysql/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 mysql mysql
    sharedscripts
    postrotate
        /usr/bin/mysql -e 'FLUSH LOGS'
    endscript
}
```

### 2. Monitoring Log Size

```sql
-- Check binlog disk usage
SELECT 
    SUM(ROUND(FILE_SIZE/1024/1024,2)) AS `Total Binlog Size (MB)`
FROM information_schema.GLOBAL_STATUS
WHERE VARIABLE_NAME = 'Binlog_cache_disk_use';

-- Or check filesystem
```

```bash
du -sh /var/lib/mysql/mysql-bin.*
```

### 3. Automatic Cleanup

```ini
[mysqld]
# Auto-delete binlogs after 7 days
expire_logs_days = 7

# Or in seconds (MySQL 8.0.1+)
binlog_expire_logs_seconds = 604800  # 7 days
```

### 4. Log Security

```bash
# Restrict permissions
chmod 640 /var/log/mysql/*.log
chown mysql:mysql /var/log/mysql/*.log

# Encrypt binlogs (MySQL 8.0.14+)
```

```ini
[mysqld]
binlog_encryption = ON
```

---

## 🧪 Practical Exercises

### Exercise 1: Enable and Analyze Slow Queries

```sql
-- 1. Enable slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;

-- 2. Run a slow query
SELECT SLEEP(2);

-- 3. Check slow query log
```

```bash
tail /var/lib/mysql/slow-query.log
mysqldumpslow /var/lib/mysql/slow-query.log
```

### Exercise 2: Binary Log Analysis

```sql
-- 1. Make some changes
CREATE DATABASE test_binlog;
USE test_binlog;
CREATE TABLE test_table (id INT, data VARCHAR(100));
INSERT INTO test_table VALUES (1, 'Test data');
UPDATE test_table SET data = 'Updated data' WHERE id = 1;

-- 2. Check current binlog
SHOW MASTER STATUS;

-- 3. Extract events
```

```bash
mysqlbinlog --verbose /var/lib/mysql/mysql-bin.XXXXXX | grep -A 10 "test_table"
```

### Exercise 3: Log Cleanup

```sql
-- 1. Check binlog size
SHOW BINARY LOGS;

-- 2. Purge old logs
PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL 3 DAY);

-- 3. Verify
SHOW BINARY LOGS;
```

---

## 🔍 Troubleshooting

### Issue: Disk Full Due to Logs

**Diagnosis**:
```bash
df -h
du -sh /var/lib/mysql/
```

**Solution**:
```sql
-- Immediate: Purge old binlogs
PURGE BINARY LOGS BEFORE NOW() - INTERVAL 1 DAY;

-- Long-term: Enable auto-expiration
SET GLOBAL expire_logs_days = 3;
```

### Issue: Can't Find Specific Event in Binlog

**Solution**:
```bash
# Search all binlogs
for binlog in /var/lib/mysql/mysql-bin.*; do
    echo "Checking $binlog"
    mysqlbinlog --verbose "$binlog" | grep -i "search_term"
done
```

### Issue: Slow Query Log Not Working

**Check**:
```sql
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'long_query_time';
```

**Fix**:
```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
```

---

## 📚 Summary

| Log Type | When to Use | Performance Impact |
|----------|-------------|-------------------|
| **Error Log** | Always ON | Minimal |
| **General Log** | Debugging only | High ⚠️ |
| **Slow Query Log** | Performance tuning | Low-Medium |
| **Binary Log** | Replication/Recovery | Low |

**Key Takeaways**:
- Always monitor error log
- Enable slow query log in production
- Use general log sparingly (debugging only)
- Manage binlog size with auto-expiration
- Regular log analysis prevents issues

---

# Lab 4: User Management and Security

## 🎯 Objectives
- Create and manage MySQL users
- Implement principle of least privilege
- Configure password policies
- Manage user privileges effectively

## 📖 Theory

### Authentication in MySQL 8.0

**Default Plugin**: `caching_sha2_password`
- More secure than older `mysql_native_password`
- Requires SSL for non-localhost connections (first time)
- Faster subsequent authentication via cache

**User Format**: `'username'@'host'`
- Username: Up to 32 characters
- Host: Determines where user can connect from

### Privilege Levels

MySQL has hierarchical privilege levels:

```
Global (*.*)
  ↓
Database (database_name.*)
  ↓  
Table (database_name.table_name)
  ↓
Column (specific columns)
  ↓
Routine (stored procedures/functions)
```

---

## 💻 User Management Operations

### 1. View Available Privileges

```sql
SHOW PRIVILEGES;
```

**Output** (partial):
```
+----------------+---------------------------------------+
| Privilege      | Context                               |
+----------------+---------------------------------------+
| SELECT         | Tables                                |
| INSERT         | Tables                                |
| UPDATE         | Tables                                |
| DELETE         | Tables                                |
| CREATE         | Databases,Tables,Indexes              |
| DROP           | Databases,Tables                      |
| RELOAD         | Server Admin                          |
| SUPER          | Server Admin                          |
| REPLICATION SLAVE | Server Admin                       |
+----------------+---------------------------------------+
```

---

### 2. List Existing Users

**Method 1**: Query mysql.user table
```sql
USE mysql;
SELECT user, host, plugin, password_expired 
FROM user;
```

**Example Output**:
```
+------------------+-----------+-----------------------+------------------+
| user             | host      | plugin                | password_expired |
+------------------+-----------+-----------------------+------------------+
| root             | localhost | caching_sha2_password | N                |
| mysql.infoschema | localhost | caching_sha2_password | Y                |
| mysql.session    | localhost | caching_sha2_password | Y                |
| mysql.sys        | localhost | caching_sha2_password | Y                |
+------------------+-----------+-----------------------+------------------+
```

**System Users** (don't modify):
- `mysql.infoschema`: INFORMATION_SCHEMA access
- `mysql.session`: Plugin use
- `mysql.sys`: sys schema access

---

### 3. Create Users

#### Basic User Creation

```sql
-- Local access only
CREATE USER 'appuser'@'localhost' IDENTIFIED BY 'Password@1';
```

**Explanation**:
- `@'localhost'`: Can only connect from same machine
- `IDENTIFIED BY`: Sets password
- Uses default `caching_sha2_password` plugin

#### User with Specific IP

```sql
CREATE USER 'rwuser'@'172.4.3.67' IDENTIFIED BY 'Password@1';
```

**Use Case**: Application server at specific IP

#### User from IP Range

```sql
CREATE USER 'rwuser'@'172.4.%' IDENTIFIED BY 'Password@1';
```

**Wildcard Matching**:
- `%`: Matches any sequence
- `_`: Matches single character
- `172.4.%`: Matches 172.4.0.0 - 172.4.255.255

#### User from Any Host (⚠️ Security Risk)

```sql
CREATE USER 'remote_user'@'%' IDENTIFIED BY 'Password@1';
```

**WARNING**: Only use with:
- Strong passwords
- Firewall rules
- VPN/Private network
- SSL enforcement

#### User with Old Authentication Plugin

```sql
-- For legacy applications
CREATE USER 'legacy_app'@'localhost' 
IDENTIFIED WITH mysql_native_password BY 'Password@1';
```

---

### 4. Grant Privileges

#### Read-Only User (SELECT only)

```sql
-- All databases
GRANT SELECT ON *.* TO 'appuser'@'localhost';

-- Specific database
GRANT SELECT ON myapp_db.* TO 'appuser'@'localhost';

-- Specific table
GRANT SELECT ON myapp_db.users TO 'appuser'@'localhost';
```

**Use Case**: Reporting, analytics, read-only replicas

#### Read-Write User

```sql
CREATE USER 'rwuser'@'172.4.3.67' IDENTIFIED BY 'Password@1';

GRANT SELECT, INSERT, UPDATE, DELETE 
ON *.* 
TO 'rwuser'@'172.4.3.67';
```

**Use Case**: Application database access

**Important**: No DDL privileges (CREATE, DROP, ALTER)

#### Full Database Access (except GRANT OPTION)

```sql
CREATE USER 'dbuser'@'172.4.3.67' IDENTIFIED BY 'Password@1';

GRANT ALL ON employees.* TO 'dbuser'@'172.4.3.67';
```

**Grants ALL privileges**:
- SELECT, INSERT, UPDATE, DELETE
- CREATE, DROP, ALTER, INDEX
- CREATE TEMPORARY TABLES
- LOCK TABLES, REFERENCES, etc.

**Does NOT grant**:
- GRANT OPTION (can't grant to others)
- SUPER (can't kill other users' queries)
- RELOAD, SHUTDOWN, etc.

#### DBA/Admin User

```sql
CREATE USER 'admin_user'@'localhost' IDENTIFIED BY 'SecureP@ssw0rd!';

GRANT ALL PRIVILEGES ON *.* 
TO 'admin_user'@'localhost' 
WITH GRANT OPTION;
```

**WITH GRANT OPTION**: Can grant privileges to other users

**⚠️ Security**: Only give to trusted administrators

#### Specific Privileges

**Application User** (Common Pattern):
```sql
CREATE USER 'webapp'@'192.168.1.%' IDENTIFIED BY 'WebAppP@ss123';

GRANT SELECT, INSERT, UPDATE, DELETE 
ON webapp_db.* 
TO 'webapp'@'192.168.1.%';

-- Also grant procedure execution
GRANT EXECUTE ON webapp_db.* TO 'webapp'@'192.168.1.%';
```

**Backup User**:
```sql
CREATE USER 'backup_user'@'localhost' IDENTIFIED BY 'BackupP@ss456';

GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER, RELOAD 
ON *.* 
TO 'backup_user'@'localhost';
```

**Replication User**:
```sql
CREATE USER 'replication_user'@'%' IDENTIFIED BY 'ReplP@ss789';

GRANT REPLICATION SLAVE ON *.* 
TO 'replication_user'@'%';
```

**Monitoring User**:
```sql
CREATE USER 'monitor_user'@'localhost' IDENTIFIED BY 'MonitorP@ss';

GRANT SELECT, PROCESS, REPLICATION CLIENT 
ON *.* 
TO 'monitor_user'@'localhost';
```

---

### 5. View User Privileges

```sql
-- Current user's privileges
SHOW GRANTS;

-- Specific user's privileges
SHOW GRANTS FOR 'appuser'@'localhost';

-- Detailed privilege info from mysql.user
SELECT * FROM mysql.user WHERE user = 'appuser'\G
```

**Example Output**:
```
GRANT USAGE ON *.* TO `appuser`@`localhost`
GRANT SELECT ON `myapp_db`.* TO `appuser`@`localhost`
```

**USAGE**: Basic connection privilege (no actual permissions)

---

### 6. Revoke Privileges

#### Revoke Specific Privileges

```sql
-- View current privileges
SHOW GRANTS FOR 'rwuser'@'172.4.3.67';

-- Revoke specific privileges
REVOKE DELETE ON *.* FROM 'rwuser'@'172.4.3.67';

-- Revoke multiple privileges
REVOKE INSERT, UPDATE ON myapp_db.* FROM 'rwuser'@'172.4.3.67';
```

#### Revoke All Privileges

```sql
REVOKE ALL PRIVILEGES ON myapp_db.* FROM 'appuser'@'localhost';
```

**Note**: User can still connect (has USAGE)

---

### 7. Delete Users

```sql
-- Drop single user
DROP USER 'rwuser'@'172.4.3.67';

-- Drop multiple users
DROP USER 'user1'@'localhost', 'user2'@'localhost';

-- Check if exists before dropping
DROP USER IF EXISTS 'tempuser'@'localhost';
```

**Important**: Automatically revokes all privileges

---

## 🔐 Advanced User Management

### 1. Dual Password Feature (MySQL 8.0.14+)

**Use Case**: Change password without breaking existing connections

```sql
-- Set new password while keeping old one
ALTER USER 'appuser'@'localhost' 
IDENTIFIED BY 'NewPassword@123' 
RETAIN CURRENT PASSWORD;
```

**How it works**:
1. Primary password: `NewPassword@123`
2. Secondary password: `Password@1` (old)
3. Both passwords work temporarily

**Update application to use new password**

**Discard old password**:
```sql
ALTER USER 'appuser'@'localhost' DISCARD OLD PASSWORD;
```

**Real-World Scenario**:
```sql
-- Day 1: Rotate password
ALTER USER 'webapp'@'%' 
IDENTIFIED BY 'NewP@ssw0rd2024' 
RETAIN CURRENT PASSWORD;

-- Day 2-7: Update all application instances

-- Day 8: Remove old password
ALTER USER 'webapp'@'%' DISCARD OLD PASSWORD;
```

---

### 2. Password Expiration

#### Manual Expiration

```sql
-- Force password change on next login
ALTER USER 'testusr'@'localhost' PASSWORD EXPIRE;
```

**User Experience**:
```
$ mysql -u testusr -p
ERROR 1820 (HY000): You must reset your password using ALTER USER
```

**User must change password**:
```sql
ALTER USER USER() IDENTIFIED BY 'NewPassword@456';
```

#### Automatic Expiration Policies

**System-Wide Default**:
```sql
-- Set global policy (90 days)
SET GLOBAL default_password_lifetime = 90;
```

**Per-User Policies**:
```sql
-- Never expire
ALTER USER 'service_account'@'localhost' PASSWORD EXPIRE NEVER;

-- Use system default
ALTER USER 'regular_user'@'localhost' PASSWORD EXPIRE DEFAULT;

-- Custom expiration (30 days)
ALTER USER 'temp_user'@'localhost' PASSWORD EXPIRE INTERVAL 30 DAY;

-- Expire immediately
ALTER USER 'compromised_user'@'localhost' PASSWORD EXPIRE;
```

**Configuration File** (`/etc/my.cnf`):
```ini
[mysqld]
default_password_lifetime = 90  # Days
```

---

### 3. Password Validation

**Install Validation Plugin**:
```sql
INSTALL COMPONENT 'file://component_validate_password';
```

**Configure Password Policy**:
```sql
-- Password length (default: 8)
SET GLOBAL validate_password.length = 12;

-- Mixed case count (default: 1)
SET GLOBAL validate_password.mixed_case_count = 1;

-- Number count (default: 1)
SET GLOBAL validate_password.number_count = 1;

-- Special character count (default: 1)
SET GLOBAL validate_password.special_char_count = 1;

-- Policy level
SET GLOBAL validate_password.policy = STRONG;
```

**Policy Levels**:
- `LOW`: Length only
- `MEDIUM`: Length + numeric + mixed case + special
- `STRONG`: Medium + dictionary file check

**Check Current Settings**:
```sql
SHOW VARIABLES LIKE 'validate_password%';
```

**Test Password**:
```sql
-- This will fail (too simple)
CREATE USER 'test'@'localhost' IDENTIFIED BY 'password';

-- Error: Password does not satisfy policy requirements

-- This works
CREATE USER 'test'@'localhost' IDENTIFIED BY 'SecureP@ssw0rd123!';
```

---

### 4. Account Locking

**Failed Login Tracking** (MySQL 8.0.19+):
```sql
CREATE USER 'secure_user'@'localhost' 
IDENTIFIED BY 'password' 
FAILED_LOGIN_ATTEMPTS 3 
PASSWORD_LOCK_TIME 1;  -- Lock for 1 day
```

**Explanation**:
- After 3 failed login attempts
- Account locked for 1 day
- Or use `UNBOUNDED` for manual unlock only

**Manual Lock/Unlock**:
```sql
-- Lock account
ALTER USER 'suspicious_user'@'localhost' ACCOUNT LOCK;

-- Unlock account
ALTER USER 'suspicious_user'@'localhost' ACCOUNT UNLOCK;
```

**Check Lock Status**:
```sql
SELECT user, host, account_locked 
FROM mysql.user 
WHERE user = 'secure_user';
```

---

### 5. Change User Password

**Self Password Change**:
```sql
-- Change own password
ALTER USER USER() IDENTIFIED BY 'NewP@ssw0rd789';
```

**Admin Password Change**:
```sql
-- Change another user's password
ALTER USER 'appuser'@'localhost' IDENTIFIED BY 'AdminSet_P@ss123';

-- For root
ALTER USER 'root'@'localhost' IDENTIFIED BY 'NewRootP@ss!';
```

**Using SET PASSWORD** (deprecated, use ALTER USER):
```sql
-- Old method (still works)
SET PASSWORD FOR 'user'@'host' = 'password';
```

---

## 🛡️ Security Best Practices

### 1. Principle of Least Privilege

❌ **BAD** - Giving too much access:
```sql
GRANT ALL PRIVILEGES ON *.* TO 'webapp'@'%';
```

✅ **GOOD** - Minimal necessary access:
```sql
CREATE USER 'webapp'@'192.168.1.%' IDENTIFIED BY 'SecureP@ss!';
GRANT SELECT, INSERT, UPDATE, DELETE ON webapp_db.* TO 'webapp'@'192.168.1.%';
```

### 2. Host Restrictions

❌ **BAD** - Allow from anywhere:
```sql
CREATE USER 'admin'@'%' IDENTIFIED BY 'password';
```

✅ **GOOD** - Specific hosts only:
```sql
CREATE USER 'admin'@'localhost' IDENTIFIED BY 'SecureP@ss!';
CREATE USER 'admin'@'10.0.1.5' IDENTIFIED BY 'SecureP@ss!';
```

### 3. Strong Passwords

❌ **BAD**:
- `password`
- `123456`
- `company_name`
- `mysql`

✅ **GOOD**:
- Minimum 12 characters
- Mixed case
- Numbers
- Special characters
- Example: `Tr0ng_P@ssW0rd_2024!`

### 4. Regular Audits

```sql
-- List all users
SELECT user, host, authentication_string != '' AS has_password
FROM mysql.user
ORDER BY user, host;

-- Find users with dangerous privileges
SELECT user, host 
FROM mysql.user 
WHERE Super_priv = 'Y' OR Grant_priv = 'Y';

-- Find users accessible from anywhere
SELECT user, host 
FROM mysql.user 
WHERE host = '%';
```

### 5. Remove Unnecessary Accounts

```sql
-- Remove anonymous users
DELETE FROM mysql.user WHERE user = '';

-- Remove test databases
DROP DATABASE IF EXISTS test;

-- Drop unused accounts
DROP USER IF EXISTS 'olduser'@'localhost';

FLUSH PRIVILEGES;
```

---

## 🧪 Practical Scenarios

### Scenario 1: E-commerce Application

```sql
-- 1. Web application user
CREATE USER 'ecommerce_app'@'192.168.10.%' 
IDENTIFIED BY 'App_SecureP@ss2024!';

GRANT SELECT, INSERT, UPDATE, DELETE 
ON ecommerce_db.* 
TO 'ecommerce_app'@'192.168.10.%';

-- 2. Read-only reporting user
CREATE USER 'reporting'@'10.20.30.40' 
IDENTIFIED BY 'Report_P@ss2024!';

GRANT SELECT ON ecommerce_db.* 
TO 'reporting'@'10.20.30.40';

-- 3. Admin user (localhost only)
CREATE USER 'db_admin'@'localhost' 
IDENTIFIED BY 'Admin_SecureP@ss!';

GRANT ALL PRIVILEGES ON ecommerce_db.* 
TO 'db_admin'@'localhost' 
WITH GRANT OPTION;
```

### Scenario 2: Password Rotation

```sql
-- Step 1: Enable dual password
ALTER USER 'production_app'@'%' 
IDENTIFIED BY 'NewP@ss_Q1_2024!' 
RETAIN CURRENT PASSWORD;

-- Step 2: Update application configuration
-- (Deploy new password to all app servers)

-- Step 3: After verification (1 week), remove old password
ALTER USER 'production_app'@'%' DISCARD OLD PASSWORD;

-- Step 4: Set next expiration (90 days)
ALTER USER 'production_app'@'%' PASSWORD EXPIRE INTERVAL 90 DAY;
```

### Scenario 3: Security Incident Response

```sql
-- 1. Immediately lock compromised account
ALTER USER 'compromised_user'@'%' ACCOUNT LOCK;

-- 2. Check what access they had
SHOW GRANTS FOR 'compromised_user'@'%';

-- 3. Check recent activity (if general log enabled)
-- grep "compromised_user" /var/lib/mysql/general.log

-- 4. After investigation, change password and unlock
ALTER USER 'compromised_user'@'%' 
IDENTIFIED BY 'NewSecureP@ss!' 
ACCOUNT UNLOCK;

-- 5. Enable failed login tracking
ALTER USER 'compromised_user'@'%' 
FAILED_LOGIN_ATTEMPTS 3 
PASSWORD_LOCK_TIME 1;
```

---

## 📊 User Privilege Matrix

| User Type | Privileges | Host | Use Case |
|-----------|-----------|------|----------|
| **Application** | SELECT, INSERT, UPDATE, DELETE | Specific IPs | Web/mobile apps |
| **Read-only** | SELECT | Reporting server | Analytics, BI |
| **Backup** | SELECT, LOCK TABLES, RELOAD | localhost | Automated backups |
| **Replication** | REPLICATION SLAVE | Replica IPs | Database replication |
| **Developer** | ALL on dev_db | Dev network | Development work |
| **DBA** | ALL with GRANT | localhost | Database administration |

---

## 🔍 Troubleshooting

### Issue: Access Denied

```
ERROR 1045 (28000): Access denied for user 'appuser'@'192.168.1.100'
```

**Check**:
```sql
-- Does user exist?
SELECT user, host FROM mysql.user WHERE user = 'appuser';

-- Check privileges
SHOW GRANTS FOR 'appuser'@'192.168.1.100';
```

**Common Causes**:
1. User doesn't exist for that host
2. Wrong password
3. Connecting from unexpected IP

### Issue: Password Expired

```
ERROR 1820 (HY000): You must reset your password
```

**Solution**:
```sql
ALTER USER USER() IDENTIFIED BY 'NewPassword@123!';
```

### Issue: Account Locked

**Check**:
```sql
SELECT user, host, account_locked 
FROM mysql.user 
WHERE user = 'locked_user';
```

**Unlock**:
```sql
ALTER USER 'locked_user'@'host' ACCOUNT UNLOCK;
```

---

## 📚 Summary

**Key Takeaways**:
1. Always use specific hosts (avoid `'%'`)
2. Grant minimum necessary privileges
3. Use strong passwords with validation
4. Implement password expiration policies
5. Regular security audits
6. Use dual passwords for smooth rotation
7. Lock suspicious accounts immediately
8. Document all user accounts and purposes

**Security Checklist**:
- ✅ Remove anonymous users
- ✅ Remove remote root access
- ✅ Enable password validation
- ✅ Set password expiration (90 days)
- ✅ Use specific host restrictions
- ✅ Regular privilege audits
- ✅ Enable failed login tracking
- ✅ Strong password policy

---

# Lab 5: Point-in-Time Recovery (PITR)

## 🎯 Objectives
- Understand Point-in-Time Recovery concept
- Perform PITR using full backups and binary logs
- Recover from accidental data deletion
- Master binary log analysis for recovery

## 📖 Theory

### What is Point-in-Time Recovery?

**Point-in-Time Recovery** (PITR) allows you to restore a database to a specific moment in the past, not just to the time of the last backup.

**Components Required**:
1. **Full Backup**: Baseline state of database
2. **Binary Logs**: Record of all changes since backup

**How PITR Works**:
```
[Full Backup at 2:00 AM]
         ↓
[Binary logs: 2:00 AM → 11:45 AM]
         ↓
[Disaster at 11:50 AM]
         ↓
[Restore backup + replay binlogs up to 11:45 AM]
```

### Real-World Scenario

**Timeline**:
```
02:00 - Full backup taken
10:00 - Normal operations
10:30 - Insert important data
11:00 - Update customer records
11:45 - Everything fine
11:50 - Developer runs: DELETE FROM customers; (forgot WHERE clause!)
12:00 - Discover disaster
```

**Recovery Goal**: Restore to 11:45 (before DELETE)

---

## 🔧 Prerequisites Check

### Step 1: Verify Binary Logging is Enabled

```sql
mysql -u root -p
SHOW VARIABLES LIKE 'log_bin';
```

**Expected Output**:
```
+---------------+-------+
| Variable_name | Value |
+---------------+-------+
| log_bin       | ON    |
+---------------+-------+
```

**If OFF, enable in** `/etc/my.cnf`:
```ini
[mysqld]
log_bin = /var/lib/mysql/binlog
binlog_format = ROW
```

Then restart MySQL:
```bash
sudo systemctl restart mysqld
```

---

## 💻 Step-by-Step PITR Lab

### Step 1: Create Sample Database

```sql
-- Connect to MySQL
mysql -u root -p

-- Create test database
CREATE DATABASE appdb;
USE appdb;

-- Create table
CREATE TABLE IF NOT EXISTS usr_details (
    id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Theory**: We're creating a simple user table to simulate a real application database.

---

### Step 2: Insert Initial Data

```sql
INSERT INTO usr_details (first_name, last_name, email) 
VALUES
    ('Jones', 'Dow', 'jones.dow@example.com'),
    ('Janet', 'Smith', 'janet.smith@example.com'),
    ('Bob', 'John', 'bob.john@example.com');

-- Verify data
SELECT * FROM usr_details;
```

**Output**:
```
+----+------------+-----------+------------------------+---------------------+
| id | first_name | last_name | email                  | created_at          |
+----+------------+-----------+------------------------+---------------------+
|  1 | Jones      | Dow       | jones.dow@example.com  | 2024-12-25 10:00:00 |
|  2 | Janet      | Smith     | janet.smith@example.com| 2024-12-25 10:00:01 |
|  3 | Bob        | John      | bob.john@example.com   | 2024-12-25 10:00:02 |
+----+------------+-----------+------------------------+---------------------+
```

---

### Step 3: Take Full Backup

```bash
# Create backup directory
mkdir -p ~/backup

# Take full backup
mysqldump -uroot -p \
  --all-databases \
  --source-data=2 \
  --single-transaction \
  --flush-logs \
  > ~/backup/appdb.sql
```

**Parameter Explanation**:

| Parameter | Purpose |
|-----------|---------|
| `--all-databases` | Backup all databases |
| `--source-data=2` | Include binary log position in comments |
| `--single-transaction` | Consistent backup without locking (InnoDB) |
| `--flush-logs` | Start new binary log after backup |

**⚠️ Important**: `--source-data=2` records the exact binary log position when backup was taken.

**Check backup file**:
```bash
head -50 ~/backup/appdb.sql | grep "CHANGE MASTER"
```

**Example Output**:
```
-- CHANGE MASTER TO MASTER_LOG_FILE='binlog.000002', MASTER_LOG_POS=157;
```

This tells us: backup taken at position 157 of binlog.000002

---

### Step 4: Simulate Normal Operations (After Backup)

```sql
-- Flush logs to start fresh binary log
FLUSH LOGS;

-- Insert new user (after backup)
INSERT INTO usr_details(first_name, last_name, email)
VALUES('Bob','Tim', 'bob.tim@example.com');

-- Verify
SELECT * FROM usr_details;
```

**Now we have**:
```
+----+------------+-----------+------------------------+---------------------+
| id | first_name | last_name | email                  | created_at          |
+----+------------+-----------+------------------------+---------------------+
|  1 | Jones      | Dow       | jones.dow@example.com  | 2024-12-25 10:00:00 |
|  2 | Janet      | Smith     | janet.smith@example.com| 2024-12-25 10:00:01 |
|  3 | Bob        | John      | bob.john@example.com   | 2024-12-25 10:00:02 |
|  4 | Bob        | Tim       | bob.tim@example.com    | 2024-12-25 11:00:00 |
+----+------------+-----------+------------------------+---------------------+
```

**Note**: Row 4 is NOT in backup (added after)

---

### Step 5: Disaster! Accidental DELETE

```sql
-- Developer forgets WHERE clause!
DELETE FROM usr_details;

-- Horror!
SELECT * FROM usr_details;
```

**Output**:
```
Empty set (0.00 sec)
```

**😱 All data gone!**

---

### Step 6: Identify Problem in Binary Log

**First, find current binary log**:
```sql
SHOW MASTER STATUS;
```

**Output**:
```
+---------------+----------+--------------+------------------+-------------------+
| File          | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+---------------+----------+--------------+------------------+-------------------+
| binlog.000002 |     4952 |              |                  |                   |
+---------------+----------+--------------+------------------+-------------------+
```

**Exit MySQL**:
```sql
exit
```

**Search for DELETE in binary log**:
```bash
mysqlbinlog --verbose /var/lib/mysql/binlog.000002 | grep -i "Delete_rows"
```

**Example Output**:
```
#231225 20:26:10 server id 1  end_log_pos 4921 CRC32 0x53432937  Delete_rows: table id 494
### DELETE FROM `appdb`.`usr_details`
### WHERE
###   @1=1
###   @2='Jones'
###   @3='Dow'
###   @4='jones.dow@example.com'
### DELETE FROM `appdb`.`usr_details`
### WHERE
###   @1=2
###   @2='Janet'
...
# at 4921
#231225 20:26:10 server id 1  end_log_pos 4952 CRC32 0x634fce0a  Xid = 3194
COMMIT/*!*/;
```

**Key Information**:
- **Timestamp**: `2023-12-25 20:26:10`
- **Event**: DELETE FROM usr_details
- **Position**: 4921-4952

**Recovery Plan**: Restore up to `2023-12-25 20:26:10` (before DELETE)

---

### Step 7: Perform Recovery

#### Sub-Step 7.1: Drop and Recreate Database

```sql
mysql -u root -p

-- Drop corrupted database
DROP DATABASE appdb;

-- Recreate empty database
CREATE DATABASE appdb;

exit
```

**Why?** Start fresh before restoring backup.

---

#### Sub-Step 7.2: Restore from Full Backup

```bash
mysql -u root -p appdb < ~/backup/appdb.sql
```

**Verify restoration**:
```sql
mysql -u root -p

USE appdb;
SELECT * FROM usr_details;
```

**Output** (only backup data):
```
+----+------------+-----------+------------------------+
| id | first_name | last_name | email                  |
+----+------------+-----------+------------------------+
|  1 | Jones      | Dow       | jones.dow@example.com  |
|  2 | Janet      | Smith     | janet.smith@example.com|
|  3 | Bob        | John      | bob.john@example.com   |
+----+------------+-----------+------------------------+
```

**Note**: Bob Tim (row 4) is missing because he was added AFTER backup!

---

#### Sub-Step 7.3: Replay Binary Logs (Up to Disaster Point)

```bash
mysqlbinlog \
  --stop-datetime="2023-12-25 20:26:10" \
  --verbose \
  /var/lib/mysql/binlog.000002 | mysql -u root -p
```

**Parameter Breakdown**:

| Parameter | Purpose |
|-----------|---------|
| `--stop-datetime` | Stop replay at this timestamp (before DELETE) |
| `--verbose` | Show detailed information |
| `/var/lib/mysql/binlog.000002` | Binary log file |
| `| mysql -u root -p` | Pipe SQL statements to MySQL |

**What Happens**:
1. mysqlbinlog reads binary log
2. Extracts all events from backup point to 20:26:10
3. Replays INSERT for Bob Tim (and any other changes)
4. Stops before DELETE statement

---

### Step 8: Verify Recovery

```sql
mysql -u root -p

USE appdb;
SELECT * FROM usr_details;
```

**Expected Output**:
```
+----+------------+-----------+-------------------------+
| id | first_name | last_name | email                   |
+----+------------+-----------+-------------------------+
|  1 | Jones      | Dow       | jones.dow@example.com   |
|  2 | Janet      | Smith     | janet.smith@example.com |
|  3 | Bob        | Johnson   | bob.johnson@example.com |
|  4 | Bob        | Climo     | bob.climo@example.com   |
+----+------------+-----------+-------------------------+
```

**✅ Success!** All data recovered up to 20:26:10

---

## 🔬 Advanced Binary Log Analysis

### Method 1: Time-Based Recovery

```bash
# Recover changes between specific times
mysqlbinlog \
  --start-datetime="2024-12-25 10:00:00" \
  --stop-datetime="2024-12-25 11:45:00" \
  /var/lib/mysql/binlog.000002 | mysql -u root -p
```

### Method 2: Position-Based Recovery

```bash
# Find positions
mysqlbinlog --verbose /var/lib/mysql/binlog.000002 | less

# Recover between specific positions
mysqlbinlog \
  --start-position=157 \
  --stop-position=4920 \
  /var/lib/mysql/binlog.000002 | mysql -u root -p
```

**When to use**:
- **Time-based**: General recovery, disaster at known time
- **Position-based**: Precise recovery, skip specific bad transaction

### Method 3: Extract Specific Database Only

```bash
mysqlbinlog \
  --database=appdb \
  --stop-datetime="2024-12-25 11:45:00" \
  /var/lib/mysql/binlog.000002 > appdb_recovery.sql

# Review before applying
less appdb_recovery.sql

# Apply
mysql -u root -p < appdb_recovery.sql
```

### Method 4: Multiple Binary Logs

```bash
# If changes span multiple binlog files
mysqlbinlog \
  --stop-datetime="2024-12-25 11:45:00" \
  /var/lib/mysql/binlog.000001 \
  /var/lib/mysql/binlog.000002 \
  /var/lib/mysql/binlog.000003 | mysql -u root -p
```

---

## 🔍 Binary Log Analysis Commands

### View Binary Log Events

```sql
-- List all binary logs
SHOW BINARY LOGS;

-- View events in specific binlog
SHOW BINLOG EVENTS IN 'binlog.000002';

-- Limit output
SHOW BINLOG EVENTS IN 'binlog.000002' LIMIT 10;

-- From specific position
SHOW BINLOG EVENTS IN 'binlog.000002' FROM 157;
```

### Find Specific Events

```bash
# Find all DELETE statements
mysqlbinlog --verbose /var/lib/mysql/binlog.000002 | grep -i DELETE

# Find events for specific table
mysqlbinlog --verbose /var/lib/mysql/binlog.000002 | grep -A 10 "usr_details"

# Find events in time range
mysqlbinlog \
  --start-datetime="2024-12-25 10:00:00" \
  --stop-datetime="2024-12-25 12:00:00" \
  /var/lib/mysql/binlog.000002 | grep -i "UPDATE\|INSERT\|DELETE"
```

### Extract Event Timeline

```bash
# Create human-readable timeline
mysqlbinlog --verbose --base64-output=DECODE-ROWS \
  /var/lib/mysql/binlog.000002 > binlog_timeline.txt

# View timeline
less binlog_timeline.txt
```

---

## 📊 PITR Strategies

### Strategy 1: Full Recovery (Complete Database)

**Scenario**: Server crashed, need to restore everything

```bash
# 1. Restore full backup
mysql -u root -p < /backup/full_backup.sql

# 2. Replay all binary logs from backup point
mysqlbinlog /var/lib/mysql/binlog.* | mysql -u root -p
```

### Strategy 2: Partial Recovery (Specific Database)

**Scenario**: One database corrupted, others fine

```bash
# 1. Drop and recreate database
mysql -u root -p -e "DROP DATABASE appdb; CREATE DATABASE appdb;"

# 2. Restore database from backup
mysql -u root -p appdb < /backup/appdb_backup.sql

# 3. Replay binlogs for this database only
mysqlbinlog --database=appdb /var/lib/mysql/binlog.* | mysql -u root -p
```

### Strategy 3: Skip Bad Transaction

**Scenario**: Known bad transaction at specific position

```bash
# Replay before bad transaction
mysqlbinlog --stop-position=4920 /var/lib/mysql/binlog.000002 | mysql -u root -p

# Skip bad transaction and continue from after
mysqlbinlog --start-position=4953 /var/lib/mysql/binlog.000002 | mysql -u root -p
```

### Strategy 4: Table-Level Recovery

**Scenario**: Single table corrupted

```bash
# 1. Extract CREATE TABLE and INSERTs for specific table
mysqlbinlog --verbose /var/lib/mysql/binlog.000002 | \
  grep -A 1000 "CREATE TABLE.*customers" > customers_recovery.sql

# 2. Review and clean up
nano customers_recovery.sql

# 3. Drop and recreate table
mysql -u root -p appdb -e "DROP TABLE customers;"
mysql -u root -p appdb < customers_recovery.sql
```

---

## ⚠️ Common Pitfalls and Solutions

### Pitfall 1: Binary Logs Purged

**Problem**: Binary logs deleted before recovery

**Prevention**:
```sql
-- Set retention period
SET GLOBAL expire_logs_days = 7;

-- Or in /etc/my.cnf
[mysqld]
expire_logs_days = 7
```

**Solution if already purged**:
```
Only able to restore to last backup point.
Recent changes lost.
```

### Pitfall 2: Wrong Binlog Format

**Problem**: STATEMENT format with non-deterministic functions

**Check**:
```sql
SHOW VARIABLES LIKE 'binlog_format';
```

**Fix**:
```sql
SET GLOBAL binlog_format = 'ROW';
```

### Pitfall 3: Insufficient Backup Frequency

**Problem**: Backup taken daily, incident at 11 PM

**Impact**: Up to 23 hours of data loss possible

**Solution**: Increase backup frequency
```bash
# Hourly backups via cron
0 * * * * /usr/local/bin/mysql_backup.sh
```

### Pitfall 4: No Test Restores

**Problem**: Backups taken but never tested

**Solution**: Monthly restore test
```bash
# Test restore procedure monthly
0 2 1 * * /usr/local/bin/test_restore.sh
```

---

## 🧪 Practice Exercises

### Exercise 1: Complete PITR Workflow

```sql
-- 1. Create test database
CREATE DATABASE pitr_test;
USE pitr_test;
CREATE TABLE transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    amount DECIMAL(10,2),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Insert data
INSERT INTO transactions (amount) VALUES (100.00), (250.50), (75.25);

-- 3. Take backup
-- (Run in bash)
exit
```

```bash
mysqldump -uroot -p --databases pitr_test --source-data=2 > pitr_backup.sql
```

```sql
-- 4. Make more changes
mysql -u root -p
USE pitr_test;
INSERT INTO transactions (amount) VALUES (500.00), (125.75);

-- 5. Disaster!
DELETE FROM transactions WHERE amount < 300;

-- 6. Perform PITR (find DELETE time first)
exit
```

```bash
# Find DELETE timestamp
mysqlbinlog --verbose /var/lib/mysql/binlog.* | grep -B 5 -A 5 "DELETE.*transactions"

# Restore
mysql -u root -p pitr_test < pitr_backup.sql
mysqlbinlog --stop-datetime="<time_before_delete>" /var/lib/mysql/binlog.* | mysql -u root -p
```

### Exercise 2: Position-Based Recovery

```bash
# 1. List binary log events
mysql -u root -p -e "SHOW BINLOG EVENTS IN 'binlog.000002';"

# 2. Identify position of bad event

# 3. Recover up to that position
mysqlbinlog --stop-position=<position> /var/lib/mysql/binlog.000002 | mysql -u root -p
```

---

## 📚 Summary

### PITR Process Overview

```
1. BEFORE disaster:
   ├── Regular full backups
   ├── Binary logging enabled
   └── Retention policy set

2. DURING disaster:
   ├── Identify problem time
   ├── Note current binlog position
   └── Stop application if possible

3. RECOVERY:
   ├── Restore from full backup
   ├── Replay binlogs up to disaster time
   └── Verify data integrity

4. AFTER recovery:
   ├── Document incident
   ├── Review backup strategy
   └── Test recovery procedure
```

### Key Takeaways

1. **Always enable binary logging**
2. **Regular full backups** (daily minimum)
3. **Retain binary logs** (7+ days)
4. **Test recovery procedures** monthly
5. **Use ROW binlog format** for safety
6. **Document recovery procedures**
7. **Monitor binary log disk usage**
8. **Keep backup and binlogs separate** (different disks)

### Essential Commands Reference

```bash
# Take backup with binlog position
mysqldump --source-data=2 --single-transaction --all-databases > backup.sql

# Find event in binlog
mysqlbinlog --verbose binlog.000002 | grep -i "DELETE"

# Time-based recovery
mysqlbinlog --stop-datetime="2024-12-25 11:45:00" binlog.* | mysql -u root -p

# Position-based recovery
mysqlbinlog --start-position=157 --stop-position=4920 binlog.000002 | mysql -u root -p
```

### Backup Strategy Checklist

- ✅ Binary logging enabled
- ✅ Daily full backups (minimum)
- ✅ Binlog retention 7+ days
- ✅ Backups stored off-server
- ✅ Monthly restore tests
- ✅ Documented recovery procedures
- ✅ Monitoring binlog disk usage
- ✅ Application-consistent backups

---

This comprehensive documentation covers all 5 major labs with detailed theory, step-by-step instructions, explanations, real-world scenarios, and best practices. Would you like me to continue with Lab 6 (Replication) and Lab 7 (Installation)?

