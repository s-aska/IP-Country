# *-*-perl-*-*
use Test;
use strict;
$^W = 1;
use IP::Country::Fast;
# use Time::HiRes qw ( time );
BEGIN { plan tests => 1 }

# my $iter = 65535;
my $iter = 32767;
my $reg = IP::Country::Fast->new();
my ($found,$t1,$delta);

$found = 0;
$t1 = time();
for (my $i=1; $i<=$iter; $i++)
{
    my $ip = int(rand(256)).'.'.int(rand(256)).'.'
	.int(rand(256)).'.'.int(rand(256));
    if ($reg->inet_atocc($ip)){
        $found++;
    }
}
$delta = (time() - $t1) || 1; # avoid zero division
ok(1);
print STDERR (" # random find (".int(($found * 100)/$iter)."%, "
	      .int($iter/$delta)." lookups/sec)\n");
sleep(10);
