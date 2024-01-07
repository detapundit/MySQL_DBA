MySQL Point-in-time recovery - How to restore a database to a specific time in the past.

Introduction to MySQL point-in-time recovery
The point-in-time recovery allows you to restore a MySQL database to a specific time in the past. The point-in-time recovery relies on two key components:

Full backup: This serves as the foundation for recovery, providing the starting state of the database.
Binary logs: These binary log files record all changes made to the database, allowing you to replay those changes to a desired point.
If you don’t have a full backup or binary logs enabled, you cannot carry the point-in-time recovery.

We’ll illustrate how to perform the point-in-time recovery in MySQL to recover a database to a specific point in time.


Connect to the MySQL Server:

    mysql -u root -p

Check if the binary log is enabled

    show global variables like 'log_bin';

    +---------------+-------+
    | Variable_name | Value |
    +---------------+-------+
    | log_bin       | ON    |
    +---------------+-------+
    1 row in set (0.01 sec)

After that, exit the mysql program:

Creating a new sample database & taking a full backup

    mysql -u root -p

    create a new database called appdb:
    
    CREATE DATABASE appdb;
    
    USE appdb;
    
    CREATE TABLE IF NOT EXISTS usr_details (
        id INT AUTO_INCREMENT PRIMARY KEY,
        first_name VARCHAR(255) NOT NULL,
        last_name VARCHAR(255) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL
    );

Insert three rows into the usr_details table:

    INSERT INTO usr_details (first_name, last_name, email) 
    VALUES
        ('Jones', 'Dow', 'jones.dow@example.com'),
        ('Janet', 'Smith', 'janet.smith@example.com'),
        ('Bob', 'John', 'bob.john@example.com');

Finally, take a full backup of the appdb database and store the dump file in the ~/backup/ directory:

    mysql -u root -p > ~/backup/appdb.sql

Making changes to the database
First, reconnect to the MySQL server:

    mysql -u root -p

Change the current database to appdb:

    USE appdb;

Insert a new row into the appdb database:

    INSERT INTO usr_details(first_name, last_name, email)
    VALUES('Bob','Tim', 'bob.tim@example.com');

Delete a record with the id 1 but forget to add a WHERE clause, hence, the statement deletes all rows from the usr_details table:

    DELETE FROM usr_details;

Since we delete all rows from the usr_details table unintentionally, we want to recover the usr_details table.

Show the current position of the binary log:

    SHOW MASTER STATUS;
    
    +---------------+----------+--------------+------------------+-------------------+
    | File          | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
    +---------------+----------+--------------+------------------+-------------------+
    | binlog.000001 |     4952 |              |                  |                   |
    +---------------+----------+--------------+------------------+-------------------+
    1 row in set (0.00 sec)

The current binary log file is binlog.000001.

Exit the mysql program:

    exit


Check the time when we delete all rows from the usr_details table in the binary log file using the mysqlbinlog utility program:

    mysqlbinlog  --verbose /var/lib/mysql/binlog.000001 | grep -i -C 10 "delete table"

The output looks like this:

--
    #231225 20:26:10 server id 1  end_log_pos 4921 CRC32 0x53432937         Delete_rows: table id 494 flags: STMT_END_F
    
    BINLOG '
    8oKJZRMBAAAARAAAAHISAAAAAO4BAAAAAAEABG15ZGIACGNvbnRhY3RzAAQDDw8PBvwD/AP8AwAB
    AQACA/z/ADxQW1A=
    8oKJZSABAAAAxwAAADkTAAAAAO4BAAAAAAEAAgAE/wABAAAABABKb2huAwBEb2UUAGpvaG4uZG9l
    QGV4YW1wbGUuY29tAAIAAAAEAEphbmUFAFNtaXRoFgBqYW5lLnNtaXRoQGV4YW1wbGUuY29tAAMA
    AAADAEJvYgcASm9obnNvbhcAYm9iLmpvaG5zb25AZXhhbXBsZS5jb20ABAAAAAMAQm9iBQBDbGlt
    bxUAYm9iLmNsaW1vQGV4YW1wbGUuY29tNylDUw==
    '/*!*/;
    ### DELETE FROM `appdb`.`usr_details`
    ### WHERE
    ###   @1=1
    ###   @2='John'
    ###   @3='Doe'
    ###   @4='john.doe@example.com'
    ### DELETE FROM `appdb`.`usr_details`
    ### WHERE
    ###   @1=2
    ###   @2='Jane'
    ###   @3='Smith'
    ###   @4='jane.smith@example.com'
    ### DELETE FROM `appdb`.`usr_details`
    ### WHERE
    ###   @1=3
    ###   @2='Bob'
    ###   @3='Johnson'
    ###   @4='bob.johnson@example.com'
    ### DELETE FROM `appdb`.`usr_details`
    ### WHERE
    ###   @1=4
    ###   @2='Bob'
    ###   @3='Climo'
    ###   @4='bob.climo@example.com'
    # at 4921
    #231225 20:26:10 server id 1  end_log_pos 4952 CRC32 0x634fce0a         Xid = 3194
    COMMIT/*!*/;
    SET @@SESSION.GTID_NEXT= 'AUTOMATIC' /* added by mysqlbinlog */ /*!*/;
    DELIMITER ;

The output shows that at 2023-12-25 20:26:10 we delete all rows from the usr_details table. Therefore, we need to recover the database up to 2023-12-25 20:26:10.

Performing a point-in-time recovery
Reconnect to the MySQL server:

    mysql -u root -p

Drop the appdb database and recreate it:

    DROP DATABASE appdb;
    CREATE DATABASE appdb;

Exit mysql program:

    exit

Restore the appdb database from the full backup:

    mysql -u root -p appdb < ~/backup/appdb.sql

Recover the rows from the usr_details table from the binary log file using the mysqlbinlog utility program:

    mysqlbinlog --stop-datetime="2023-12-25 20:26:10" --verbose /var/lib/mysql/binlog.000001 | mysql -u root -p 

This command reads the MySQL binary log file (/var/lib/mysql/binlog.000001), stopping at a specified datetime (2023-12-25 20:26:10), displays the contents with additional verbosity, and then pipes that output to the mysql command, which executes the SQL statements recorded in the binary log on a MySQL server, using the specified user (root) and prompting for a password.

Let’s breakd down the command:

    mysqlbinlog:
    mysqlbinlog is a command-line utility provided by MySQL for processing and displaying the contents of binary log files.
    --stop-datetime="2023-12-25 20:26:10": This option specifies a datetime value and mysqlbinlog will process the binary log until it reaches the specified datetime. In this case, it stops processing at December 25, 2023, 20:26:10.
    --verbose: This option causes mysqlbinlog to display additional information along with the actual log contents. It can be useful for debugging and understanding the log entries.
    /var/lib/mysql/binlog.000001: This is the path to the binary log file that mysqlbinlog will process.
    | (pipe):
    The pipe symbol (|) is used to redirect the output of the first command (mysqlbinlog) to the input of the second command (mysql).
    mysql:
    mysql is another command-line utility used to execute SQL statements based on the output of mysqlbinlog.
    -u root -p: These are options for specifying the MySQL user (root in this case) and prompting for a password (-p).

Connect to MySQL server:

    mysql -u root -p

    use appdb;

Finally, retrieve data from the usr_details table:

    SELECT * FROM usr_details;
    Output:
    
    
    +----+------------+-----------+-------------------------+
    | id | first_name | last_name | email                   |
    +----+------------+-----------+-------------------------+
    |  1 | John       | Doe       | john.doe@example.com    |
    |  2 | Jane       | Smith     | jane.smith@example.com  |
    |  3 | Bob        | Johnson   | bob.johnson@example.com |
    |  4 | Bob        | Climo     | bob.climo@example.com   |
    +----+------------+-----------+-------------------------+
    4 rows in set (0.00 sec)
