package IP::Country::Medium;
use strict;
use Carp;
use Socket qw ( inet_aton inet_ntoa AF_INET );
use IP::Country::Fast;

use vars qw ( $VERSION );
$VERSION = '0.02';

my $singleton = undef;

my $ip_match = qr/^(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])\.(\d|[01]?\d\d|2[0-4]\d|25[0-5])$/o;
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
    my $bool = defined $_[1] ? $_[1] : $_[0];
    if ($bool){
	$cache = 1;
    } else {
	$cache = 0;
	%cache = ();
    }
}

sub inet_atocc
{
    my $hostname = $_[1] || $_[0];
    if ($hostname =~ $ip_match){
	# IP address
	return inet_ntocc(inet_aton($hostname));
    } else {
	# assume domain name
	if ($cache && exists $cache{$hostname}){
	    return $cache{$hostname};
	} else {
	    if ($hostname =~ $tld_match){
		return $1;
	    } else {
		my $cc =  IP::Country::Fast::inet_atocc($hostname);
		$cache{$hostname} = $cc if $cache;
		return $cc;
	    }
	}
    }
}

sub inet_ntocc
{
    my $ip_addr = $_[1] || $_[0];
    if ($cache && exists $cache{$ip_addr}){
	return $cache{$ip_addr};
    } else {
	my $ip_dotted = inet_ntoa($ip_addr);
	return undef if ($ip_dotted =~ $private_ip);

	if (my $cc = IP::Country::Fast::inet_ntocc($ip_addr)){
	    return $cc;
	} elsif (gethostbyaddr($ip_addr, AF_INET) =~ $tld_match){
	    my $cc = $1;
	    $cache{$ip_addr} = $cc if $cache;
	    return $cc;
	} else {
	}
    }
    return undef;
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

IP::Country::Medium - cached lookup of country codes by IP address and domain name

=head1 SYNOPSIS

  use IP::Country::Medium;

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

3. The IP address is sent to the IP::Country::Fast module, which maintains a local 
database of country codes for various IP ranges.

4. If this fails to find a country code, and the IP address can be reverse mapped 
to a domain name, this is done, and that name is checked to see whether it ends 
in a two-letter top-level domain. If so, this is changed to upper case and returned.

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
IP::Country::Fast module, which maintains a local database of country codes for
various IP ranges.

4. If this still fails to find a country code, undef is returned.

=back

=head1 CONSTRUCTOR

The constructor takes no arguments.

  use IP::Country::Medium;
  my $ic = IP::Country::Medium->new();

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
