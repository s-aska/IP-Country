#!/usr/local/bin/perl -w
use strict;

use Net::FTP;

my $now = time();
my $yesterday = $now - (60 * 60 * 24);

my $dl = 
{
    'ftp.arin.net'   => [ { dir  => '/other/dump',
			    name => 'aup_dump.txt.gz',
			    gzip => 1 },
			  
			  { dir  => '/pub/stats/arin',
			    name => undef,
			    gzip => 0 } ],
    
    'ftp.ripe.net'   => [ { dir  => '/ripe/dbase/split',
			    name => 'ripe.db.inetnum.gz',
			    gzip => 1 },
			  
			  { dir  => '/ripe/stats',
			    name => undef,
			    gzip => 0 } ],
    
    'ftp.lacnic.net' => [ { dir  => '/pub/stats/lacnic',
			    name => undef,
			    gzip => 0 } ],
    
    'ftp.apnic.net'  => [ { dir  => '/public/apnic/stats/apnic',
			    name => undef,
			    gzip => 0 } ],

};

foreach my $site (keys %$dl){

    print "connecting to $site\n";
    my $connection = Net::FTP->new($site,(Timeout => 15));
    unless ($connection){
	warn("couldn't connect to ".$site);
	next;
    }

    unless ($connection->login()){
	warn("couldn't login to ".$site);
	$connection->quit();
	next;
    }

    foreach my $remote_file (@{$dl->{$site}}){

	unless ($connection->cwd($remote_file->{dir})){
	    warn ("couldn't change directory to ".$site.$remote_file->{dir});
	    next;
	}
	
	unless ($remote_file->{name}){
	    unless ($remote_file->{name} = latest_file($connection->ls())){
		warn("couldn't get directory listing of ".$site.$remote_file->{dir});
		next;
	    }
	}
    
	my $local_filename = $remote_file->{name};
	if ($remote_file->{gzip}){
	    $local_filename =~ s/\.gz$//
		unless (-e $local_filename);
	    unless ($connection->binary()){
		warn ("could set type to binary on ".$site);
		next;
	    }
	} else {
	    unless ($connection->ascii()){
		warn("could set type to ascii on ".$site);
		next;
	    }
	}

	if (-e $local_filename){
	    my $local_mdtm = (stat($local_filename))[9];
	    my $remote_mdtm = $connection->mdtm($remote_file->{name}) || $now;
	    print "Remote MDTM is ".localtime($remote_mdtm)."\n";
	    print "Local MDTM is ".localtime($local_mdtm)."\n";
	    if ($local_mdtm > $remote_mdtm){
		my $local_size = -s $local_filename;
		my $remote_size = $connection->size($remote_file->{name}) || 0;
		print "Remote SIZE is $remote_size bytes\n";
		print "Local SIZE is $local_size bytes\n";
		if (($local_size == $remote_size) ||
		    ($local_filename ne $remote_file->{name})){
		    print "skipping\n\n";
		    next;
		}
	    }
	    print "deleting partial or old download\n";
	    unlink $local_filename;
	}


	print "downloading ".$remote_file->{dir}.'/'.$remote_file->{name}."\n";
	unless ($connection->get($remote_file->{name})){
	    warn("couldn't get ".$remote_file->{name}." from ".$site);
	    next;
	}


	if ($remote_file->{gzip}){
	    print "unzipping\n";
	    my @args = ("gunzip", $remote_file->{name});
	    system(@args) == 0
		or warn "gunzip ".$remote_file->{name}." failed: $?";
	}

    }
    print "disconnecting\n\n";
    $connection->quit();
}

sub latest_file
{
    my @dir = @_;
    my $latest_file = "";
    my $latest_year  = 0;
    my $latest_month = 0;
    my $latest_day   = 0;
    foreach my $file (@dir){
	my ($day,$month,$year) = (0,0,0);
	if (($file =~ /(\d{4})(\d{2})(\d{2})$/) ||
	    ($file =~ /(\d{4})-(\d{2})-(\d{2})$/)){
	    ($day,$month,$year) = ($3,$2,$1);
	} else {
	    next;
	}
	if(($year > $latest_year) ||
	   (($year == $latest_year) && ($month > $latest_month)) ||
	   (($year == $latest_year) && ($month == $latest_month) && ($day > $latest_day))){
	    $latest_year = $year;
	    $latest_month = $month;
	    $latest_day = $day;
	    $latest_file = $file;
	}
    }
    return $latest_file;
}

