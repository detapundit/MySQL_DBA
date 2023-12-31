**Replication filters**

**Binary log filter**

    i) Binlog_do_db  - binlog_do_db=dbname
    
    ii) Binlog_ignore_db - binlog_ignore_db=dbname

**Replicate Filter**

    i) Replicate_do_db - replicate_do_db=dbname
    ii) Replicate_ignore_db - replicate_ignore_db=dbname
    iii) Replicate_do_table - replicate_do_table= dbname.tblname
    iv) Replicate_ignore_table - replicate_Ignore_Table= dbname.tblname
    v) Replicate_wild_do_table - replicate_wild_do_table= dbname.tblname%
    vi) Replicate_rewrite_db - replicate_rewrite_db=dbname->dbname_new




