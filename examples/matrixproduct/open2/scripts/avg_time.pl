#!/usr/local/bin/perl
use warnings;
use strict;
use List::Util qw(sum);

foreach (@ARGV) {

  open FILE, $_;
  my @lines = <FILE>;
  close FILE;

  my $avg_time = sum(map { /(\d+.\d+)/ } @lines) / @lines;
  print "Tiempo medio de $_: $avg_time\n";

}
