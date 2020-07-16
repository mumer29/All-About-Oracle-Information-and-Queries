create table tq84_long_raw_test (
   id            integer,
   long_raw_     long raw
);

create table tq84_long_test (
   id            integer,
   long_         long
);

   insert into tq84_long_raw_test values (1, 'abcdef');
-- insert into tq84_long_raw_test values (2, 'ghijkl') -- invalid hex number;
   insert into tq84_long_raw_test values (3, hextoraw('fedcba'));


   insert into tq84_long_test     values (1, 'abcdef');
   insert into tq84_long_test     values (2, 'ghijkl');
   insert into tq84_long_test     values (3, hextoraw('fedcba'));


   set long 80

   select * from tq84_long_raw_test;
   select * from tq84_long_test;

--
-- LONG columns cannot appear in SQL-built in functions, expressions or conditions:
--
-- select id, rawtohex(long_raw_) from tq84_long_raw_test -- ORA-00997: illegal use of LONG datatype;
-- select id, rawtohex(long_    ) from tq84_long_test     -- ORA-00997: illegal use of LONG datatype;

   
-- select id, to_lob(long_raw_) from tq84_long_raw_test -- ORA-00932: inconsistent datatypes: expected - got LONG;
-- select id, to_lob(long_    ) from tq84_long_test     -- ORA-00932: inconsistent datatypes: expected - got LONG;

create table tq84_long_raw_to_lob_test as select id, to_lob(long_raw_) as long_raw_ from tq84_long_raw_test;
create table tq84_long_to_lob_test     as select id, to_lob(long_    ) as long_raw_ from tq84_long_test;

desc tq84_long_raw_to_lob_test;
desc tq84_long_to_lob_test;

select * from tq84_long_raw_to_lob_test;
select * from tq84_long_to_lob_test;


drop table tq84_long_raw_test;
drop table tq84_long_test;
drop table tq84_long_raw_to_lob_test;
drop table tq84_long_to_lob_test;
