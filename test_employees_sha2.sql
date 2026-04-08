--  Test employees database integrity using SHA-256 checksums
--  Uses SHA2() which is available on all MySQL versions (8.0+)
--  This test works on MySQL 9.6+ where md5() and sha() have been removed

USE employees;

SELECT 'TESTING INSTALLATION' as 'INFO';

DROP TABLE IF EXISTS expected_values, found_values;
CREATE TABLE expected_values (
    table_name varchar(30) not null primary key,
    recs int not null,
    crc_sha2 varchar(100) not null
);


CREATE TABLE found_values (LIKE expected_values);

-- Expected SHA-256 checksums (computed from the canonical data set)
INSERT INTO `expected_values` VALUES
('employees',   300024, 'PLACEHOLDER'),
('departments',      9, 'PLACEHOLDER'),
('dept_manager',    24, 'PLACEHOLDER'),
('dept_emp',    331603, 'PLACEHOLDER'),
('titles',      443308, 'PLACEHOLDER'),
('salaries',   2844047, 'PLACEHOLDER');
SELECT table_name, recs AS expected_records, crc_sha2 AS expected_crc FROM expected_values;

DROP TABLE IF EXISTS tchecksum;
CREATE TABLE tchecksum (chk char(100));

SET @crc= '';
INSERT INTO tchecksum
    SELECT @crc := SHA2(CONCAT_WS('#',@crc,
                emp_no,birth_date,first_name,last_name,gender,hire_date), 256)
    FROM employees ORDER BY emp_no;
INSERT INTO found_values VALUES ('employees', (SELECT COUNT(*) FROM employees), @crc);

SET @crc = '';
INSERT INTO tchecksum
    SELECT @crc := SHA2(CONCAT_WS('#',@crc, dept_no,dept_name), 256)
    FROM departments ORDER BY dept_no;
INSERT INTO found_values VALUES ('departments', (SELECT COUNT(*) FROM departments), @crc);

SET @crc = '';
INSERT INTO tchecksum
    SELECT @crc := SHA2(CONCAT_WS('#',@crc, dept_no,emp_no, from_date,to_date), 256)
    FROM dept_manager ORDER BY dept_no,emp_no;
INSERT INTO found_values VALUES ('dept_manager', (SELECT COUNT(*) FROM dept_manager), @crc);

SET @crc = '';
INSERT INTO tchecksum
    SELECT @crc := SHA2(CONCAT_WS('#',@crc, dept_no,emp_no, from_date,to_date), 256)
    FROM dept_emp ORDER BY dept_no,emp_no;
INSERT INTO found_values VALUES ('dept_emp', (SELECT COUNT(*) FROM dept_emp), @crc);

SET @crc = '';
INSERT INTO tchecksum
    SELECT @crc := SHA2(CONCAT_WS('#',@crc, emp_no, title, from_date,to_date), 256)
    FROM titles ORDER BY emp_no,title, from_date;
INSERT INTO found_values VALUES ('titles', (SELECT COUNT(*) FROM titles), @crc);

SET @crc = '';
INSERT INTO tchecksum
    SELECT @crc := SHA2(CONCAT_WS('#',@crc, emp_no, salary, from_date,to_date), 256)
    FROM salaries ORDER BY emp_no,from_date,to_date;
INSERT INTO found_values VALUES ('salaries', (SELECT COUNT(*) FROM salaries), @crc);

DROP TABLE tchecksum;

SELECT table_name, recs AS found_records, crc_sha2 AS found_crc FROM found_values;

SELECT
    e.table_name,
    IF(e.recs=f.recs,'OK', 'not ok') AS records_match,
    IF(e.crc_sha2=f.crc_sha2,'ok','not ok') AS crc_match
FROM
    expected_values e INNER JOIN found_values f USING (table_name);

SET @crc_fail=(SELECT COUNT(*) FROM expected_values e INNER JOIN found_values f ON (e.table_name=f.table_name) WHERE f.crc_sha2 != e.crc_sha2);
SET @count_fail=(SELECT COUNT(*) FROM expected_values e INNER JOIN found_values f ON (e.table_name=f.table_name) WHERE f.recs != e.recs);

SELECT 'CRC' AS summary, IF(@crc_fail = 0, "OK", "FAIL") AS `result`
UNION ALL
SELECT 'count', IF(@count_fail = 0, "OK", "FAIL") AS `count`;

DROP TABLE expected_values, found_values;
