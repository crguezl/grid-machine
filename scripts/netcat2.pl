#!/usr/bin/perl -w
#######################################################
# netcat.pl
# Written by: Brandon Zehm <caspian @ dotconf.net>
#
# License:
#
# netcat.pl (hereafter referred to as "program") is free software;
#   you can redistribute it and/or modify it under the terms of the GNU General
#   Public License as published by the Free Software Foundation; either version
#   2 of the License, or (at your option) any later version.
# Note that when redistributing modified versions of this source code, you
#   must ensure that this disclaimer and the above coder's names are included
#   VERBATIM in the modified code.
#
# Disclaimer:
# This program is provided with no warranty of any kind, either expressed or
#   implied.  It is the responsibility of the user (you) to fully research and
#   comprehend the usage of this program.  As with any tool, it can be misused,
#   either intentionally (you're a vandal) or unintentionally (you're a moron).
#   THE AUTHOR(S) IS(ARE) NOT RESPONSIBLE FOR ANYTHING YOU DO WITH THIS PROGRAM
#   or anything that happens because of your use (or misuse) of this program,
#   including but not limited to anything you, your lawyers, or anyone else
#   can dream up.  And now, a relevant quote directly from the GPL:
#
#                           NO WARRANTY
#
#  11. BECAUSE THE PROGRAM IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
# FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW.  EXCEPT WHEN
# OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
# PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED
# OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE ENTIRE RISK AS
# TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.  SHOULD THE
# PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
# REPAIR OR CORRECTION.
#
#   ---
#
# Whee, that was fun, wasn't it?  Now let's all get together and think happy
#   thoughts - and remember, the same class of people who made all the above
#   legal spaghetti necessary are the same ones who are stripping your rights
#   away with DVD CCA, DMCA, stupid software patents, and retarded legal
#   challenges to everything we've come to hold dear about our internet.
#   So enjoy your dwindling "freedom" while you can, because 1984 is coming
#   sooner than you think.  :[
#
#######################################################
use strict;
use Socket qw (:DEFAULT :crlf);
use IO::Socket;



## Global Variable(s)
my %conf = (
    "name"            => "netcat.pl",
    "version"         => "v0.65",
    "debug"           => "0",
    
    "passphrase"      => "The Default Pass-Phrase should be changed!",
    
    "mode"            => "",   ## This will either be 'server' or 'client'
    "server"          => "",   ## The remote server name/ip for client operation
    "port"            => "",   ## Local or remote port
    "timeout"         => "60",
    "disableDNS"      => "0", 
    "crypt"           => 0,
);







#############################
##
##      MAIN PROGRAM
##
#############################


## Process Command Line
processCommandLine();




###################
##  CLIENT MODE  ##
###################

if ($conf{'mode'} eq 'client') {  
  
  ## Connect to remote host:port
  my $result = connectTo($conf{'server'}, $conf{'port'}, $conf{'timeout'});
  
  ## Reset alarm()
  alarm(0);
  
  ## Print Connection Result
  quit($result,1) if ($result !~ /SUCCESS/);
  
  ## Send all data
  my $data = "";
  while (<STDIN>) {
    if ($conf{'crypt'}) {
      ## We want to break data into 16384 byte chuncks (this is so the encrypted data doesn't get out of allignment)
      $data .= $_;
      if (length($data) >= 16384) {
        $data =~ s/(.{16384})//s;
        $_ = RC4($conf{'passphrase'}, $&);
        print SERVER $_;
      }
    }
    else {
      print SERVER $_;
    }
  }
  
  ## If crypt'ing check for leftovers
  if ($conf{'crypt'}) {
    $_ = RC4($conf{'passphrase'}, $data) if ($data);
    print SERVER $_;
  }
  
  ## Disconnect
  disconnect();
  
  ## Quit
  quit("",0);

}





###################
##  SERVER MODE  ##
###################

elsif ($conf{'mode'} eq 'server') {  
  
  ## Open a socket and listen for an incoming connection
  alarm($conf{'timeout'});
  my $socket = IO::Socket::INET->new(        LocalPort => $conf{'port'},
                                             Proto => 'tcp',
                                             Listen => 1
  ) or quit("ERROR: Failed to open tcp port $conf{'port'}",1);
  my $data_socket = $socket->accept();  
  alarm(0);
  
  
  ## Recieve data and print to stdout
  my $data = "";
  while (<$data_socket>) {
    if ($conf{'crypt'}) {
      ## We want to break data into 16384 byte chuncks
      $data .= $_;
      if (length($data) >= 16384) {
        $data =~ s/(.{16384})//s;
        print RC4($conf{'passphrase'}, $&);
      }
    }
    else {
      print $_;
    }
  }
  
  ## If crypt'ing check for leftovers
  if ($conf{'crypt'}) {
    print RC4($conf{'passphrase'}, $data) if ($data);
  }
  
  ## Close network socket
  $data_socket->close();
  $socket->close();
  
  
  ## Quit
  quit("",0);

}
else {
  quit("Looks like some command line parameters were incorrect!\nTry \"$conf{'name'} --help\"\n", 1);
}































#########################################################
## SUB: help
##
## hehe, for all those newbies ;)
#########################################################
sub help {
print <<EOM;

$conf{'name'}-$conf{'version'} by Brandon Zehm <caspian\@dotconf.net>

Usage:  
  Connect to somewhere:   $conf{'name'} [-options] hostname port
  Listen for inbound:     $conf{'name'} -l -p port [-options]

Options:
    -l                      Listen mode, for inbound connects
    -n                      Numeric-only IP addresses, no DNS
    -p port                 Local port number
    -w secs                 Timeout for connects and final net reads
    -rc4                    RC4 encode/decode all data with a pass-phrase. *
                            * Set pass-prase by editing this script.
    
EOM
quit("", 1);
}











######################################################################
##  Function: initialize ()
##  
##  Does all the script startup jibberish.
##  
######################################################################
sub initialize {
  
  ## Set STDOUT to flush immediatly
  $| = 1;
  
  ## Intercept signals
  $SIG{'QUIT'}  = sub { quit("$$ - EXITING: Received SIG$_[0]", 1); };
  $SIG{'INT'}   = sub { quit("$$ - EXITING: Received SIG$_[0]", 1); };
  $SIG{'KILL'}  = sub { quit("$$ - EXITING: Received SIG$_[0]", 1); };
  $SIG{'TERM'}  = sub { quit("$$ - EXITING: Received SIG$_[0]", 1); };
  
  ## ALARM and HUP signals are not supported in Win32
  unless ($^O =~ /win/i) {
    $SIG{'HUP'}   = sub { quit("$$ - EXITING: Received SIG$_[0]", 1); };
    $SIG{'ALRM'}  = sub { quit("$$ - EXITING: Received SIG$_[0]", 1); };
  }
  
  return(1);
}











######################################################################
##  Function: processCommandLine ()
##  
##  Processes command line storing important data in global var %conf
##  
######################################################################
sub processCommandLine {
  
  
  ############################
  ##  Process command line  ##
  ############################
  
  my $numargv = @ARGV;
  my $counter = 0;
  for ($counter = 0; $counter < $numargv; $counter++) {
    
    if ($ARGV[$counter] =~ /^-l$/) {                    ## Listen Mode ##
      $conf{'mode'} = 'server';
    }
    
    elsif ($ARGV[$counter] =~ /^-n$/) {                 ## Numeric Only - (No DNS) ##
      $conf{'disableDNS'} = 1;
    }
    
    elsif ($ARGV[$counter] =~ /^-p$/) {                 ## Local Port ##
      $counter++;
      $conf{'port'} = $ARGV[$counter];
    }
    
    elsif ($ARGV[$counter] =~ /^-w$/) {                 ## Timeout ##
      $counter++;
      $conf{'timeout'} = $ARGV[$counter];
    }
    
    elsif ($ARGV[$counter] =~ /^-rc4$/) {               ## RC4 Encode/Decode Data ##
      $conf{'crypt'} = 1;
    }
    
    elsif ($ARGV[$counter] =~ /^-h$|^--help$/) {        ## Help ##
      help();
    }
    
    else {                                              ## Server ##
      
      if (!$conf{'mode'}) {
        $conf{'mode'} = 'client';
        $conf{'server'} = $ARGV[$counter];
        $counter++;
        $conf{'port'} = $ARGV[$counter];
      }
      else {
        quit("ERROR:  The option '$ARGV[$counter]' is unrecognised.\n");
      }
    }
  }
  
  
  
  ###################################################
  ##  Verify required variables are set correctly  ##
  ###################################################
  if (!$conf{'mode'}) {
    help();
  }
  if (!$conf{'port'}) {
    help();
  }
 
  
  return(1);
}













######################################################################
## Function: connectTo($server, $port, $timeout)
##           Assumes port is 80 if $port is blank.
##           Connects $server:$post to a global socket named
##           SERVER
##           Returns a text message describing the success or failure
######################################################################
sub connectTo {
  my %incoming = ();
  ## Get incoming variables
  ( 
    $incoming{'server'},
    $incoming{'port'},
    $incoming{'timeout'}
  ) = @_;
  
  print "$$ - connectTo() - sub entry\n" if ($conf{'debug'} > 5);
  my $return = 1;
  my $alarm = 0;
  
  ## Setup alarm()
  $SIG{'ALRM'}  = sub { setAlarmTrue(\$alarm, \$incoming{'timeout'}); };
  alarm($incoming{'timeout'});
  
  ## Check incoming variables
  $incoming{'port'} = 80 if (!$incoming{'port'});
  return("$$ - ERROR: connectTo() Incoming \$server variable was empty.") if ($incoming{'server'} eq "");
  
  ## Open a IP socket in stream mode with tcp protocol. 
  print "$$ - connectTo() - requesting a streaming tcp/ip socket from the system\n" if ($conf{'debug'} > 5);
  socket(SERVER, PF_INET, SOCK_STREAM, getprotobyname('tcp')) || ($return = 0);
  return("$$ - ERROR: [$incoming{'server'}:$incoming{'port'}] Connection timeout exceeded.") if ($alarm);
  return("$$ - ERROR: Problem opening a tcp/ip socket with the system.") if ($return == 0);
  
  ## Create the data structure $dest by calling sockaddr_in(port, 32bit IP)
  print "$$ - connectTo() - creating data structure from server name and port\n" if ($conf{'debug'} > 5);
  my $inet_aton = inet_aton($incoming{'server'})
    || return("$$ - ERROR: Hostname [$incoming{'server'}] DNS lookup failed.");
  return("$$ - ERROR: [$incoming{'server'}:$incoming{'port'}] Connection timeout exceeded.") if ($alarm);
  my $dest = sockaddr_in ($incoming{'port'}, $inet_aton) 
    || return("$$ - ERROR: Calling sockaddr_in() returned an error");
  return("$$ - ERROR: [$incoming{'server'}:$incoming{'port'}] Connection timeout exceeded.") if ($alarm);
  
  ## Connect our socket to SERVER
  print "$$ - connectTo() - connecting the socket to the server\n" if ($conf{'debug'} > 5);
  connect(SERVER, $dest) || ($return = 0);
  return("$$ - ERROR: [$incoming{'server'}:$incoming{'port'}] Connection timeout exceeded.") if ($alarm);
  return("$$ - ERROR: Connection attempt to [$incoming{'server'}:$incoming{'port'}] failed!") if ($return == 0);
  print "$$ - connectTo() - successfully connected to $incoming{'server'}:$incoming{'port'}\n" if (($conf{'debug'} > 5) && ($return));
   
  ## Return success
  print "$$ - connectTo() - sub exit: returning [$return]\n" if ($conf{'debug'} > 5);
  return("$$ - SUCCESS: Connection to [$incoming{'server'}:$incoming{'port'}] succeeded.");
}




sub setAlarmTrue {
  ${$_[0]}=1;
  $SIG{'ALRM'}  = sub { setAlarmTrue($_[0]); };
  alarm(${$_[1]});
}











######################################################################
##  Function: RC4 ($passphrase, $plaintext) or
##                ($passphrase, $encrypted)
##  
##  The following code was pulled from the perl package:
##  Crypt::RC4 - Perl implementation of the RC4 encryption algorithm
##  
##  Synopsis:
##            $encrypted = RC4( $passphrase, $plaintext );
##            $decrypt = RC4( $passphrase, $encrypted );
######################################################################
sub RC4 {
        my $x = 0;
        my $y = 0;
        
        my $key = shift;
        my @k = unpack( 'C*', $key );
        my @s = 0..255;
        
        for ($x = 0; $x != 256; $x++) {
                $y = ( $k[$x % @k] + $s[$x] + $y ) % 256;
                @s[$x, $y] = @s[$y, $x];
        }
 
        $x = $y = 0;
 
        my $z = undef;
        
        for ( unpack( 'C*', shift ) ) {
                $x = ($x + 1) % 256;
                $y = ( $s[$x] + $y ) % 256;
                @s[$x, $y] = @s[$y, $x];
                $z .= pack ( 'C', $_ ^= $s[( $s[$x] + $s[$y] ) % 256] );
        }
 
        return $z;
}












######################################################################
# SUB: disconnect()
# Closes the SERVER socket.
# Returns 1 on success 0 on failure.
######################################################################
sub disconnect {
  print "$$ - disconnect() - sub entry\n" if ($conf{'debug'} > 5);
  my $return = 1;
  if (!(close SERVER)) {              ## and drop the connection.
  ##  print "$$ - ERROR:  There was an error disconnecting form the server\n";
    $return = 0;                      ## Return failure if we didn't disconnect correctly
  } 
  print "$$ - disconnect() - disconnected from the server successfully\n" if ($conf{'debug'} > 5);
  print "$$ - disconnect() - sub exit: returning [$return]\n" if (($conf{'debug'} > 5) && ($return));
  return($return);                    ## Return
}


















######################################################################
##  Function: quit (string $message, int $errorLevel)
##  
##  Exits the program, optionally printing $message.  It returns
##  an exit error level of $errorLevel to the system (0 means no
##  errors, and is assumed if empty.)
##
######################################################################
sub quit {
  my %incoming = ();
  (
    $incoming{'message'},
    $incoming{'errorLevel'}
  ) = @_;
  $incoming{'errorLevel'} = 0 if (!defined($incoming{'errorLevel'}));
  
  
  ## Print exit message
  if ($incoming{'message'} ne "") { 
    print "$incoming{'message'}\n";
  }
  
  ## Exit
  exit($incoming{'errorLevel'});
}





