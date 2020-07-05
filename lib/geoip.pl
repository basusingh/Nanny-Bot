#!/usr/bin/perl -w

use strict;   # strict keeps us from making stupid typos.
use DBI;
use Geo::IP; # GeoIP is used for locating IP addresses.
use DynaLoader;

# connect to the region database.
my $region_names_dbh = DBI->connect("dbi:SQLite:dbname=databases/region_names","","");

print ( &geolocate_ip_win32($ARGV[0]) . "\n"  );


sub geolocate_ip_win32 {
    my $ip = shift;
    if (!defined($ip)) { return "Tried to geolocate a null IP"; }
    if ($ip !~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) { return "Tried to geolocate an invalid IP:  $ip"; }

    my $gi = Geo::IP->open("databases/GeoLiteCity.dat", GEOIP_STANDARD);

    my $record = $gi->record_by_name($ip);

    if (!defined($record)) {
	return 'nowhere in particular'; 
    }

    # region code is built as COUNTRY.REGION
    my $region_code = $record->country_code . '.' . $record->region;

    # check the database for this region code
    my $region_name;
    my $sth = $region_names_dbh->prepare("SELECT region_name FROM region_names WHERE region_code=?");
    $sth->execute($region_code) or &die_nice("Unable to execute query: $region_names_dbh->errstr\n");
    my @row = $sth->fetchrow_array;
    if ($row[0]) {
        $region_name = $row[0];
    } else {
        print "DEBUG: no region code for $region_code\n";
    }
    # end of database region lookup

    my $geo_ip_info;

    if (defined($record->city) ) {
	# we know the city
	if (defined($region_name)) {
	    # and we know the region name
	    if ($record->city ne $region_name) {
		# the city and region name are different, all three are relevant.
		$geo_ip_info = $record->city . ', ' . $region_name . ' - ' . $record->country_name;
	    } else {
		# the city and region name are the same.  Use city and country.
		$geo_ip_info = $record->city . ', ' . $record->country_name;		
	    }
	} else {
	    # Only two pieces we have are city and country.
	    $geo_ip_info = $record->city . ', ' . $record->country_name;
	}
    } elsif (defined($region_name)) {
	# don't know the city, but we know the region name and country.  close enough.
	$geo_ip_info = "$region_name, " . $record->country_name;
    } elsif (defined($record->country_name)) {
	# We may not know much, but we know the country.
	$geo_ip_info = $record->country_name;
    } elsif (defined($record->country_code)) {
	# How about a 2 letter country code at least?
	$geo_ip_info = $record->country_code;
    } else {
	# I give up.
	$geo_ip_info = 'nowhere in particular';
    }

    # debugging
    print "        Country Code: " . $record->country_code . "
        Country Code 3: " . $record->country_code3 . "
        Country Name: " . $record->country_name . "
        Region: " . $record->region . "
        Region Name: " . $region_name . "
        City: " . $record->city . "
        Postal Code: " . $record->postal_code . "
        Lattitude: " . $record->latitude . "
        Longitude: " . $record->longitude . "
        DMA Code: " . $record->dma_code . "
        Area Code: " . $record->area_code . "\n";

    return $geo_ip_info;
}
# END geolocate_ip_win32
