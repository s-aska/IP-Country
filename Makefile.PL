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
my %mask;
my %not_mask;
my %packed_range;

foreach (my $i=0; $i<=31; $i++){
    $mask{$i} = pack('B32', ('1'x(32-$i)).('0'x$i));
    $not_mask{$i} = pack('B32', ('0'x(32-$i)).('1'x$i));
    $packed_range{$i} = pack('C',$i);
}

# this is our database
my %ip;

# and these are our raw files that will combine to form the database
my @reg_files = ('apnic-2002-11-01', 'arin.20021101', 'ripencc.20021201', 'lacnic.20021105');
foreach my $reg (@reg_files){
    process_reg_file('rir_data/'.$reg);
}


my $run_again;

print "Cutting smaller holes in registry...\n";
$run_again = 1;
my $holes = 0;
while ($run_again) {
    $run_again = 0;
    foreach my $key (sort keys %ip)
    {
	if (exists $ip{$key}){
	    my $ip = substr($key,0,4);
	    my $mask = substr($key,4,2);
	    my $decimal_mask = unpack("C",$mask);
	    for (my $big_mask = 31; $big_mask > $decimal_mask; $big_mask--){
		my $bigger_ip = $ip & $mask{$big_mask};
		my $bigger_key = $bigger_ip.$packed_range{$big_mask};
		if (exists $ip{$bigger_key}){
		    if ($ip{$bigger_key} ne $ip{$key}){
#			print "found: ".inet_ntoa($ip) . "/$decimal_mask ". $ip{$key} ."\n";
			cut_hole( $bigger_key, $key);
			$holes++;
			$run_again = 1;
		    }
		}
	    }
	}
    }
}
print "  cut $holes holes for smaller IP ranges...\n";

print "Complementing registry...\n";
my $complements = 0;
my @keys = sort keys %ip;
for (my $i = 0; $i <= $#keys; $i++)
{
    my $end_of_range = unpack("N",substr($keys[$i],0,4)) + (2 ** unpack("C",substr($keys[$i],4,2)));
    my $next_ip;
    if ($i < $#keys){
	$next_ip = unpack("N",substr($keys[$i+1],0,4));
    } else {
	$next_ip = 2 ** 32;
    }
    if (($next_ip - $end_of_range) > 0){
	# blanks
	add_region(pack("N",$end_of_range),($next_ip-$end_of_range),undef);
	$complements++;
    }
}
print "  added $complements empty spaces...\n";

print "Optimizing registry\n";
my $removals = 0;
$run_again = 1;
while ($run_again) {
    $run_again = 0;
    foreach my $key (keys %ip)
    {
	my $ip = substr($key,0,4);
	my $mask = substr($key,4,2);

	my $decimal_mask = unpack("C",$mask);
	my $next_ip = pack("N",unpack("N",$ip) + 2**$decimal_mask);
	my $next_key = $next_ip.$mask;

	if (exists $ip{$next_key}){
	    my $cc = $ip{$key};
	    if ($ip{$next_key} eq $cc){
		if (get_max_mask($ip) > $decimal_mask){
		    delete $ip{$key};
		    delete $ip{$next_key};
		    my $big_mask = $packed_range{$decimal_mask+1};
		    $ip{$ip.$big_mask} = $cc;
		    $removals++;
		    $run_again = 1;
		}
	    }
	}
    }
}
print "  removed $removals IP ranges...\n";

# used for discovering the distribution of IP addresses by mask
#my %mask_sizes;
#foreach my $key (keys %ip){
#    my $mask = substr($key,4,2);
#    my $decimal_mask = unpack("C",$mask);
#    $mask_sizes{$decimal_mask}++;
#}
#
#foreach my $size (sort keys %mask_sizes){
#    print "$size = ".(int($mask_sizes{$size} * (2**$size) / (2**32) * 10000)/100) ."%\n";
#}
#
# used for discovering the countries
my %countries;
foreach my $key (keys %ip){
    $countries{$ip{$key}} = 1;
}

print "  num_countries = ".(scalar keys %countries)."\n";
print "  num_ranges    = ".(scalar keys %ip)."\n";

print "Saving registry...\n";
my %database;
tie (%database,'AnyDBM_File','lib/IP/Country/Fast/data',O_RDWR|O_CREAT, 0666)
    or die ("couldn't create registry database: $!");
%database = ();
while (my($key,$value) = each %ip){
    my $ip = substr($key,0,4);
    my $mask = substr($key,4,2);
    $database{$mask.$ip} = $value;
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
	if (get_max_mask($ip) < $mask){
	    $mask = get_max_mask($ip);
	}
	unless (exists $ip{$ip.$packed_range{$mask}}){
	    $ip{$ip.$packed_range{$mask}} = $cc;
	}
	$size = $size - (2 ** $mask);
	$ip = pack("N", unpack("N",$ip) + 2 ** $mask);
    }
}

sub get_max_mask
{
    my $ip = shift;
    for (my $i = 31; $i>=0; $i--){
	if (($ip & $mask{$i}) eq $ip){
	    return $i;
	}
    }
    die("odd IP: ". unpack("N",$ip));
}

sub cut_hole
{
    my ($larger,$smaller) = @_;
    my $larger_ip = substr($larger,0,4);
    my $larger_mask = substr($larger,4,2);
    my $larger_cc = $ip{$larger};

    my $smaller_ip = substr($smaller,0,4);
    my $smaller_mask = substr($smaller,4,2);
    my $smaller_cc = $ip{$smaller};

    delete $ip{$larger};

    my $larger_begin = unpack("N",$larger_ip);
    my $larger_end = unpack("N",$larger_ip) + (2 ** unpack("C",$larger_mask));

    my $smaller_begin = unpack("N",$smaller_ip);
    my $smaller_end = unpack("N",$smaller_ip) + (2 ** unpack("C",$smaller_mask));

    if ($larger_begin < $smaller_begin){
#	print (inet_ntoa($larger_ip) .' '. ($smaller_begin-$larger_begin) .' '.$larger_cc."\n");
	add_region($larger_ip,$smaller_begin-$larger_begin,$larger_cc);
    }

    if ($larger_end > $smaller_end){
#	print (inet_ntoa(pack("N",$smaller_end)) .' '. ($larger_end-$smaller_end) .' '.$larger_cc."\n");
	add_region(pack("N",$smaller_end),$larger_end-$smaller_end,$larger_cc);
    }
}
