#! /usr/bin/perl
#    Licence : GPLv3
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>. 1

use strict;
use warnings;
use Getopt::Long;
use REST::Client;
use Data::Dumper;
use JSON;

my $action = "";
my $apitoken = "";
my $failoverip = "";
my $destinationip = "";
my $online_api_url = "https://api.online.net/api/v1/server/failover";
my ($silence, $negate);
GetOptions (
	"action=s" 		=> \$action,		"a=s"	=> \$action,
	"apitoken=s"	 	=> \$apitoken,		"t=s"	=> \$apitoken,
	"failoverip=s" 		=> \$failoverip,	"f=s"	=> \$failoverip,
	"destinationip=s"	=> \$destinationip,	"d=s"	=> \$destinationip,
	"negate"		=> \$negate,		"n"	=> \$negate,
	"silence"		=> \$silence,		"s"	=> \$silence
);

sub print_usage(){
	print("Usage : $0 --action|-a=ACTION --apitoken|-t=API_TOKEN --failoverip|-f=FAILOVER_IP --destinationip|-d=DESTINATION_IP [--negate|-n] [--silence|-s]\n");
	print("Where :\n");
	print("\tACTION is one of the following choice :\n");
	print("\t\t- start : migrate the FAILOVER_IP to DESTINATION_IP target\n");
	print("\t\t- stop : release the FAILOVER_IP, so it won't point anywhere\n");
	print("\t\t- status : get the IP failover status\n");
	print("\tAPI_TOKEN is the TOKEN given in online.net console (https://console.online.net/en/api/access)\n");
	print("\tFAILOVER_IP is the failover IP\n");
	print("\tDESTINATION_IP is the destination IP on which to point the failover IP\n");
	print("\t[--negate|-n] : when we just want to check that the failover IP is NOT assign to the destination. (optional)\n");
	print("\t[--silence|-s] : do all the stuff, silently. (optional)\n");
}


sub check_mandatory_options(){
	my $error_on_mandatory_option=0;
	if ( ! $action ){
		print("Please enter the targeted action using the --action switch.\n");
		$error_on_mandatory_option=1;
	};
	if ( $action !~ m/^(start|stop|status)$/ ){
		print("Wrong action called.\n");
		$error_on_mandatory_option=1;
	}
	if ( ! $apitoken ){
		print("Please enter the API token using the --apitoken switch.\n");
		$error_on_mandatory_option=1;
	};
	if ( ! $failoverip ){
		print("Please enter the failover IP using the --failoverip switch.\n");
		$error_on_mandatory_option=1;
	};
	if (( ! $destinationip ) and ( $action eq 'start')) {
		print("Destination is mandatory for action 'start'.\n");
		print("Please enter the destination IP using the --destinationip switch.\n");
		$error_on_mandatory_option=1;
	};
	if ( $error_on_mandatory_option == 1 ){
		print_usage();
		exit 1;
	}
}

check_mandatory_options();

if ( "$action" eq "start" ){
	my $client = REST::Client->new();
	$client->addHeader("Authorization", "Bearer $apitoken");
	$client->addHeader("X-Pretty-JSON", "0");

	my $req = 'source=' . $failoverip . '&destination=' . $destinationip;

	my $url = "$online_api_url/edit";
	$client->POST( $url, $req,  { "Content-type" => 'application/x-www-form-urlencoded'} );
	my $response=$client->responseContent();
#	print Dumper($client);
	if ( $client->responseCode() == 200 ){
		print "IP failover assigned to $destinationip\n";
		exit 0
	} elsif ( $client->responseCode() == 409 ){
		print "IP failover already assigned to $destinationip.\n";
		exit 0
	} else {
		my $error_explanation = decode_json($response);
		print "Error code $error_explanation->{'code'} : $error_explanation->{'error'}. (see https://console.online.net/fr/api/)\n";
		exit 1;
	};
}
	
if ( "$action" eq "stop" ){
	my $client = REST::Client->new();
	$client->addHeader("Authorization", "Bearer $apitoken");
	$client->addHeader("X-Pretty-JSON", "0");

	my $req = 'source=' . $failoverip . '&destination=';

	my $url = "$online_api_url/edit";
	$client->POST( $url, $req,  { "Content-type" => 'application/x-www-form-urlencoded'} );
	my $response=$client->responseContent();
	if ( $client->responseCode() == 200 ){
		print "IP failover successfuly unassigned.\n";
		exit 0
	} elsif ( $client->responseCode() == 409 ){
		print "IP failover already unassigned\n";
		exit 0
	} else {
		my $error_explanation = decode_json($response);
		print "Error code $error_explanation->{'code'} : $error_explanation->{'error'}. (see https://console.online.net/fr/api/)\n";
		exit 1;
	};
}
	
if ( "$action" eq "status" ){
	my $client = REST::Client->new();
	$client->addHeader("Authorization", "Bearer $apitoken");
	$client->addHeader("X-Pretty-JSON", "0");

	my $url = "$online_api_url";
	my $json_response;

	$client->GET($url);
	if ( $client->responseCode() == 200 ){
		$json_response = decode_json($client->responseContent());
	} else {
		print "Failed to get failover info " . $client->responseCode();
		exit 1;
	}
	foreach my $ip_failover (@$json_response) {
		if ( $ip_failover->{'source'} eq "$failoverip" ) {
			if (( ! $ip_failover->{'destination'}) and (! $destinationip)){
				print "Info : Failover IP is not assigned to any destination.\n" unless ($silence);
				exit 0;		
			} elsif (( ! $destinationip ) and ( $ip_failover->{'destination'}) and ( ! $negate )){
				print 'Info : Failover IP is assigned to ' . $ip_failover->{'destination'} . " .\n" unless ($silence);
				exit 0;		
			} elsif (( $destinationip ) and ( $ip_failover->{'destination'}) and ( $negate )){
				print 'CRITICAL : Failover IP is assigned to ' . $ip_failover->{'destination'} . ", whereas it should NOT !\n" unless ($silence);
				exit 1;		
			} elsif (( $destinationip ) and ( ! $ip_failover->{'destination'} )){
				print "CRITICAL : Failover IP is NOT assigned to $destinationip !\n" unless ($silence);
				exit 1;
			} elsif (( $destinationip ) and ( $ip_failover->{'destination'} eq "$destinationip" )) {
				print "OK : Failover IP is correctly assigned to $destinationip.\n" unless ($silence);
				exit 0;
			} elsif (( $destinationip ) and ( $ip_failover->{'destination'} ne "$destinationip" ) and ( ! $negate )){
				print "CRITICAL : Failover IP is NOT assigned to $destinationip !\n" unless ($silence);
				exit 1;
			} elsif (( $destinationip ) and ( $ip_failover->{'destination'} ne "$destinationip" ) and ( $negate )){
				print "Info : Failover IP is not assigned to $destinationip !\n" unless ($silence) ;
				exit 0;
			}
		}
	}
}
