#!/usr/bin/perl -w
use strict;
use DBI;
use Socket qw (inet_aton inet_ntoa);

my @mask;
for (my $i=0; $i<=31; $i++){
    $mask[$i] = pack('B32', ('1'x(32-$i)).('0'x$i));
}

my $dbh;
my $ip_match = qr/^(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])$/o;
my $reg_dir = 'rir_data';

my $insert_sql = 'INSERT INTO ranges (start,end,cc) VALUES (?,?,?)';

my ($datasource,$user,$pass) = @ARGV;
unless ($#ARGV == 2){
    print("usage: rdbms_reg.pl driver database username password\n  for example, ./rdbms_reg.pl dbi:mysql:foo fred passw0rd\n");
    exit;
}

$dbh = DBI->connect($datasource, $user, $pass)
    or die $DBI::errstr;
$dbh->do('DELETE FROM ranges')
    or die $dbh->errstr;

# RFC1918
insert( 167772160, 184549375,'**') or die("couldn't insert 10/8");       # 10.0.0.0 - 10.255.255.255 (10/8 prefix)
insert(2886729728,2887778303,'**') or die("couldn't insert 172.16/12");  # 172.16.0.0 - 172.31.255.255 (172.16/12 prefix)
insert(3232235520,3232301055,'**') or die("couldn't insert 192.168/16"); # 192.168.0.0 - 192.168.255.255 (192.168/16 prefix)

insert(3758096384,4294967295,'--') or die("couldn't insert IPv4 end ranges"); # 224.0.0.0 - 255.255.255.255

opendir(RIR,$reg_dir) or die("can't open $reg_dir: $!");
while (defined (my $path = readdir RIR)){
    next if $path =~ /^\.\.?$/;
    open (REG, "< $reg_dir/$path") || die("can't open $reg_dir/$path: $!");
    while (my $line = <REG>){
	chomp $line;
	next unless $line =~ /^([^\|]+)\|(..)\|ipv4\|([^\|]+)\|(\d+)\|/;
	my ($auth,$cc,$ip,$size) = ($1,$2,$3,$4);
	next if ($auth eq 'iana'); # ipv6 and private IP ranges
	if ($ip =~ $ip_match){
	    # next line converts IP address to unsigned integer
	    my $start = ($1 * 16777216) + ($2 * 65536) + ($3 * 256) + $4;
	    my $end = ($start - 1) + $size;
	    insert($start,$end,$cc)
		or die("couldn't insert $ip");
	} else {
	    next;
	}
    }
    close REG || warn("can't close $reg_dir/$path, but continuing: $!");
}
closedir(RIR);

optimize()
    or die("couldn't optimize");

output();

$dbh->disconnect();

sub output
{
    if (my $sth = $dbh->prepare("SELECT start,end,cc FROM ranges ORDER BY start")){
	if ($sth->execute()){
	    while (my ($start,$end,$cc) = $sth->fetchrow_array()){
		formatRange($start,$end,$cc);
	    }
	}
    }
}

sub formatRange
{
    my ($start,$end,$cc) = @_;
    my $ip = pack('N',$start);
    my $size = ($end - $start) + 1;

    while (1){
	my $mask = int(log($size)/log(2));
	my $max_mask = get_max_mask($ip);
	if ($max_mask < $mask){
	    $mask = $max_mask;
	}
	print inet_ntoa($ip).'|'. 2 ** $mask .'|'. $cc ."\n";
	$size = $size - (2 ** $mask);
	return unless ($size > 0);
	$ip = pack('N',(unpack('N',$ip) + 2 ** $mask)); 
    }
}

sub get_max_mask ($)
{
    my $ip = shift;
    for (my $i = 31; $i>=0; $i--){
	if (($ip & $mask[$i]) eq $ip){
	    return $i;
	}
    }
    die("strange IP: ". inet_ntoa($ip));
}

sub optimize
{
    my $success = 1;
    my $sth;
    my $start = -1;
    my $end = -1;
    my $cc = '--'; # empty
    if ($sth = $dbh->prepare("SELECT start,end,cc FROM ranges ORDER BY start")){
	if ($sth->execute()){
	    while (my ($next_start,$next_end,$next_cc) = $sth->fetchrow_array()){
		if ($end >= $next_end){
		    # delete unreachable ranges
		    $dbh->do("DELETE FROM ranges WHERE start=$next_start and end=$next_end");
		} else {
		    if ($end < ($next_start - 1)){
			# blanks between ranges
			insert($end + 1,$next_start - 1,'--')
			    or die("couldn't insert");
			$start = $next_start;
			$end = $next_end;
			$cc = $next_cc;
		    } elsif ($end == ($next_start - 1)) {
			# ranges abutt one another
			if ($cc eq $next_cc){
			    $dbh->do("DELETE FROM ranges WHERE start=$start and end=$end");
			    $dbh->do("DELETE FROM ranges WHERE start=$next_start and end=$next_end");
			    $end = $next_end;
			    insert($start,$end,$cc)
				or die("couldn't insert");
			} else {
			    $start = $next_start;
			    $end = $next_end;
			    $cc = $next_cc;
			}
		    } else {
			# ranges overlap
			if ($cc eq $next_cc){
			    $dbh->do("DELETE FROM ranges WHERE start=$start and end=$end");
			    $dbh->do("DELETE FROM ranges WHERE start=$next_start and end=$next_end");
			    $end = $next_end;
			    insert($start,$end,$cc)
				or die("couldn't insert");
			} else {
			    die("ranges overlap with differing country codes");
			}
		    }
		}
	    }
	}
    }
    return $success;
}

sub insert
# insert so long as range does not already include other country codes
{
    my ($start,$end,$cc) = @_;
    my $success = 1;
    my $sth;

    # remove indentical ranges
    if ($success){
	if ($sth = $dbh->prepare("SELECT start,end,cc FROM ranges WHERE start=$start OR end=$end")){
	    if ($sth->execute()){
		while (my ($old_start,$old_end,$old_cc) = $sth->fetchrow_array()){
		    if ($old_cc ne $cc){
			$success = 0;
		    } else {
			$start = $old_start if ($old_start < $start);
			$end = $old_end if ($old_end > $end);
 			$dbh->do("DELETE FROM ranges WHERE start=$old_start and end=$old_end")
			    or die $dbh->errstr;
		    }
		}
	    }
	}
    }

    # insert the new range
    if ($success){
	if ($sth = $dbh->prepare($insert_sql)){
	    unless ($sth->execute($start,$end,$cc)){
		warn $sth->errstr;
		$success = 0;
	    }
	} else {
	    warn $dbh->errstr;
	    $success = 0;
	}
	
	return $success;
    }
}

__END__

=head1 NAME

rdbms_reg.pl - generates a complete list of IP-country codes using a relational database

=head1 SYNOPSIS

  ./rdbms_reg.pl dbi:mysql:foo fred passw0rd

=head1 IMPORTANT

Note that it is *not* necessary to run this script to install the IP::Country modules.
It is only included with this distribution for completeness, so that you will be able to
work out the entire process of converting raw Internet registry files to the fast database
used by the bundled modules.

The output of this script can be found in the file named ./sorted_ranges.txt

=head1 DESCRIPTION

The files distributed by the regional Internet registries (included with
this distribition under the ./rir_data directory) contain ranges of IP addresses that
have been allocated to ISPs in various countries.

To produce a fast database for the IP::Country modules, it is essential to know not
only the allocated ranges, but also the unallocated ranges. It is also advantageous
to concatenate abutting ranges allocated to the same country.

This script does all this, and prints (to STDOUT) a list of ranges covering the entire
IPv4 space, in the following format:

  dotted_ip|size_of_range|country_code

For example:

  64.39.224.0|4096|US
  64.39.240.0|4096|--
  64.40.0.0|16384|US
  64.40.64.0|8192|US
  64.40.96.0|4096|CA

Where coutry_code is the two-letter international country code, or '--' for an 
unallocated range, or '**' for a private range (see RFC1918).

=head1 DATABASE SCHEMA

This script should work with most relational databases, so long as a table exists
with the following column definitions:

  start INT UNSIGNED
  end INT UNSIGNED
  cc CHARACTER (2)

I have enclosed a schema that can be used with MySQL as the file ./mysql_schema.sql

I would welcome bug reports or patches if you notice problems using this script with
any other database systems.

=cut
