package IP::Country::Fast;
use strict;
$^W = 1;
use Socket qw ( inet_aton );

use vars qw ( $VERSION );
$VERSION = '212.007'; # DEC 2002, version 0.06

my $singleton = undef;
my $ip_db;
my $null = substr(pack('N',0),0,1);
my %cc;
my $tld_match = qr/\.([a-zA-Z][a-zA-Z])$/o;
my $ip_match = qr/^(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])$/o;

my $bit0 = substr(pack('N',2 ** 31),0,1);
my $bit1 = substr(pack('N',2 ** 30),0,1);
my @mask;
my @dtoc;
{
    for (my $i = 0; $i <= 32; $i++){
	$mask[$i] = pack('N',2 ** (32 - $i));
    }

    for (my $i = 0; $i <= 255; $i++){
	$dtoc[$i] = substr(pack('N',$i),3,1);
    }
    (my $module_dir = $INC{'IP/Country/Fast.pm'}) =~ s/\.pm$//;

    local $/;   # set it so <> reads all the file at once

    open (IP, "< $module_dir/ip.gif")
	or die ("couldn't read IP database: $!");
    binmode IP;
    $ip_db = <IP>;
    close IP;

    open (CC, "< $module_dir/cc.gif")
	or die ("couldn't read country database: $!");
    binmode CC;
    my $cc_ultra = <CC>;  # read in the file
    close CC;
    my $cc_num = (length $cc_ultra) / 3;
    for (my $i = 0; $i < $cc_num; $i++){
	my $cc = substr($cc_ultra,3 * $i + 1,2);
	$cc = undef if ($cc eq '--');
	$cc{substr($cc_ultra,3 * $i,1)} = $cc;
    }
}

sub new ()
{
    my $caller = shift;
    unless (defined $singleton){
        my $class = ref($caller) || $caller;
	$singleton = bless {}, $class;
    }
    return $singleton;
}

sub inet_atocc ($)
{
    my $inet_a = $_[1];
    if ($inet_a =~ $ip_match){
	return inet_ntocc($dtoc[$1].$dtoc[$2].$dtoc[$3].$dtoc[$4]);
    } elsif ($inet_a =~ $tld_match){
	return uc $1;
    } else {
	return inet_ntocc(inet_aton($inet_a));
    }
}

sub inet_ntocc ($)
{
    my $inet_n = $_[1] || $_[0];

    my $pos = 0;
#    print STDERR unpack('B32',$inet_n)."\n";
#    print STDERR "position: $pos\n";
    for (my $i = 1; $i <= 32; $i++){
	my $byte_zero = substr($ip_db,$pos,1);
	if (($byte_zero & $bit0) eq $bit0){ # country code
	    if (($byte_zero & $bit1) eq $bit1){ # unpopular country code - skip a byte
		return $cc{substr($ip_db,$pos+1,1)};
	    } else { # popular country code
		return $cc{$byte_zero ^ $bit0};
	    }
	} else {
	    if (($inet_n & $mask[$i]) eq $mask[$i]){
		my $jump = unpack('N',$null.substr($ip_db,$pos,3));
		$pos = $pos + 3 + $jump;
#		print STDERR "ONE: jumping: $jump\n";
	    } else {
		$pos = $pos + 3;
#		print STDERR "ZERO\n";
	    }
	}
    }
#    print STDERR "\n";
    return undef;
}

1;
__END__

=head1 NAME

IP::Country::Fast - fast lookup of country codes by IP address

=head1 SYNOPSIS

  use IP::Country::Fast;

=head1 DESCRIPTION

See documentation for IP::Country.

=cut
