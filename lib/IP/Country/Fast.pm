package IP::Country::Fast;
use strict;
$^W = 1;
use Socket qw ( inet_aton );

use vars qw ( $VERSION );
$VERSION = '212.005'; # DEC 2002, version 0.04

my $singleton = undef;
my %ip_db;
my %cc;
my $tld_match = qr/\.([a-zA-Z][a-zA-Z])$/o;
my $ip_match = qr/^(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])$/o;

my @dton;
my @dtoc;
{
    for (my $i = 0; $i <= 31; $i++){
	$dton[$i] = pack('N', 2**32 - 2**$i);
    }
    for (my $i = 0; $i <= 255; $i++){
	$dtoc[$i] = substr(pack('N',$i),3,1);
    }
    (my $module_dir = $INC{'IP/Country/Fast.pm'}) =~ s/\.pm$//;

    open (IP, "< $module_dir/ip.gif")
	or die ("couldn't create IP database: $!");
    binmode IP;
    my $ip_ultra;
    {
	local $/;   # set it so <> reads all the file at once
	$ip_ultra = <IP>;  # read in the file
    }
    close IP;
    my $ip_num = (length $ip_ultra) / 6;
    for (my $i = 0; $i < $ip_num; $i++){
	$ip_db{substr($ip_ultra,6 * $i,5)} = substr($ip_ultra,6 * $i + 5,1);
    }

    open (CC, "< $module_dir/cc.gif")
	or die ("couldn't create country database: $!");
    binmode CC;
    my $cc_ultra;
    {
	local $/;   # set it so <> reads all the file at once
	$cc_ultra = <CC>;  # read in the file
    }
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
    for (my $i = 31; $i >= 0; $i--)
    {
	my $masked_ip = $inet_n & $dton[$i];
	my $key = $masked_ip.$dtoc[$i];
	if (exists $ip_db{$key}){
	    return $cc{$ip_db{$key}};
	}
    }
    return undef;
}

1;
__END__

=head1 NAME

IP::Country::Ultra - fast lookup of country codes by IP address

=head1 SYNOPSIS

  use IP::Country::Fast;

=head1 DESCRIPTION

Finding the home country of a client using only the IP address can be difficult.
Looking up the domain name associated with that address can provide some help,
but many IP address are not reverse mapped to any useful domain, and the
most common domain (.com) offers no help when looking for country.

This module comes bundled with a database of countries where various IP addresses
have been assigned. Although the country of assignment will probably be the
country associated with a large ISP rather than the client herself, this is
probably good enough for most log analysis applications.

=head1 CONSTRUCTOR

The constructor takes no arguments.

  use IP::Country::Fast;
  my $reg = IP::Country::Fast->new();

=head1 OBJECT METHODS

All object methods are designed to be used in an object-oriented fashion.

  $result = $object->foo_method($bar,$baz);

Using the module in a procedural fashion (without the arrow syntax) won't work.

=over 4

=item $cc = $reg-E<gt>inet_atocc(HOSTNAME)

Takes a string giving the name of a host, and translates that to an
two-letter country code. Takes arguments of both the 'rtfm.mit.edu' 
type and '18.181.0.24'. If the host name cannot be resolved, returns undef. 
If the resolved IP address is not contained within the database, returns undef.
For multi-homed hosts (hosts with more than one address), the first 
address found is returned.

If domain names are submitted to inet_atocc that end with a two-letter 
top-level domain, this is upper-cased and returned without further effort. 
If you don't like this behaviour, call Socket::inet_aton() on the hostname 
and pass it to IP::Country::Fast::inet_ntocc() rather than this method.

=item $cc = $reg-E<gt>inet_ntocc(IP_ADDRESS)

Takes a string (an opaque string as returned by Socket::inet_aton()) 
and translates it into a two-letter country code. If the IP address is 
not contained within the database, returns undef.

=back

=head1 PERFORMANCE

With a random selection of 65,000 IP addresses, the module can look up
over 15,000 IP addresses per second on a 730MHz PIII (Coppermine) and
over 25,000 IP addresses per second on a 1.3GHz Athlon. Out of this random 
selection of IP addresses, 43% had an associated country code. Please let 
me know if you've run this against a set of 'real' IP addresses from your
log files, and have details of the proportion of IPs that had associated
country codes.

=head1 BUGS/LIMITATIONS

Only works with IPv4 addresses.

=head1 SEE ALSO

L<IP::Country> - slower, but more accurate. Uses reverse hostname lookups
before consulting this database.

L<Geo::IP> - wrapper around the geoip C libraries. Faster, but less portable.

L<www.apnic.net> - Asia pacific

L<www.ripe.net> - Europe

L<www.arin.net> - North America

L<www.lacnic.net> - Latin America

=head1 COPYRIGHT

Copyright (C) 2002 Nigel Wetters. All Rights Reserved.

NO WARRANTY. This module is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

Some parts of this software distribution are derived from the APNIC,
ARIN and RIPE databases (copyright details below). The author of
this module makes no claims of ownership on those parts.

=head1 APNIC conditions of use

The files are freely available for download and use on the condition 
that APNIC will not be held responsible for any loss or damage 
arising from the application of the information contained in these 
reports.

APNIC endeavours to the best of its ability to ensure the accuracy 
of these reports; however, APNIC makes no guarantee in this regard.

In particular, it should be noted that these reports seek to 
indicate the country where resources were first allocated or 
assigned. It is not intended that these reports be considered 
as an authoritative statement of the location in which any specific 
resource may currently be in use.

=head1 ARIN database copyright

Copyright (c) American Registry for Internet Numbers. All rights reserved.

=head1 RIPE database copyright

The information in the RIPE Database is available to the public 
for agreed Internet operation purposes, but is under copyright.
The copyright statement is:

"Except for agreed Internet operational purposes, no part of this 
publication may be reproduced, stored in a retrieval system, or transmitted, 
in any form or by any means, electronic, mechanical, recording, or 
otherwise, without prior permission of the RIPE NCC on behalf of the 
copyright holders. Any use of this material to target advertising 
or similar activities is explicitly forbidden and may be prosecuted. 
The RIPE NCC requests to be notified of any such activities or 
suspicions thereof."

=cut
