#!/usr/bin/perl -w

my $Version='1.0';

use strict;
use Getopt::Long;
use Switch;
use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request;

my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

my $o_apikey = undef;          	# ControlNCloud API KEY
my $o_type = undef;        	# "all" or ControlNCloud CHECK ID
my $o_help= undef;          	# wan't some help?
my $o_version= undef;          	# version
my $url = undef;
my $content = undef;
my $nstatus = undef;

sub print_usage {
    
    print "\ncheck_cnc.pl - Nagios Plugin\n\n";
    print "usage:\n";
    print "Usage: $0 -k <controlncloud_user_apikey> -t <check_type> [-v] [-h]\n";
    print "options:\n";
    print " -k           Your ControlNCloud API KEY\n";
    print " -t           -t all: overall status or -t <control id> : one control status or -t list : to get the list of your control\n";
    print " -v           display version\n"; 
    print " -h           display help\n\n"; 
    print "\nCopyright (C) 2014 TheControlNCloud <contact\@controlncloud.com>\n";
    print "check_cnc.pl comes with absolutely NO WARRANTY either implied or explicit\n";
    print "This program is licensed under the terms of the\n";
    print "GNU General Public License (check source code for details)\n";
    exit $ERRORS{'UNKNOWN'}; 

}

sub p_version{
    print "\nControlNCloud Nagios Plugin ",$Version,"\n";
    print_usage();
}

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'h'     => \$o_help,            'help'          => \$o_help,
        'k:s'   => \$o_apikey,          'apikey:s'    	=> \$o_apikey,
        't:s'   => \$o_type,            'type:s'     	=> \$o_type,
        'v'     => \$o_version,         'version'       => \$o_version,
        );

	if (defined ($o_help)) 		{ print_usage(); exit $ERRORS{"UNKNOWN"}};
	if (defined($o_version)) 	{ p_version(); exit $ERRORS{"UNKNOWN"}};
    	if (!defined($o_apikey)) 	{ print_usage(); exit $ERRORS{"UNKNOWN"}}
	if (!defined($o_type)) 		{ print_usage(); exit $ERRORS{"UNKNOWN"}}
}

#####################
# 		MAIN		#
#####################		
check_options();

if ($o_type eq "all"){
	$url = 'http://api.controlncloud.com/mychecks/plugin/status/';
	$content = '{"apiKey":"' . $o_apikey . '"}';
}
elsif ($o_type eq "list"){
	$url = 'http://api.controlncloud.com/mychecks/plugin/controls/';
	$content = '{"apiKey":"' . $o_apikey . '"}';
}
else {
	$url = 'http://api.controlncloud.com/mychecks/plugin/measure/';
	$content = '{"apiKey":"' . $o_apikey . '","controlId":"' . $o_type .'"}';
} 

my $ua = LWP::UserAgent->new();

my $h = HTTP::Headers->new(
        Content_Length  => length($content),
        Content_Type    => 'application/json'
        );

my $request = HTTP::Request->new('POST', $url, $h, $content);
my $response = $ua->request($request);
my $result =  $response->content;
my $code = $response->code( );
my $status = $response->status_line( );

if ($code  == 200) {
	$result  =~ s/[\"{}]+//g;
	$result  =~ s/r_result://;
	my @values = split(';', $result);
	my $nagios_status = $values[0];

	switch ($nagios_status) {
			case "0" 	{ $nstatus="OK"; }
			case "1" 	{ $nstatus="WARNING"; }
			case "2" 	{ $nstatus="CRITICAL"; }
			case "3" 	{ $nstatus="UNKNOWN"; }
			else 		{ $nstatus="UNKNOWN";}
		}
	if ($o_type eq "all"){

		my $nagios_perfdata = $values[1];
		my $nagios_output = $values[2];
		
		print "$nstatus-",$nagios_output,"|error=",$nagios_perfdata,";;;0\n";

		switch ($nagios_status) {
			case "0" 	{ exit $ERRORS{'OK'}; }
			case "1" 	{ exit $ERRORS{'WARNING'}; }
			case "2" 	{ exit $ERRORS{'CRITICAL'}; }
			case "3" 	{ exit $ERRORS{'UNKNOWN'}; }
			else 		{ exit $ERRORS{'UNKNOWN'};;}
		}
	}
	elsif ($o_type eq "list"){
		my $list_result = $response->content;
		$list_result  =~ s/[\"\\]+//g;
        	$list_result  =~ s/r_result://;
		$list_result  =~ s/{\[{//;	
		$list_result  =~ s/}\]}//;
		
		my @list_values = split("}.{",$list_result);
		
		print "\n\nControlNCloud Plugin List\n\n";
	
		foreach my $val (@list_values) {
			my @control_values = split(",",$val);
    			printf("%15s\t%30s\t%50s\n",$control_values[0],$control_values[1],$control_values[2]);
		}
		
	} 
	else {	

		my $nagios_perfdata = $values[1];
		my $nagios_perfdata_min = $values[2];
		my $nagios_perfdata_max = $values[3];
		my $nagios_output = $values[4];

		print "$nstatus-",$nagios_output,"|time=",$nagios_perfdata,"s;$nagios_perfdata_min;$nagios_perfdata_max;0\n";
		
		switch ($nagios_status) {
			case "0" 	{ exit $ERRORS{'OK'}; }
			case "1" 	{ exit $ERRORS{'WARNING'}; }
			case "2" 	{ exit $ERRORS{'CRITICAL'}; }
			case "3" 	{ exit $ERRORS{'UNKNOWN'}; }
			else 		{ exit $ERRORS{'UNKNOWN'};;}
		}

	}
} else {
	print "UNKNOWN - ",$status,"|error=0;;;0\n";  
	exit $ERRORS{'UNKNOWN'};
}

