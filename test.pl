use WIn32::API;

# import OpenPrinter function. See 
# http://msdn.microsoft.com/library/en-us/gdi/prntspol_9qnm.asp
# for docs
$OpenPrinter = new Win32::API('Winspool.drv',
			      'OpenPrinter',
			      [P, P, P],
			      I);

# import ClosePrinter function. See
# http://msdn.microsoft.com/library/en-us/gdi/prntspol_4w1e.asp for docs
$ClosePrinter = new Win32::API('Winspool.drv',
			       'ClosePrinter',
			       [P],
			       I);

# import EnumJobs function. See 
# http://msdn.microsoft.com/library/en-us/gdi/prntspol_2cj7.asp for docs
$EnumJobs = new Win32::API('Winspool.drv',
			   'EnumJobs',
			   [P, I, I, I, P, I, I, I],
			   I);
			   

# import windows error tracking
$GetLastError = new Win32::API('kernel32.dll',
			       'GetLastError',
			       I);

## All functions imported OK

# open a printer handle
$lpstr = 'HP Laserjet 4Si';
$hPrinter =" " x 128; # init a 128 char buffer to take the printer handle
$OpenPrinter->Call($lpstr, $hPrinter, NULL)
    or die $GetLastError->Call;
# this works

# remove trailing space from $hPrinter
$hPrinter =~ s/\0.*$//;

# find out how much space needed for job buffer. I need to do this
# because EnumJobs only returns information on as few (or as many)
# jobs as you ask it for. 
$pJob = \@Job_list;
$cbBuff = 0;


$EnumJobs->Call($hPrinter, 0, 255, 1, undef, $cbBuff, $pcbNeeded,
		$pcReturned)
    or die $GetLastError->Call;




