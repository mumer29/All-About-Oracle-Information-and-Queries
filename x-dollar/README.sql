Dynamic performance views are useful for identifying instance-level
performance problems.
Whereas X$ tables are a representation of internal data
structures that can be processed by SQL statements,
V$ views allow users other than SYS access to this data.


-- { Two types of x$ tables


  o Some are real windows into the SGA.
  o Others invoke a helper function to copy data to a memory location
    where it will be read

  An example of a real table into the SGA is x$ksuse
  An example of one where data needs to be copied is x$kccle
  

-- }
-- { addr, indx

  Each x$ table has the columns addr and index

  select
     …
  from
    x$….
  where
    addr = hextoraw('00007FF718801D20')

  select
     to_number(addr, 'XXXXXXXXXXXXXXXX') addr
  from
    x$…;

-- }

Links:
  http://www.soocs.de/public/talk/161115_DOAG2016_Hacking_Oracles_Memory_About_Internals_Troubleshooting_PDF.pdf
  https://books.google.ch/books?id=ZxEL-FO4u7wC&pg=PA93&lpg=PA93&dq=fixed+tables+oracle&source=bl&ots=6fv5qbkG74&sig=ACfU3U2KWT7tqk_OsJwLzktuybU946zpkA&hl=de&sa=X&ved=2ahUKEwjTxcfNgcfkAhXjoIsKHbyjDtE4FBDoATAIegQICBAB#v=onepage&q=fixed%20tables%20oracle&f=false
  http://www.adp-gmbh.ch/ora/misc/x.html
  https://www.orafaq.com/wiki/X$_Table
  https://logicalread.com/oracle-11g-xtables-mc02/#.XXfapaWxX4Y
  https://books.google.ch/books?id=QE5UntUi-4oC&pg=PA197&lpg=PA197&dq=x$+addr+to+number+oracle&source=bl&ots=gAFtTYeDlw&sig=ACfU3U2_c1114gYZUseYTk2EZVfcg2LeLQ&hl=de&sa=X&ved=2ahUKEwiqrKT95MbkAhVP66QKHQn2DsYQ6AEwD3oECAgQAQ#v=onepage&q=x%24%20addr%20to%20number%20oracle&f=false
  https://blog.orapub.com/20151209/watching-an-oracle-buffer-over-time.html
  https://blog.tanelpoder.com/2014/01/10/oracle-x-tables-part-1-where-do-they-get-their-data-from/
  http://yong321.freeshell.org/computer/x$table.html
  https://www.morganslibrary.org/reference/xdollarsign.html
  https://queryadvisor.com/queryadvisor.com/technology/xTables.html
  http://oraperf.sourceforge.net/
  http://www.dba-oracle.com/t_x$_tables.htm
  https://blogs.sap.com/2013/06/19/oracle-database-cache-internals-and-why-one-data-block-can-use-multiple-cache-buffers/
  http://www.dba-oracle.com/art_builder_buffer.htm



select * from x$ksmfs;
select * from x$ksmssinfo;
select * from x$ksmsp;
select * from x$trace;

-- be aware that running queries on X$ toables may result in heavy
-- latch contention (e.g. X$KSMSP - shared pool latch)

-- Tanel Poder has written a script called fcha.sql ([F]ind [CH]unk [A]ddress) [2] that determines
-- in which heap (e.g. UGA, PGA, SGA) a memory address is located, but be careful because this script
-- is based on the X$ table x$ksmsp, which can cause severe shared pool latch contention.


create user x$ identified by x$;
grant dba to x$;


select * from x$ksuse   ; -- session state object / v$session
select * from x$ksusecst; -- v$session_wait

select
   ksuse.addr,
   ksusecst.addr
from
   x$ksuse         ksuse                                  full outer join
   x$ksusecst      ksusecst on ksuse.addr = ksusecst.addr;




select kqftanam from x$kqfta; -- Names of x$ tables

-- x$ksmsp { Shared Pool? SGA?

  select
     count(*),
     ksmchsiz
  from 
     x$ksmsp
  group by
     ksmchsiz
  order by
     ksmchsiz;

-- }

-- { Buffer header

select
   count(*) over () cnt,
   count(*) over (partition by bh.addr) cnt,
   bh.addr,
   case bh.state  -- See https://docs.oracle.com/database/121/REFRN/GUID-A8230335-47C4-4707-A866-678DD8D322A8.htm#REFRN30029
     when 0 then 'free'  -- Not currently in use
     when 1 then 'xcur'  -- Exclusive
     when 2 then 'scur'  -- Shared current
     when 3 then 'cr'    -- Consistent read
     when 4 then 'read'  -- Being read from disk
     when 5 then 'mrec'  -- In media recovery mode
     when 6 then 'irec'  -- In instance recover mode
     when 7 then 'write' -- 
     when 8 then 'pi'    -- Past image in RAC mode
     else '?' || state
   end                      state,
   count(*) over (partition by bh.dbarfil, bh.dbablk)           clone_cnt,
   obj.owner                                                    obj_owner,
   obj.object_name                                              obj_name,
   bh.tch                                                       touch_cnt,                -- How many times has the buffer been accessed: a measure of its popularity.
   to_date(date '1970-01-01' + bh.tim / 24/60/60)               last_touch_time_uct,
   case when bitand(bh.flag, power(2, 0)) > 0 then 'dirty'  end is_dirty,
   case when bitand(bh.flag, power(2, 4)) > 0 then 'temp'   end is_temp,
   case when bitand(bh.flag, power(2, 9)) > 0 then 'ping1'  end is_ping1,
   case when bitand(bh.flag, power(2,10)) > 0 then 'ping1'  end is_ping2,
   case when bitand(bh.flag, power(2,14)) > 0 then 'stale'  end is_stale,
   case when bitand(bh.flag, power(2,16)) > 0 then 'direct' end is_direct,
   case when bitand(bh.flag, power(2,20)) > 0 then 'fts'    end is_fts   ,  -- full table scan
-- le.*,
-- bh.set_ds                     ,  -- Maps to x$kcbwds.addr
   bh.dbarfil,
   bh.dbablk,
   kcbwds.addr              kcbwds_addr,
   lc.name                                                      latch_child_name,
   lc.gets                                                      latch_child_gets,
   lc.misses                                                    latch_child_misses,
   lc.wait_time                                                 latch_child_wait_time,
   bh.*,
   lc.name                                                      latch_child_name,
   lc.gets                                                      latch_child_gets,
   lc.misses                                                    latch_child_misses,
   lc.wait_time                                                 latch_child_wait_time
from
   x$bh               bh                                            left join
   x$kcbwds           kcbwds on bh.set_ds   = kcbwds.addr           left join
   x$le               le     on bh.le_addr  = le.le_addr /* ?? */   left join    -- x$le = lock element?
   v$latch_children   lc     on bh.hladdr   = lc.addr               left join
-- dba_extents        ext    on bh.
   dba_objects        obj    on bh.obj      = obj.data_object_id
where
   obj.owner not in ('SYS', 'SYSTEM')
-- obj.object_name = 'COL'
order by
-- bh.addr
   bh.tim,
   bh.dbarfil, bh.dbablk
;

-- }

select * from x$kcbwbpd


-- { Buffer Pool

select
   bp.addr      buffer_pool_addr,
   bp.bp_name   buffer_pool_name,
   bp.bp_blksz  buffer_pool_block_size,
   bp.bp_size   blocks_in_buffer_pool,      -- compare select count(*) from x$bh
   bp.*
from
   x$kcbwbpd bp

-- }

select * from x$ksmup; -- x$ksmup and x$ksmpp do not see other --              session/process memory
select * from x$ksmpp; -- x$ksmup and x$ksmpp do not see other --              session/process memory

The X$kcccp table contains information about the current redo log file.

The X$kccle table contains information about all redo log files, as shown here:


-- Parameters { 

   select
      param  .ksppinm    name,
      sesVal .ksppstvl   session_value,
      instVal.ksppstvl   instance_value,
      sesVal .ksppstdvl,
      sesVal .ksppstdfl,
      sesVal .ksppstdf ,
      valu2  .kspftctxdf  isdefault,
      decode(bitand(valu2.kspftctxvf,7),
              1, 'MODIFIED',
              4, 'SYSTEM_MOD',
                 'FALSE'                        )  ismod,
      decode(bitand(valu2.kspftctxvf,2),
              2, 'TRUE',
                 'FALSE'                        )  isadj,
      decode(bitand(param.ksppiflg / 65535, 3),
              1, 'IMMEDIATE',
              2, 'DEFERRED' ,
              3, 'IMMEDIATE',
                 'FALSE'                        )  sysMod,
      param.ksppdesc                               description,
      param.ksppiflg,
      param.ksppilrmflg,
      param.ksppity                                priority -- ?
   from
      x$ksppi   param                                               join
      x$ksppcv  sesVal  on  param.indx    = sesVal.indx      and
                            param.inst_id = sesVal.inst_id          join
      x$ksppcv2 valu2   on  param.indx    = valu2.indx       and
                            param.inst_id = valu2.inst_id           join
      x$ksppsv  instVal on  param.indx    = instVal.indx     and
                            param.inst_id = instVal.inst_id
   where
      param.inst_id = userenv('instance') ;

      and
      param.ksppinm like '%max_reason%';





-- }

-- { SGA, UGA and PGA

-- x$ksmsp: shared pool chunks



with heap_chunks_ as (
  select -- { Shared pool
     'Shared Pool'                            heap,
      to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') start_addr_chunk,
  --  min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')) over ()  start_addr_sga_uga_pga,
      KSMCHIDX,
      KSMCHDUR,
      KSMCHCOM                                comment_chunk, -- ?
      KSMCHSIZ                                size_chunk,
      KSMCHCLS,
      KSMCHTYP,
      KSMCHPAR
  from 
      sys.x$ksmsp 
  -- where 
  --     to_number(substr('&1', instr(lower('&1'), 'x')+1) ,'XXXXXXXXXXXXXXXX') 
  --     between 
  --         to_number(ksmchptr,'XXXXXXXXXXXXXXXX')
  --     and to_number(ksmchptr,'XXXXXXXXXXXXXXXX') + ksmchsiz - 1
  union all -- }
  select -- { UGA
     'UGA'                                     heap,
      to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')  start_addr_chunk,
  --  min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')) over ()  start_addr_sga_uga_pga,
      null,
      null,
      KSMCHCOM,
      KSMCHSIZ,
      KSMCHCLS,
      KSMCHTYP,
      KSMCHPAR
  from 
      sys.x$ksmup 
  -- where 
  --     to_number(substr('&1', instr(lower('&1'), 'x')+1) ,'XXXXXXXXXXXXXXXX') 
  --     between 
  --         to_number(ksmchptr,'XXXXXXXXXXXXXXXX')
  --     and to_number(ksmchptr,'XXXXXXXXXXXXXXXX') + ksmchsiz - 1
  union all -- }
  select -- { PGA
     'PGA'                                      heap,
      to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')    start_addr_chunk,
  --  min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')) over ()  start_addr_sga_uga_pga,
      null,
      null,
      KSMCHCOM,
      KSMCHSIZ,
      KSMCHCLS,
      KSMCHTYP,
      KSMCHPAR
  from 
      sys.x$ksmpp 
), -- }
-- }
heap_chunks as ( -- {
  select
     heap,
     min(start_addr_chunk                  ) over (partition by heap) start_addr_heap,
     max(start_addr_chunk + size_chunk - 1 ) over (partition by heap) end_addr_heap,
     comment_chunk,
     start_addr_chunk,
     size_chunk,
     start_addr_chunk + size_chunk - 1 end_addr_chunk,
     KSMCHIDX,
     KSMCHDUR,
     KSMCHCLS,
     KSMCHTYP,
     KSMCHPAR
  from
     heap_chunks_
) -- }
select * -- {
from
   heap_chunks
where
-- (SELECT to_number(addr, 'XXXXXXXXXXXXXXXX') FROM x$ksuse WHERE rownum = 1)
-- (SELECT to_number(addr, 'XXXXXXXXXXXXXXXX') FROM x$kcccp WHERE rownum = 1)
-- (select to_number(addr, 'XXXXXXXXXXXXXXXX') from x$bh    where rownum = 1)
   (select to_number(addr, 'XXXXXXXXXXXXXXXX') from x$kqrst where rownum = 1)
 between start_addr_chunk and end_addr_chunk
order by
   start_addr_chunk
;
-- }


-- Combine Shared Pool and row cache 

   with s as (
     select -- { Shared pool
        'shared pool'                            y,
         to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') addr,
         KSMCHCOM                                txt
     from 
         sys.x$ksmsp 
     union all
       select
         'row cache',
          to_number(x.addr, 'XXXXXXXXXXXXXXXX')  addr,
          x.kqrsttxt
       from
          x$kqrst x
   )
   select
      y,
      addr,
      addr - (select min(addr) from s where y = 'row cache') d,
      txt
   from 
      s
   order by
         s.addr;

-- }


select * from ( -- {
  select 'SGA min addr', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')           ) addr from x$ksmsp union all
  select 'SGA max addr', max(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz) addr from x$ksmsp union all
  select 'UGA min addr', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')           ) addr from x$ksmup union all
  select 'UGA max addr', max(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz) addr from x$ksmup union all
  select 'PGA min addr', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')           ) addr from x$ksmpp union all
  select 'PGA max addr', max(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz) addr from x$ksmpp
)
order by
  addr; -- }

select -- { Combine UGA and PGA
      y,
      addr_start,
      addr_end,
      lead(addr_start) over (order by addr_start) - addr_end - 1 gap,
      comment_,
      type_,
      param
   from (  
   select
     'UGA' y,
      to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')                addr_start,
      to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz - 1 addr_end,
      ksmchcom  comment_,
      ksmchtyp  type_,
      ksmchpar  param
   from
      x$ksmup
 union all
   select
     'PGA' y,
      to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')                addr_start,
      to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz - 1 addr_end,
      ksmchcom,
      ksmchtyp,
      ksmchpar
   from
      x$ksmpp
)
order by
   addr_start
   


select
   addr_start,
   addr_end,
   addr_next,
   addr_next - addr_end -1 gap,
   sum(size_) over() size_used,
   sum(size_) over() - (select value from v$pgastat where name = 'total PGA inuse')
from (
   select
           to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')                           addr_start,
           to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz - 1            addr_end,
      lead(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')) over (order by ksmchptr) addr_next,
      ksmchsiz                                                               size_,
      x.*
   from
      x$ksmup x -- UGA
) s;

select
   max_addr - min_addr size_uga
select 'UGA', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')) min_addr, min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz) max_addr from x$ksmup


select * from ( -- {
  select 'SGA', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')) min_addr, min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz) max_addr from x$ksmsp union all
  select 'SGA max addr',  addr from x$ksmsp union all
  select 'UGA min addr', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')           ) addr from x$ksmup union all
  select 'UGA max addr', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz) addr from x$ksmup union all
  select 'PGA min addr', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX')           ) addr from x$ksmpp union all
  select 'PGA max addr', min(to_number(ksmchptr, 'XXXXXXXXXXXXXXXX') + ksmchsiz) addr from x$ksmpp
)
order by
  addr; -- }
 

-- where 
--     to_number(substr('&1', instr(lower('&1'), 'x')+1) ,'XXXXXXXXXXXXXXXX') 
--     between 
--         to_number(ksmchptr,'XXXXXXXXXXXXXXXX')
--     and to_number(ksmchptr,'XXXXXXXXXXXXXXXX') + ksmchsiz - 1


-- }


-- x$kcccp {

   If you trace what the X$KCCCP access does – you’d see a bunch of control file
   parallel read wait events every time you query the X$ table (to retrieve the
   checkpoint progress records). So this X$ is not doing just a passive read only
   presentation of some memory structure (array). The helper function will first
   do some real work, allocates some runtime memory for the session (the
   kxsFrame4kPage chunk in UGA) and copies the results of its work to this UGA
   area – so that the X$ array & offset parsing code can read and present it back
   to the query engine.

-- }

-- x$kccle {

   select
       ADDR,
       INDX,
       INST_ID,
       CON_ID,
       LENUM,
       LESIZ,
       LESEQ,
       LEHWS,
       LEBSZ       as log_block_size,
       LENAB,
       LEFLG,
       LETHR,
       LELFF,
       LELFB,
       LELOS,
       LELOT,
       LENXS,
       LENXT,
       LEPVS,
       LEARF,
       LEARB,
       LEFNH,
       LEFNT,
       LEDUP
    from
       x$kccle;

-- }

-- x$kccfe { Kernal Cache Current Control File

-- }

-- x$kccrt { Kernel Cache Current Redo Thread

-- }

select * from x$messages;
select * from x$ksbtabact;

select * from x$ksmlru; --  can be helpful for tracking library cache contention.

-- x$kq…  { Kernel Query

  -- x$kqf… { kernel Query FixedView

     -- x$kqfco { Kernel Query FixedView columns

       --> x$ column names  

          -- Select x$ column and table names: {
          drop   table x$.col purge;
          
          create table x$.col as
          select
             tab.addr       tab_addr,
             tab.kqftanam   tab_name,
             col.kqfconam   col_name,
             col.kqfcodty   col_type_id,
             case col.kqfcodty
                  when  1 then 'text'
                  when  2 then 'number'
                  when 23 then 'raw'     end               col_type,
             col.kqfcosiz                                  col_size,
                                     col.kqfcooff          col_offset,
          -- lpad('0x'||trim(to_char(col.kqfcooff,'XXXXXXXX')),8)  xde_off_hex,
             to_number(decode(col.kqfcoidx,0,null,col.kqfcoidx)) xde_kqfcoidx,
             tab.indx       tab_indx,
             col.indx       col_indx,
             tab.kqftaobj,
             col.kqfcotab
          from
             x$kqfta tab   left join
             x$kqfco col              on     tab.indx      = col.kqfcotab
                                          -- tab.kqftaobj  = col.kqfcotob /* Alternative join */
          -- where
          --    tab.kqftanam = 'X$KCCLE'
          order by
             tab.kqftanam,
             col.indx;   
          

          select * from x$.col where tab_name = 'X$ASH' order by offset;


          -- }

          select 'select * from ' || tab_name || ';' from x$.col where col_name like '%NAM' order by col_name; -- {

          select * from X$KCCCF;
          select * from X$KEWECLS;
          select * from X$KCCDC;
          select * from X$KCCDFHIST;
          select * from X$KCVDF; -- data file
          select * from X$KCCFN; -- all files?
          select * from X$KSOLSFTS; -- stat names (per tablespace)
          select * from X$KJICVT;
          select * from X$KKAEET; -- dependent things?
          select * from X$KKSBV; -- ?
          select * from X$KMMDI; -- ?
          select * from X$KMMSI; -- ?
          select * from X$KQFCO; -- Column names
          select * from X$KQFDT;  -- data table names?
          select * from X$KQFTA; -- Table names
          select * from X$KQFVI;  -- view names
          select * from X$KSBDP; -- processes?
          select * from X$KSLED; -- events?
          select * from X$KSLEPX; --?
          select * from X$KSLWSC; -- latches?
          select * from X$KSLLD; -- latches? / locks?
          select * from X$KSLLTR; -- latches?
          select * from X$KSLPO; -- post....
          select * from X$KSLLW; -- ?
          select * from X$KSMFSV; -- fixed variables (SGA) ?
          select * from X$KSMNS;
          select * from X$KSMSD; -- SGA sizes
          select * from X$KSMSGMEM; -- SGA sizes, incl Pool sizes, Granule size, Maximum SGA Size (--> v$sgainfo)
          select * from X$KSMJS; -- Free memory?
          select * from X$KSMFS; -- x$ksmsd + data_transfer_cache
          select /* regexp_replace(ksmssnam, '\d+\.?', ''), */ x.* from X$KSMSS x order by case when lower(ksmssnam) like '%x$%' then chr(0) else regexp_replace(ksmssnam, '\d+\.?', '') end;
          select * from X$KSMSTRS; -- Compare x$ksmjs
          select * from X$KSMLS; -- Compare x$ksmjs
          select * from X$KSUPR; -- Processes?
          select * from X$CON_KSUSGSTA order by ksusdnam; -- Statistics;
          select * from X$KSUSD order by ksusdnam; -- Statistics
          select * from X$KSUSGSTA; -- Statistics
          select * from X$KSUSE; -- Processes
          select * from X$KTCSP;
          select * from X$KTCXB;
          select * from X$KTRSO;
          select * from X$KTUSUS; -- tablespaces
          select * from X$KXFBBOX; -- ?
          select * from X$KXFPBS; -- Large pool?
          select * from X$KXFPDP; --?
          select * from X$KXFPNS; -- ?
          select * from X$KXFPSST; -- Parallel processing
          select * from X$KXFPYS; -- ?
          select * from X$KCCLH ; -- ?
          select * from X$KEWESMAS;
          select * from X$KEWESMS;
          select * from X$KCRMX;
          select * from X$KCRMT;
          select * from X$UGANCO;
          select * from X$KRSOPROC; -- Tome porcesses (LGWR, TMON, TT0n)
          select * from X$QESRCMSG;
          select * from X$QESRCOBJ; -- SQL Area?
          select * from X$QESRCOBJ; -- SQL Area?
          select * from X$QESRCSTA; -- Statistics, about what?
          select * from X$KCCRL;
          select * from X$KCCRM;
          select * from X$KEWESMS;
          select * from X$KEWESMAS;
          select * from X$KEWSSVCV; -- Services?
          select * from X$KCCTS; -- Tablespaces


          select 'select ''' || tab_name || ''', ''' || col_name || ''' from ' || tab_name || ' where lower(' || col_name || ') like ''%ksmst%'' union all' from x$.col where col_name like '%NAM' order by col_name; -- {

           select * from X$KQFTA	where lower(KQFTANAM) like '%ksmst%';
           select * from X$KSMFSV	where lower(KSMFSNAM) like '%ksmst%';
          -- }


     --  }

          select 'select * from ' || tab_name || ';' from x$.col where col_name like '%NAME' order by col_name; -- {


                  select * from X$DBKEFAFC; -- ?
                  select * from X$AUD_DV_OBJ_EVENTS; -- Audit actions
                  select * from X$AUD_OBJ_ACTIONS; -- Audit actions
                  select * from X$AUD_OLS_ACTIONS;  -- Audit actions
                  select * from X$AUD_XS_ACTIONS;  -- Audit actions
                  select * from X$AUD_DPAPI_ACTIONS; -- Audit Actions
                  select * from X$AUD_DP_ACTIONS; -- Audit Datapump Actions
                  select * from X$MMON_ACTION; -- MMON
                  select * from X$GCRACTIONS;
                  select * from X$DIAG_IPS_PACKAGE;
                  select * from X$DIAG_DDE_USR_INC_TYPE; -- Diagnostic type names 
                  select * from X$DIAG_DDE_USR_ACT_PARAM_DEF; -- Diagnostics
                  select * from X$DIAG_DDE_USR_ACT_PARAM;
                  select * from X$DIAG_DDE_USER_ACTION;
                  select * from X$KZCKMEK;
                  select * from X$KZCKMEK;
                  select * from X$KZCKMEK;
                  select * from X$KRBZA; -- AES Keys?
                  select * from X$KJDDDEADLOCKSES;
                  select * from X$KSMSSINFO; -- Fixed size, Redo Buffers, Variable Size
                  select * from X$KSMXMINFO;
                  select * from X$KSFMEXTELEM;
                  select * from X$KSFMEXTELEM;
                  select * from X$KSFMEXTELEM;
                  select * from X$KSFMEXTELEM;
                  select * from X$KSFMEXTELEM;
                  select * from X$XS_SESSION_NS_ATTRIBUTES;
                  select * from X$KRBPSPARSE;
                  select * from X$KJDDDEADLOCKSES;
                  select * from X$KSDHNG_CHAINS;
                  select * from X$KJDDDEADLOCKSES;
                  select * from X$KCBWBPD; -- Buffer Pool
                  select * from X$KCFISCAP; -- Capabilities
                  select * from X$KCFISTCAP;
                  select * from X$KPPLCONN_INFO;
                  select * from X$KPPLCC_STATS;
                  select * from X$KPPLCC_INFO;
                  select * from X$KCFISOSST;
                  select * from X$KCFISOSSN;
                  select * from X$KCFISOSS;
                  select * from X$KCFISOSSAWR;
                  select * from X$KCFISOSSC;
                  select * from X$KCFISOSSL;
                  select * from X$DIAG_HM_FINDING;
                  select * from X$DIAG_DIAGV_INCIDENT; -- Diagnostics - incidents
                  select * from X$KZVDVCLAUSE;  -- Clause names
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$KSFDSSCLONEINFO;
                  select * from X$DBKFDG;
                  select * from X$DIAG_HM_RECOMMENDATION;
                  select * from X$KFNSDSKIOST;
                  select * from X$KFNRCL;
                  select * from X$DBKRUN;
                  select * from X$KDMIMEUCOL;
                  select * from X$KDZCOLCL;
                  select * from X$KEACMDN; -- Commands (SQL?)
                  select * from X$KSFMCOMPL;
                  select * from X$KSFMCOMPL;
                  select * from X$KSFMCOMPL;
                  select * from X$KSFMCOMPL;
                  select * from X$KSFMCOMPL;
                  select * from X$KTFTBTXNMODS;
                  select * from X$KTFTBTXNGRAPH;
                  select * from X$DBGTFOPTT;
                  select * from X$DIAG_DDE_USR_ACT_PARAM_DEF; --Diag
                  select * from X$DBGTFVIEW; -- Content of tracefile?
                                           select
                                              adr_home || '/' ||  trace_filename trace_file_name,
                                              timestamp,
                                              line_number,
                                              payload             txt,
                                              file_name           c_source_file,
                                              function_name       c_function,
                                              component_name,
                                              record_type
                                          from
                                             x$dbgtfview
                                          where
                                             -- session_id = 156 and
                                             -- serial# = 38124  and
                                                1 =1
                                                ;
                                          order by
                                             session_id,
                                             serial#,
                                             line_number;
                  select * from X$DBGTFSQLT;
                  select * from X$DBGTFSSQLT;
                  select * from X$DBGTFSOPTT;
                  select * from X$DIAG_AMS_XACTION;
                  select * from X$KEC_COMPONENT_TIMING; -- ?
                  select * from X$DBGTFOPTT;
                  select * from X$DIAG_ALERT_EXT; -- Alert File (Diag?)
                  select * from X$DBGALERTEXT; -- Alert Fie
                  select * from X$DIAG_HM_FINDING;
                  select * from X$DIAG_HM_RECOMMENDATION;
                  select * from X$DIAG_RELMD_EXT; -- ?
                  select * from X$DBGLOGEXT; -- ?
                  select * from X$DBGTFSOPTT;
                  select * from X$DBGTFSQLT; -- SQL (no record found)
                  select * from X$DBGTFSSQLT; -- SQL (no records found)
                  select * from X$DBGTFVIEW;  -- Something the the column PAYLOAD
                  select * from X$DIAG_VSHOWINCB; -- ?
                  select * from X$KESWXMON; -- ?
                  select * from X$KZCKMEK;
                  select * from X$KZCKMEK;
                  select * from X$KZCKMEK;
                  select * from X$XSLONGOPS;
                  select * from X$KRBPHEAD;
                  select * from X$KFNSDSKIOST;
                  select * from X$KFNRCL;
                  select * from X$ASH;    -- ASH
                  select * from X$KJPMPRC;
                  select * from X$LOGMNR_LOGFILE;
                  select * from X$LOGMNR_LOGS;
                  select * from X$LOGMNR_SESSION;
                  select * from X$LOGMNR_DICTIONARY;
                  select * from X$KTFTBTXNGRAPH;
                  select * from X$KSFDKLL;
                  select * from X$KSFQDVNT; -- RMAN Devices?
                  select * from X$DNFS_SERVERS;
                  select * from X$KSFDSTLL; -- IO?
                  select * from X$KSFDSTLL; -- IO?
                  select * from X$KSFDSTLL; -- I)?
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$LOGMNR_CONTENTS; -- dbms_logmnr.start_logmnr() must be invoked before selecting from v$logmnr_contents
                  select * from X$KSFMSUBELEM;
                  select * from X$KSFMFILEEXT;
                  select * from X$KSFMELEM;
                  select * from X$BUFFER;
                  select * from X$BUFFER2;
                  select * from X$BUFFER2;
                  select * from X$KZSRT;
                  select * from X$LOGMNR_TYPE$;
                  select * from X$LOGMNR_ATTRIBUTE$;
                  select * from X$XML_AUDIT_TRAIL;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$DIAG_ALERT_EXT;  -- Again tracefile?
                  select * from X$KSFQP;
                  select * from X$XSOQMEHI;
                  select * from X$DNFS_FILES;
                  select * from X$DIAG_RELMD_EXT; --?
                  select * from X$LOGMNR_DICTIONARY;
                  select * from X$LOGMNR_LOGFILE;
                  select * from X$LOGMNR_LOGS;
                  select * from X$TIMEZONE_FILE; -- time zone file
                  select * from X$KSFDSTLL; -- control file writes
                  select * from X$KSFMFILE;
                  select * from X$DIAG_VIEW;
                  select * from X$LOGMNR_LOG;
                  select * from X$DBGTFVIEW;
                  select * from X$DBGTFOPTT; -- Another(?) tracefile
                  select * from X$DBGTFSSQLT;
                  select * from X$KZSRPWFILE;
                  select * from X$DBGTFSQLT;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$DBGTFSOPTT;
                  select * from X$KECPRT;
                  select * from X$KEAFDGN; -- Finding name
                  select * from X$QOSADVFINDINGDEF; -- Finding name
                  select * from X$DBGTFSQLT;
                  select * from X$DBGTFOPTT;
                  select * from X$DBGTFSOPTT;
                  select * from X$DBGTFSSQLT;
                  select * from X$DBGTFVIEW; -- Another tracefile?
                  select * from X$KXDRS;
                  select * from X$KCFISOSSL;
                  select * from X$KXTT_PTT;
                  select * from X$LOGMNR_TYPE$;
                  select * from X$VINST;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$KSXPIF;
                  select * from X$DIAG_INC_METER_PK_IMPTS; -- ORA-xxxxx ?
                  select * from X$KEWX_INDEXES;
                  select * from X$KEWEFXT;
                  select * from X$VINST;
                  select * from X$KFNSDSKIOST;
                  select * from X$KFNRCL;
                  select * from X$KJPMPRC;
                  select * from X$DIAG_DFW_PATCH_CAPTURE; -- ?
                  select * from X$DIAG_EM_TARGET_INFO;
                  select * from X$KWSBSMSLVSTAT; -- QMON 
                  select * from X$KZALOADJOBS;
                  select * from X$KWSBGQMNSTAT; -- QMON
                  select * from X$JSKJOBQ;
                  select * from X$JOXFT;
                  select * from X$JOXFT;
                  select * from X$JOXFT;
                  select * from X$KCBFCIO;
                  select * from X$KDLU_STAT; -- Statnames
                  select * from X$KESPLAN;
                  select * from X$DBGRIKX;  -- SID, Serial, ProcId, PQ...
                  select * from X$DIAG_INCIDENT_FILE; -- Trace file
                  select * from X$KJBL;
                  select * from X$KJBR;
                  select * from X$KJFMHBACL;
                  select * from X$KJXM;
                  select * from X$KMPCMON;
                  select * from X$KMPCP;
                  select * from X$KMPSRV; --?
                  select * from X$KPOQSTA;
                  select * from X$KQLFBC; -- Bind Variable?
                  select * from X$KQLFSQCE;
                  select * from X$KQLFXPL;  -- Optimizer ? for SQL?
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$KSBSRVDT; -- Slaves?
                  select * from X$KSLCS; -- Stats ?
                  select * from X$KSLSCS; --  Stats?
                  select * from X$CON_KSLSCS; -- Stats?
                  select * from X$KSLSESOUT;
                  select * from X$KSMMGASEG;
                  select * from X$KSMNIM;
                  select * from X$KSMPGDSTA;
                  select * from X$KSMPGDST;
                  select * from X$KSMPGST; -- Component / CAT ? for processes
                  select * from X$KSOLTD;
                  select * from X$KSO_PRESPAWN_POOL;
                  select * from X$KSPSPFILE; -- init parameters
                  select * from X$KSUCLNPROC; -- ?
                  select * from X$KSUCPUSTAT; -- CPU Stats
                  select * from X$KSUNETSTAT; -- TCP STats
                  select * from X$KSUPR; -- Tracefile name (KSUPRTFN)
                  select * from X$KSUVMSTAT; -- Physical memory , swapping
                  select * from X$KSWSCLSTAB;  -- Service? classes
                  select * from X$KSWSCRSTAB;
                  select * from X$KSFMLIB;
                  select * from X$LOGMNR_OBJ$;
                  select * from X$KEWX_LOBS;
                  select * from X$DIAG_LOG_EXT;  -- Diag tracefile
                  select * from X$DIAG_ALERT_EXT;
                  select * from X$DBGLOGEXT;
                  select * from X$DIAG_RELMD_EXT;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$KFMDGRP;
                  select * from X$KFMDGRP;
                  select * from X$DIAG_AMS_XACTION;
                  select * from X$XSOQOPLU;
                  select * from X$KXDCM_METRIC_DESC;
                  select * from X$GCRMETRICS;
                  select * from X$KNLP_PEND_MSGS;
                  select * from X$KNLP_ACTV_MSGS;
                  select * from X$KNLPMSGSTAT; -- stats
                  select * from X$KSUINSTSTAT;
                  select * from X$KSXPCLIENT;
                  select * from X$KSXRCH;
                  select * from X$KWRSNV; -- Rule set evaulations etc.
                  select * from X$KXDBIO_STATS;
                  select * from X$LOGMNR_ATTRCOL$;
                  select * from X$LOGMNR_ATTRIBUTE$;
                  select * from X$LOGMNR_COL$;
                  select * from X$LOGMNR_KOPM$;
                  select * from X$LOGMNR_LATCH;
                  select * from X$LOGMNR_NTAB$;
                  select * from X$LOGMNR_OBJ$;
                  select * from X$LOGMNR_PROPS$;
                  select * from X$LOGMNR_ROOT$;
                  select * from X$LOGMNR_TS$;
                  select * from X$LOGMNR_UNDO$;
                  select * from X$LOGMNR_USER$;
                  select * from X$NSV;
                  select * from X$OPERATORS; -- SQL Functions
                  select * from X$PRMSLTYX; -- descriptions of advices?
                  select * from X$PROPS; -- Properties / NLS_COMP, GLOBAL_DB_NAME, DICTIONARY_ENDIAN_TYPE
                  select * from X$QOSADVRULEDEF; -- Advisor names?
                  select * from X$RFOB; -- ?
                  select * from X$RULE_SET; -- Alert Queue
                  select * from X$UNFLUSHED_DEQUEUES;
                  select * from X$VINST;
                  select * from X$CON; -- CON
                  select * from X$CON_KEWMDRMV; -- Con statistics
                  select * from X$CON_KEWMSMDV; -- Con Statistics
                  select * from X$DBKFDG;
                  select * from X$DBKH_CHECK;
                  select * from X$DBKH_CHECK_PARAM;
                  select * from X$DBKINFO;
                  select * from X$DBKRECO;
                  select * from X$DBKRUN;
                  select * from X$DGLPARAM;
                  select * from X$DIAG_ADR_CONTROL_AUX;
                  select * from X$DIAG_HM_FDG_SET;
                  select * from X$DIAG_HM_MESSAGE;
                  select * from X$DIAG_HM_RECOMMENDATION;
                  select * from X$DIAG_HM_RUN;
                  select * from X$DIAG_INFO;
                  select * from X$DIAG_IPS_PACKAGE_INCIDENT;
                  select * from X$DIAG_IPS_PROGRESS_LOG;
                  select * from X$DIAG_VIEWCOL;
                  select * from X$DRA_FAILURE;
                  select * from X$DRA_FAILURE_PARAM;
                  select * from X$DRA_REPAIR;
                  select * from X$DRA_REPAIR_PARAM;
                  select * from X$GIMSA; -- Statuis: Abnormal Termination ...
                  select * from X$GSMREGIONS;
                  select * from X$IPCOR_TOPO_NDEV;
                  select * from X$IR_RS_PARAM;
                  select * from X$IR_WF_PARAM;
                  select * from X$IR_WR_PARAM;
                  select * from X$JSKMIMRT;
                  select * from X$KBRPSTAT;
                  select * from X$KEHR;
                  select * from X$KEHRP;
                  select * from X$KEHSQT;
                  select * from X$KESWXMON_STATNAME;
                  select * from X$KEWMAFMV;
                  select * from X$KEWMDRMV;
                  select * from X$KEWMDSM;
                  select * from X$KEWMGSM;
                  select * from X$KEWMRSM;
                  select * from X$KEWMRWMV;
                  select * from X$KEWMSMDV;
                  select * from X$KFBTYP;
                  select * from X$KFCSTAT;
                  select * from X$KGLNA;
                  select * from X$KGLNA1;
                  select * from X$KRDEVTHIST;
                  select * from X$KRSTPVRS;
                  select * from X$KRVSLVS;
                  select * from X$KRVXDTA;
                  select * from X$KRVXSV;
                  select * from X$KSIPCIP;
                  select * from X$KSIPCIP_CI;
                  select * from X$KSIPCIP_KGGPNP;
                  select * from X$KSIPCIP_OSD;
                  select * from X$KSIRESTYP;
                  select * from X$KSI_REUSE_STATS;
                  select * from X$KSMDD;
                  select * from X$KSQEQTYP;
                  select * from X$XS_SESSION_NS_ATTRIBUTES;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$XML_AUDIT_TRAIL;
                  select * from X$DNFS_STATS;
                  select * from X$KQPXINV;
                  select * from X$KCCNRS;
                  select * from X$KCRRLNS;
                  select * from X$KFCLLE;
                  select * from X$OBJ_BIN_EXCEPTIONS;
                  select * from X$XML_AUDIT_TRAIL;
                  select * from X$IMHMSEG1;
                  select * from X$HEATMAPSEGMENT1;
                  select * from X$KZPOPR;
                  select * from X$KELRXMR;
                  select * from X$KEIUT;
                  select * from X$KCFISOSS;
                  select * from X$KSXM_DFT;
                  select * from X$XML_AUDIT_TRAIL;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$RFAHIST;
                  select * from X$OCT;
                  select * from X$OFS_RW_SIZE_STATS;
                  select * from X$OFS_RW_LATENCY_STATS;
                  select * from X$OFS_STATS;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$UNIFIED_AUDIT_TRAIL;
                  select * from X$IMCSEGMENTS;
                  select * from X$DBGTFVIEW;
                  select * from X$DBGTFSSQLT;
                  select * from X$DBGTFSQLT;
                  select * from X$DBGTFOPTT;
                  select * from X$DBGTFSOPTT;
                  select * from X$ORAFN;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$KZCKMCS;
                  select * from X$KZCKMCS;
                  select * from X$KZCKMCS;
                  select * from X$DIAG_DDE_USER_ACTION;
                  select * from X$DIAG_DDE_USR_INC_TYPE;
                  select * from X$KZVDVCLAUSE;
                  select * from X$DBREPLAY_PATCH_INFO;
                  select * from X$KSPTCH;
                  select * from X$KSFMLIB;
                  select * from X$LOGMNR_DICTIONARY;
                  select * from X$KSDHNG_CHAINS;
                  select * from X$LOGMNR_DICTIONARY;
                  select * from X$DIAG_LOG_EXT;
                  select * from X$KRBPHEAD;
                  select * from X$KCPXPL;
                  select * from X$XML_AUDIT_TRAIL;
                  select * from X$KPPLCC_INFO;
                  select * from X$KPPLCP_STATS;
                  select * from X$KZPOPR;
                  select * from X$KWSBSMSLVSTAT;
                  select * from X$KWSBGQMNSTAT;
                  select * from X$KJCISPT;
                  select * from X$KSFDKLL;
                  select * from X$KWSBGAQPCSTAT;
                  select * from X$KNLP_ACTV_MSGS;
                  select * from X$KJPMPRC;
                  select * from X$KFCLLE;
                  select * from X$PERSISTENT_PUBLISHERS;
                  select * from X$AQ_REMOTE_DEQAFF;
                  select * from X$AQ_SUBSCRIBER_LOAD;
                  select * from X$BUFFERED_PUBLISHERS;
                  select * from X$PERSISTENT_QUEUES;
                  select * from X$KWSCPJOBSTAT;
                  select * from X$MESSAGE_CACHE;
                  select * from X$BUFFERED_QUEUES;
                  select * from X$QOSADVRATIONALEDEF;
                  select * from X$KXDCM_IOREASON_NAME;
                  select * from X$QOSADVRECDEF;
                  select * from X$DIAG_EM_USER_ACTIVITY;
                  select * from X$DIAG_VINCIDENT;
                  select * from X$KSIRESTYP;
                  select * from X$KSI_REUSE_STATS;
                  select * from X$KSQEQTYP;
                  select * from X$RXS_SESSION_ROLES;
                  select * from X$XS_SESSION_ROLES;
                  select * from X$KCCRSP;
                  select * from X$RULE;
                  select * from X$DIAG_HM_FINDING;
                  select * from X$DIAG_DIAGV_INCIDENT;
                  select * from X$MESSAGE_CACHE;
                  select * from X$KWSCPJOBSTAT;
                  select * from X$DGLXDAT;
                  select * from X$DBGTFOPTT;
                  select * from X$DBGTFVIEW;
                  select * from X$DBGTFSSQLT;
                  select * from X$DBGTFSQLT;
                  select * from X$DBGTFSOPTT;
                  select * from X$KEWX_SEGMENTS;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$BUFFER;
                  select * from X$BUFFERED_PUBLISHERS;
                  select * from X$BUFFER2;
                  select * from X$KJSCAPKAT;
                  select * from X$KJSCASVCAT;
                  select * from X$LOGMNR_SESSION;
                  select * from X$KFNSDSKIOST;
                  select * from X$KWQMNTASK;
                  select * from X$KTSJPROC;
                  select * from X$KEWSSMAP;
                  select * from X$IMCSEGMENTS;
                  select * from X$KSFDSSCLONEINFO;
                  select * from X$KRSTPVRS;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$ASH;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$KCFISOSST;
                  select * from X$KEC_PROGRESS;
                  select * from X$KSOLSSTAT;
                  select * from X$LOGMNR_OBJ$;
                  select * from X$IMHMSEG1;
                  select * from X$HEATMAPSEGMENT1;
                  select * from X$BUFFERED_SUBSCRIBERS;
                  select * from X$KWSCPJOBSTAT;
                  select * from X$NONDURSUB;
                  select * from X$AQ_SUBSCRIBER_LOAD;
                  select * from X$PERSISTENT_SUBSCRIBERS;
                  select * from X$IMCSEGMENTS;
                  select * from X$DNFS_SERVERS;
                  select * from X$DNFS_CHANNELS;
                  select * from X$KDMUFASTSTARTAREA;
                  select * from X$KXTT_PTT;
                  select * from X$KCFISTCAP;
                  select * from X$KRBPDIR;
                  select * from X$KDZCOLCL;
                  select * from X$KXTT_PTT;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$KEWX_INDEXES;
                  select * from X$KEWX_LOBS;
                  select * from X$KTUQQRY;
                  select * from X$KTCNREG;
                  select * from X$ASH;
                  select * from X$DBGTFVIEW;
                  select * from X$DBGTFSSQLT;
                  select * from X$DBGTFSQLT;
                  select * from X$DBGTFSOPTT;
                  select * from X$DBGTFOPTT;
                  select * from X$DBGTFLIST;
                  select * from X$DBGATFLIST;
                  select * from X$NONDURSUB;
                  select * from X$IMCSEGMENTS;
                  select * from X$KTFTBTXNMODS;
                  select * from X$KTFTBTXNGRAPH;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$DIAG_IPS_PACKAGE;
                  select * from X$DIAG_DDE_USR_INC_ACT_MAP;
                  select * from X$TIMEZONE_NAMES;
                  select * from X$IMCSEGMENTS;
                  select * from X$KPPLCONN_INFO;
                  select * from X$RO_USER_ACCOUNT;
                  select * from X$LOGMNR_CONTENTS;
                  select * from X$GLOBALCONTEXT;
                  select * from X$XSLONGOPS;
                  select * from X$KRVXISPCHK;
                  select * from X$KTCNREG;
                  select * from X$KZSRT;
                  select * from X$DIAG_EM_DIAG_JOB;
                  select * from X$KGLLK;
                  select * from X$DIAG_EM_TARGET_INFO;
                  select * from X$KSFMLIB;
                  select * from X$PRMSLTYX; -- Predictions
                  select * from X$XS_SESSION_NS_ATTRIBUTES;
                  select * from X$DGLXDAT;
                  select * from X$XPLTON; -- SQL Operatino?
                  select * from X$XPLTOO; -- Access to table (SQL)?

     -- x$kqfta { Kernel Query FixedView table

       --> x$ table names

     --  }

  -- }

  -- { x$kqrst

    -- v$rowcache is based upon x$kqrst

    select
       to_number(addr, 'XXXXXXXXXXXXXXXX'),
       x.*
    from
       x$kqrst x;

  -- }

-- }

-- x$kc   { Kernel cache

   select * from X$KCCCF; -- control file

   -- x$kccdi { -- kernel cache, controlfilemanagement database information - 

     x$kccdi  Contains the Current SCN.

   -- }


-- }
-- x$ks   {

  -- x$ksmge { Describes granules

     select
              min(to_number(baseaddr, 'XXXXXXXXXXXXXXXX')),
              max(to_number(baseaddr, 'XXXXXXXXXXXXXXXX') + gransize) 
        from
              x$ksmge
          union all
     select
            min(to_number(addr, 'XXXXXXXXXXXXXXXX')),
            max(to_number(addr, 'XXXXXXXXXXXXXXXX')) 
         from
            x$ksmmem;

  -- }
  -- x$ksmsd {

     -- v$sga is based on x$ksmsd

     select
        to_number(sga_component.addr, lpad('X', 16, 'X')) addr,
        ksmsdnam                                          sga_component,
        ksmsdval                                          component_size
     from
        x$ksmsd  sga_component
     ;

  -- }
  -- x$ksmsv { acronym for “[K]ernel Layer, [S]ervice Layer, [M]emory Management, Addresses of [F]ixed [S]GA [V]ariables” (MOS ID #22241.1 {

     -- Access fixed variables in SGA

          -- { SCN

         select
            ksmfsadr  addr_of_value_of_scn,
            x$ksmfsv.*
         from
            x$ksmfsv
         where
            ksmfsnam =
               'kcsgscn_' -- SCN Number  

        ;


        SQL> oradebug dumpvar sga kcsgscn_

            select
              (  select KSMMMVAL from X$KSMMEM where ADDR = hextoraw('00007FF718801D20' /* x$ksmfsv.ksmfsadr */ )) as SCN_HEX_KSMMEM,
              to_char(CURRENT_SCN,'xxxxxxxxxxxxxxxx') as SCN_HEX_DATABASE,
              CURRENT_SCN as SCN_DECIMAL
           from
              V$DATABASE;

            --
            -- Selecting from x$kccdi seems to increase the SCN:
            --
             select
                dicur_scn -- current SCN
             from
                x$kccdi;


         -- }

        -- Determine value of fixed variable in SGA {

           -- Two steps required (because join directly to x$ksmmem) does not seem to work.
              
              -- first: determine index of value for variable:


            with
            sga as (
               select
                  to_number(addr, 'XXXXXXXXXXXXXXXX') min_addr
               from
                  x$ksmmem
               where
                  indx=0
            ),
            fixed_sga_variable as (
                select
                   ksmfsnam                                name,
                -- to_number(addr    , 'XXXXXXXXXXXXXXXX') addr
                   to_number(ksmfsadr, 'XXXXXXXXXXXXXXXX') addr_of_value
                from
                   x$ksmfsv
                where
                  ksmfsnam =  'kcsgscn_' -- or -- SCN Number      
               --   ksmfsnam like '%pool%'
            )
            -- memory_ as (
               select
                   name,
                  (fixed_sga_variable.addr_of_value - sga.min_addr) / 8 indx_of_value
               from
                  sga                 cross join
                  fixed_sga_variable
            ;
            --
            --  indx_of_value is:
            -->    19876
            
            
            -- second step: use determined indx_of_value to access value:   
            select
               to_number(addr,     'XXXXXXXXXXXXXXXX') addr,
               to_number(ksmmmval, 'XXXXXXXXXXXXXXXX') scn
            from
               x$ksmmem x
            where
                x.indx = 19876;
            
        -- } 

        -- Types of these variables

            select
              count(*),
              ksmfstyp
           from
              x$ksmfsv
            group by
               ksmfstyp
           order by
              count(*) desc;

        -- }


  -- }
  -- x$ksmmem {

     --> Access each memory in the fixed SGA
       select
          value
       from
          v$sga
       where
          name = 'Fixed Size'
       union all
       select
          max(to_number(x$ksmmem.addr, lpad('X', 16, 'X'))) -
          min(to_number(x$ksmmem.addr, lpad('X', 16, 'X'))) + 8
       from
          x$ksmmem;

  -- }
  -- x$ksuse {

     -- One record per potential session
     select to_number(value) from v$parameter where name = 'sessions' union all
     select count(*) from x$ksuse;

  -- }
  -- x$ksusecst { One record per sessino:

     select to_number(value) from v$parameter where name = 'sessions' union all
     select count(*) from x$ksusecst;

  -- }


-- }


-- Enqueue locks {



select
  type || '-' || id1 || '-' || id2  "RESOURCE",
  sid,
  decode(
    lmode,
    1, '      N',
    2, '     SS',
    3, '     SX',
    4, '      S',
    5, '    SSX',
    6, '      X'
  )  holding,
  decode(
    request,
    1, '      N',
    2, '     SS',
    3, '     SX',
    4, '      S',
    5, '    SSX',
    6, '      X'
  )  wanting,
  ctime  seconds
from
  sys.v$lock
order by
  type || '-' || id1 || '-' || id2,
  ctime desc
/

-- }

Query X$KGLLK by matching X$KGLLK.KGLHDADR to V$SESSION_WAIT.PARAMETER1



