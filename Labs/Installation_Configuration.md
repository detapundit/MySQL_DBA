#This document will cover installation steps for Redhat/Amazon linux

# Prerequisites for lab practicals

#  1. Putty or MobaXterm for connecting to lab
      Putty download link for windows machine: https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.79-installer.msi
      MobaXterm link: https://download.mobatek.net/2322023060714555/MobaXterm_Installer_v23.2.zip

###############################################################################################################################################

A. Before installing any package, we must gather few details of OS, so that we can install the correct package.

    1. Find OS type : Windows/Linux
    2. OS Version :
            In Linux/Unix you can check type of OS by running below commands:
            a. cat /etc/os-release or cat /etc/redhat-release
            b. hostnamectl

B. Find out which Mysql version needs to be installed - MySQL 5.7/8.0 ?

C. Find disk space details to identify data directory location for mysql.
            Command to identify disk space utilization:
            
            df -h

D. Once these details are gathered, we can proceed with next steps.

###############################################################################################################################################

We can install MySQL by using Repo or Manual RPM installation or Binary installation

MySQL REPO based installation:

What is repo? A repository is a location from where the Linux system retrieves and installs updates and applications related to the Operating system or any desired application.

Command to check existing repos in the OS:
      
      # ll /etc/yum.repos.d/
      total 8
      -rw-r--r-- 1 root root 1003 Oct 26  2021 amzn2-core.repo
      -rw-r--r-- 1 root root 2150 Sep  6 18:19 amzn2-extras.repo

Above you can see 2 repos for an AWS Linux OS. These 2 repos are used by AWS Linux to update OS packages and to install OS related packages.

Similarly, we will be adding a repo for MySQL as well, so that we can install the desired version along with necessary dependent packages.

# STEPS TO ADD MYSQL REPO

# MySQL Repo link for Amazon Linux 2 image
      https://dev.mysql.com/get/mysql80-community-release-el7-10.noarch.rpm

1. Login to server where we need to install MySQL

2. Check if any mysql process is already running

         ps -ef|grep mysql

4. Check if mysql is already installed

         rpm -qa|grep -i mysql

6. Download the MySQL repo file from below link based on OS and MySQL version
      https://dev.mysql.com/downloads/repo/yum/

         wget download_link_of_repo_file

8. Install the repo

         yum install repo_file_name

10. Verify the repo file

          ls /etc/yum.repos.d
          cat /etc/yum.repos.d/file_name.repo    <= Mention Mysql repo file here

12. Install MySQL

          yum install mysql-community-server*

14. If installation is successful, then start mysql service.

          systemctl start mysqld

16. Verify if process is up and running

          systemctl status mysqld

          ps -ef|grep mysql

          netstat -tnlp

18. First time login to mysql. Get temporary root password from mysql log file

          cat /var/log/mysqld.log |grep 'temporary'   <= Copy the root password
          mysql -uroot -p  <= Press enter, it will prompt for password. Enter/Paste the password copied in above command

20. Once logged in, first command will be to change the root password. It will not allow to run any other command unless you change the password.

          ALTER USER 'root'@'localhost' IDENTIFIED BY 'Password$1';

22. Exit from mysql prompt and login again as root with new password.

          mysql -uroot -p  <= Press enter, it will prompt for password. Enter/Paste new password that was created in previous step.
      






