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
}
######################################################################
sub use_default {
    # select the default printer
    my $self = shift;

    # default name is the human readable printer name (not port)
    # look in the registry to find it
    my $register = 'Config\0001\SYSTEM\CurrentControlSet\Control\Print\Printers';
    my ($hkey, %values);
    my $HKEY_LOCAL_MACHINE = $main::HKEY_LOCAL_MACHINE;
    $HKEY_LOCAL_MACHINE->Open($register, $hkey) or 
      Carp::croak "Can't open registry key $register (call 1): $!";
    $hkey->GetValues(\%values);
    my $default = $values{Default}[2];

    # $default now holds the human readable printer name, get the 
    # name of the corresponding port.
    $register = 'SYSTEM\CurrentControlSet\control\Print\Printers\\';
    my $path = $register . $default;
    $HKEY_LOCAL_MACHINE->Open($path, $hkey) or 
      Carp::croak "Can't open registry key $path (call 2): $!";
    $hkey->GetValues(\%values);
    $self->{'printer'}{$OSNAME} = $values{Port}[2];
}
######################################################################
sub print {
    # print
    my $self = shift;
    my $data;
    foreach (@_) {
	$data .= $_;
    }
    unless ($self->{print_command}->{$OSNAME}) {
	# default pipish method

	# Windows NT variations (NT/2k/XP)
	if ($self->{winver} =~ m/Win2000|WinXP|WinNT/ ) {
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

