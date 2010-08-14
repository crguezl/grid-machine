#!/usr/bin/perl -w
use strict;
use PDL;

=head1 DESCRIPTION

prints the inverse of the given matrix 
using Boriel's format

=cut

die "Provide file name containing the matrix. Usage $0 matrixfilename\n" unless @ARGV;

my @m = <>;
my $fln = shift @m;

my ($N, $M) = split /\s+/, $fln;

my $m  = [ map { [ split /\s+/ ] } @m ];

$m = pdl $m;

my $inv = inv $m;

print "$N $M\n";

#local $PDL::use_commas = 1;
my $s = "$inv";

# Eliminate ]\n[
$s =~ s/\]\n\s*\[/\n/g;

# Eliminate initial [[ and ending ]]
$s =~ s/\[\s*\[//;
$s =~ s/\]\s*\]//;

print $s;
