**How to use local in file **

    LOAD DATA INFILE 'data.txt' INTO TABLE appdb.my_table;  => secure_file_priv variable decides the path where you can keep data to load
                                                            => LOAD DATA LOCAL INFILE is used if loading from client host

    mysql> show variables like '%local%';
    +---------------+-------+
    | Variable_name | Value |
    +---------------+-------+
    | local_infile  | OFF   |
    +---------------+-------+
    1 row in set (0.00 sec)

**How to use OUTFILE**

    select * into OUTFILE '/var/lib/mysql-files/dept.txt' from departments;

**How to use SOURCE command**

      source /root/create.sql ;




  
