use Test;
BEGIN { plan tests => 4 }
use strict;
$^W = 1;
use IP::Country;
use IP::Country::Fast;
use IP::Country::Medium;
use IP::Country::Slow;

ok(IP::Country->new());
ok(IP::Country::Fast->new());
ok(IP::Country::Medium->new());
ok(IP::Country::Slow->new());
