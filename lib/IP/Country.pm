package IP::Country;
use strict;
use Carp;
use Socket;
use IP::Registry;

use vars qw ( $VERSION );
$VERSION = '1.66';

my $singleton = undef;
my $ip_match = qr/^([01]?\d\d|2[0-4]\d|25[0-5])\.([01]?\d\d|2[0-4]\d|25[0-5])\.([01]?\d\d|2[0-4]\d|25[0-5])\.([01]?\d\d|2[0-4]\d|25[0-5])$/o;
my $private_ip = qr/^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)/o; # RFC1918
my $tld_match = qr/\.([a-zA-Z][a-zA-Z])$/o;

my %cache;
my $cache = 1; # cache is switched on

sub new
{
    my $caller = shift;
    unless (defined $singleton){
        my $class = ref($caller) || $caller;
	$singleton = bless {}, $class;
    }
    return $singleton;
}

sub cache
{
    my ($self,$bool) = @_;
    if ($bool){
	$cache = 1;
    } else {
	$cache = 0;
	%cache = ();
    }
}

sub inet_atocc
{
    my ($self,$hostname) = @_;
    if ($hostname =~ $ip_match){
	# IP address
	return $self->inet_ntocc(inet_aton($hostname));
    } else {
	# assume domain name
	if ($cache && exists $cache{$hostname}){
	    return $cache{$hostname};
	} else {
	    if (my $cc = _get_cc_from_tld($hostname)){
		return $cc;
	    } else {
		my $cc =  IP::Registry->new()->inet_atocc($hostname);
		$cache{$hostname} = $cc if $cache;
		return $cc;
	    }
	}
    }
}

sub inet_ntocc
{
    my ($self,$ip_addr) = @_;
    if ($cache && exists $cache{$ip_addr}){
	return $cache{$ip_addr};
    } else {
	my $ip_dotted = inet_ntoa($ip_addr);
	return undef if $ip_dotted =~ $private_ip;
	if (my $hostname = gethostbyaddr($ip_addr, AF_INET)){
	    if (my $cc = _get_cc_from_tld($hostname)){
		$cache{$ip_addr} = $cc if $cache;
		return $cc;
	    }
	}
	my $cc = IP::Registry->new()->inet_ntocc($ip_addr);
	$cache{$ip_addr} = $cc if $cache;
	return $cc;
    }
}

sub _get_cc_from_tld ($)
{
    my $hostname = shift;
    if ($hostname =~ $tld_match){
	return uc $1;
    } else {
	return undef;
    }
}


1;
__END__

=head1 NAME

IP::Country - cached lookup of country codes by domain name and IP address

=head1 SYNOPSIS

  use IP::Country;

=head1 DESCRIPTION

Finding the home country of a client can be difficult. This module tries to ease this
process by presenting a combined interface to the domain and IP systems. The algorithm for
discovering country code differs slightly depending on whether the user enters a hostname
of the form '18.181.0.24' (IP address) or 'rtfm.mit.edu' (domain name).  Here's 
how a typical lookup of a county code might procede for a hostname of the form
'18.181.0.24':

=over 4

1. If the cache has been enabled, and the country code has previously been found, it is
immediately returned.

2. If the IP address is part of a private address range (e.g. 10.*, 192.168.*, or various
172. addresses), undef is returned [see RFC1918].

3. If the IP address can be reverse mapped to a domain name, this is done, and that
name is checked to see whether it ends in a two-letter top-level domain. If so,
this is changed to upper case and returned.

4. If reverse mapping fails to find a country code, the IP address is sent to
the IP::Registry module, which maintains a local database of country codes for
various IP ranges.

5. If this still fails to find a country code, undef is returned.

=back

Here's how a typical lookup of a county code might procede for a hostname of the 
form 'rtfm.mit.edu'.

=over 4

1. If the hostname ends with a two-letter top-level domain (TLD), this is changed to
upper case and returned.

2. If the cache has been enabled, and the country code has previously been found, it is
returned.

3. If the hostname can be resolved to an IP address. This IP address is sent to
IP::Registry module, which maintains a local database of country codes for
various IP ranges.

4. If this still fails to find a country code, undef is returned.

=back

Using these approaches, this module has a greater accuracy and coverage than the 
IP::Registry module alone. However, these benefits come at a price, which is the
speed decrease brought about by accessing the domain name system. If you're less
worried about accuracy and coverage, I recommend using the IP::Registry module.

=head1 CONSTRUCTOR

The constructor takes no arguments.

  use IP::Country;
  my $ic = IP::Country->new();

=head1 OBJECT METHODS

All object methods are designed to be used in an object-oriented fashion.

  $result = $object->foo_method($bar,$baz);

Using the module in a procedural fashion (without the arrow syntax) won't work.

=over 4

=item $country = $ic-E<gt>inet_atocc(HOSTNAME)

Takes a string giving the name of a host, and translates that to an
two-letter country code. Takes arguments of both the 'rtfm.mit.edu' 
type and '18.181.0.24'. If the country code cannot be found, returns undef. 

=item $country = $ic-E<gt>inet_ntocc(IP_ADDRESS)

Takes a string (an opaque string as returned by Socket::inet_aton()) 
and translates it into a two-letter country code. If the country code 
cannot be found, returns undef. 

=item $ic-E<gt>cache(BOOLEAN)

By default, the module caches results of country-code lookups. This feature 
can be switched off by setting cache to a false value (zero, empty string or 
undef), and can be switched on again by setting cache to a true value (anything
which isn't false).

  $ic->cache(0); # clears and disables cache
  $ic->cache(1); # enables the cache

The cache is formed at the class level, so any change in caching in one object
will affect all objectcs of this class. Turning off the cache also clears the
cache.

=back

=head1 COPYRIGHT

Copyright (C) 2002 Nigel Wetters. All Rights Reserved.

NO WARRANTY. This module is free software; you can redistribute 
it and/or modify it under the same terms as Perl itself.

=cut
