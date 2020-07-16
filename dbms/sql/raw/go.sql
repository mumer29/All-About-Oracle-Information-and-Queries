create table tq84_tab_with_long_raw (
   id  integer primary key,
   lr  long raw
);


declare
   cur  integer := dbms_sql.open_cursor;

   id   integer;
   lr   long raw;
begin

   dbms_sql.parse(
      cur,
     'insert into tq84_tab_with_long_raw values (:id, :lr)',
      dbms_sql.native
   );

-- id := 1;

   dbms_sql.bind_variable(cur, ':id', 1);
   dbms_sql.bind_variable(cur, ':lr', lr);
   dbms_output.put_line(dbms_sql.execute(cur));

   dbms_sql.bind_variable(cur, ':id', 2);
   dbms_output.put_line(dbms_sql.execute(cur));

   dbms_sql.close_cursor(cur);
end;
/

select * from tq84_tab_with_long_raw;

drop table tq84_tab_with_long_raw;

exit
