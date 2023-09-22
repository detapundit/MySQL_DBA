# MAnual installation for RHEL based systems

# 1. wget https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.34-1.el7.x86_64.rpm-bundle.tar

# 2. Untar the bundle
       tar -xvf mysql-8.0.34-1.el7.x86_64.rpm-bundle.tar
       ls -lt

# 3. Install below packages one by one using below command:

    rpm -ivh package name  <= If any errors comes for dependent package, install it via yum

# Sequence:

       mysql-community-common-8.0.34-1.el7.x86_64.rpm
       mysql-community-client-plugins-8.0.34-1.el7.x86_64.rpm
       mysql-community-libs-8.0.34-1.el7.x86_64.rpm
       mysql-community-libs-compat-8.0.34-1.el7.x86_64.rpm
       mysql-community-test-8.0.34-1.el7.x86_64.rpm
       mysql-community-icu-data-files-8.0.34-1.el7.x86_64.rpm
       mysql-community-server-8.0.34-1.el7.x86_64.rpm
       mysql-community-client-8.0.34-1.el7.x86_64.rpm


