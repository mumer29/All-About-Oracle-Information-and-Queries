declare
-- r          raw(1000) := '00000000';
-- r_overlaid raw(1000);   
   r          long raw := '00000000';
   r_overlaid long raw;
begin

   r_overlaid := utl_raw.overlay(
      overlay_str  =>'01020304',
      target       => r,
      pos          => 1,
      len          => 4
   );

   dbms_output.put_line(rawtohex(r_overlaid));
   dbms_output.put_line(utl_raw.length(r_overlaid));

end;
/


exit
