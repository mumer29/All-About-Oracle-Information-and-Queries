
select * from database_properties;

select * from v_$kccfe;

select
  max(st         ) st,
      name         name,
  max(type_      ) type_,
  max(description) description
from (
  select 'OK'       st, name         , null type_, description                                      from v$parameter          union all
  select 'Obsolete' st, name         , null type_, null                                             from v$obsolete_parameter union all
  select '?'        st, name         , type type_, null                                             from v$spparameter        union all
  select '?'        st,'_fix_control', null type_,'See v$session_fix_control, v$system_fix_control' from dual
)
group by
  name
order by
  replace(lower(name), '_','')
;

select * from obj$ where name = 'X$BH';

select owner, object_type from dba_objects where object_name = 'V$FIXED_TABLE';
--
-- PUBLIC SYNONYM

select table_owner, table_name from dba_synonyms where synonym_name = 'V$FIXED_TABLE' and owner = 'PUBLIC';
--
-- SYS v_$FIXED_TABLE

select owner, object_type from dba_objects where object_name = 'V_$FIXED_TABLE' and owner = 'SYS';
--
-- SYS VIEW

select text from dba_views where view_name = 'V_$FIXED_TABLE' and owner = 'SYS';
--
-- select "NAME","OBJECT_ID","TYPE","TABLE_NUM","CON_ID" from v$fixed_table

select owner, object_type from dba_objects where object_name = 'V$FIXED_TABLE' and owner = 'SYS';
--
-- No Record!

select view_definition from v$fixed_view_definition where view_name = 'V$FIXED_TABLE';
-- select  NAME , OBJECT_ID , TYPE , TABLE_NUM, CON_ID from GV$FIXED_TABLE where inst_id = USERENV('Instance')

select view_definition from v$fixed_view_definition where view_name = 'GV$FIXED_TABLE';
-- select inst_id,kqftanam, kqftaobj, 'TABLE', indx, con_id from x$kqfta union all
-- select inst_id,kqfvinam, kqfviobj, 'VIEW', 65537, con_id from x$kqfvi union all
-- select inst_id,kqfdtnam, kqfdtobj, 'TABLE', 65537, con_id from x$kqfdt

select * from x$kqfta where kqftanam = 'X$KSLLTR';
select * from x$kqfdt;

select
   *
from
   x$kqfta  ta  left join
   x$kqfdt  dt on ta.kqftanam = dt.kqfdtequ
;
   


select * from v$fixed_view_definition where view_name not like 'GV$%' and view_name not like 'V$%';

select owner, object_type from dba_objects where object_name = 'V$FIXED_TABLE' and owner = 'SYS';

select * from v$fixed_table where name = 'TQ84';
select * from v$sql where sql_text like '%TQ84%';

select * from v$sql where address = '00007FFB8AB2BB80';


select * from dba_objects where object_name = 'V_$ROLLNAME';

select text from dba_views where view_name = 'V_$ROLLNAME';

select * from sys.v$fixed_table;


select * from dba_objects where object_name like '%FIXED%' order by object_name;

select * from FIXED_OBJ$;

select * from SENSITIVE_FIXED$;



