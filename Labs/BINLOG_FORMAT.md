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

