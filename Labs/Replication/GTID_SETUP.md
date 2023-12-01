**GTID SETUP**

MySQL GTIDs stands for global transaction identifier (GTID) which uniquely identifies a transaction committed on the server of origin (master). A unique MySQL GTIDs is created when any transaction occurs. MySQL GTIDs are displayed as a pair of coordinates, separated by a colon character (:)

    GTID = source_id:transaction_id

The source_id is generally the server_uuid of the server and the transaction_id is the sequence number on which the transaction is committed. 

    3E11FA47-71CA-11E1-9E33-C80AA9429562:23

**SETUP**

Synchronize both servers by setting them to read-only if the replication is running already by using the following command:

    mysql> SET @@GLOBAL.read_only = ON;

Step 2: Stopping Master & Slave Server

    sudo service mysqld stop

    #my.cnf in master
    server-id = 1
    log-bin = mysql-bin
    binlog_format = row
    gtid-mode=ON
    enforce-gtid-consistency
    log-slave-updates

    sudo service mysqld start

    create user 'repl_user'@'%' identified by 'XXXXXXXXXX';
    Grant replication slave on *.* to 'repl_user'@'%';

    mysql> show master status ;

    mysql> show global variables like 'gtid_executed';

    mysqldump --all-databases -flush-privileges --single-transaction --flush-logs --triggers --routines --events -hex-blob --      host=54.89.xx.xx --port=3306 --user=root  --password=XXXXXXXX > mysqlbackup_dump.sql

    server-id = 2
    log-bin = mysql-bin
    relay-log = relay-log-server
    relay-log = relay-log-server
    read-only = ON
    gtid-mode=ON
    enforce-gtid-consistency
    log-slave-updates

    sudo service mysqld start

    mysql> show global variables like 'gtid_executed';

    mysql> source mysqlbackup_dump.sql ;
    mysql> show global variables like 'gtid_executed';

    CHANGE MASTER TO
    MASTER_HOST = '54.89.xx.xx',
    MASTER_PORT = 3306,
    MASTER_USER = 'repl_user',
    MASTER_PASSWORD = 'XXXXXXXXX',
    MASTER_AUTO_POSITION = 1;

    start slave;

    mysql> show slave status\G

    mysql> SET @@GLOBAL.read_only = OFF;
