use strict;
$^W = 1;
use Socket qw ( inet_aton );

print "Building registry... this will take a moment...\n";

my %log2;
for (my $i=0; $i<=31; $i++){
    $log2{2 ** $i} = $i;
}

my @dtoc;
for (my $i=0; $i<=255; $i++){
    $dtoc[$i] = substr(pack('N',$i),3,1);
}

# this is our fast stash
my %ip;
my $tree = IPTree->new();

# and this is our pre-generated list of ranges
my $reg_file = 'sorted_ranges.txt';

open (REG, "< $reg_file") || die("can't open $reg_file: $!");
while (my $line = <REG>){
    chomp $line;
    next unless $line =~ /^([^\|]+)\|([^\|]+)\|(..)$/;
    my ($ip,$size,$cc) = ($1,$2,$3);
    $cc = 'UK' if ($cc eq 'GB');
    my $packed_ip = inet_aton($ip);
    my $packed_range = $dtoc[$log2{$size}];
    my $key = $packed_ip.$packed_range;
    $tree->add($key,$cc);
    $ip{$key} = $cc;
}
close REG || warn("can't close $reg_file, but continuing: $!");

print "Saving ultralite IP registry to disk\n";

open (IP, "> lib/IP/Country/Fast/ip.gif")
    or die ("couldn't create IP database: $!");
binmode IP;
foreach my $range (keys %ip){
    print IP $range . $dtoc[$tree->get_cc_as_num($ip{$range})];
}
close(IP);

print "Saving ultralite country database to disk\n";

open (CC, "> lib/IP/Country/Fast/cc.gif")
    or die ("couldn't create country database: $!");
binmode CC;
foreach my $country (sort $tree->get_countries()){
    print CC $dtoc[$tree->get_cc_as_num($country)].$country;
}
close(CC);
print "Finished.\n";



package IPTree;
use strict;
use Socket qw ( inet_aton inet_ntoa );
$^W = 1;

my $null;
my @mask;
my %ctod;

BEGIN {
    $null = inet_aton ('0.0.0.0');

    for (my $i = 1; $i <= 32; $i++){
	$mask[$i] = pack('N',2 ** (32 - $i));
    }
    
    for (my $i=0; $i<=255; $i++){
	$ctod{substr(pack('N',$i),3,1)} = $i;
    }
}

sub new
{
    return bless {
	countries => {}
    }, 'IPTree';
}

sub add
{
    my ($tree,$key,$cc) = @_;
    $tree->_ccPlusPlus($cc);
    my $ip = substr($key,0,4);
    my $netmask = 32 - $ctod{substr($key,4,1)};
#    printf "%2s - %15s (",$cc, inet_ntoa($ip);
    for (my $i = 1; $i <= $netmask; $i++){
	if (($ip & $mask[$i]) eq $mask[$i]){
#	    print '1';
	    unless (exists $tree->{1}){
		$tree->{1} = undef;
	    }
	    $tree = $tree->{1};
	} else {
#	    print '0';
	    unless (exists $tree->{0}){
		$tree->{0} = undef;
	    }
	    $tree = $tree->{0};
	}
	$tree->{cc} = $cc;
    }
#    print ")\n";
}

sub get_cc_as_num
{
    my ($self,$cc) = @_;
    unless (exists $self->{sorted_cc}){
	$self->{sorted_cc} = {};
	my $i = 0;
	foreach my $c (sort { $self->{countries}->{$b} <=> $self->{countries}->{$a} }
		       keys %{$self->{countries}})
	{
	    $self->{sorted_cc}->{$c} = $i;
#	    print "$c - $i\n";
	    $i++;
	}
    }
    unless (exists $self->{sorted_cc}->{$cc}){
	die("couldn't find $cc in country database");
    }
    return $self->{sorted_cc}->{$cc};
}

sub get_countries
{
    my ($self) = @_;
    unless (exists $self->{sorted_cc}){
	$self->get_cc_as_num('US');
    }
    return sort keys %{$self->{sorted_cc}};
}

sub _ccPlusPlus
{
    my ($self,$cc) = @_;
    if (exists $self->{countries}->{$cc}){
	$self->{countries}->{$cc}++;
    } else {
	$self->{countries}->{$cc} = 1;
    }
}

1;
