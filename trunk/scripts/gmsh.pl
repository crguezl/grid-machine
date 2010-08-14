#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);
use IO::Select;
use GRID::Machine qw{slurp_file};

my $commandfile = '';

GetOptions (
            "commandfile=s" => \$commandfile, 
            "help"      => \&usage,
          ) or  usage();

exit print usage() unless @ARGV && $commandfile && -r $commandfile;

my @pid;  # List of process pids
my @proc; # List of handles
my %id;   # Gives the ID for a given handle
my %machine; # Hash of GRID::Machine objects

my @machine = @ARGV;
my $np = @machine;
my $lp = $np-1;

my $readset = IO::Select->new(); 

for my $host (@machine) {
  my $m = eval { 
    GRID::Machine->new(host => $host) 
  };

  warn "Cant' create GRID::Machine connection with $host\n", next unless UNIVERSAL::isa($m, 'GRID::Machine');

  warn "Cant' transfer $commandfile to $host\n", next unless $m->put([ $commandfile ], '/tmp/');

  $m->eval("chmod 0700, '/tmp/$commandfile'");

  $machine{$host} = $m;
}

my $t0 = [gettimeofday];
for (0..$lp) {
  my $hn = $machine[$_];
  my $m = $machine{$hn};
  ($proc[$_], $pid[$_]) = $m->open("/tmp/$commandfile |");

  $readset->add($proc[$_]); 
  my $address = 0+$proc[$_];
  $id{$address} = $_;
}

my %output;
my @ready;
my $count = 0;
do {
  push @ready, $readset->can_read unless @ready;
  my $handle = shift @ready;

  my $me = $id{0+$handle};

  my $partial = '';
  my $numBytesRead;
  $numBytesRead = sysread($handle,  $partial, 65535, length($partial));

  my $name = "$machine[$me]: ";
  $partial =~ s/^/$name/gme;
  $output{$name} .= $partial;

  if (defined($numBytesRead) && !$numBytesRead) {
    # eof
    print "$output{$name}\n";
    $readset->remove($handle);
    $count ++;
  }

} until ($count == $np);

my $elapsed = tv_interval ($t0);
print "Time = $elapsed\n";


sub usage {
  exit print "Usage:\n\t$0 [-file commandfile | -command 'command' ] host host host ...\n";
}

#  gmsh.pl -hostfile  -e 'print "Hello World from ".SERVER->host()."\n"'
#  gmsh.pl -hostfile  program.pl

=head1 NAME 

gmsh.pl - parallel perl script

=head1 SYNOPSIS

  pp2@europa:~/LGRID-Machine/examples/matrixproduct$ cat listdirs
  #!/bin/bash
  ls -l | tail -2

  pp2@europa:~/LGRID-Machine/examples/matrixproduct$ gmsh.pl -c listdirs beowulf orion
  beowulf: lrwxrwxrwx  1 root    root        32 feb 22  2007 webapps -> /var/lib/tomcat5/webapps/casiano
  beowulf: drwxr-xr-x  2 casiano casiano   4096 mar 16  2007 webservices
  beowulf:
  orion: lrwxrwxrwx  1 casiano casiano             31 2006-07-15 13:08 websvn.conf -> /etc/apache2/conf.d/websvn.conf
  orion: -rw-r-----  1 casiano casiano          38134 2008-03-11 16:02 yaccexamples.tex
  orion:
  Time = 0.165698


