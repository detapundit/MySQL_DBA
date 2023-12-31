
On '172.31.39.97'

    create user 'slave_user_1'@'172.31.38.45'  IDENTIFIED WITH 'mysql_native_password' by 'P@ssword1';
    grant replication slave on *.* to 'slave_user_1'@'172.31.38.45' ;

On '172.31.38.45'

    create user 'slave_user_2'@'172.31.39.97'  IDENTIFIED WITH 'mysql_native_password' by 'P@ssword1';
    grant replication slave on *.* to 'slave_user_2'@'192.168.201.94' ;


For '172.31.39.97' - Add in My.cnf & restart

    auto-increment-increment = 2
    auto-increment-offset = 1
    log_slave_updates = 1

Run below commands in Mysql '172.31.39.97'  ( Check file name and position of binlog in 172.31.38.45 with command "show master status;") 

    CHANGE MASTER TO MASTER_HOST='172.31.38.45', 
    master_port=3306,
    MASTER_USER='slave_user_2', 
    MASTER_PASSWORD='P@ssword1', 
    MASTER_LOG_FILE='binlog.000029', 
    MASTER_LOG_POS=880 ;


For '172.31.38.45' Add in My.cnf & restart

    auto-increment-increment = 2
    auto-increment-offset = 2
    log_slave_updates = 1

Run below commands in Mysql '172.31.38.45' ( Check file name and position of binlog in 172.31.39.97 with command "show master status;") 

    CHANGE MASTER TO MASTER_HOST='172.31.39.97', 
    master_port=3306,
    MASTER_USER='slave_user_1',
    MASTER_PASSWORD='P@ssword1', 
    MASTER_LOG_FILE='binlog.00002',
    MASTER_LOG_POS=710 ;
 
 
 On Server 1
 
    create table DBA_1( 
    DBA_ID bigint NOT NULL AUTO_INCREMENT,
    DBA_NAME varchar(200),
    Primary Key(DBA_ID));
 
    insert into DBA_1 (DBA_NAME) values('Test'),('Mysql');
