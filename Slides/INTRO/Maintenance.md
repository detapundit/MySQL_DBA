**In this tutorial, you will learn how to use the MySQL CHECK TABLE statement to check one or more tables or views for errors.
**

Introduction to MySQL CHECK TABLE statement

The CHECK TABLE statement allows you to check one or more tables for errors.

The following shows the syntax of the CHECK TABLE statement:

CHECK TABLE tbl_name, [,table_name]...

MySQL CHECK TABLE statement examples
Let’s take some examples of using the CHECK TABLE statement.

1) Using the CHECK TABLE to check for errors in tables
First, log in to the MySQL database server using the root account:
  
       mysql -u root -p

Code language: SQL (Structured Query Language) (sql)
It’ll prompt you to enter the password. Enter the valid password to log in:


    use classicmodels;

    CHECK TABLE customers, products;

Output:

    +-------------------------+-------+----------+----------+
    | Table                   | Op    | Msg_type | Msg_text |
    +-------------------------+-------+----------+----------+
    | classicmodels.customers | check | status   | OK       |
    | classicmodels.products  | check | status   | OK       |
    +-------------------------+-------+----------+----------+
    2 rows in set (0.03 sec)

2) Using the MySQL CHECK TABLE to check for errors in a view
First, create a database called test:

        CREATE DATABASE IF NOT EXISTS test;
        Code language: SQL (Structured Query Language) (sql)
        Second, switch to the test database:
        
        USE test;
        Code language: PHP (php)
        Third, create a table called employees in the test database:
        
        CREATE TABLE employees(
          id INT AUTO_INCREMENT PRIMARY KEY, 
          first_name VARCHAR(255) NOT NULL, 
          last_name VARCHAR(255) NOT NULL, 
          email VARCHAR(255) NOT NULL, 
          phone VARCHAR(255) NOT NULL
        );
        Code language: SQL (Structured Query Language) (sql)
        Fourth, create a view called contacts based on the employees table:
        
        CREATE VIEW contacts AS 
        SELECT 
          concat_ws(' ', first_name, last_name) as name, 
          email, 
          phone 
        FROM 
          employees;
        Code language: SQL (Structured Query Language) (sql)
        Fifth, drop the table employees:
        
        DROP TABLE employees;
        Code language: SQL (Structured Query Language) (sql)
        Finally, check the view contacts for the error:
        
        CHECK TABLE contacts\G;
        Code language: SQL (Structured Query Language) (sql)
        Output:
        
        *************************** 1. row ***************************
           Table: test.contacts
              Op: check
        Msg_type: Error
        Msg_text: View 'test.contacts' references invalid table(s) or column(s) or function(s) or definer/invoker of view lack rights to use them
        *************************** 2. row ***************************
           Table: test.contacts
              Op: check
        Msg_type: error
        Msg_text: Corrupt
        2 rows in set (0.00 sec)
        
        ERROR:
        No query specified
        Code language: SQL (Structured Query Language) (sql)
        Note that the \G instructs mysql to display the result in a more readable, vertical format rather than a traditional horizontal, table-based layout.

The first row indicates that the view references an invalid table and the second row specifies that the view is corrupt.


###########################################################

Introduction to MySQL ANALYZE TABLE statement

In MySQL, the query optimizer relies on table statistics to optimize query execution plans.

The table statistics help the query optimizer estimate the number of rows in a table that satisfy a particular condition.

However, sometimes the table statistics can be inaccurate. For example, after you have done a lot of data changes in the table such as inserting, deleting, or updating.

If the table statistics are not accurate, the query optimizer may pick a non-optimal query execution plan that may cause a severe performance issue.

To address this issue, MySQL provides the ANALYZE TABLE statement that updates these statistics, ensuring that the query optimizer has accurate information for efficient query planning.

The following ANALYZE TABLE statement performs a key distribution analysis:

ANALYZE TABLE table_name [, table_name];
Code language: SQL (Structured Query Language) (sql)
In this syntax:

table_name: The name of the table that you want to analyze. If you want to analyze multiple tables, you separate them by commas.
This key distribution analysis is essential for understanding the distribution of key values within the table. The query optimizer uses the results of this statement to optimize join operations and index usage.

The ANANLYZE TABLE statement works only with InnoDB, NDB, and MyISAM tables.

MySQL ANALYZE TABLE statement example
We’ll use the table from the sample database for the demonstration.

First, log in to the MySQL Server using the root account:

      mysql -u root -p
Code language: SQL (Structured Query Language) (sql)
It’ll prompt you to enter a password for the root account.

Second, switch the current database to classicmodels:

    use classicmodels;
Code language: SQL (Structured Query Language) (sql)
Third, analyze the customers table:

    analyze table customers;
Code language: SQL (Structured Query Language) (sql)
Output:

    +-------------------------+---------+----------+----------+
    | Table                   | Op      | Msg_type | Msg_text |
    +-------------------------+---------+----------+----------+
    | classicmodels.customers | analyze | status   | OK       |
    +-------------------------+---------+----------+----------+
    1 row in set (0.01 sec)
Code language: SQL (Structured Query Language) (sql)
The output table has the following columns:

Table: The table name that was analyzed.
op: analyze or histogram.
Msg_type: show the message type including status, error, info, note, or warning.
Msg_text: an informational message.
Summary
Use the MySQL ANALYZE TABLE statement to ensure that the query optimizer has accurate and up-to-date table statistics, allowing it to generate optimal query execution plans.

##########################################################


Introduction to MySQL REPAIR TABLE statement
During operation, your tables may be corrupted due to various reasons, such as hardware failures, unexpected shutdowns, or software bugs.

To repair the possibly corrupted tables, you use the REPAIR TABLE statement. The REPAIR TABLE statement can repair only tables that use MyISAM, ARCHIVE, or CSV storage engines.

Here’s the syntax of the REPAIR TABLE statement:

REPAIR TABLE table_name [, table_name] ... 
[QUICK] [EXTENDED] [USE_FRM];
Code language: SQL (Structured Query Language) (sql)
In this syntax:

table_name: The name of the table you want to repair. The statement allows you to repair multiple tables at once.
QUICK: This is the default option that allows you to perform a quick repair. It is suitable for most cases.
EXTENDED: This option allows you to perform an extended repair. It may take longer however can fix more complex issues.
USE_FRM: This option re-creates the .frm file. It’ll help when the table definition file is corrupted.
MySQL REPAIR TABLE statement examples
Let’s take some examples of using the REPAIR TABLE statement.

The following command performs a quick repair on the sample_table table:

REPAIR TABLE sample_table;
Code language: SQL (Structured Query Language) (sql)
It’s equivalent to the following statement that uses the QUICK option explicitly:

    REPAIR TABLE sample_table QUICK;
Code language: SQL (Structured Query Language) (sql)
The following command performs an extended repair on the sample_table table:

    REPAIR TABLE sample_table EXTENDED;
Code language: SQL (Structured Query Language) (sql)
When you find that the table definition file (.frm) is suspected to be corrupted, you can use the USE_FRM option to recreate it:

    REPAIR TABLE sample_table USE_FRM;
Code language: SQL (Structured Query Language) (sql)
Important notes on using the REPAIR TABLE statement
When using the REPAIR TABLE statement, you should consider the following important notes:

Making a backup before repairing tables
It’s important to make a backup of a table before you repair it. In some cases, the REPAIR TABLE statement may cause data loss.

Table lock
The REPAIR TABLE statement requires a table lock during the repair process. If you issue queries to the table, they will blocked until the repair is complete.

Storage Engines
The REPAIR TABLE statement only works with MyISAM, CSV, and ARCHIVE tables. It doesn’t support tables of other storage engines.

Replication
If they run the REPAIR TABLE for the original tables, the fixes will not propagate to replicas.

Summary
Use the REPAIR TABLE statement to repair possibly corrupted tables.

######################################################

Introduction to MySQL OPTIMIZE TABLE statement
The OPTIMIZE TABLE statement allows you to reorganize the physical storage of table data 
to reclaim unused storage space and improve performance when accessing the table.

In practice, you’ll find the OPTIMIZE TABLE statement useful in the following cases:

Frequent deletions/updates: If a table has frequent updates or deletions, its data may be fragmented. The OPTIMIZE TABLE statement can help rearrange the storage structure and eliminate wasted space.
Table with variable-length rows: Tables with variable-length data such as VARCHAR, TEXT, and BLOB may become fragmented over time. By using the OPTIMIZE TABLE statement, you can reduce the storage overhead.
Significant data growth and shrinkage: If your database experiences significant growth & shrinkage, you can run the OPTIMIZE TABLE periodically to maintain optimal storage efficiency.
Overall, using the OPTIMIZE TABLE statement helps you optimize the storage space of table data and improve the query performance.

The OPTIMIZE TABLE statement works with InnoDB, MyISAM, and ARCHIVE tables.

MySQL OPTIMIZE TABLE statement examples
Let’s take some examples of using the MySQL OPTIMIZE TABLE statement.

1) Using the MySQL OPTIMIZE TABLE statement for MyISAM tables
For MyISAM tables, the OPTIMIZE TABLE statement works as follows:

Repair the table if it has deleted or split rows.
Sort the index pages if they are not sorted.
Update the table statistics if they are not up to date.
The following example illustrates the steps for optimizing a MyISAM table:

First, check the table status using the show table status statement:

    SHOW TABLE STATUS LIKE '<table_name>'\G
Code language: SQL (Structured Query Language) (sql)
It’ll return the output like this:

    *************************** 1. row ***************************
               Name: <table_name>
             Engine: MyISAM
            Version: 10
         Row_format: Dynamic
               Rows: 5000
     Avg_row_length: 44
        Data_length: 440000
    Max_data_length: 281474976710655
       Index_length: 105472
          Data_free: 220000
     Auto_increment: 10001
        Create_time: 2023-11-21 07:34:39
        Update_time: 2023-11-21 07:38:43
         Check_time: NULL
          Collation: utf8mb4_0900_ai_ci
           Checksum: NULL
     Create_options:
            Comment:
    1 row in set (0.00 sec)
Code language: SQL (Structured Query Language) (sql)
There are two important columns in the output regarding optimizing the table:

The Data_length represents the space used by all rows in the table including any overhead as row headers.
The Data_free is the amount of free space (in bytes) in the data file. It indicates how much space can potentially be reclaimed by the OPTIMIZE TABLE statement.
Second, optimize the table using the OPTIMIZE TABLE statement:

    OPTIMIZE TABLE <table_name>;
Code language: SQL (Structured Query Language) (sql)
Output:

    +----------------+----------+----------+----------+
    | Table          | Op       | Msg_type | Msg_text |
    +----------------+----------+----------+----------+
    | test.text_data | optimize | status   | OK       |
    +----------------+----------+----------+----------+
    1 row in set (0.05 sec)
Code language: SQL (Structured Query Language) (sql)
The Msg_text is OK which indicates the optimization is successful.

Third, check the status of the table again:

    SHOW TABLE STATUS LIKE '<table_name>'\G
Code language: SQL (Structured Query Language) (sql)
If the table space is fragmented, you’ll see Data_free is zero:

    *************************** 1. row ***************************
               Name: <table_name>
             Engine: MyISAM
            Version: 10
         Row_format: Dynamic
               Rows: 5000
     Avg_row_length: 44
        Data_length: 440000
    Max_data_length: 281474976710655
       Index_length: 105472
          Data_free: 0
     Auto_increment: 10001
        Create_time: 2023-11-21 08:03:12
        Update_time: 2023-11-21 08:03:41
         Check_time: NULL
          Collation: utf8mb4_0900_ai_ci
           Checksum: NULL
     Create_options:
            Comment:
    1 row in set (0.00 sec)
Code language: SQL (Structured Query Language) (sql)
2) Using the MySQL OPTIMIZE TABLE statement for InnoDB tables
When you run the OPTIMIZE TABLE statement on InnoDB tables, you’ll get the following output:

    +--------+----------+----------+-------------------------------------------------------------------+
    | Table  | Op       | Msg_type | Msg_text                                                          |
    +--------+----------+----------+-------------------------------------------------------------------+
    | test.t | optimize | note     | Table does not support optimize, doing recreate + analyze instead |
    | test.t | optimize | status   | OK                                                                |
    +--------+----------+----------+-------------------------------------------------------------------+
    2 rows in set (0.05 sec)
Code language: SQL (Structured Query Language) (sql)
The first message:

Table does not support optimize, doing recreate + analyze instead
Code language: SQL (Structured Query Language) (sql)
It means that the OPTIMIZE TABLE does not optimize the InnoDB tables in the same way it optimizes the MyISAM tables. Instead, the OPTIMIZE TABLE statement performs the following actions:

First, create a new empty table.
Second, copy all rows from the original table into the new table.
Third, delete the original table and rename the new tables.
Finally, run the ANALYZE statement to gather table statistics.
One caution is that you should avoid running the OPTIMIZE TABLE statement on a large InnoDB table when the disk space is low, as it is likely to cause the server to run out of space while attempting to recreate the large table.

Summary
Use the OPTIMIZE TABLE statement to reorganize the physical storage of tables to reduce disk space usage and improve query execution time.

##########################################################

