# *-*-perl-*-*
use Test;
use strict;
$^W = 1;
use IP::Country::Fast;
use Geography::Countries;

BEGIN { plan tests => 220 }

(my $module_dir = $INC{'IP/Country/Fast.pm'}) =~ s/\.pm$//;

local $/;   # set it so <> reads all the file at once

open (CC, "< $module_dir/cc.gif")
    or die ("couldn't read country database: $!");
binmode CC;
my $cc_ultra = <CC>;  # read in the file
close CC;
my $cc_num = (length $cc_ultra) / 3;
for (my $i = 0; $i < $cc_num; $i++){
    my $cc = substr($cc_ultra,3 * $i + 1,2);
    next if (($cc eq '--') || 
	     ($cc eq '**') || 
	     ($cc eq 'AP') ||
	     ($cc eq 'CS') ||
	     ($cc eq 'EU') ||
	     ($cc eq 'FX') ||
	     ($cc eq 'PS') ||
	     ($cc eq 'UK'));
    if (defined (scalar country $cc)){
	ok(1);
    } else {
	ok(0);
	warn $cc;
    }
}

