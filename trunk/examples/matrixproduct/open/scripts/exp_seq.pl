#!/usr/local/bin/perl
use warnings;
use strict;

my @files = qw/ 100x100 500x500 1000x1000 1500x1500 2000x2000 /;


foreach my $file (@files) {
  foreach (1..30) {
    print "Execution number $_ of A$file.dat x B$file.dat\n";
    system "matrix 0 1 A$file.dat B$file.dat >> results/$file\_seq.dat";
  }
}
