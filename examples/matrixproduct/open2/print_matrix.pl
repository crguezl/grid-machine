#!/usr/local/bin/perl
use warnings;
use strict;

die "Uso: ./print_matrix matrix_file_A matrix_file_B | ./matrix\n" if (@ARGV != 2);

my $A = shift;
my $B = shift;

# Reads the matrix files
open DAT, $A or die "The file $A can't be opened to read\n";
my @A_lines = <DAT>;
my ($A_rows, $A_cols) = split(/\s+/, $A_lines[0]);
close DAT;
chomp @A_lines;

open DAT, $B or die "The file $B can't be opened to read\n";
my @B_lines = <DAT>;
my ($B_rows, $B_cols) = split(/\s+/, $B_lines[0]);
close DAT;
chomp @B_lines;

# Checks the dimensions of the matrix
die "Dimensions error. Matrix A: $A_rows x $A_cols, Matrix B: $B_rows x $B_cols.\n" if ($A_cols != $B_rows);

# Prints the matrix into the standard output
print "$_ " foreach (@A_lines);
print "$_ " foreach (@B_lines);


# This script allows the execution of the program "matrix" in a sequential manner.
# The use is as follows: ./print_matrix matrix_file_A matrix_file_B | ./matrix
#
# If you want to obtain time measures, you can use the "time" command:
# time "./print_matrix matrix_file_A matrix_file_B | ./matrix > out.dat"
# This time measures include the I/O operations
