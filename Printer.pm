############################################################################
############################################################################
##                                                                        ##
##    Copyright 2001 Stephen Patterson (s.patterson@freeuk.com)           ##
##                                                                        ##
##    A cross platform perl printer interface                             ##
##    This code is made available under the perl artistic licence         ##
##                                                                        ##
##    Documentation is at the end (search for __END__)                    ##
##                                                                        ##
############################################################################
############################################################################

package Printer;
$VERSION = '0.93';

use English;
use strict;
no strict 'refs';
use Carp qw(croak, cluck);
use vars qw(%Env);
# load environment variables which contain the default printer name (Linux)
# (from the lprng lpr command manpage)
# and the windows temp directory spec as well.
use Env qw(PRINTER LPDEST NPRINTER NGPRINTER TEMP);

# macperl $OSNAME is /^macos/i; 

#############################################################################
sub new {
    # constructor
    my $type = shift;
    my %params = @ARGS;
    my $self = {};

    $self->{'system'} = $OSNAME;

    # frob the system value to use linux routines below for the
    # various unices
    # see perldoc perlport for system names
    if ($OSNAME eq ('aix' or 'bsdos' or 'dgux' or 'dynixptx' or
		    'freebsd' or 'hpux' or 'irix' or 'rhapsody' or
		    'machten' or ' next' or 'openbsd' or 'dec_osf'
		    or 'svr4' or 'sco_sv' or 'unicos' or 'unicosmk'
		    or 'solaris' or 'sunos') ) {
	$self->{'system'} = 'linux';
    }
		    

    # load system specific modules 
    BEGIN {
	if ($self->{'system'} eq "MSWin32") {
	    require Win32::Registry;  # to list printers
	    require Win32::AdminMisc; # to find out the windows version
	}
    }
    $self->{'printer'} = \%params;

    # die with an informative message if using an unsupported platform.
    unless ($self->{'system'} eq 'linux' or $self->{'system'} eq 'MSWin32') {
      Carp::croak 'Platform $OSNAME is not yet supported';
	return undef;
    }
    return bless $self, $type;

}
############################################################################
sub list_printers {
    # list available printers
    my $self = shift;
    my %printers;

    # linuxish systems
    if ($self->{'system'} eq "linux") {
	open (PRINTCAP, '</etc/printcap') or 
	  Carp::croak "Can't read /etc/printcap: $!";
	my @prs;
	while (<PRINTCAP>) {
	    if ($ARG =~ /\|/) {
		chomp $ARG;
		$ARG =~ s/\|.*//;
		push @prs, $ARG;
	    }
	}
	$printers{name} = [ @prs ];
	$printers{port} = [ @prs ];
    } # end linux

    # win32
    elsif ($self->{'system'} eq "MSWin32") {
	# look at registry to get printer names for local machine
	my $Register = 'SYSTEM\CurrentControlSet\Control\Print\Printers';
	my ($hkey, @key_list, @names, @ports);
	
	my $HKEY_LOCAL_MACHINE = $main::HKEY_LOCAL_MACHINE;
	
	$HKEY_LOCAL_MACHINE->Open($Register, $hkey) or 
	    Carp::croak 'Can\'t open registry key $path: $!';
	$hkey->GetKeys(\@key_list);
	foreach my $key (@key_list) {
	    my $path = $Register . "\\$key";
	    my ($pkey, %values, $printers);
	    $HKEY_LOCAL_MACHINE->Open($path, $pkey) or 
	    Carp::croak 'Can\'t open registry key $path: $!';
	    $pkey->GetValues(\%values);
	    push @ports, $values{Port}[2];
	    push @names, $values{Name}[2];
	    }
	$printers{name} = [ @names ];
	$printers{port} = [ @ports ];
    } #end win32
    return %printers;
}
#############################################################################
sub use_default {
    # select the default printer
    my $self = shift;
 
    # linuxish systems
    if ($self->{'system'} eq "linux") {
	if ($Env{PRINTER}) {
	    $self->{'printer'}{$OSNAME} = $Env{PRINTER};
	} elsif ($Env{LPDEST}) {
	    $self->{'printer'}{$OSNAME} = $Env{LPDEST};
	} elsif ($Env{NPRINTER}) {
	    $self->{'printer'}{$OSNAME} = $Env{NPRINTER};
	} elsif ($Env{NGPRINTER}) {
	    $self->{'printer'}{$OSNAME} = $Env{NGPRINTER};
	} else {
	    cluck 'I can\'t determine your default printer, setting it to lp'; 
	    $self->{'printer'}{$OSNAME} = "lp";
	}
    }
    # windows
    elsif ($self->{'system'} eq "MSWin32") {
	# default name is the human readable printer name (not port)
	# look in the registry to find it
	my $register = 'Config\0001\SYSTEM\CurrentControlSet\Control\Print\Printers';
	my ($hkey, %values);
	my $HKEY_LOCAL_MACHINE = $main::HKEY_LOCAL_MACHINE;
	$HKEY_LOCAL_MACHINE->Open($register, $hkey) or 
	    Carp::croak 'Can\'t open registry key $path: $!';
	$hkey->GetValues(\%values);
	my $default = $values{Default}[2];
      
        # $default now holds the human readable printer name, get the 
	# name of the corresponding port.
	my $register = 'SYSTEM\CurrentControlSet\control\Print\Printers';
	my $path = $register . $default;
	$HKEY_LOCAL_MACHINE->Open($path, $hkey) or 
	    Carp::croak 'Can\'t open registry key $path: $!';
	$hkey->GetValues(\%values);
	$self->{'printer'}{$OSNAME} = $values{Port}[2];
    } # end win32
}
############################################################################
sub get_unique_spool {
    # used currently for Win95 only. Get a filename to use as the
    # spoolfile without overwriting another file
    my $i;
    while (-e "$ENV{TEMP}/printer-$PID.$i") {
	++$i;
    }
    return "$ENV{TEMP}/printer-$PID.$i";
}
############################################################################
sub print {
    # print
    my $self = shift;
    my $data;
    foreach (@ARGS) {
	$data .= $ARG;
    }

    # linuxish systems
    if ($self->{'system'} eq "linux") {
	open PRINTER, "|lpr -P$self->{'printer'}{$OSNAME}" 
	    or Carp::croak "Can't open printer connection to $self->{'printer'}{$OSNAME}: $!";
	print PRINTER $data;
	close PRINTER;
    }

    # windows
    elsif ($self->{'system'} eq "MSWin32") {
	# see which windows platform this is being run on.
	my %win_info = GetWinVersion();
	
	# Windows NT (tested on NT4)
	if ($win_info{Platform} eq "Win32_NT") {
	    open SPOOL, ">>" . $self->{'printer'}{$OSNAME} or
	      Carp::croak "Can't open print spool $self->{'printer'}: $!" ;
	    print SPOOL $data or 
	      Carp::croak "Can't write to print spool $self->{'printer'}: $!";
	    close SPOOL;
	} 
	
	# windows 9X
	elsif ($win_info{Platform} =~ /^Win32_9/) {
	    my $spoolfile = get_unique_spool();
	    open SPOOL, ">" . $spoolfile;
	    print SPOOL $data;
	    system("copy /B $spoolfile $self->{'printer'}{$OSNAME}");
	    unlink $spoolfile;
	}
    } #end windows
}
#############################################################################
sub list_jobs {
    # list the current print queue
    my $self = shift;
    my @queue;
    
    # linuxish systems
    if ($self->{'system'} eq "linux") {
	my @lpq = `lpq -P$self->{'printer'}{$OSNAME}`;
	chomp @ARGS;
        # lprng returns
	# Printer: lp@localhost 'HP Laserjet 4Si' (dest raw1@192.168.1.5)
	# Queue: 1 printable job
	# Server: pid 7145 active
	# Status: job 'cfA986localhost.localdomain' removed at 15:34:48.157
	# Rank   Owner/ID            Class Job Files           Size Time
        # 1      steve@localhost+144   A   144 (STDIN)          708 09:45:35
	
	# BSD lpq returns
	# lp is ready and printing
	# Rank   Owner   Job  Files        Total Size
	# active mwf     31   thesis.txt   682048 bytes

	if ($queue[0] =~ /^Printer/) {
	    # first line of lpq starts with Printer
            # lprng spooler, skip first 5 lines
	    for (my $i = 5; $i < @lpq; ++$i) {
		push(@queue, $lpq[$i]);
	    }
	} elsif ($queue[1] =~/^Rank/) {
	    # second line of lpq starts with Rank
	    # BSD  spooler, skip first 2 lines
	    for (my $i = 2; $i < @lpq; ++$i) {
		push @queue, $lpq[$i];
	    }
	}
    } # end linux
    
    elsif ($self->{'system'} eq "MSWin32") {
	# I have no idea
	# return an empty queue (for compatibility)
      Carp::croak 'This code segment hasn\'t yert been written. Share and enjoy';
    }
    return @queue;
}
#############################################################################
1;
#############################################################################
__END__

=head1 NAME 

Printer.pm - a low-level, platform independent printing interface
(curently Linux and MS Win32. other UNIXES should also work.)

This version includes working support for Windows 95.

=head1 SYNOPSIS
    
    use Printer;
    
    $prn = new Printer('linux' => 'lp', 
	               'MSWin32' => 'LPT1', 
		       $OSNAME => 'Printer');

    @available_printers = $prn->list_printers;

    $prn->use_default;

    $prn->print($data);


=head1 DESCRIPTION

A low-level cross-platform interface to system 
printers. 

This module is intended to allow perl programs to use and query
printers on any computer system capable of running perl. The
intention of this module is for a program to be able to use the
printer without having to know which operating system is being
used.


=head1 PLATFORMS

This code has been tested on Linux, windows 95 and windows NT4. 

I've added possible UNIX support, using the Linux routines. This
assumes that your print command is lpr, your queue list command is
lpq and that your printer names can be found by grepping
/etc/printcap. If it's anything different, email me with the value
of C<$OSNAME> or C<$^O> and the corrections.

=head1 USAGE


=head2 Open a printer handle

       $printer = new Printer('osname' => 'printer port');
       $printer = new Printer('MSWin32' => 'LPT1', 
			      'Linux' => 'lp');

This method takes a hash to set the printer
name to be used for each operating system that this module is to
be used on (the hash keys are the values of $^O or $OSNAME for
each platform) and returns a printer handle which 
is used by the other methods.

This method dies with an error message on unsupported platforms.

=head2 Select the default printer

       $printer->use_default;

=head3 Linux
    
The default printer is read from the environment variables 
$PRINTER, $LPDEST, $NPRINTER, $NGPRINTER in that order, or is set to
"lp" if these variables are not defined. You will be warned if
this happens.

=head3 Win32

THe default printer is read from the registry (trust me, this works).

=head2 List available printers
     
     %hash = $printer->list_printers.
    
This returns a hash of arrays listing all available printers. 
The hash keys are:

=over 4

=item * C<%hash{names}> - printer names

=item * C<%hash{ports}> - printer ports

=back

=head2 Print

       $printer->print($data);

Print a scalar value onto the print server through a pipe (like Linux)

=head2 List queued jobs

       @jobs = $printer->list_jobs;

=head3 Linux
    
Each cell of the array returned is an entire line from the
system's lpq command.

=head3 Windows

The array returned is empty (for compatibility).

=head3 Warning

This method will probably return a hash in future when I've
figured out how to access the print queue on windows. 

=head1 BUGS

list_queue needs writing for win32

=head1 AUTHOR

Stephen Patterson <s.patterson@freeuk.com>

=head1 TODO
    
Make list_queue work on windows.

Test and fully port to UNIX.

Port to MacOS.

=head1 Changelog

=head2 0.93

=over 4

=item * Printing on windows 95 now uses a unique spoolfile which
    will not overwrite an existing file.

=item * Documentation spruced up to look like a normal linux manpage.

=head2 0.92

=over 4

=item * Carp based error tracking introduced.

=back

=head2 0.91

=over 4

=item * Use the linux routines for all UNIXES.
    
=back

=head2 0.9
    
Initial release version
