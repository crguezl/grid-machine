#!/usr/local/bin/perl -w
use strict;
use Test::More tests => 13;
BEGIN { use_ok('GRID::Machine', 'is_operative') };

my $test_exception_installed;
BEGIN {
  $test_exception_installed = 1;
  eval { require Test::Exception };
  $test_exception_installed = 0 if $@;
}

my $host = $ENV{GRID_REMOTE_MACHINE};

my $machine;
SKIP: {
    skip "Remote not operative or Test::Exception not installed", 12
  unless $test_exception_installed and $host and is_operative('ssh', $host);

########################################################################

  Test::Exception::lives_ok { 
    $machine = GRID::Machine->new(host => $host);
  } 'No fatals creating a GRID::Machine object';

########################################################################

  unshift @INC, "t/";
  $machine->include("Include2");

  for my $method (qw(one two three)) {
    can_ok($machine, $method);
    is($machine->$method()->stdout, "$method\n", "and works");
  }

  ok(!$machine->can('four'), "DATA filehandle is correctly skipped");

  ok(!$machine->can('five'), "subs inside comments skipped");

  ok(!$machine->can('twoexample'), "subs inside POD skipped");

  ok(!$machine->can('six'), "subs inside qq strings skipped");

  ok(!$machine->can('seven'), "subs inside q strings skipped");

} # end SKIP block

