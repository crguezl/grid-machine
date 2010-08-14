#!/usr/bin/perl -w
use strict;
use Test::LectroTest::Generator qw(:common Gen);

my $N = shift || 10;
$N = 10 unless $N =~ m{^\d+$};

my $mg = List( List( Float(sized=>0), length => $N ), length => $N);
my $mat = $mg->generate;

print "$N $N\n";
print "@$_\n" for @$mat;
