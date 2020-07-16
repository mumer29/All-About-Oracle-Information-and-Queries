#!/usr/bin/perl
use warnings;
use strict;

# my $x = 'fo1 and o2x and o3is also here';

# for my $m ($x=~/(o.)/g) {
#   print "$m\n";
# }
# exit 0;

open (my $f, '<', 'oracle.exe') or die

my %hints;
my %xDollar;

while (my $l = <$f>) {

  
   for my $h ($l =~ /\/\*\+ *(\w+)/g) {
     $hints{lc $h} = 1;
   # print $h, "\n";
   }

   for my $x ($l =~ /\b(x\$\w+)/gi) {
     $xDollar{lc $x} = 1;
   # print $h, "\n";
   }
 

}

for my $h (keys %hints) {
  print "$h\n";
}

for my $x (keys %xDollar) {
  print "$x\n";
}
