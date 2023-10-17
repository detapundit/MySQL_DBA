# Replication setup requirements

Minimum 2 servers required. One will act as master and other will act as slave

# If setting up replication on freshly installed mysql servers with no existing data in Master

**Configuration required in Master MySQL my.cnf**

    Parameters to be added in my.cnf

    server-id=1
    log-bin=1  => By default it is enabled in Latest mysql versions


