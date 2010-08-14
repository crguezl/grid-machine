#!/usr/bin/perl
use warnings;
use strict;
use IO::Select;
use GRID::Machine;
use Time::HiRes qw(time gettimeofday tv_interval);

my @machine = qw{nereida beowulf orion};
#my @machine = qw{127.0.0.1 127.0.0.2 127.0.0.3};

my $nummachines = @machine;
my %machine; # Hash of GRID::Machine objects

my %debug = (beowulf => 0, orion => 0, nereida => 0);
#my %debug = (127.0.0.1 => 0, 127.0.0.2 => 0, 127.0.0.3 => 0);

my $np = shift || $nummachines; # number of processes
my $A  = shift || "A.dat";
my $B  = shift || "B.dat";
die "Cant find matrix file $A\n" unless -r $A;
die "Cant find matrix file $B\n" unless -r $B;

my $lp = $np - 1;
my @pid;  # List of process pids
my @proc; # List of handles
my %id;   # Gives the ID for a given handle

my $cleanup = 0; 

my $readset = IO::Select->new();

my $i = 0;
for (@machine){
	my $m = GRID::Machine->new(host => $_, debug => $debug{$_}, );

	$m->copyandmake(
	  dir        => 'matrix',
	  makeargs   => 'matrix',
	  files      => [ 'matrix.c', 'Makefile', $A, $B ],
	  cleanfiles => $cleanup,
	  cleandirs  => $cleanup, # remove the whole directory at the end
	  keepdir    => 1,
	) unless $m->_r("matrix/$A")->result && ($m->_M("matrix/$A")->result > (-M $A));

	$m->chdir("matrix/");

	die "Can't execute 'matrix'\n" unless $m->_x("matrix")->result;

	$machine{$_} = $m;
	last unless ++$i < $np;
}

my $t0 = [gettimeofday];
for (0..$lp) {
	my $hn = $machine[$_ % $np];
	my $m = $machine{$hn};
	($proc[$_], $pid[$_]) = $m->open("./matrix $_ $np $A $B|");
	$readset->add($proc[$_]);
	my $address = 0+$proc[$_];
	$id{$address} = $_;
}

my @ready;
my $count = 0;
my $result = [];


local $/ = undef;
while ($count < $np) {
  push @ready, $readset->can_read unless @ready;

	my $handle = shift @ready; 

  my $me = $id{0+$handle};

  my $r = <$handle>;
  $result->[$me] = eval $r;
  die "Wrong result from processor $me\n" unless defined($result->[$me]);
  print "Process $me: machine = $machine[$me % $nummachines] received result\n";

  $readset->remove($handle) if eof($handle);

	$count++;
}
my $elapsed = tv_interval ($t0);

print "Elapsed time: $elapsed\n";

# Place result rows in their final location
my @r = map { @$_ } @$result;

if (@r > 10) { # Send to file if too big to display
  open my $f, "> /tmp/result.dat";
  print $f "@$_\n" for @r;
  close($f);
}
else { # Send to STDOUT
  print "@$_\n" for @r;
}

__DATA__
pp2@nereida:~/LGRID_Machine/examples/boriel$ time matrix_grid.pl 1
Elapsed time: 13.666532

real    0m17.079s
user    0m3.920s
sys     0m0.496s
pp2@nereida:~/LGRID_Machine/examples/boriel$ time matrix_grid.pl 2
Elapsed time: 7.522326

real    0m13.050s
user    0m4.348s
sys     0m0.844s
pp2@nereida:~/LGRID_Machine/examples/boriel$ time matrix_grid.pl 3
Elapsed time: 6.849804

real    0m15.562s
user    0m4.756s
sys     0m1.160s

************************************************

pp2@nereida:~/LGRID_Machine/examples/boriel$ time generam.pl 1000 > A1000.dat

real    0m7.271s
user    0m6.936s
sys     0m0.328s
pp2@nereida:~/LGRID_Machine/examples/boriel$ time generam.py 1000 > A1000.dat

real    0m7.197s
user    0m6.836s
sys     0m0.088s

***************************************************
pp2@nereida:~/LGRID_Machine/examples/boriel$ time matrix 0 1 A1000.dat B1000.dat > /tmp/result1000.dat

real    0m23.984s
user    0m23.809s
sys     0m0.128s

pp2@nereida:~/LGRID_Machine/examples/boriel$ time matrix 0 1 A1000.dat B1000.dat > /tmp/result1000.dat

real    0m25.621s
user    0m25.426s
sys     0m0.172s


pp2@nereida:~/LGRID_Machine/examples/boriel$ time matrix_grid.pl 1 A1000.dat B1000.dat
Process 0: machine = nereida received result
Elapsed time: 26.44533

real    0m29.486s
user    0m4.900s
sys     0m0.496s

pp2@nereida:~/LGRID_Machine/examples/boriel$ time matrix_grid.pl 2 A1000.dat B1000.dat
Process 1: machine = beowulf received result
Process 0: machine = nereida received result
Elapsed time: 14.035967

real    0m17.399s
user    0m5.064s
sys     0m0.532s

pp2@nereida:~/LGRID_Machine/examples/boriel$ time matrix_grid.pl 3 A1000.dat B1000.dat
Process 1: machine = beowulf received result
Process 0: machine = nereida received result
Process 2: machine = orion received result
Elapsed time: 11.018193

real    0m15.178s
user    0m5.112s
sys     0m0.588s


