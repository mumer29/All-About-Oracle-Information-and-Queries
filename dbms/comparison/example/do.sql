CREATE TABLE departments_1 (
   id_department NUMBER CONSTRAINT pk_department_1 PRIMARY KEY,
   name_department VARCHAR2(50)
);

CREATE TABLE departments_2 (
   id_department NUMBER CONSTRAINT pk_department PRIMARY KEY,
   name_department VARCHAR2(50)
);

CREATE TABLE employees_1 (
   id_employees NUMBER CONSTRAINT pk_employees_1 PRIMARY KEY,
   id_department NUMBER,
   name_employees VARCHAR2(50)
);


CREATE TABLE employees_2 (
   id_employees NUMBER CONSTRAINT pk_employees PRIMARY KEY,
   id_department NUMBER,
   name_employees VARCHAR2(50)
);


INSERT INTO departments_1 VALUES (1001,'Executive');
INSERT INTO departments_1 VALUES (1002,'Accounting');
INSERT INTO departments_1 VALUES (3001,'Finance');
INSERT INTO departments_1 VALUES (3002,'Treasury');
INSERT INTO departments_1 VALUES (4001,'Shipping');
INSERT INTO departments_1 VALUES (4002,'Public Relations');

INSERT INTO employees_1 VALUES (1001,1001,'Hermann OConnell');
INSERT INTO employees_1 VALUES (1002,1002,'Shelley Grant');
INSERT INTO employees_1 VALUES (3001,3001,'Neena Kochhar');
INSERT INTO employees_1 VALUES (3002,3002,'Lex De Haan');
INSERT INTO employees_1 VALUES (4001,4001,'Pat Fay');
INSERT INTO employees_1 VALUES (4002,4002,'Susan Mavris');

INSERT INTO departments_2 VALUES (1001,'Administration');
INSERT INTO departments_2 VALUES (1002,'Marketing');
INSERT INTO departments_2 VALUES (2001,'Purchasing');
INSERT INTO departments_2 VALUES (2002,'Human Resources');
INSERT INTO departments_2 VALUES (4001,'Shipping');
INSERT INTO departments_2 VALUES (4002,'Public Relations');
 
 
INSERT INTO employees_2 VALUES (1001,1001,'Donald OConnell');
INSERT INTO employees_2 VALUES (1002,1002,'Douglas Grant');
INSERT INTO employees_2 VALUES (2001,2001,'Jennifer Whalen');
INSERT INTO employees_2 VALUES (2002,2002,'Michael Hartstein');
INSERT INTO employees_2 VALUES (4001,4001,'Pat Fay');
INSERT INTO employees_2 VALUES (4002,4002,'Susan Mavris');
 
COMMIT;
/


BEGIN
   DBMS_COMPARISON.CREATE_COMPARISON (
      comparison_name => 'compare_departments',
      schema_name     =>  user,
      object_name     => 'DEPARTMENTS_1',
      dblink_name     =>  null,
      remote_schema_name => user,
    remote_object_name => 'departments_2'
   );
END;
/

DECLARE
   consistent BOOLEAN;
   scan_info DBMS_COMPARISON.COMPARISON_TYPE;
BEGIN
   consistent := DBMS_COMPARISON.COMPARE
                 (
                    comparison_name  => 'compare_departments',
                    scan_info        => scan_info,
                    perform_row_dif  => TRUE
                 );
   DBMS_OUTPUT.PUT_LINE('Scan ID: '||scan_info.scan_id);
   IF consistent=TRUE THEN
      DBMS_OUTPUT.PUT_LINE('No differences were found.');
   ELSE
      DBMS_OUTPUT.PUT_LINE('Differences were found.');
   END IF;
END;
/

select
   c.OWNER AS COMPARISON_OWNER,
   c.COMPARISON_NAME,
   c.SCHEMA_NAME,
   c.OBJECT_NAME,
   s.CURRENT_DIF_COUNT AS DIFFERENCES
FROM DBA_COMPARISON c
   INNER JOIN DBA_COMPARISON_SCAN s
      ON c.COMPARISON_NAME = s.COMPARISON_NAME
         AND c.OWNER = s.OWNER
WHERE
   s.SCAN_ID = 21  -- CHANGE HERE
;

select
   c.COLUMN_NAME AS IndexColumn,
   r.INDEX_VALUE AS IndexValue,
   DECODE(r.LOCAL_ROWID ,NULL,'-' ,'+') AS LocalRowExists,
   DECODE(r.REMOTE_ROWID,NULL, '-','+') AS RemoteRowExists
FROM DBA_COMPARISON_COLUMNS c
   INNER JOIN DBA_COMPARISON_ROW_DIF r
      ON c.COMPARISON_NAME = r.COMPARISON_NAME
         AND c.OWNER = r.OWNER
   INNER JOIN DBA_COMPARISON_SCAN s
      ON r.SCAN_ID = s.SCAN_ID
WHERE
   c.COMPARISON_NAME = 'compare_departments' AND
   s.PARENT_SCAN_ID =  21 AND                       -- Change here
   r.STATUS         = 'DIF' AND
   c.INDEX_COLUMN = '  Y' AND
ORDER BY
   r.INDEX_VALUE;



select
   c.COLUMN_NAME AS IndexColumn,
   r.INDEX_VALUE AS IndexValue,
   DECODE(r.LOCAL_ROWID ,NULL,'-' ,'+') AS LocalRowExists,
   DECODE(r.REMOTE_ROWID,NULL, '-','+') AS RemoteRowExists,
   r.local_rowid,
   r.remote_rowid,
   r.last_update_time,
   c.*
FROM DBA_COMPARISON_COLUMNS c   INNER JOIN
    DBA_COMPARISON_ROW_DIF r      ON c.COMPARISON_NAME = r.COMPARISON_NAME         AND
                                     c.OWNER = r.OWNER    INNER JOIN
   DBA_COMPARISON_SCAN s         ON r.SCAN_ID = s.SCAN_ID
WHERE
   c.COMPARISON_NAME = 'COMPARE_DEPARTMENTS' AND
   s.PARENT_SCAN_ID =  21 AND                       -- Change here
   r.STATUS         = 'DIF'
   --- c.INDEX_COLUMN = 'Y' 
ORDER BY
   r.INDEX_VALUE;


exec dbms_comparison.drop_comparison('compare_departments');
drop table departments_2 purge;
drop table employees_2   purge;
drop table departments_1 purge;
drop table employees_1   purge;
