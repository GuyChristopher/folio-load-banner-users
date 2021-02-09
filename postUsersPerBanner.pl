#! /usr/bin/perl

require 'getOkapiToken.pl'; 

use JSON;
use DateTime;

$addressTypes= `curl -s -X GET -G -H '$jsonHeader' -H '$xOkapiToken' $baseURL/addresstypes?id="*"`; 
$hash = decode_json $addressTypes; 
for ( @{$hash->{addressTypes}} ) {
	$addressType = $_->{'addressType'};
	$id = $_->{'id'};
	$addressTypeId{$addressType} = $id;
}

$dateTime = DateTime->now;
$dateTime->subtract( hours => 5 );

$expDate4FacStaff = "2022-03-15";

$expDate4Students = "2021-07-15";

@userData = `cat allBannerInfo.txt`;

$users = `curl -s -X GET -G -H '$jsonHeader' -H '$xOkapiToken' -d "limit=2147483647" $baseURL/users?query=id="*"`;
$hash = decode_json $users; 
for ( @{$hash->{users}} ) {
	$barcode = $_->{'barcode'};
	$externalSystemId = $_->{'externalSystemId'};
	if (length($barcode) == 14) {$thisUser{$barcode} = $externalSystemId;}
}

$usergroups = `curl -s -X GET -G -H '$jsonHeader' -H '$xOkapiToken' -d 'limit=20' $baseURL/groups?id="*"`;
$hash = decode_json $usergroups; 
for ( @{$hash->{usergroups}} ) {
	$group = $_->{'group'};
	$id = $_->{'id'};
	$groupId{$group} = $id;
}

foreach $line (@userData) {
	
	@parsed = split(/\|/,$line);
	
	if ($thisUser{$parsed[0]} eq $parsed[1]) {
		
		$note2self = qq[this user is already in the system];
		
	} else {
		
		if ($parsed[19] eq "Y" || $parsed[20] eq "Y") {

			$active = qq["active":true,];

			$barcode = qq["barcode":"$parsed[0]",];

			$countNewUsers++;

			$enrollmentDate = qq["enrollmentDate":"$dateTime.000+0000",];

			$expirationDate = qq["expirationDate":"];
			if ($parsed[20] eq "Y") {
				$expirationDate .= $expDate4facStaff;
			} else {
				$expirationDate .= $expDate4Students;
			}
			$expirationDate .= qq[T23:59:59.000+0000",];

			$externalSystemId = qq["externalSystemId":"$parsed[1]",];

			$metadata = qq["metadata":{"createdDate":"$dateTime.000+0000"}];

			$patronGroup = qq["patronGroup":];
			if ($parsed[20] eq "Y" && $parsed[21] eq "FACULTY") {$patronGroupId = $groupId{'Faculty'};}
			if ($parsed[20] eq "Y" && $parsed[21] eq "LIBRARY") {$patronGroupId = $groupId{'Library Faculty and Staff'};}
			if ($parsed[20] eq "Y" && $parsed[21] eq "STAFF")   {$patronGroupId = $groupId{'Staff'};}
			if ($parsed[19] eq "Y" && $parsed[24] eq "C")       {$patronGroupId = $groupId{'CLA'};}
			if ($parsed[19] eq "Y" && $parsed[24] eq "G")       {$patronGroupId = $groupId{'CSGS'};}
			if ($parsed[19] eq "Y" && $parsed[24] eq "T")       {$patronGroupId = $groupId{'Theo'};}
			$patronGroup .= qq["$patronGroupId",];

			$personal = qq["personal":{];
			$personal .= qq["lastName":"$parsed[3]",];
			$personal .= qq["firstName":"$parsed[4]",];
			$personal .= qq["email":"$parsed[25]",];
			if ($parsed[5] ne "-") {$personal .= qq["middleName":"$parsed[5]",];}
			if ($parsed[17] eq $parsed[18]) {
				if ($parsed[13] ne "-") {
					$personal .= qq["phone":"$parsed[13]",];
				}
			} else {
				$personal .= qq["phone":"$parsed[17]-$parsed[18]",];
			}
			$personal .= qq["addresses":] . "[{";
			if ($parsed[12] ne "-") {$personal .= qq["countryId":"$parsed[12]",];}
			if ($parsed[7] ne "-")  {$personal .= qq["addressLine1":"$parsed[7]",];}
			if ($parsed[8] ne " ")  {$personal .= qq["addressLine2":"$parsed[8]",];}
			if ($parsed[9] ne "-")  {$personal .= qq["city":"$parsed[9]",];}
			if ($parsed[10] ne "-") {$personal .= qq["region":"$parsed[10]",];}
			if ($parsed[11] ne "-") {$personal .= qq["postalCode":"$parsed[11]",];}
			$personal .= qq["addressTypeId":"$addressTypeId{'Home'}",];
			$personal .= qq["primaryAddress":true}];
			if ($parsed[14] ne "-" || $parsed[15] ne "-" || $parsed[16] ne "-") {
				$personal .= qq[, {];
				if ($parsed[14] ne "-") {$campusAddressLine1 .= "$parsed[14]";}
				if ($parsed[15] ne "-") {$campusAddressLine1 .= "$parsed[15]";}
				if (length($campusAddressLine1) > 1) {$personal .= qq["addressLine1":"$campusAddressLine1",];}
				if ($parsed[16] ne "-") {$personal .= qq["addressLine2":"$parsed[16]",];}
				$personal .= qq["addressTypeId":"$addressTypeId{'Campus'}"}];
				$campusAddressLine1 = "";
			}
			$personal .= "]," . qq["preferredContactTypeId":"002"},];

			$type = qq["type":"patron",];

			$username = qq["username":]; @emailParsed = split(/\@/,$parsed[25]); $username .= qq["$emailParsed[0]",];

			$data = qq[{$username $externalSystemId $barcode $active $type $patronGroup $personal $enrollmentDate $expirationDate $metadata}]; 
			$data =~ s/'/'\\''/g; 
			$post = `curl -s -X POST -H '$jsonHeader' -H '$xOkapiToken' -d '$data' $baseURL/users`;
		 	
		}
	}
}

print "$countNewUsers users have been POSTed\n";

