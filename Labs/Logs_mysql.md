** Different logs in mysql**

**MySQL ERROR LOGS: Default location - /var/log/mysqld.log (Check my.cnf for log location):**

    less /var/log/mysqld.log

**General logs in mysql: Default location - check from mysql command line using show variables**

    set global general_log=1  => Default is 0, which is OFF, 1 is ON

**Slow query logs: Default location - check from mysql command line using show variables**

    set global slow_query_log=1
    set global long_query_time=5  => Value in secs. Default is 10 secs
    mysqldumpslow -s -t /var/lib/mysql/ip-172-31-7-234-slow.log
    
Binary logs:  Enabled by default in recent version of mysql. check from mysql command line using show variables**

    mysql>show variables like '%log_bin%
    log-bin=mysql-bin  # in my.cnf
    expire_logs_days = 2 # in my.cnf
    binlog_format=mixed  # in my.cnf
    mysql> SHOW BINARY LOGS;

    # Entries of specific database:
    mysqlbinlog -d mdata mysqld-bin.000001 > crm-event_log.txt

    # you can specify the position you want to read data from, using the -j option as follows:
    
    mysqlbinlog -j 123 mysqld-bin.000002 > from-123.txt

    # you can specify the position till where you want to extract the data:

    mysqlbinlog --stop-position=219 mysqld-bin.000001 > upto-219.txt
    
    mysqlbinlog --start-datetime="2005-12-25 11:25:56" binlog.000003
    mysqlbinlog binlog.000001 | mysql -u root -p
    mysqlbinlog binlog.000001 binlog.000002 | mysql -u root -p





