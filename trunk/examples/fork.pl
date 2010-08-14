#!/usr/local/bin/perl -w
use strict;
use GRID::Machine qw(is_operative);
use Data::Dumper;

my $host = shift || 'casiano@orion.pcg.ull.es';

my $machine = GRID::Machine->new( 
      host => $host,
      uses => [ 'Sys::Hostname' ],
   );

my $r;
 $r = $machine->_fork( q{
   open my $F, ">child.log";
   print $F "Hello from process $$\n";
   close($F);
 }
);
print Dumper($r);

print $r->Results,"\n";

$r = $machine->eval(q{
  gprint "Written with gprint after fork\n";
  gprint hostname(),"\n";
  print "This message is via print after fork\n";
  print "Contents of child.log:\n".`cat child.log`;
});

print $r;

