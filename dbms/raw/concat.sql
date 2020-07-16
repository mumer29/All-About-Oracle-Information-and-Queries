declare
   r long raw := '00';
begin

   while r < 1000000 loop
     r := utl_raw.concat(r, r);
     dbms_output.put_line(utl_raw.length(r));
   end loop;

end;
/

exit
