############################################################################
############################################################################
##                                                                        ##
##    Copyright 2001 Stephen Patterson (s.patterson@freeuk.com)           ##
##                                                                        ##
##    A cross platform perl printer interface                             ##
##    This code is made available under the perl artistic licence         ##
##                                                                        ##
##    Documentation is at the end (search for __END__) or process with    ##
##    pod2man/pod2text/pod2html                                           ##
##                                                                        ##
##    Debugging and code contributions from:                              ##
##    David W Phillips (ss0300@dfa.state.ny.us)                           ##
##                                                                        ##
############################################################################
############################################################################

package Printer;
$VERSION = '0.95';

use English;
use strict;
no strict 'refs';
use Carp qw(croak cluck);
use vars qw(%Env @ISA);

# load environment variables which contain the default printer name (Linux)
# (from the lprng lpr command manpage)
# and the windows temp directory spec as well.
use Env qw(PRINTER LPDEST NPRINTER NGPRINTER TEMP PATH);

# macperl $OSNAME is /^macos/i; 

#############################################################################
sub new {
    # constructor
    my $type = shift;
    my %params = @_;
    my $self = {};

    $self->{system} = $OSNAME;

    # frob the system value to use linux routines below for the
    # various unices
    # see perldoc perlport for system names
    if (grep { /^$OSNAME$/  } qw(aix     bsdos  dgux   dynixptx 
				 freebsd hpux   irix   rhapsody
				 machten next   openbsd dec_osf
				 svr4    sco_sv unicos  unicosmk
				 solaris sunos) ) {
	$self->{system} = 'linux';

	# search PATH for lpr, lpq, lp, lpstat (use first found)            DWP
	my %progs;                                        # will hold prg locs  DWP
	my @PathDirs = grep {/^[^\.]/} (split /:/,$PATH); # paths, no ./..      DWP
	foreach my $dir ( @PathDirs ) {                   # go down path        DWP
	    foreach my $prg ( qw(lpr lpq lp lpstat) ) {   # check each prg      DWP
		next if exists $progs{$prg};              # skip if found       DWP
		my $loc = "$dir/$prg";                    #                     DWP
		-f $loc && -x $loc && ($progs{$prg}=$loc);# save location       DWP
		}                                                                 # DWP
	}                                                                     # DWP
	$self->{'program'} = \%progs;                     # include locs in obj DWP
	
    }
    

    # load system specific modules
    BEGIN {
	if ($^O eq "MSWin32") {
	    # win32 specific modules
	    require Win32::Registry;  # to list printers
	    require Win32;
	}
    }

    $self->{printer} = \%params;

    # die with an informative message if using an unsupported platform.
    unless ($self->{system} eq 'linux' or $self->{system} eq 'MSWin32') {
	Carp::croak "Platform $OSNAME is not yet supported. Share and enjoy.";
	  return undef;
      }
    return bless $self, $type;

}
############################################################################
sub print_command {
    # allow users to specify a print command to use for a system
    my $self = shift();
    my %systems = @_;
    my %final_data;
    
    foreach my $system (keys %systems) {
	foreach my $opt (keys %{ $systems{$system} }) {
	    my %cmd_data = %{ $systems{$system} };
	    $final_data{$system} = \%cmd_data;
	}
    }
    
    $self->{print_command} = \%final_data;
    
}
############################################################################
sub list_printers {
    # list available printers
    my $self = shift();
    my %printers;


    # linuxish systems
    if ($self->{system} eq "linux") {
        my @prs;
        if ( -f '/etc/printcap' ) {                                         
            # DWP - linux, dec_osf
            open (PRINTCAP, '</etc/printcap') or 
		Carp::croak "Can't read /etc/printcap: $!";
            while (<PRINTCAP>) {
                if ($ARG =~ /^\w/) {
                    chomp $ARG;
                    $ARG =~ s!\\!!;
		    $ARG =~ s!|.*!!;
                    push @prs, $ARG;
                }
            }
        } elsif ( -f '/etc/printers.conf' ) {                               
            # DWP - solaris
            open (PRINTCNF, '</etc/printers.conf') or                       
		Carp::croak "Can't read /etc/printers.conf: $!";              
            while (<PRINTCNF>) {                                            
                if ($ARG =~ /\|/ or $ARG =~ /^[^:]+:\\/) {                  
                    chomp $ARG;                                             
                    $ARG =~ s/[\|:].*//;                                    
                    push @prs, $ARG unless $ARG =~ /^_(?:all|default)/i;    
                }                                                           
            }                                                               
        } elsif ( -d '/etc/lp/member' ) {                                   
            # DWP - hpux
            opendir (LPMEM, '/etc/lp/member') or                            
		Carp::croak "Can't readdir /etc/lp/member: $!";               
            @prs = grep { /^[^\.]/ && -f "/etc/lp/member/$_" } readdir(LPMEM);
        }                                                                   
        $printers{name} = [ @prs ];
        $printers{port} = [ @prs ];
    } # end linux

    # win32
    elsif ($self->{system} eq "MSWin32") {
       	# look at registry to get printer names for local machine
	my $Register = 'SYSTEM\CurrentControlSet\Control\Print\Printers';
	my ($hkey, @key_list, @names, @ports);
	
	my $HKEY_LOCAL_MACHINE = $main::HKEY_LOCAL_MACHINE;
	
	$HKEY_LOCAL_MACHINE->Open($Register, $hkey) or 
	    Carp::croak "Can't open registry key $Register: $!";
	$hkey->GetKeys(\@key_list);
	foreach my $key (@key_list) {
	    my $path = $Register . "\\$key";
	    my ($pkey, %values, $printers);
	    $HKEY_LOCAL_MACHINE->Open($path, $pkey) or 
		Carp::croak "Can\'t open registry key $path: $!";
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
	} elsif ( open LPDEST, 'lpstat -d |' ) {
            # DWP - lpstat -d
	    my @lpd = grep { /system default destination/i } <LPDEST>;
	    if ( @lpd == 0 ) {                                        
		Carp::cluck 'I can\'t determine your default printer, setting it to lp';
		  $self->{'printer'}{$OSNAME} = "lp";                            
	      } elsif ( $lpd[-1] =~ /no system default destination/i ) {     
		  Carp::cluck 'No default printer specified, setting it to lp';    
		    $self->{'printer'}{$OSNAME} = "lp";                        
		} elsif ( $lpd[-1] =~ /system default destination:\s*(\S+)/i ) {
		    $self->{'printer'}{$OSNAME} = $1;
		} 
	} else {
	    cluck 'I can\'t determine your default printer, setting it to lp'; 
	    $self->{'printer'}{$OSNAME} = "lp";
	}
	print "Linuxish default = $self->{printer}{$OSNAME}\n\n";
        # DWP - test
    } # end linux

    # windows
    elsif ($self->{system} eq "MSWin32") {
	# default name is the human readable printer name (not port)
	# look in the registry to find it
	my $register = 'Config\0001\SYSTEM\CurrentControlSet\Control\Print\Printers';
	my ($hkey, %values);
	my $HKEY_LOCAL_MACHINE = $main::HKEY_LOCAL_MACHINE;
	$HKEY_LOCAL_MACHINE->Open($register, $hkey) or 
	    Carp::croak "Can't open registry key $register: $!";
	$hkey->GetValues(\%values);
	my $default = $values{Default}[2];
	
        # $default now holds the human readable printer name, get the 
	# name of the corresponding port.
	my $register = 'SYSTEM\CurrentControlSet\control\Print\Printers';
	my $path = $register . $default;
	$HKEY_LOCAL_MACHINE->Open($path, $hkey) or 
	    Carp::croak "Can't open registry key $path: $!";
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
    foreach (@_) {
	$data .= $_;
    }

    # linuxish systems
    if ($self->{'system'} eq "linux") {
	# use standard print command
	unless ($self->{print_command}) {
	    # use available print program, lpr preferred      # DWP
	    my $lpcmd;                                     # DWP
	    if ( exists $self->{'program'}{'lpr'} ) {      # DWP
		$lpcmd = $self->{'program'}{'lpr'}.' -P'   # DWP
		} elsif ( exists $self->{'program'}{'lp'} ) {  # DWP
		    $lpcmd = $self->{'program'}{'lp'}.' -d'    # DWP
		    } else {                                       # DWP
			Carp::croak "Can't find lpr or lp program for print function" # DWP
			}                                              # DWP
	    open PRINTER, "| $lpcmd$self->{'printer'}{$OSNAME}" # DWP- use $lpcmd for lpr/lp
		or Carp::croak "Can't open printer connection to $self->{'printer'}{$OSNAME}: $!";
	    print PRINTER $data;
	    close PRINTER;
	} else {
	    # user has specified a custom print command
	    if ($self->{print_command}->{linux}->{type} eq 'pipe') {
		# command accepts piped data
		open PRINTER, "| $self->{print_command}->{linux}->{command}"
		    or Carp::croak "Can't open printer connection to $self->{print_command}->{linux}->{command}";
		print PRINTER $data;
		close PRINTER;
	    } else {
		# command accepts file data, not piped
		
		# write $data to a temp file
		my $spoolfile = &get_unique_spool();
		open SPOOL, ">" . $spoolfile;
		print SPOOL $data;
		system("copy /B $spoolfile $self->{'printer'}{$OSNAME}");

		# place filename in command
		my $cmd = $self->{print_command}->{linux}->{command};
		
		# print
		system($cmd) or 
		    Carp::croak "Can't execute print command: $cmd, $!\n"; 
		
		unlink $spoolfile;
	    }

	}
    } # end linux ############################################################


    # windows ################################################################
    elsif ($self->{'system'} eq "MSWin32") {
	
	unless ($self->{print_command}) {
	    # default pipish method

	    # Windows NT (tested on NT4)
	    if (Win32::IsWinNT() ) {
		open SPOOL, ">>" . $self->{'printer'}{$OSNAME} or
		    Carp::croak "Can't open print spool $self->{'printer'}{$OSNAME}: $!" ;
		print SPOOL $data or 
		    Carp::croak "Can't write to print spool $self->{'printer'}: $!";
		close SPOOL;
	    } 
	    
	    # any other windows version
	    else {
		my $spoolfile = get_unique_spool();
		open SPOOL, ">" . $spoolfile;
		print SPOOL $data;
		close SPOOL;
		system("copy /B $spoolfile $self->{printer}{$OSNAME}");
		unlink $spoolfile;
	    }

	} else {
	    # custom print command
	    if ($self->{print_command}->{MSWin32}->{type} eq 'file') {
		# non-pipe accepting command - use a spoolfile
		my $cmd = $self->{print_command}->{MsWin32}->{command};
		my $spoolfile = get_unique_spool();
		open SPOOL, ">" . $spoolfile;
		print SPOOL $data;
		system("$cmd") || Carp::croak $OS_ERROR;
		unlink $spoolfile;
	    } else {
		# pipe accepting command
		# can't use this - windows perl doesn't support pipes.
	    }
	}
    } # end windows
} 
#############################################################################
sub list_jobs {
    # list the current print queue
    my $self = shift;
    my @queue;
    
    # linuxish systems
    if ($self->{'system'} eq "linux") {
	# use available query program, lpq preferred      # DWP
	my $lpcmd;                                     # DWP
	if ( exists $self->{'program'}{'lpq'} ) {      # DWP
	    $lpcmd = $self->{'program'}{'lpq'}.' -P'   # DWP
	    } elsif ( exists $self->{'program'}{'lpstat'} ) { # DWP
		$lpcmd = $self->{'program'}{'lpstat'}.' -o' # DWP
		} else {                                       # DWP
		    Carp::croak "Can't find lpq or lpstat prog for jobs function" # DWP
		    }                                              # DWP
	my @lpq = `$lpcmd$self->{'printer'}{$OSNAME}`;     # DWP-use lpcmd for lpq/lpstat
	chomp @_;
	# lprng returns
	# Printer: lp@localhost 'HP Laserjet 4Si' (dest raw1@192.168.1.5)
	# Queue: 1 printable job
	# Server: pid 7145 active
	# Status: job 'cfA986localhost.localdomain' removed at 15:34:48.157
	# Rank   Owner/ID            Class Job Files           Size Time
	# 1      steve@localhost+144   A   144 (STDIN)          708 09:45:35
	
	my $pr = $self->{'printer'}{$OSNAME};                             

	if ($lpq[0] =~ /^Printer/) {              # DWP - said queue, should be lpq
	    # first line of lpq starts with Printer
	    # lprng spooler, skip first 5 lines
	    for (my $i = 5; $i < @lpq; ++$i) {
		push @queue, join(' ',(split(/\s+/,$lpq[$i]))[0,1,3..5]);         # DWP - fix to exclude class
	    }
	} elsif ($lpq[1] =~/^Rank/) {                      # DWP - said queue, should be lpq
	    # second line of BSD & solaris lpq starts with Rank                 DWP - compressed doc, inc solaris
	    # Rank   Owner   Job  Files        Total Size                       DWP - compressed doc
	    # active mwf     31   thesis.txt   682048 bytes                     DWP - compressed doc
	    for (my $i = 2; $i < @lpq; ++$i) {
		push @queue, $lpq[$i];
	    }
	} elsif ($lpq[0] =~ /^$pr-\d+\s+/ and $lpq[1] =~ / bytes/) {          # DWP
	    # hpux lpstat -o has multi-line entries                             DWP
	    #NE1-9638            da0240         priority 0  Mar 14 14:53 on NE1 DWP
	    #        (standard input)                          661 bytes        DWP
	    #NE1-110             ss0300         priority 0  Oct 19 12:51        DWP
	    #        mediafas             [ 3 copies ]       69 bytes           DWP
	    #        rescan               [ 3 copies ]       62 bytes           DWP
	    my @job;                                                          # DWP
	    foreach my $line ( @lpq ) {                                       # DWP
		if ( $line =~ /^($pr-\d+)\s+(\S+)\s+priority/ ) {             # DWP
		    if ( @job ) {                             # previous job    DWP
			push @queue, join(' ',@job);                          # DWP
			@job<5 and Carp::cluck "Short job entry: $queue[-1] ";# DWP
			}                                                         # DWP
		    @job = ( 'active', $2, $1 );              # rank,owner,job  DWP
		} elsif ( $line =~ /^\s*(\S+|\(.+\))\s.*\s(\d+)\s+bytes/ ) {  # DWP
		    $job[3] = $job[3] ? $job[3].",$1" : $1;   # add file(s)     DWP
		    my $sz = $2;                                              # DWP
		    $line =~ /\s(\d+)\s+copies/ and ( $sz *= $1 ); # copies?    DWP
		    $job[4] = $job[4] ? $job[4].",$sz" : $sz; # add size(s)     DWP
		    $job[3] =~ s/ /_/g;                       # elim spaces     DWP
		}                                                             # DWP
	    }                                                                 # DWP
	} elsif ( ($lpq[1] !~ /\S/) and ($lpq[2] =~/^Rank/) ) {               # DWP
	    # third line of dec_osf lpq starts with Rank, second is blank       DWP
	    #Rank   Owner      Job  Files                        Total Size     DWP
	    #active ss0300     40   lpr.doc, Printer.pm          103014 bytes   DWP
	    #active ss0300     42   (standard input)             54585 bytes    DWP
	    for (my $i = 3; $i < @lpq; ++$i) {                                # DWP
		$lpq[$i] =~ s/,\s/,/g;                        # multi-files     DWP
		if ( $lpq[$i] =~ /(\(.*\))/ ) {               # spaces in file  DWP
		    my ($ofil,$nfil) = ($1,$1);                               # DWP
		    $nfil =~ s/ /_/g;                                         # DWP
		    ($ofil,$nfil) = (quotemeta($ofil),quotemeta($nfil));      # DWP
		    $lpq[$i] = s/$ofil/$nfil/;                                # DWP
		}                                                             # DWP
		push @queue, $lpq[$i];                                        # DWP
	    }
	}

	# make the queue into an array of hashes
	for(my $i = 0; $i < @queue; ++$i) {
	    $queue[$i] =~ s/\s+/ /g; # remove extraneous spaces
	    my @job = split / /, $queue[$i];
	    $queue[$i] = ('Rank' => $job[0],
			  'Owner' => $job[1],
			  'Job' => $job[2],
			  'Files' => $job[3],
			  'Size' => $job[4]
			  );
	}

    } # end linux
    
    elsif ($self->{'system'} eq "MSWin32") {
	# return an empty queue (for compatibility)
	Carp::croak 'list_jobs  hasn\'t yet been written for windows. Share and enjoy';
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

 $prn->print_command('linux' = {'type' => 'pipe',
			        'command' => 'lpr -P lp'},
		    'MSWin32' = {'type' => 'command',
				 'command' => 'gswin32c -sDEVICE=mswinpr2 
                                 -dNOPAUSE -dBATCH $spoolfile'}
		    );

 %available_printers = $prn->list_printers;

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

This code has been tested on Linux, DEC-OSF, Solaris, HP/UX windows 95 and windows NT4. 

UNIX printing works using the Linux routines. This
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

If you intend to use the C<use_default()> or C<print_command()> methods,
you don't need to supply any parameters to C<new()>.

This method dies with an error message on unsupported platforms.

=head2 Define a printer command to use

 $prn->print_command('linux' = {'type' => 'pipe',
                     'command' => 'lpr -P lp'},
                     'MSWin32' = {'type' => 'file',
                                  'command' => 'gswin32c -sDEVICE=mswinpr2 
                                  -dNOPAUSE -dBATCH $spoolfile'}
                    );

This method allows you to specify your own print command to use. It
takes 2 parameters for each operating system: 

=head3 type

=over 4

=item * pipe - the specified print command accepts data on a pipe.

=item * file - the specified print command works on a file. The
Printer module replaces $spoolfile with a temporary filename which contains
the data to be printed 

=back

=head3 command

This specifies the command to be used. 

=head2 Select the default printer

 $printer->use_default;

=head3 Linux
    
The default printer is read from the environment variables 
$PRINTER, $LPDEST, $NPRINTER, $NGPRINTER in that order, or is set to
the value of lpstat -d or is set to
"lp" if it cannot be otherwise determined. You will be warned if
this happens.

=head3 Win32

 THe default printer is read from the registry (trust me, this works).

=head2 List available printers
    
 %printers = list_printers().
  
This returns a hash of arrays listing all available printers. 
The hash keys are:

=over 4

=item * %hash{names} - printer names

=item * %hash{ports} - printer ports

=back

=head2 Print

 $printer->print($data);

 $printer->print(@pling);

Print a scalar value or an array onto the print server through 
a pipe (like Linux)

=head2 List queued jobs

 @jobs = $printer->list_jobs();

This returns an array of hashes where each element in the array
contains a hash containing information on a single print job. The hash
keys are: Rank, Owner, Job, Files, Size.

This code shows how you can access each element of the hash for all of
the print jobs.

=for html <PRE>

 @queue = list_jobs();
 foreach $ref (@queue) {
    foreach $field (qw/Rank Owner Job Files Size/) {
        print $field, " = ", $$ref{$field}, " ";
    }
 print "\n";
 }

=for html </PRE>

=head3 Windows

The array returned is empty (for compatibility).

=head1 BUGS

=over 4

=item * list_jobs needs writing for win32

=back

=head1 AUTHORS

Stephen Patterson (s.patterson@freeuk.com)

David W Phillips (ss0300@dfa.state.ny.us)

=head1 TODO

=over 4    

=item * Make list_jobs work on windows.

=item * Port to MacOS.

=back

=head1 Changelog

=head2 0.95

=over 4

=item * added support for user defined print commands.

=back

=head2 0.94c

=over 4

=item * removed unwanted dependency on Win32::AdminMisc

=item * added support of user-defined print command

=back

=head2 0.94b

=over 4

=item * added documentation of the array input capabilities of the print() 
method

=item * windows installation fixed (for a while)

=back

=head2 0.94a

=over 4

=item * glaring typos fixed to pass a syntax check (perl -c)

=back

=head2 0.94

=over 4

=item * uses the first instance of the lp* commands from the user's path

=item * more typos fixed

=item * list_jobs almost entirely rewritten for linux like systems.

=back

=head2 0.93b

=over 4

=item * Checked and modified for dec_osf, solaris and HP/UX thanks to
data from David Phillips.

=item * Several quoting errors fixed.

=head2 0.93a

=over 4

=item * list_jobs returns an array of hashes 

=item * list_printers exported into main namespace so it can be called
without an object handle (which it doesn't need anyway).

=back

=head2 0.93

=over 4

=item * Printing on windows 95 now uses a unique spoolfile which
will not overwrite an existing file.

=item * Documentation spruced up to look like a normal linux manpage.

=back

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
