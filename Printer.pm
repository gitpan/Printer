############################################################################
############################################################################
##                                                                        ##
##    Copyright 2001 Stephen Patterson (s.patterson@freeuk.com)           ##
##                                                                        ##
##    A cross platform perl printer interface                             ##
##    This code is made available under the GPL version 2 or later        ##
##                                                                        ##
############################################################################
############################################################################

package Printer;
$VERSION = '0.9';

use English;
use strict;
no strict 'refs';
my %Env;
# load environment variables which contain the default printer name (Linux)
# (from the lprng lpr command manpage)
use Env qw(PRINTER LPDEST NPRINTER NGPRINTER);

# macperl $OSNAME is /^macos/i; 

#############################################################################
sub new {
    # constructor
    my $type = shift;
    my %params = @_;
    my $self = {};

    # load system specific modules 
    BEGIN {
	if ($OSNAME eq "MSWin32") {
	    require Win32::Registry;  # to list printers
	    require Win32::AdminMisc; # to find out the windows version
	}
    }
    $self->{'printer'} = \%params;
    return bless $self, $type;

}
############################################################################
sub list_printers {
    # list available printers
    my $self = shift;
    my %printers;

    # linux
    if ($OSNAME eq "linux") {
	open (PRINTCAP, '</etc/printcap') || die "Can't read printcap";
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
    elsif ($OSNAME eq "MSWin32") {
	# look at registry to get printer names for local machine
	my $Register = "SYSTEM\\CurrentControlSet\\Control\\Print\\Printers";
	my ($hkey, @key_list, @names, @ports);
	
	my $HKEY_LOCAL_MACHINE = $main::HKEY_LOCAL_MACHINE;
	
	$HKEY_LOCAL_MACHINE->Open($Register, $hkey);
	$hkey->GetKeys(\@key_list);
	foreach my $key (@key_list) {
	    my $path = $Register . "\\$key";
	    my ($pkey, %values, $printers);
	    $HKEY_LOCAL_MACHINE->Open($path, $pkey);
	    $pkey->GetValues(\%values);
	    push @ports, $values{Port}[2];
	    push @names, $values{Name}[2]; # Fix this
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
 
    # linux
    if ($OSNAME eq "linux") {
	if ($Env{PRINTER}) {
	    $self->{'printer'}{$OSNAME} = $Env{PRINTER};
	} elsif ($Env{LPDEST}) {
	    $self->{'printer'}{$OSNAME} = $Env{LPDEST};
	} elsif ($Env{NPRINTER}) {
	    $self->{'printer'}{$OSNAME} = $Env{NPRINTER};
	} elsif ($Env{NGPRINTER}) {
	    $self->{'printer'}{$OSNAME} = $Env{NGPRINTER};
	} else {
	    $self->{'printer'}{$OSNAME} = "lp";
	}
    }
    # windows
    elsif ($OSNAME eq "MSWin32") {
	# default name is the human readable printer name (not port)
	# look in the registry to find it
	my $register = "Config\\0001\\SYSTEM\\CurrentControlSet\\Control\\Print\\Printers";
	my ($hkey, %values);
	my $HKEY_LOCAL_MACHINE = $main::HKEY_LOCAL_MACHINE;
	$HKEY_LOCAL_MACHINE->Open($register, $hkey);
	$hkey->GetValues(\%values);
	my $default = $values{Default}[2];
      
        # $default now holds the human readable printer name, get the 
	# name of the corresponding port.
	my $register = "SYSTEM\\CurrentControlSet\\control\\Print\\Printers\\";
	my $path = $register . $default;
	$HKEY_LOCAL_MACHINE->Open($path, $hkey);
	$hkey->GetValues(\%values);
	$self->{'printer'}{$OSNAME} = $values{Port}[2];
    } # end win32
}
############################################################################
sub print {
    # print
    my $self = shift;
    my $data;
    foreach (@_) {
	$data .= $_;
    }

    # linux
    if ($OSNAME eq "linux") {
	open PRINTER, "|lpr -P$self->{'printer'}{$OSNAME}" 
	    || die "Can't open printer connection to $self->{'printer'}{$OSNAME}: $!";
	print PRINTER $data;
	close PRINTER;
    }

    # windows
    elsif ($OSNAME eq "MSWin32") {
	# see which windows platform this is being run on.
	my %win_info = GetWinVersion();
	
	# Windows NT (testted on NT4)
	if ($win_info{Platform} eq "Win32_NT") {
	    open SPOOL, ">>" . $self->{'printer'}{$OSNAME};
	    print SPOOL $data;
	    close SPOOL;
	} 
	
	# windows 95
	elsif ($win_info{Platform} eq "Win32_95") {
	    my $spoolfile = undef;
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
    
    # linux
    if ($OSNAME eq "linux") {
	my @lpq = `lpq -P$self->{'printer'}{$OSNAME}`;
	chomp @_;
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
	    # lprng spooler, skip first 5 lines
	    for (my $i = 5; $i < @lpq; ++$i) {
		push(@queue, $lpq[$i]);
	    }
	} elsif ($queue[1] =~/^Rank/) {
	    # BSD  spooler, skip first 2 lines
	    for (my $i = 2; $i < @lpq; ++$i) {
		push @queue, $lpq[$i];
	    }
	}
    } # end linux
    
    elsif ($OSNAME eq "MSWin32") {
	# I have no idea
	# return an empty queue (for compatibility)
    }
    return @queue;
}
#############################################################################
1;
#############################################################################
__END__

=head1 NAME
    Printer.pm 
    
    low-level, platform independent printing (curently Linux and 
    MS Win32. other UNIXES should also work.)

=head1 SYNOPSIS
    
    use Printer;
    
    $prn = new Printer('lp');

    @available_printers = $prn->list_printers;

    $prn->use_default;

    $prn->{'printer'} = 'foo';

    $prn->print($data);

=head1 DESCRIPTION
    A low-level cross-platform interface to system 
    printers. 

    This module is intended to allow perl programs to use and query
    printers on any computer system capable of running perl. The
    intention of this module is for a program to be able to use the
    printer without having to know which operating system is being
    used.

=head1 USAGE


=head2 Open a printer handle

    $printer = new Printer('osname' => 'printer port');
    $printer = new Printer('MSWin32' => 'LPT1', 'Linux' => 'lp');

    This method takes a hash to set the printer
    name to be used for each operating system that this module is to
    be used on (the hash keys are the values of $^O or $OSNAME for
    each platform) and returns a printer handle which 
    is used by the other methods.

=head2 Select the default printer

    $printer->use_default;

    =head3 Linux
    
    The default printer is read from the environment variables 
    $PRINTER, $LPDEST, $NPRINTER, $NGPRINTER in that order, or is set to
    "lp" if these variables are not defined. 

    =head3 Win32

    THe default printer is read from the registry (trust me, this works).

=head2 List available printers
     
    %hash = $printer->list_printers.
    
    This returns a hash of arrays listing all available printers. 
    The hash keys are:

    =over 4

    =item * %hash{names} - printer names

    =item * %hash{ports} - printer ports

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

    List_jobs needs writing for win32

=head1 TESTED PLATFORMS

    This module has been tested under Linux, Windows NT4 and Windows 95.
    Testers and developers are wanted for all other platforms.

=head1 AUTHOR
    Stephen Patterson <s.patterson@freeuk.com>

=head1 TODO
    
    Make printer name a $OSNAME keyed hash.
    Make list_queue work on windows.
