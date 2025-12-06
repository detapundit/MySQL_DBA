    mysqlbinlog mysql-bin.000001
    
    mysqlbinlog --start-position=120 mysql-bin.000001
    
    mysqlbinlog --start-position=120 --stop-position=1024 mysql-bin.000001
    
    mysqlbinlog --start-datetime="2025-06-04 10:00:00" mysql-bin.000001
    
    mysqlbinlog --start-datetime="2025-06-04 10:00:00" --stop-datetime="2025-06-04 11:00:00" mysql-bin.000001
    
    mysqlbinlog --database=mydb mysql-bin.000001
    
    mysqlbinlog --verbose --base64-output=DECODE-ROWS mysql-bin.000001
    
    mysqlbinlog --read-from-remote-server --host=127.0.0.1 --user=replica --password --raw --stop-never mysql-bin.000001
    
    mysqlbinlog --raw --result-file=./ mysql-bin.000001
    
    mysqlbinlog mysql-bin.000001 | mysql -u root -p
