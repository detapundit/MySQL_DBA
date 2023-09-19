# Some basic SQL operations

1. Create a database
     create database database_name;

2. Select a database
     show databases;
     use database_name;

3. Display list of tables inside a database
     use database_name
     show tables;

4. Check/View the structure of a table
     show create table table_name;
     desc table_name;

5. Find what is the primary key for a table
     show create table table_name;
   
6. Create a table with primary key
     | employees | CREATE TABLE `employees` (
      `emp_no` int NOT NULL,
      `birth_date` date NOT NULL,
      `first_name` varchar(14) NOT NULL,
      `last_name` varchar(16) NOT NULL,
      `gender` enum('M','F') NOT NULL,
      `hire_date` date NOT NULL,
      PRIMARY KEY (`emp_no`)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci |

7. Column with a Unique key
     | departments | CREATE TABLE `departments` (
      `dept_no` char(4) NOT NULL,
      `dept_name` varchar(40) NOT NULL,
       PRIMARY KEY (`dept_no`),
       UNIQUE KEY `dept_name` (`dept_name`)
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci |

9. Column with a Foreign key
      | salaries | CREATE TABLE `salaries` (
        `emp_no` int NOT NULL,
        `salary` int NOT NULL,
        `from_date` date NOT NULL,
        `to_date` date NOT NULL,
        PRIMARY KEY (`emp_no`,`from_date`),
        CONSTRAINT `salaries_ibfk_1` FOREIGN KEY (`emp_no`) REFERENCES `employees` (`emp_no`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci |

10. Indexed column
      | employees | CREATE TABLE `employees` (
        `emp_no` int NOT NULL,
        `birth_date` date NOT NULL,
        `first_name` varchar(14) NOT NULL,
        `last_name` varchar(16) NOT NULL,
        `gender` enum('M','F') NOT NULL,
        `hire_date` date NOT NULL,
        PRIMARY KEY (`emp_no`),
        **KEY `idx_fname` (`first_name`)**
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci |

