use Test::More tests => 1;
use strict;
use warnings;
use IP::Country;

my $reg;
ok($reg = IP::Country->new(),'object creates ok');
