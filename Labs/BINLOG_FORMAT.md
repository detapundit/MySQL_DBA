**BINLOG FORMAT**

MySQL supports multiple binary log (binlog) formats. The two commonly used ones are STATEMENT-based and ROW-based logging.

1. STATEMENT-Based Replication (SBR)

What it logs

Logs the SQL statement exactly as executed on the primary.
The same statement is re-executed on the replica.

Key characteristics
Logs one statement, regardless of how many rows are affected.

Smaller binlog size.

Faster logging.

Pros

Smaller binlog files

Less disk and network usage

            UPDATE employees
            SET salary = salary + 1000
            WHERE department = 'IT';

BINLOG:
              
              UPDATE employees SET salary = salary + 1000 WHERE department = 'IT';

Problematic case:

              INSERT INTO audit_log VALUES (NOW());

Cons

Non-deterministic functions (NOW(), RAND(), UUID())

Statements like LIMIT without ORDER BY can behave differently

Harder to debug row-level data differences

2. ROW-Based Replication (RBR)

What it logs

Logs the actual row changes (before/after image of rows).

Replica does not re-execute SQL logic.

            UPDATE employees
            SET salary = salary + 1000
            WHERE department = 'IT'; #Assume 2 rows are affected.

Binlog entry (conceptually):

            Row 1: salary 50000 → 51000
            Row 2: salary 60000 → 61000

Key characteristics

Logs each changed row

Larger binlog size

Deterministic replication

Pros

Accurate and safe replication

Works correctly with functions, triggers, and complex queries

Easier to ensure data consistency

Cons

Larger binlog files

More disk and network I/O
