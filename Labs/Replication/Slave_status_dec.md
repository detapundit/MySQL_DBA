# SHOW SLAVE STATUS DESCRIPTION

    Replica_IO_State: Waiting for source to send event    => State of IO thread 
                  Source_Host: 172.31.7.234               => Master IP
                  Source_User: replica_user               => User used by slave to connect to master
                  Source_Port: 3306                       => Port at which master is running
                Connect_Retry: 60                         => Secs - If failed to connect
              Source_Log_File: binlog.000026              => Master binlog file which IO thread is reading
          Read_Source_Log_Pos: 157                        => Master binlog file postion
               Relay_Log_File: ip-172-31-45-247-relay-bin.000005    => Slave relay binlog file which SQL thread refers
                Relay_Log_Pos: 367                            => Slave relay binlog file position which SQL thread refers
        Relay_Source_Log_File: binlog.000026                   => Name of the primary binary log file that contains the most recent                                                                         event executed by the SQL thread.
           Replica_IO_Running: Yes                  => IO_THREAD Status
                        
          Replica_SQL_Running: Yes                  => SQL_THREAD Status
       
                   Last_Errno: 0                => Error# for replication issue
                   Last_Error:                  => Error description
        
          Exec_Source_Log_Pos: 157            => Position till which SQL thread has completed
              Relay_Log_Space: 754

        Seconds_Behind_Source: 0               => How many secs behind master

                Last_IO_Errno: 0                => Error for IO/SQL thread
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 

        Replica_SQL_Running_State:       => SQL Thread state
          
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
     
