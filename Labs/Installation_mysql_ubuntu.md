# Ubuntu 22.04 LTS MySQL installation

1. Download MySQL APT repository
        wget https://dev.mysql.com/get/mysql-apt-config_0.8.26-1_all.deb

2. Install the repository
        dpkg -i mysql-apt-config_0.8.26-1_all.deb   <= As per file name downloaded in previous step

3. apt-get update

4. apt-get install mysql-server

5. Setup the root password for mysql when it prompts

6. Login to mysql with root user name and password set in previous step
