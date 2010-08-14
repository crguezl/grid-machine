#!/usr/bin/perl

# Adaptado del ejemplo de GRID::Machine

# Importante observacion en Linux Journal
# http://www.linuxjournal.com/article/3882

use warnings;
use strict;
use IO::Select;
use GRID::Machine;
use Time::HiRes qw(time gettimeofday tv_interval);

#my @machine = qw{beowulf orion nereida};
my @machine = qw{127.0.0.1 127.0.0.2 127.0.0.3};
my $nummachines = @machine;
my %machine; # Hash of GRID::Machine objects
#my %debug = (beowulf => 12345, orion => 0, nereida => 0);
my %debug = (127.0.0.1 => 0, 127.0.0.2 => 0, 127.0.0.3 => 0);

my $np = shift || $nummachines; # number of processes
my $lp = $np - 1;
my @pid;  # List of process pids
my @proc; # List of handles
my %id;   # Gives the ID for a given handle

my $cleanup = 0; # Poner a 0 para entornos de archivo compartido (NFS, localhost)

my $readset = IO::Select->new();

my $i = 0;
for (@machine){
	my $m = GRID::Machine->new(host => $_, debug => $debug{$_}, );

	$m->copyandmake(
	  dir => 'matrix',
	  makeargs => 'matrix',
	  files => [ qw{matrix.c Makefile A.dat B.dat} ],
	  cleanfiles => $cleanup,
	  cleandirs => $cleanup, # remove the whole directory at the end
	  keepdir => 1,
	);

	$m->chdir("matrix/");

	die "Can't execute 'matrix'\n" unless $m->_x("matrix")->result;

	$machine{$_} = $m;
	last unless $i++ < $np;
}

my $t0 = [gettimeofday];
for (0..$lp) {
	my $hn = $machine[$_ % $np];
	my $m = $machine{$hn};
	($proc[$_], $pid[$_]) = $m->open("./matrix $_ $np A.dat B.dat|");
	$readset->add($proc[$_]);
	my $address = 0+$proc[$_];
	$id{$address} = $_;
}

my @ready;
my $count = 0;
my @result = ();


# Lee un float del handle pasado por parametro
# Si no puede leelo, muere
sub read_float
{
	my $handle = shift;
	my $input = '';
	my $char = ' ';
	my $was_read = 1;

	while (($was_read) && (($char eq " ") || ($char eq "\n"))) { # saltamos al siguiente numero
		$was_read = sysread($handle, $char, 1);
	}

	while (($was_read) && ($char ne " ") && ($char ne "\n")) {
		$input .= $char;
		$was_read = sysread($handle, $char, 1);
	}

	$input ne '' || die(shift); # Ejemplo de vicio perl

	return $input;
}


# Utiliza la subrutina anterior para leer el una matriz
# y devolverla como resultado.
sub read_result
{
	my $handle = shift; # Handle de comunicacion
	my $id = shift; # Id del proceso
	my @result = @_; #shift; # Matrix del resultado
	
	my $rows = read_float($handle, "Error leyendo filas del proceso [$id]");
	my $cols = read_float($handle, "Error leyendo columnas del proceso [$id]");
	my $fila;

	print "[$id] Reading $rows filas x $cols columnas...";

	for $fila (0..$rows - 1) {
		my @lista = ();
		my $col;

		for $col (0..$cols - 1) {
			push @lista, read_float($handle, "\nError leyendo dato [$fila][$col] del proceso [$id]");
		}

		push @result, [@lista];
	}

	print "done\n";

	return @result;
}


# Para cada proceso se lee su chunk. Tiene que ser ordenado.
# Asi que esperamos a que el proceso $me termine
while ($count < $np) {
	my @ready = $readset->can_read;

	my $handle = shift @ready; # Toma el siguiente que pueda leer
  	my $me = $id{0+$handle};

	while (($me ne $count) && (@ready)) {
		$handle = shift @ready; # Toma el siguiente que pueda leer
  		$me = $id{0+$handle};
	}

	next if ($me ne $count); # Tiene que ser el proceso $count
	
	@result = read_result($handle, $me, @result); # Leemos el trozo i-esimo
  	$readset->remove($handle); # if eof($handle);
	$count++;
}
my $elapsed = tv_interval ($t0);


my $filas = @result;
my $cols = @{$result[1]}; # <=== This is why Perl SUCKS

print "$filas $cols\n";

for $i (0..$filas - 1) {
	my $j;

	for $j (0..$cols - 1) {
		print $result[$i][$j];
		print " ";
	}

	print "\n";
}

print "Matrix: $filas x $cols N: $np Time = $elapsed\n";
