use strict;
$^W = 1;
use Socket qw ( inet_aton );
use IO::File;
print "Building registry... this will take a moment...\n";

my %log2;
for (my $i=0; $i<=31; $i++){
    $log2{2 ** $i} = $i;
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
    my $packed_range = substr(pack('N',$log2{$size}),3,1);
    my $key = $packed_ip.$packed_range;
    $tree->add($key,$cc);
    $ip{$key} = $cc;
}
close REG || warn("can't close $reg_file, but continuing: $!");


print "Saving ultralite IP registry to disk\n";
my $ip = new IO::File "> lib/IP/Country/Fast/ip.gif";
if (defined $ip) {
    binmode $ip;
    $tree->printTree($ip);
    $ip->close();
} else {
    die "couldn't write IP registry:$!\n";
}


print "Saving ultralite country database to disk\n";

open (CC, "> lib/IP/Country/Fast/cc.gif")
    or die ("couldn't create country database: $!");
binmode CC;
foreach my $country (sort $tree->get_countries()){
    print CC substr(pack('N',$tree->get_cc_as_num($country)),3,1).$country;
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
my @dtoc;
my $bit0;
my $bit1;
BEGIN {
    $null = inet_aton ('0.0.0.0');
    $bit0 = substr(pack('N',2 ** 31),0,1);
    $bit1 = substr(pack('N',2 ** 31),0,1);

    for (my $i = 1; $i <= 32; $i++){
	$mask[$i] = pack('N',2 ** (32 - $i));
    }
    
    for (my $i=0; $i<=255; $i++){
	$ctod{substr(pack('N',$i),3,1)} = $i;
	$dtoc[$i] = substr(pack('N',$i),3,1);
    }
}

sub new ()
{
    return bless {
	countries => {}
    }, 'IPTree';
}

sub add ($$$)
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
		$tree->{1} = {};
	    }
	    $tree = $tree->{1};
	} else {
#	    print '0';
	    unless (exists $tree->{0}){
		$tree->{0} = {};
	    }
	    $tree = $tree->{0};
	}
    }
    $tree->{cc} = $cc;
#    print ")\n";
}

sub get_cc_as_num ($)
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

sub get_countries ()
{
    my ($self) = @_;
    unless (exists $self->{sorted_cc}){
	$self->get_cc_as_num('UK');
    }
    return sort keys %{$self->{sorted_cc}};
}

sub _ccPlusPlus ($)
{
    my ($self,$cc) = @_;
    if (exists $self->{countries}->{$cc}){
	$self->{countries}->{$cc}++;
    } else {
	$self->{countries}->{$cc} = 1;
    }
}

sub printTree ($)
{
    my ($self,$fh) = @_;
    $self->_findSize($self);
    _printSize($self,$self,$fh);
}

sub _printSize
{
    my ($self,$node,$fh) = @_;
    if (exists $node->{cc}){
	# country codes are two bytes - might shrink this to one and a bit
	my $cc = $self->get_cc_as_num($node->{cc});
	if ($cc < 64){
	    print $fh ($dtoc[$cc] | $bit0);
	} else {
	    print $fh $dtoc[255] . $dtoc[$self->get_cc_as_num($node->{cc})];
	}
    } else {
	# jump distances are three bytes - might also be shrunk later
	my $jump = $node->{0}->{size};
	my $binary_jump = substr(pack('N',$jump),1,3);
	die("bad jump: $jump") if ($jump >= 2 ** 24);
	die("bad jump: $jump") if (($binary_jump & $bit0) eq $binary_jump);
	print $fh $binary_jump;

	_printSize($self,$node->{0},$fh);
	_printSize($self,$node->{1},$fh);
    }
}

sub _findSize
{
    my ($self,$node) = @_;
    my $size = 0;
    if (exists $node->{cc}){
	my $cc = $self->get_cc_as_num($node->{cc});
	if ($cc < 64){
	    $size = 1;
	} else {
	    $size = 2;
	}
    } else {
	$size = 3 + $self->_findSize($node->{0}) + $self->_findSize($node->{1});
    }
    $node->{size} = $size;
    return $size;
}

1;
