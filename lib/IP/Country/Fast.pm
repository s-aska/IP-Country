package IP::Country::Fast;
use strict;
use Socket;
use Fcntl;
BEGIN { @AnyDBM_File::ISA = qw(SDBM_File GDBM_File NDBM_File DB_File ODBM_File ) }
use AnyDBM_File;

use vars qw ( $VERSION );
$VERSION = '211.008'; # NOV 2002, version 0.08

my $singleton = undef;
my %ip_db;
my $tld_match = qr/\.([a-zA-Z][a-zA-Z])$/o;
my $ip_match = qr/^([01]?\d\d|2[0-4]\d|25[0-5])\.([01]?\d\d|2[0-4]\d|25[0-5])\.([01]?\d\d|2[0-4]\d|25[0-5])\.([01]?\d\d|2[0-4]\d|25[0-5])$/o;

my %mask;
my %packed_range;

my @ip_distribution = (24,28,16,17,18,19,20,21,22,23,13,15,14,12,11,10,9,8);

foreach my $i (@ip_distribution){
    $mask{$i} = pack('B32', ('1'x(32-$i)).('0'x$i));
    $packed_range{$i} = pack('C',$i);
}

{
    (my $module_dir = $INC{'IP/Country/Fast.pm'}) =~ s/\.pm$//;
    my %database;
    tie (%database,'AnyDBM_File',"$module_dir/data",O_RDONLY, 0666)
	or die ("couldn't open registry database: $!");
    %ip_db = %database;
    untie %database;
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

sub inet_atocc
{
    my $inet_a = $_[1] || $_[0];
    unless ($inet_a =~ $ip_match){
	if ($inet_a =~ $tld_match){
	    return uc $1;
	}
    }
    return inet_ntocc(inet_aton($inet_a));
}

sub inet_ntocc
{
    my $inet_n = $_[1] || $_[0];
    foreach my $range (@ip_distribution)
    {
	my $masked_ip = $inet_n & $mask{$range};
	if (exists $ip_db{$masked_ip.$packed_range{$range}}){
	    return $ip_db{$masked_ip.$packed_range{$range}};
	}
    }
}

1;
__END__

=head1 NAME

IP::Country::Fast - fast lookup of country codes by IP address

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

This module will probably be most useful when used after domain lookup has failed,
or when it has returned a non-useful TLD (.com, .net, etc.).

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
over 10,000 IP addresses per second on a 730MHz PIII (Coppermine) and
over 20,000 IP addresses per second on a 1.3GHz Athlon. Out of this random 
selection of IP addresses, 43% had an associated country code. Please let 
me know if you've run this against a set of 'real' IP addresses from your
log files, and have details of the proportion of IPs that had associated
country codes.

=head1 BUGS/LIMITATIONS

Only works with IPv4 addresses. LACNIC ranges have not yet been incorporated.

=head1 SEE ALSO

L<IP::Country> - slower, but more accurate. Uses reverse hostname lookups
before consulting this database.

L<Geo::IP> - wrapper around the geoip C libraries. Faster, but less portable.

L<www.apnic.net> - Asia pacific

L<www.ripe.net> - Europe

L<www.arin.net> - North America

L<www.lacnic.net> - Latin America (soon)

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
