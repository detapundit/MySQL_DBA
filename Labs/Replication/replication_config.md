# Replication setup requirements

Minimum 2 servers required. One will act as master and other will act as slave

# If setting up replication on freshly installed mysql servers with already existing data in Master

**Configuration required in Master MySQL my.cnf. Restart if adding or making any changes in my.cnf**

    Parameters to be added in my.cnf

    server-id=1
    log-bin=1  => By default it is enabled in Latest mysql versions
    

**Configuration required in Slave MySQL my.cnf**

    server-id=2

**We need to create a user in Master mysql so that Slave mysql can connect to master and read binary logs details**

    CREATE USER 'replica_user'@'slave_IP' IDENTIFIED by 'Password$1';
    GRANT REPLICATION SLAVE ON *.* TO 'replica_user'@'slave_ip';
    FLUSH PRIVILEGES;

**Take full database dump from master and transfer dump file to slave server**

    mysqldump -uroot -p --all-databases --source-data > /alldb.sql
    scp /alldb.sql root@slaveip:/root

**Restore the dump in slave server**

    mysql -uroot -p < /alldb.sql

**Once restore is completed, configure replication**

    CHANGE REPLICATION SOURCE TO
    SOURCE_HOST='master_ip',
    SOURCE_USER='replica_user',
    SOURCE_PASSWORD='Password$1',
    SOURCE_LOG_FILE='mysql-bin.000001',   => Get file name from dump file
    SOURCE_LOG_POS=899;    => Get position from dump file

**Start replication from slave**

    START REPLICA; OR start slave;

**Check replication status**

    SHOW REPLICA STATUS\G OR Show slave status\G





