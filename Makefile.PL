# A template for Makefile.PL used by Arena Networks.
# - Set the $PACKAGE variable to the name of your module.
# - Set $LAST_API_CHANGE to reflect the last version you changed the API 
#   of your module.
# - Fill in your dependencies in PREREQ_PM
# Alternatively, you can say the hell with this and use h2xs.
use ExtUtils::MakeMaker;
use strict;
use Fcntl;
use Socket qw ( inet_aton );

BEGIN { @AnyDBM_File::ISA = qw(SDBM_File GDBM_File NDBM_File DB_File OBBM_File ) }
use AnyDBM_File;

my $PACKAGE = 'IP::Country';
(my $PACKAGE_FILE = $PACKAGE) =~ s|::|/|g;
my $LAST_API_CHANGE = 1.67;
my $CURR_VERSION;
eval "require $PACKAGE;\n\$CURR_VERSION = \$$PACKAGE"."::VERSION;";

unless ($@) { # Make sure we did find the module.
    if( $CURR_VERSION < $LAST_API_CHANGE ) {
        print "-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-\n".
	    "NOTE: There have been API changes between this version and any older\n".
	    "      than version $LAST_API_CHANGE! It seems that you have a copy\n".
	    "      of this software installed with a version number of $CURR_VERSION.\n".
	    "      Please read the CHANGES file if you have been building software\n".
	    "      that relies on a previous version of this software.\n".
	    "-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-!-\n";
        sleep 5;
    }
}

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

print "Saving registry to disk\n";

my %database;
%database = ();
tie (%database,'AnyDBM_File','lib/IP/Country/Fast/data',O_RDWR|O_CREAT, 0666)
    or die ("couldn't create registry database: $!");
foreach my $range (keys %ip){
    $database{$range} = $tree->get_cc_as_num($ip{$range});
}

untie %database;

print "Saving country DB to disk\n";

my %cc;
tie (%cc,'AnyDBM_File','lib/IP/Country/Fast/cc',O_RDWR|O_CREAT, 0666)
    or die ("couldn't create country database: $!");
%cc = ();
foreach my $country ($tree->get_countries()){
    $cc{$tree->get_cc_as_num($country)} = $country;
}
untie %cc;



# my %countries;
# foreach my $key ($ips->get_keys()){
#    $countries{$ips->get_range($key)} = 1;
#}

#print "  num_countries = ".(scalar keys %countries)."\n";
#print "  num_ranges    = ".(scalar $ips->get_keys())."\n";

# if everything works, we can build our makefile
WriteMakefile(
	      NAME            => $PACKAGE,
	      VERSION_FROM    => "lib/$PACKAGE_FILE.pm", # finds $VERSION
	      PREREQ_PM       => {
		  },
	      AUTHOR          => 'Nigel Wetters <nwetters@cpan.org>',
	      ABSTRACT_FROM   => "lib/$PACKAGE_FILE.pm"
	      );


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
    return keys %{$self->{sorted_cc}};
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
