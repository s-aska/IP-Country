# A template for Makefile.PL used by Arena Networks.
# - Set the $PACKAGE variable to the name of your module.
# - Set $LAST_API_CHANGE to reflect the last version you changed the API 
#   of your module.
# - Fill in your dependencies in PREREQ_PM
# Alternatively, you can say the hell with this and use h2xs.
use ExtUtils::MakeMaker;
use strict;
use Fcntl;
use Socket;

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

# cached packed IP ranges
my $log2 = log(2);
my $null_ip  = inet_aton('0.0.0.0');
my %mask;
my %not_mask;
my %packed_range;

foreach (my $i=0; $i<=32; $i++){
    $mask{$i} = pack('B32', ('1'x(32-$i)).('0'x$i));
    $not_mask{$i} = pack('B32', ('0'x(32-$i)).('1'x$i));
    $packed_range{$i} = pack('C',$i);
}

# this is our database
my %ip;

# and these are our raw files that will combine to form the database
my @reg_files = ('apnic-2002-11-01', 'arin.20021101', 'ripencc.20021101');
foreach my $reg (@reg_files){
    process_reg_file($reg);
}


print "Optimizing registry...\n";
my $run_again = 1;
my $removals = 0;
while ($run_again) {
    $run_again = 0;
    foreach my $key (sort keys %ip)
    {
	my $ip = substr($key,0,4);
	my $mask = substr($key,4,2);
	my $cc = $ip{$key};

	my $decimal_mask = unpack("C",$mask);
	my $dotted_ip = inet_ntoa($ip);

	
	my $next_ip = pack("N",unpack("N",$ip) + 2**$decimal_mask);
	my $next_key = $next_ip.$mask;
	my $big_mask = pack("C",$decimal_mask+1);
	if (exists $ip{$next_key}){
	    if ($ip{$next_key} eq $cc){
		if (get_max_mask($ip) > $decimal_mask){
		    if ($decimal_mask < 24){
#			print "$dotted_ip - $decimal_mask - ".inet_ntoa($next_ip)." - $cc\n";
			delete $ip{$key};
			delete $ip{$next_key};
			$ip{$ip.$big_mask} = $cc;
			$removals++;
			$run_again = 1;
		    }
		}
	    }
	}
    }
    print "  removed $removals keys while optimizing... ";
    if ($run_again){
	print "running again\n";
    } else {
	print "\n";
    }
}

# used for discovering the distribution of IP addresses by mask
#my %mask_sizes;
#foreach my $key (keys %ip){
#    my $mask = substr($key,4,2);
#    my $decimal_mask = unpack("C",$mask);
#    $mask_sizes{$decimal_mask}++;
#}
#
#foreach my $size (sort keys %mask_sizes){
#    print "$size = ".$mask_sizes{$size} * (2**$size)."\n";
#}

print "Saving registry...\n";
my %database;
tie (%database,'AnyDBM_File','lib/IP/Country/Fast/data',O_RDWR|O_CREAT, 0666)
    or die ("couldn't create registry database: $!");
while (my($key,$value) = each %ip){
    $database{$key} = $value;
}
untie %database;

# if everything works, we can build our makefile
WriteMakefile(
	      NAME            => $PACKAGE,
	      VERSION_FROM    => "lib/$PACKAGE_FILE.pm", # finds $VERSION
	      PREREQ_PM       => {
		  },
	      AUTHOR          => 'Nigel Wetters <nwetters@cpan.org>',
	      ABSTRACT_FROM   => "lib/$PACKAGE_FILE.pm"
	      );

sub process_reg_file
{
    my $reg = shift;
    open (REG, "< $reg") || die("can't open $reg: $!");
    while (my $line = <REG>){
	chomp $line;
	next unless $line =~ /^([^\|]+)\|(..)\|ipv4\|([^\|]+)\|(\d+)\|/;
	my ($auth,$cc,$ip,$size) = ($1,$2,$3,$4);
	$cc = undef if ($auth eq 'iana'); # ipv6 and private IP ranges

	my $packed_ip = inet_aton($ip);
	add_region($packed_ip,$size,$cc);
    }
    close REG || warn("can't close $reg, but continuing: $!");
}

sub add_region
{
    my ($ip,$size,$cc) = @_;
    die unless $size;
    while ($size > 0){
	my $mask = int(log($size)/$log2);
	my $d_ip = inet_ntoa($ip);
	if (get_max_mask($ip) < $mask){
	    $mask = get_max_mask($ip);
	}
	$ip{$ip.$packed_range{$mask}} = $cc;
	$size = $size - (2 ** $mask);
	$ip = pack("N", unpack("N",$ip) + 2 ** $mask);
    }
}

sub get_max_mask
{
    my $ip = shift;
    for (my $i= 32; $i>=1; $i--){
	if (($ip & $not_mask{$i}) eq $null_ip){
	    return $i;
	}
    }
    die("odd IP");
}
