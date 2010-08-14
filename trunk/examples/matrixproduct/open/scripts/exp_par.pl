#!/usr/local/bin/perl
use warnings;
use strict;

my @files = qw/ 100x100 500x500 1000x1000 1500x1500 2000x2000 /;
my @num_procs = qw/ 1 2 3 /;


foreach my $num_procs (@num_procs) {
  foreach my $file (@files) {
    foreach (1..30) {
      print "GRID::Machine, $num_procs processors: Execution number $_ of A$file.dat x B$file.dat\n";
      system "./matrix_grid.pl $num_procs A$file.dat B$file.dat >> results/$file\_grid_$num_procs.dat";
    }
  }
}
