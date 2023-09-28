** Different logs in mysql**

**MySQL ERROR LOGS: Default location - /var/log/mysqld.log (Check my.cnf for log location):**

    less /var/log/mysqld.log

**General logs in mysql: Default location - check from mysql command line using show variables**

    set global general_log=1  => Default is 0, which is OFF, 1 is ON

**Slow query logs: Default location - check from mysql command line using show variables**

    set global slow_query_log=1
    set global long_query_time=5  => Value in secs. Default is 10 secs

Binary logs:  Enabled by default in recent version of mysql. check from mysql command line using show variables**

    show variables like '%log_bin%





