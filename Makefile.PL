use ExtUtils::MakeMaker;
use English;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.


$abstract = "low-level, platform independent printing (curently Linux and 
    MS Win32. other UNIXES should also work.)";

if ($OSNAME eq "MSWin32") {
  WriteMakefile(
		'NAME'		=> 'Printer',
		'VERSION_FROM'	=> 'Printer.pm',
		'PREREQ_PM'	=> {Win32::Registry, Win32::AdminMisc},
		($] >= 5.005 ?
		 (ABSTRACT => $abstract,
		  AUTHOR     => 'Stephen Patterson <s.patterson@freeuk.com>') :())
	       );
} else {
  WriteMakefile(
		'NAME'		=> 'Printer',
		'VERSION_FROM'	=> 'Printer.pm',
		'PREREQ_PM'	=> {},
		($] >= 5.005 ?
		 (ABSTRACT => $abstract,
		  AUTHOR     => 'Stephen Patterson <s.patterson@freeuk.com>') :())
	       );
}
