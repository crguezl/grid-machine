#!/usr/local/bin/perl -w
# Execute this program being the user
# that initiated the X11 session
use strict;
use GRID::Machine;

my $host = 'casiano@beowulf.pcg.ull.es';

my $machine = GRID::Machine->new(
   command => "ssh -X $host perl", 
);

print $machine->eval(q{ 
  print "$ENV{DISPLAY}\n";
  system('xclock &');
  print "Hello world!\n";
});

