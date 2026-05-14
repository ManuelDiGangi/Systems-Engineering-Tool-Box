#!/usr/bin/perl
#
# check_bgp - nagios plugin 
#
# Copyright (C) 2006 Larry Low
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
# Report bugs to:  llow0@yahoo.com
#
# Primary MIB reference - BGP4-MIB
#
# Version 0.6 
# - added support for Cisco ASR1k & ASR9k, IPv6, prefix count, min/max prefix warnings - Michael Buschmann / Cisco  
# Version 0.5
#  - added bgp prefix count support juniper only
# Version 0.4
#  - added snmpv3 support
# Version 0.3 
#  - fixed $snmp was not checked for being defined
# Version 0.2
#  - added conformed with ePN
#

use strict;
use warnings;
use Data::Dumper ;
## Adjust lib to point to where ever 'utils' lives
use lib "/opt/software/cmdb-remote-poller/check-scripts";
use Net::IP;
#use utils qw($TIMEOUT %ERRORS &print_revision &support);
use vars qw($PROGNAME);
use Nagios::Plugin qw(%ERRORS);
my $TIMEOUT = 60;
#use Nagios::Plugin qw($TIMEOUT);

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
	print ("ERROR: Plugin took too long to complete (alarm)\n");
	exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

$PROGNAME = "check_bgp.0.5.pl";
sub print_help ();
sub print_usage ();
use POSIX qw(floor);
sub seconds_to_string($);

my ($opt_h,$opt_V,$opt_i);
my $community = "public";
my $snmp_version = 2;
my ($hostname,$bgppeer);
my ($bgpmin,$bgpmax);
#my inv = 0;

# number of variables to return on a get_table / get_bulk query
# if too many, might go over the MTU and the IP packet will be fragmented
# which will break things
my $max_repetions = 10;

use Getopt::Long;
&Getopt::Long::config('bundling');
GetOptions(
    "i" => \$opt_i,     "inverso" => \$opt_i,       #asggiunta opzione inverso per avvisare quando le rottte ricevute sono piu di zero
	"V"   => \$opt_V,	"version"    => \$opt_V,
	"h"   => \$opt_h,	"help"       => \$opt_h,
	"C=s" => \$community,	"community=s" => \$community,
	"H=s" => \$hostname,	"hostname=s" => \$hostname,
	"p=s" => \$bgppeer,	"peer=s" => \$bgppeer,
    "min=i" => \$bgpmin, "min=i" => \$bgpmin,
    "max=i" => \$bgpmax, "max=i" => \$bgpmax,
    "v=i" => \$snmp_version,"snmp_version=i" => \$snmp_version
);


# -h & --help print help
if ($opt_h) { print_help(); exit $ERRORS{'OK'}; }
# -V & --version print version
if ($opt_V) { print_revision($PROGNAME,'$Revision: 0.6 $ '); exit $ERRORS{'OK'}; }
# Invalid hostname print usage
#if (!utils::is_hostname($hostname)) { print_usage(); exit $ERRORS{'UNKNOWN'}; }
# No BGP peer specified, print usage
if (!defined($bgppeer)) { print_usage(); exit $ERRORS{'UNKNOWN'}; }

## ASR Support for IPv6 only 
my $IPv6;

### Function to convert v6 peer to decimal for snmp
sub IPv6_To_OID
    {
    my $ip_str = $_[0];
    my $ip_oid;
    my $i;
    foreach my $c (split(':',$ip_str))
        {
        $ip_oid .= sprintf("%s.", hex(substr($c, 0, 2)));
        $i++;
        if($i<15)
            {
            $ip_oid .= sprintf("%s.", hex(substr($c, 2, 2)));
            $i++;
            }
    else
            {
            $ip_oid .= sprintf("%s", hex(substr($c, 2, 2)));
            }
        }
    return $ip_oid;
    }

## Check if the peer IP is v6 or v4

my $bgppeer_family_check = new Net::IP ($bgppeer);

if ($bgppeer_family_check->version() == '6') { 
    $IPv6 = '1';
} elsif ($bgppeer_family_check->version() == '4') {
    $IPv6 = '0';
}



# Setup SNMP object
use Net::SNMP qw(INTEGER OCTET_STRING IPADDRESS OBJECT_IDENTIFIER NULL);
my ($snmp, $snmperror);
if ($snmp_version == 2) {
	($snmp, $snmperror) = Net::SNMP->session(
		-hostname => $hostname,
		-version => 'snmpv2c',
		-community => $community
	);
} elsif ($snmp_version == 3) {
	my ($v3_username,$v3_password,$v3_protocol,$v3_priv_passphrase,$v3_priv_protocol) = split(":",$community);
	my @auth = ();
	if (defined($v3_password)) { push(@auth,($v3_password =~ /^0x/) ? 'authkey' : 'authpassword',$v3_password); }
	if (defined($v3_protocol)) { push(@auth,'authprotocol',$v3_protocol); }
	if (defined($v3_priv_passphrase)) { push(@auth,($v3_priv_passphrase =~ /^0x/) ? 'privkey' : 'privpassword',$v3_priv_passphrase); }
	if (defined($v3_priv_protocol)) { push(@auth,'privprotocol',$v3_priv_protocol); }

	($snmp, $snmperror) = Net::SNMP->session(
		-hostname => $hostname,
		-version => 'snmpv3',
		-username => $v3_username,
		@auth
	);
} else {
	($snmp, $snmperror) = Net::SNMP->session(
		-hostname => $hostname,
		-version => 'snmpv1',
		-community => $community
	);
}

if (!defined($snmp)) {
	print ("UNKNOWN - SNMP error: $snmperror\n");
	exit $ERRORS{'UNKNOWN'};
}

### Check for ASR1k or ASR9k, if not assume Junos for now - Version 0.6 only adds ASR and V6

my $result ;
my $sysObjectID = '1.3.6.1.2.1.1.2.0';
$result = $snmp->get_request(-varbindlist => [$sysObjectID]) ;
if (!defined($result)) {
        print("UNKNOWN: SNMP get_request : ".$snmp->error()."\n");
            exit $ERRORS{'UNKNOWN'};
        } 

my $systemOID = $result->{$sysObjectID};
my $model = '';

## We are an ASR if
if ( $systemOID eq '1.3.6.1.4.1.9.1.1525' or $systemOID eq '1.3.6.1.4.1.9.1.2144' or $systemOID eq '1.3.6.1.4.1.9.1.1017' or $systemOID eq '1.3.6.1.4.1.9.12.3.1.3.1507' or $systemOID eq '1.3.6.1.4.1.9.1.1018') {
    $model = 'asr';
}


my $state = 'UNKNOWN';
my $bgp_state ;
my $prefix_state ;
my $output = "Impossibile recuperare informazioni per $bgppeer";
my $perf_data ="";
my $bgpmin_warning = "Warning we are recieving less routes than expected";
my $bgpmax_warning = "Warning we are recieving more routes than expected";

# Begin plugin check code

    if (!defined($result)) {
        my $answer = $snmp->error;
        $snmp->close;
        print ("UNKNOWN: SNMP error: $answer\n");
        exit $ERRORS{'UNKNOWN'};
    }

if ($IPv6 eq '1') {
  my $bgppeer_v6 .= IPv6_To_OID(Net::IP::ip_expand_address($bgppeer, 6));
  #print "-- $bgppeer_v6 --"; #decommentare per prendere l' indirizzo IPV6 del neighbor in notazione con i punti
    my $bgpPeerState = "1.3.6.1.4.1.9.9.187.1.2.5.1.3.2.16";
    my $bgpPeerRemoteAs = "1.3.6.1.4.1.9.9.187.1.2.5.1.11.2.16";
    my $bgpPeerFsmEstablishedTime = "1.3.6.1.4.1.9.9.187.1.2.5.1.19.2.16";
    my $bgpPeerLastError = "1.3.6.1.4.1.9.9.187.1.2.5.1.28.2.16";

    my %bgpPeerStates = (
        -1 => 'unknown(-1)',
        1 => 'idle(1)',
        2 => 'connect(2)',
        3 => 'active(3)',
        4 => 'opensent(4)',
        5 => 'openconfirm(5)',
        6 => 'established(6)'
    );

    my %bgpPeerAdminStatuses = (
        1=>'stop(1)',
        2=>'start(2)'
    );

    my %bgpErrorCodes = (
        '01 00' => 'Message Header Error',
        '01 01' => 'Message Header Error - Connection Not Synchronized',
        '01 02' => 'Message Header Error - Bad Message Length',
        '01 03' => 'Message Header Error - Bad Message Type',
        '02 00' => 'OPEN Message Error',
        '02 01' => 'OPEN Message Error - Unsupported Version Number',
        '02 02' => 'OPEN Message Error - Bad Peer AS',
        '02 03' => 'OPEN Message Error - Bad BGP Identifier',
        '02 04' => 'OPEN Message Error - Unsupported Optional Parameter',
        '02 05' => 'OPEN Message Error', #deprecated
        '02 06' => 'OPEN Message Error - Unacceptable Hold Time',
        '03 00' => 'UPDATE Message Error',
        '03 01' => 'UPDATE Message Error - Malformed Attribute List',
        '03 02' => 'UPDATE Message Error - Unrecognized Well-known Attribute',
        '03 03' => 'UPDATE Message Error - Missing Well-known Attribute',
        '03 04' => 'UPDATE Message Error - Attribute Flags Error',
        '03 05' => 'UPDATE Message Error - Attribute Length Erro',
        '03 06' => 'UPDATE Message Error - Invalid ORIGIN Attribute',
        '03 07' => 'UPDATE Message Error', #deprecated
        '03 08' => 'UPDATE Message Error - Invalid NEXT_HOP Attribute',
        '03 09' => 'UPDATE Message Error - Optional Attribute Error',
        '03 0A' => 'UPDATE Message Error - Invalid Network Field',
        '03 0B' => 'UPDATE Message Error - Malformed AS_PATH',
        '04 00' => 'Hold Timer Expired',
        '05 00' => 'Finite State Machine Error',
        '06 00' => 'Cease',
        '06 01' => 'Cease - Maximum Number of Prefixes Reached',
        '06 02' => 'Cease - Administrative Shutdown',
        '06 03' => 'Cease - Peer De-configured',
        '06 04' => 'Cease - Administrative Reset',
        '06 05' => 'Cease - Connection Rejected',
        '06 06' => 'Cease - Other Configuration Change',
        '06 07' => 'Cease - Connection Collision Resolution',
        '06 08' => 'Cease - Out of Resources'
    );
    #print $bgppeer_v6;
    my @snmpoids;
    push (@snmpoids,"$bgpPeerState.$bgppeer_v6");
    push (@snmpoids,"$bgpPeerRemoteAs.$bgppeer_v6");
    push (@snmpoids,"$bgpPeerFsmEstablishedTime.$bgppeer_v6");
    push (@snmpoids,"$bgpPeerLastError.$bgppeer_v6");
    my $result = $snmp->get_request(
        -varbindlist => \@snmpoids
    );

    my $lasterror;
	my $lasterrorcode = $result->{"$bgpPeerLastError.$bgppeer_v6"};
    
    
    if ($result->{"$bgpPeerState.$bgppeer_v6"} ne "noSuchInstance") {
        #print Dumper(\$result), "\n";
        $output = "Stato connessione con $bgppeer (AS".
            $result->{"$bgpPeerRemoteAs.$bgppeer_v6"}.
            ") <br> Stato: ".
            $bgpPeerStates{$result->{"$bgpPeerState.$bgppeer_v6"}} ." <br>";

        my $establishedtime = seconds_to_string($result->{"$bgpPeerFsmEstablishedTime.$bgppeer_v6"});
        my $p_accepted = "0";
        my $p_rejected = "0";
        my $p_bgpmax_warning = "Warning we are recieving less routes than expected";
        my $p_bgpmin_warning = "Warning we are recieving more routes than expected";                

        if ($model eq 'asr' ) {
            if ($result->{"$bgpPeerState.$bgppeer_v6"} == 6) {
                $bgp_state = 'OK';
                # Now try to get num of prefixes received by this peer.
                my $peer_index_oid = "1.3.6.1.2.1.15.3.1.2";
                my $bgp_index = $snmp->get_table(-baseoid => $peer_index_oid, -maxrepetitions => $max_repetions);
                if (defined($bgp_index)) {
                    #print Dumper(\$bgp_index), "\n";
                    my $peer_id = undef;
                    foreach my $key ( keys %$bgp_index) {
                        #print ($key," : ",$$bgp_index{$key},"\n");
                        if ($key =~ /$bgppeer$/) {
                            #print "found index $$bgp_index{$key} for $bgppeer_v6\n";
                            $peer_id = $$bgp_index{$key};
                        }
                    }
                    if(defined($bgppeer_v6)) {
                        my @numprefix_oid;
                        my $accepted_prefixes =  ".1.3.6.1.4.1.9.9.187.1.2.8.1.1.2.16.$bgppeer_v6.2.1";
                        ## Rejected Prefixes are cumulative on ASRs
                        my $rejected_prefixes =  ".1.3.6.1.4.1.9.9.187.1.2.8.1.2.2.16.$bgppeer_v6.2.1";
                        push (@numprefix_oid, $accepted_prefixes, $rejected_prefixes);
                        my $prefix_result = $snmp->get_request(
                            -varbindlist => \@numprefix_oid
                        );
                        if (defined($prefix_result->{$accepted_prefixes})) {
                            $p_accepted = $prefix_result->{$accepted_prefixes};
                            ### Check if received is less than our minimum
                            if (defined($bgpmin) && ($p_accepted < $bgpmin)) {
                                $prefix_state = "WARNING";
                            } elsif (defined($bgpmax) && ($p_accepted > $bgpmax)) {
                                $prefix_state = "WARNING";
                            } elsif (defined($bgpmin) && ($p_accepted > $bgpmin)) {
                                $prefix_state = "OK";
                            } elsif (defined($bgpmax) && ($p_accepted < $bgpmax)) {
                                $prefix_state = "OK";
                            }
                        }
                        if (defined($prefix_result->{$rejected_prefixes})) {
                            $p_rejected = $prefix_result->{$rejected_prefixes};
                        }
                    }
                }
                if ($opt_i) {
                     if (($bgp_state eq 'OK') && ($p_accepted <= 0)) {
                        $state = 'OK';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    } elsif (($bgp_state eq 'OK') && ($p_accepted > 0)) {
                        $state = 'WARNING';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    }
                } else {
                    ## Check for warnings with args and set exit status 
                    if ((defined($bgpmin)) && (defined($bgp_state)) && ($bgp_state eq 'OK') && ($prefix_state eq 'OK')) {
                        $state = 'OK';
                        $output .= "Connessione stabilita da $establishedtime <br> expected_min=$bgpmin, prefixes_rejected=$p_rejected <br> Ultimo messaggio di errore: $lasterrorcode";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    } elsif ((defined($bgpmin)) && ($bgp_state eq 'OK') && ($prefix_state eq 'WARNING')) { 
                        $state = 'WARNING';   
                        $output .= "Connessione stabilita da $establishedtime <br> $bgpmin_warning expected_min=$bgpmin, prefixes_rejected=$p_rejected <br> Ultimo messaggio di errore: $lasterrorcode";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected"; 
                    } elsif ((defined($bgpmax)) && (defined($bgp_state)) && ($bgp_state eq 'OK') && ($prefix_state eq 'OK')) {
                        $state = 'OK';
                        $output .= "Connessione stabilita da $establishedtime <br> expected_min=$bgpmax, prefixes_rejected=$p_rejected <br> Ultimo messaggio di errore: $lasterrorcode"; 
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    } elsif ((defined($bgpmax)) && ($bgp_state eq 'OK') && ($prefix_state eq 'WARNING')) {
                        $state = 'WARNING'; 
                        $output .= "Connessione stabilita da $establishedtime <br> $bgpmax_warning expected_max=$bgpmax, prefixes_rejected=$p_rejected <br> Ultimo messaggio di errore: $lasterrorcode";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    } elsif (($bgp_state eq 'OK') && ($p_accepted > 0)) {
                        $state = 'OK';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterrorcode";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    }elsif (($bgp_state eq 'OK') && ($p_accepted <= 0)) {
                        $state = 'WARNING';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterrorcode";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    }
                }
            } else {
                $output .= "Connessione stabilita da $establishedtime. <br> Ultimo messaggio di errore: $lasterrorcode";
                $state = 'CRITICAL';
            }        
        }
    }
} else {

	my $bgpPeerState = "1.3.6.1.2.1.15.3.1.2"; 
	my $bgpPeerAdminStatus = "1.3.6.1.2.1.15.3.1.3";
	my $bgpPeerRemoteAs = "1.3.6.1.2.1.15.3.1.9";
	my $bgpPeerLastError = "1.3.6.1.2.1.15.3.1.14";
	my $bgpPeerFsmEstablishedTime = "1.3.6.1.2.1.15.3.1.16";

	my %bgpPeerStates = (
		-1 => 'unknown(-1)',
		1 => 'idle(1)',
		2 => 'connect(2)',
		3 => 'active(3)',
		4 => 'opensent(4)',
		5 => 'openconfirm(5)',
		6 => 'established(6)'
	);

	my %bgpPeerAdminStatuses = (
		1=>'stop(1)',
		2=>'start(2)'
	);

	my %bgpErrorCodes = (
		'01 00' => 'Message Header Error',
		'01 01' => 'Message Header Error - Connection Not Synchronized',
		'01 02' => 'Message Header Error - Bad Message Length',
		'01 03' => 'Message Header Error - Bad Message Type',
		'02 00' => 'OPEN Message Error',
		'02 01' => 'OPEN Message Error - Unsupported Version Number',
		'02 02' => 'OPEN Message Error - Bad Peer AS',
		'02 03' => 'OPEN Message Error - Bad BGP Identifier',
		'02 04' => 'OPEN Message Error - Unsupported Optional Parameter',
		'02 05' => 'OPEN Message Error', #deprecated
		'02 06' => 'OPEN Message Error - Unacceptable Hold Time',
		'03 00' => 'UPDATE Message Error',
		'03 01' => 'UPDATE Message Error - Malformed Attribute List',
		'03 02' => 'UPDATE Message Error - Unrecognized Well-known Attribute',
		'03 03' => 'UPDATE Message Error - Missing Well-known Attribute',
		'03 04' => 'UPDATE Message Error - Attribute Flags Error',
		'03 05' => 'UPDATE Message Error - Attribute Length Erro',
		'03 06' => 'UPDATE Message Error - Invalid ORIGIN Attribute',
		'03 07' => 'UPDATE Message Error', #deprecated
		'03 08' => 'UPDATE Message Error - Invalid NEXT_HOP Attribute',
		'03 09' => 'UPDATE Message Error - Optional Attribute Error',
		'03 0A' => 'UPDATE Message Error - Invalid Network Field',
		'03 0B' => 'UPDATE Message Error - Malformed AS_PATH',
		'04 00' => 'Hold Timer Expired',
		'05 00' => 'Finite State Machine Error',
		'06 00' => 'Cease',
		'06 01' => 'Cease - Maximum Number of Prefixes Reached',
		'06 02' => 'Cease - Administrative Shutdown',
		'06 03' => 'Cease - Peer De-configured',
		'06 04' => 'Cease - Administrative Reset',
		'06 05' => 'Cease - Connection Rejected',
		'06 06' => 'Cease - Other Configuration Change',
		'06 07' => 'Cease - Connection Collision Resolution',
		'06 08' => 'Cease - Out of Resources'
	);

	my @snmpoids;
	push (@snmpoids,"$bgpPeerState.$bgppeer");
	push (@snmpoids,"$bgpPeerAdminStatus.$bgppeer");
	push (@snmpoids,"$bgpPeerRemoteAs.$bgppeer");
	push (@snmpoids,"$bgpPeerLastError.$bgppeer");
	push (@snmpoids,"$bgpPeerFsmEstablishedTime.$bgppeer");
	my $result = $snmp->get_request(
		-varbindlist => \@snmpoids
	);

	if ($result->{"$bgpPeerState.$bgppeer"} ne "noSuchInstance") {
		$output = "Stato connessione con $bgppeer (AS". $result->{"$bgpPeerRemoteAs.$bgppeer"}.
			") <br> Stato: ".
			$bgpPeerStates{$result->{"$bgpPeerState.$bgppeer"}} ." <br>";


		my $lasterror;
		my $lasterrorcode = $result->{"$bgpPeerLastError.$bgppeer"};
		if (hex($lasterrorcode) != 0) {
			$lasterrorcode = substr($lasterrorcode,2,2)." ".substr($lasterrorcode,4,2);
			my ($code,$subcode) = split(" ",$lasterrorcode);
			if (!defined($bgpErrorCodes{$lasterrorcode})) {
				$lasterror = $bgpErrorCodes{"$code 00"};
			} else {
				$lasterror = $bgpErrorCodes{$lasterrorcode};
			}
			if (!defined($lasterror)) {
				$lasterror = "Unknown ($code $subcode)";
			}
		}

       	my $establishedtime = seconds_to_string($result->{"$bgpPeerFsmEstablishedTime.$bgppeer"});
        my $p_accepted = "0";
        my $p_rejected = "0";
        my $p_bgpmax_warning = "Warning we are recieving less routes than expected";
        my $p_bgpmin_warning = "Warning we are recieving more routes than expected";        

        ## Added support for Cisco ASRs
        if ($model eq 'asr' ) {
    		if ($result->{"$bgpPeerState.$bgppeer"} == 6) {
    		    $bgp_state = 'OK';
                # Now try to get num of prefixes received by this peer.
    			my $peer_index_oid = "1.3.6.1.2.1.15.3.1.2";
    			my $bgp_index = $snmp->get_table(-baseoid => $peer_index_oid, -maxrepetitions => $max_repetions);
    			if (defined($bgp_index)) {
                    #print Dumper(\$bgp_index), "\n";
                    my $peer_id = undef;
    				foreach my $key ( keys %$bgp_index) {
    					#print ($key," : ",$$bgp_index{$key},"\n");
    					if ($key =~ /$bgppeer$/) {
    						#print "found index $$bgp_index{$key} for $bgppeer\n";
    						$peer_id = $$bgp_index{$key};
    					}
    				}
    				if(defined($peer_id)) {
                        my @numprefix_oid;
    					my $accepted_prefixes =  ".1.3.6.1.4.1.9.9.187.1.2.4.1.1.$bgppeer.1.1";
                        ## Rejected Prefixes are cumulative on ASRs
                        my $rejected_prefixes =  ".1.3.6.1.4.1.9.9.187.1.2.4.1.2.$bgppeer.1.1";
    	 				push (@numprefix_oid, $accepted_prefixes, $rejected_prefixes);
    					my $prefix_result = $snmp->get_request(
    						-varbindlist => \@numprefix_oid
                        );
                        if (defined($prefix_result->{$accepted_prefixes})) {
                            $p_accepted = $prefix_result->{$accepted_prefixes};
                            ### Check if received is less than our minimum
                            if (defined($bgpmin) && ($p_accepted < $bgpmin)) {
                                $prefix_state = "WARNING";
                            } elsif (defined($bgpmax) && ($p_accepted > $bgpmax)) {
                                $prefix_state = "WARNING";
                            } elsif (defined($bgpmin) && ($p_accepted >= $bgpmin)) {
                                $prefix_state = "OK";
                            } elsif (defined($bgpmax) && ($p_accepted <= $bgpmax)) {
                                $prefix_state = "OK";
                            }
                        }
                        if (defined($prefix_result->{$rejected_prefixes})) {
                            $p_rejected = $prefix_result->{$rejected_prefixes};
                        }
                    }
                }
                if ($opt_i) {
                    if (($bgp_state eq 'OK') && ($p_accepted <= 0)) {
                        $state = 'OK';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    } elsif (($bgp_state eq 'OK') && ($p_accepted > 0)) {
                        $state = 'WARNING';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    }
                } else {
                     ## Check for warnings with args and set exit status
                     if ((defined($bgpmin)) && (defined($bgp_state)) && ($bgp_state eq 'OK') && ($prefix_state eq 'OK')) {
                        $state = 'OK';
                        $output .= "Connessione stabilita da $establishedtime, expected_min=$bgpmin, prefixes_rejected=$p_rejected";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                     } elsif ((defined($bgpmin)) && ($bgp_state eq 'OK') && ($prefix_state eq 'WARNING')) {
                        $state = 'WARNING';
                        $output .= "Connessione stabilita da $establishedtime, $bgpmin_warning expected_min=$bgpmin, Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                     } elsif ((defined($bgpmax)) && (defined($bgp_state)) && ($bgp_state eq 'OK') && ($prefix_state eq 'OK')) {
                        $state = 'OK';
                        $output .= ". Connessione stabilita da $establishedtime, expected_max=$bgpmax, Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                     } elsif ((defined($bgpmax)) && ($bgp_state eq 'OK') && ($prefix_state eq 'WARNING')) {
                        $state = 'WARNING';
                        $output .= "Connessione stabilita da $establishedtime, $bgpmax_warning expected_max=$bgpmax, Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                     } elsif (($bgp_state eq 'OK') && ($p_accepted > 0)) {
                        $state = 'OK';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                     } elsif (($bgp_state eq 'OK') && ($p_accepted <= 0)) {
                        $state = 'WARNING';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                     } elsif (($opt_h) && ($bgp_state eq 'OK') && ($p_accepted <= 0)) {
                        $state = 'OK';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                     } elsif (($opt_h) && ($bgp_state eq 'OK') && ($p_accepted > 0)) {
                        $state = 'WARNING';
                        $output .= "Connessione stabilita da $establishedtime <br> Rotte ricevute: $p_accepted  Rotte respinte: $p_rejected <br> Ultimo messaggio di errore: $lasterror";
                        $perf_data = "| prefixes_accepted=$p_accepted prefixes_rejected=$p_rejected";
                    }
                }
            } else {
                $output .= "Connessione stabilita da $establishedtime <br> ";
                $state = 'CRITICAL';
        		if (defined($lasterror)) {
        			$output .= " Ultimo messaggio di errore: \"$lasterror\"";
        		}
            }        
        ## Only juniper support beyond here - Version 0.6
} else {
            if ($result->{"$bgpPeerState.$bgppeer"} == 6) {
                # Now try to get num of prefixes received by this peer.
                # Will only work on juniper for now
                my $peer_index_oid = "1.3.6.1.4.1.2636.5.1.1.2.1.1.1.14.0.1";
                my $bgp_index = $snmp->get_table(-baseoid => $peer_index_oid, -maxrepetitions => $max_repetions);
                if (defined($bgp_index)) {
                    my $peer_id = undef;
                    foreach my $key ( keys %$bgp_index) {
                        #print ($key," : ",$$bgp_index{$key},"\n");
                        if ($key =~ /$bgppeer$/) {
                            #print "found index $$bgp_index{$key} for $bgppeer\n";
                            $peer_id = $$bgp_index{$key};
                        }
                    }
                    if(defined($peer_id)) {
                        my @numprefix_oid;
                        my $received_prefixes =  "1.3.6.1.4.1.2636.5.1.1.2.6.2.1.7.$peer_id.1.1";
                        my $accepted_prefixes =  "1.3.6.1.4.1.2636.5.1.1.2.6.2.1.8.$peer_id.1.1";
                        my $rejected_prefixes =  "1.3.6.1.4.1.2636.5.1.1.2.6.2.1.9.$peer_id.1.1";
                        push (@numprefix_oid, $received_prefixes, $accepted_prefixes, $rejected_prefixes);
                        my $prefix_result = $snmp->get_request(
                            -varbindlist => \@numprefix_oid
                        );
                        my $p_received = "";
                        my $p_accepted = "";
                        my $p_rejected = "";
                        if (defined($prefix_result->{$received_prefixes})) {
                            $p_received = $prefix_result->{$received_prefixes};
                        }
                        if (defined($prefix_result->{$accepted_prefixes})) {
                            $p_accepted = $prefix_result->{$accepted_prefixes};
                        }
                        if (defined($prefix_result->{$rejected_prefixes})) {
                            $p_rejected = $prefix_result->{$rejected_prefixes};
                        }
                        $perf_data = "| prefixes_received=$p_received, prefixes_accepted=$p_accepted, prefixes_rejected=$p_rejected";
                    }
                }

                $state = 'OK';
                $output .= ". Established for $establishedtime. ";
            #} elsif ($result->{"$bgpPeerAdminStatus.$bgppeer"} == 1) { #stop
            #   $state = 'WARNING'; # admin down do warning
            #   $output .= " (administratively down). Last established $establishedtime.";
            } else {
                $state = 'CRITICAL';
                $output .= ". Last established $establishedtime.";
            }

            if (defined($lasterror)) {
                $output .= " Last error \"$lasterror\".";
            }
        }
    
    }
}
print "$state - $output $perf_data\n";
exit $ERRORS{$state};

sub print_help() {
	print_revision($PROGNAME,'$Revision: 0.6 $ ');
	print "Copyright (c) 2006 Larry Low\n";
	print "This program is licensed under the terms of the\n";
	print "GNU General Public License\n(check source code for details)\n";
	print "\n";
	printf "Check BGP peer status via SNMP.\n";
	print "\n";
	print "\n";
	print " -H (--hostname)     Hostname to query - (required)\n";
	print " -C (--community)    SNMP read community or v3 auth (defaults to public)\n";
	print "                     (v3 specified as username:authpassword:... )\n";
	print "                       username = SNMPv3 security name\n";
	print "                       authpassword = SNMPv3 authentication pass phrase (or hexidecimal key)\n";
	print "                       authprotocol = SNMPv3 authentication protocol (md5 (default) or sha)\n";
	print "                       privpassword = SNMPv3 privacy pass phrase (or hexidecmal key)\n";
	print "                       privprotocol = SNMPv3 privacy protocol (des (default) or aes)\n";
	print " -v (--snmp_version) 1 for SNMP v1\n";
	print "                     2 for SNMP v2c (default)\n";
	print "                     3 for SNMP v3\n";
    print "                      ### only ASR support for min/max\n";
    print " --min                min BGP received routes expected\n";
    print " --max                max BGP received routes expected\n";
    print " -p {--peer}         IP of BGP Peer\n";
	print " -V (--version)      Plugin version\n";
	print " -h (--help)         usage help\n";
	print "\n";
	support();
}

sub print_usage() {
	print "Usage: \n";
	print "  $PROGNAME -H <HOSTNAME> [-C <community>] -p <bgppeer>\n";
    print "  $PROGNAME -H <HOSTNAME> [-C <community>] -p <bgppeer> --max 200 \n";
    print "  $PROGNAME -H <HOSTNAME> [-C <community>] -p <bgppeer> --min 200 \n";
	print "  $PROGNAME [-h | --help]\n";
	print "  $PROGNAME [-V | --version]\n";
    print "                      ### only ASR support for min/max\n";
    print " --min                min BGP received routes expected\n";
    print " --max                max BGP received routes expected\n";
}

sub seconds_to_string($) {
	my $time = shift;
	my $timestr = "";
	if ($time > (365.24225*24*60*60)) {
		my $years = floor($time / (365.24225*24*60*60));
		$time -= $years*365.24225*24*60*60;
		$timestr .= $years."y";
	}
	if ($time > (24*60*60)) {
		my $days = floor($time / (24*60*60));
		$time -= $days*24*60*60;
		$timestr .= $days."d";
	}
	if ($time > (60*60)) {
		my $hours = floor($time / (60*60));
		$time -= $hours*60*60;
		$timestr .= $hours."h";
	}
	if ($time > 60) {
		my $minutes = floor($time / 60);
		$time -= $minutes*60;
		$timestr .= $minutes."m";
	}
	$timestr .= $time."s";
	return $timestr;
}

