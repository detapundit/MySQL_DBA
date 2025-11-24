
  1. Take MySQL Backups

      mysqldump -u root -p --all-databases --single-transaction --routines --events > /backup/all_db_backup.sql
