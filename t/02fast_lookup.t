use Test;
use strict;
$^W = 1;
use IP::Country::Fast;
use Socket qw ( inet_ntoa inet_aton );
BEGIN { plan tests => 1 }

my @test_ipa; # ip address at start of range
my @test_country; # country codes for test ranges

# and these are our raw files that will combine to form the database
my $reg_dir = 'rir_data';
my @reg_files;
opendir(RIR,$reg_dir) or die("can't open $reg_dir: $!");
while (defined (my $path = readdir RIR)){
    next if $path =~ /^\.\.?$/;
    push @reg_files, $path;
}
closedir(RIR);

foreach my $reg (@reg_files){
    open (REG, "< $reg_dir/$reg") || die("can't open $reg_dir/$reg: $!");
    while (my $line = <REG>){
    	chomp $line;
	next unless $line =~ /^([^\|]+)\|(..)\|ipv4\|([^\|]+)\|(\d+)\|/;
	my ($auth,$cc,$ip,$size) = ($1,$2,$3,$4);
	next if ($auth eq 'iana'); # ipv6 and private IP ranges
	$cc = 'UK' if ($cc eq 'GB');
        push @test_ipa, inet_ntoa(pack("N",unpack("N",inet_aton($ip)) + int(rand $size)));
        push @test_country, $cc;
    }
    close REG || warn("can't close $reg_dir/$reg, but continuing: $!");
}

my $cc = IP::Country::Fast->new();

my $fail = 0;
for (my $i = 0; $i<=$#test_ipa; $i++){
    my $cnta = $cc->inet_atocc($test_ipa[$i]);
    unless ($cnta eq $test_country[$i]){
        warn ($test_ipa[$i].'-'.$cnta.'-'.$test_country[$i]);
        $fail = 1;
    }
}
if ($fail){
  ok(0);
} else {
  ok(1);
}
