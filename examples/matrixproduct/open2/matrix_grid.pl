#!/usr/bin/perl
use warnings;
use strict;
use Scalar::Util qw{looks_like_number};
use IO::Select;
use GRID::Machine;
use Time::HiRes qw(time gettimeofday tv_interval);
use List::Util qw(sum);
use Parallel::ForkManager;
use Getopt::Long;
#use POSIX qw{WNOHANG};

use constant BUFFERSIZE => 2048;

my %machine; # Hash of GRID::Machine objects
my %map_id_machine; # Hash that contains a machine name given an id of a process

my $config = 'MachineConfig.pm';
my $np;

my $A  = "data/A100x100.dat";
my $B  = "data/B100x100.dat";
my $clean = 0; # clean the matrix dir in the remote machines
my $resultfile = '';

GetOptions(
  'config=s' => \$config, # Module containing the definition of %machine and %map_id_machine
  'np=i'     => \$np,
  'a=s'      => \$A,
  'b=s'      => \$B,
  'clean'    => \$clean,
  'result=s' => \$resultfile,
) or die "bad usage\n";

our (%debug,  %max_num_proc); 
require $config;

my @machine = sort { $max_num_proc{$b} <=> $max_num_proc{$a} } keys  %max_num_proc; # qw{europa beowulf orion};
my $nummachines = @machine;
$np ||= $nummachines; # number of processes

die "Cant find matrix file $A\n" unless -r $A;
die "Cant find matrix file $B\n" unless -r $B;

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

# Checks that the number of processes doesn't exceed 
# the number of rows of the matrix A
die "Too many processes. $np processes for $A_rows rows\n" if ($np > $A_rows);

# Checks that the number of processes doesn't exceed the
# maximum number of processes supported by all machines
my $max_processes = sum values %max_num_proc;
die "Too many processes. The list of actual machines only supports a maximum of $max_processes processes\n" if ($np > $max_processes);

my $lp = $np - 1; # Number of processes
my @pid;  # List of processes pids
my @proc; # List of handles
my @str_handles;  # List with the input string and handle of every remote process
my %id;   # Gives the ID for a given handle

sub send_message {
  my $d = shift;

  my $b = syswrite($d->{handle}, 
           join(" ", 
                  $d->{chunksize}, 
                  $d->{A_cols}, 
                  @A_lines[$d->{start}.. $d->{end}], 
                  @B_lines,
                  "\cN"
               ),
  );
  # warn "Sent $b bytes to $d->{host}\n";
  # Wait until the writing has finished
  #sleep(1);
}

sub send_message2 {
  my $d = shift;

  my $b = syswrite($d->{handle}, 
           join(" ", 
                  $d->{chunksize}, 
                  $d->{A_cols}, 
                  @A_lines[$d->{start}.. $d->{end}], 
                  @B_lines,
                  "\cD"
               ),
  );
  warn "Sent $b bytes to $d->{host}\n";
  # Wait until the writing has finished
  sleep(1);
}

sub send_message3 {
  my $d = shift;

  my $b = syswrite($d->{handle}, "$d->{chunksize} $d->{A_cols}\n");
  $b += syswrite($d->{handle}, join(" ", @A_lines[$d->{start}.. $d->{end}],"\n")); 
  $b += syswrite($d->{handle}, join(" ", @B_lines, "\cD")),

  close($d->{handle});
  warn "Sent $b bytes to $d->{host}\n";
  # Wait until the writing has finished
  #sleep(1);
}

my $cleanup = 0;

my $readset = IO::Select->new();

my $i = 0;
for (@machine){  # generates the GRID::Machine objects

  my $m = GRID::Machine->new(host => $_, debug => $debug{$_}, );
  
  $m->copyandmake(
    dir        => 'matrix',
    makeargs   => 'matrix',
    files      => [ 'matrix.c', 'Makefile' ],
    cleanfiles => $cleanup,
    cleandirs  => $cleanup, # remove the whole directory at the end
    keepdir    => 1,
  ) unless $m->_r("matrix/matrix.c")->result && $m->_stat("matrix/matrix.c")->results->[9] >= (stat("matrix.c"))[9];

  $m->chdir("matrix/");
  
  die "Can't execute 'matrix'\n" unless $m->_x("matrix")->result;

  $machine{$_} = $m;
  last unless ++$i < $np;
}

my $t0 = [gettimeofday];

my $counter = 0;
my $div  = int($A_rows / $np);
my $rest = $A_rows % $np;
my ($chunksize, $start, $end);
my ($RDR, $WTR);

for (@machine) {
  for my $actual_proc (0 .. $max_num_proc{$_} - 1) {

    # Calculates the start, the end and the size of the chunk that
    # is going to be processed
    if ($counter < $rest) {
      $chunksize = $div + 1;
      $start = $counter * $chunksize + 1;
    }
    else {
      $chunksize = $div;
      $start = $counter * $chunksize + $rest + 1;
    }
    $end = $start + $chunksize;

    # Creates the bidirectional pipe
    my $m = $machine{$_};
    $WTR = IO::Handle->new();
    $RDR = IO::Handle->new();
    $pid[$counter] = $m->open2($RDR, $WTR, "./matrix");
    $RDR->blocking(0);  # Non blocking reading
    $proc[$counter] = $RDR;
    $map_id_machine{$counter} = $_;
    $readset->add($RDR);
    my $address = 0+$proc[$counter];
    $id{$address} = $counter;

    # Builds the string which has to be written into the pipe
    # This string contains the chunk of the matrix A and fully
    # the matrix B
    $str_handles[$counter] = { 
       chunksize => $chunksize, 
       A_cols => $A_cols, 
       start => $start, 
       end => ($end - 1), 
       handle => $WTR, 
       rhandle => $RDR,
       host => $_,
    };

    last if (++$counter > $lp);
  }
  last if ($counter > $lp);
}

# Parallelise the writing into the pipes
my $pm = Parallel::ForkManager->new($np/2);

foreach (@str_handles) {
  my $pid = $pm->start;
  next if ($pid);

  send_message($_);
  #while (my $kid = waitpid(-1, WNOHANG) > 0) {}
  $pm->finish; 
}
$pm->wait_all_children;

my @ready;
my $count = 0;
my $result = [];

local $/ = undef;
while ($count < $np) {
  push @ready, $readset->can_read unless @ready;

  my $handle = shift @ready;

  my $me = $id{0+$handle};

  my ($r, $auxline, $bytes);

  while ((!defined($bytes)) || ($bytes)) {
    $bytes = sysread($handle, $auxline, BUFFERSIZE);
    $r .= $auxline if ((defined($bytes)) && ($bytes));
  }
  
  $result->[$me] = eval $r;
  die "Wrong result from process $me in machine $map_id_machine{$me}\n" unless defined($result->[$me]);
  print "Process $me: machine = $map_id_machine{$me} received result\n";

  $readset->remove($handle) if eof($handle);

  $count++;
}

# Close the input/output handles
close $_ foreach (@proc);
close $_->{handle} foreach (@str_handles);

# Place result rows in their final location
my @r = map { @$_ } @$result;

my $elapsed = tv_interval($t0);
print "Elapsed Time: $elapsed seconds\n";


if ($resultfile) { 
  print "sending result to $resultfile\n";
  open my $f, "> $resultfile";
  print $f "@$_\n" for @r;
  close($f);
}
elsif (@r < 11) { # Send to STDOUT
  print "@$_\n" for @r;
}


# close machines
$machine{$_}->DESTROY for (@machine);
