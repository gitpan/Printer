# test the Print package

BEGIN {push @INC, '.'}

use Printer;
use English;
use Win32::AdminMisc;

$foo = "Foo mane padme hum.";

print "System: ", $OSNAME, "\n";

my %WinVer = GetWinVersion

print "Windows Version: ", $WinVer{Platform}, "\n";

my $printer = new Printer;

print "You have the following printers available\n";

%printers = list_printers();

print "Ports: $printers{port}\n";
print "Names: $printers{name}\n";


print "Selecting default printer\n";

$printer->use_default();

print "Printing $foo onto default printer\n";

$printer->print($foo);
