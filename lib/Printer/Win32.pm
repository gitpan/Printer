############################################################################
sub list_printers {
    # list available printers
    my $self = shift();
    my %printers;

    # look at registry to get printer names for local machine
    my $Register = 'SYSTEM\CurrentControlSet\Control\Print\Printers';
    my ($hkey, @key_list, @names, @ports);
    my $HKEY_LOCAL_MACHINE = $main::HKEY_LOCAL_MACHINE;
    $HKEY_LOCAL_MACHINE->Open($Register, $hkey) or 
      Carp::croak "Can't open registry key HKEY_LOCAL_MACHINE\\$Register: $!";
    $hkey->GetKeys(\@key_list);
    foreach my $key (@key_list) {
	my $path = $Register . "\\$key";
	my ($pkey, %values, $printers);
	$HKEY_LOCAL_MACHINE->Open($path, $pkey) or 
	  Carp::croak "Can't open registry key  HKEY_LOCAL_MACHINE\\$path: $!";
	$pkey->GetValues(\%values);
	push @ports, $values{Port}[2];
	push @names, $values{Name}[2];
    }
    $printers{name} = [ @names ];
    $printers{port} = [ @ports ];
    return %printers;
}
######################################################################
sub use_default {
    # select the default printer
    my $self = shift;
    my ($hkey, %values);

    # default name is the human readable printer name (not port)
    # look in the registry to find it
    if ($self->{winver} eq ('Win95' or 'Win98' or 'WinNT4')) {
	# the old routines, win95/nt4 tested
	my $register = 'Config\0001\SYSTEM\CurrentControlSet\Control\Print\Printers';
	my $HKLM = $main::HKEY_LOCAL_MACHINE;
	$HKLM->Open($register, $hkey) or 
	  Carp::croak "Can't open registry key " . $register
	      . "in use_default(): $EXTENDED_OS_ERROR\n";
	$hkey->GetValues(\%values);
	my $default = $values{Default}[2];
	# $default holds the long printer name, get the port
	$register = 'SYSTEM\CurrentControlSet\Control\Print\Printers\\';
	my $path = $register . $default;
	$HKLM->Open($path, $HKEY) or
	  Carp::croak "Can't open registry key $path in use_default() "
	      . $EXTENDED_OS_ERROR;
	$hkey->GetValues(\%values);
	$self->{'printer'}{$OSNAME} = $values{Port}[2];
    } elsif ($self->{winver} eq ('Win2000' or 'WinXP/.Net')) {
	# different registry paths for win2k
	my $register = 'Software\Microsoft\Windows NT\CurrentVersion\Windows';
	my $HKCU = $main::HKEY_CURRENT_USER;
	$HKCU->Open($register, $hkey) or
	  Carp::croak "Can't open registry key $register in use_default: $EXTENDED_OS_ERROR\n";
	$hkey->GetValues(\%values);
	my $default = $values{Device}[2];
	$default =~ s/,.*//;
	# find the port for this printer
	my $register = "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Print\\Printers\\$default";
	my $HKLM = $main::HKEY_LOCAL_MACHINE;
	$HKLM->Open($register, $hkey) or
	  Carp::croak "Can't open registry key $register in use_default(): $EXTENDED_OS_ERROR\n";
	$hkey->GetValues(\%values);
	print $values{Port}[2];
	$self->{'printer'}{$OSNAME} = $values{Port}[2];
    }

}
######################################################################
sub print {
    # print
    my $self = shift;
    my $data = join("", @_);
    unless ($self->{print_command}->{$OSNAME}) {
	# default pipish method

	# for windows 2000, you get a file of what would reach the printer
	# *grrr*
	# Windows NT variations
	if ($self->{winver} =~ m/WinNT|Win2000|WinXP/ ) {
	    open SPOOL, ">>" . $self->{'printer'}{$OSNAME} or
	      Carp::croak "Can't open print spool $self->{'printer'}{$OSNAME}: $!" ;
	    print SPOOL $data or
	      Carp::croak "Can't write to print spool $self->{'printer'}: $!";
	    close SPOOL;
	}

	# any other windows version
	# for win95, may work with ME
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
	if ($self->{print_command}->{$OSNAME}->{type} eq 'command') {
	    # non-pipe accepting command - use a spoolfile
	    my $cmd = $self->{print_command}->{$OSNAME}->{command};
	    my $spoolfile = get_unique_spool();
	    $spoolfile .= '.ps';
	    $cmd =~ s/FILE/$spoolfile/;
	    open SPOOL, ">" . $spoolfile;
	    print "Spool: ", $spoolfile, "\n";
	    print SPOOL $data;
	    close SPOOL;
	    system($cmd) || die $OS_ERROR;
	    unlink $spoolfile;
	} else {
	    # pipe accepting command
	    # can't use this - windows perl doesn't support pipes.
	}
    }
}
######################################################################
sub list_jobs {
    # list the current print queue
    my $self = shift;
    my @queue;
	# return an empty queue (for compatibility)
	Carp::croak 'list_jobs  hasn\'t yet been written for windows. Share and enjoy';
}
######################################################################
1;

