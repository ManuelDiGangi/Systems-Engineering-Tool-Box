#!/usr/bin/python 
#
# Copyright (c) Brady Lamprecht
# Licensed under GPLv3
# March 2009
#
# check_env_stats plug-in for nagios
# Uses SNMP to poll for voltage, temerature, fan, and power supply statistics
#
# History:
#
# v0.1 Very basic script to poll given SNMP values (Foundry only)
# v0.2 Added functionality for temperature, fans, power supplies
# v0.3 Included Cisco support with the addition of voltage
# v0.4 Functions to set warning and critical levels were added
# v0.5 Now implements "-p" perfmon option for performance data
# v1.0 Code cleanup and a few minor bugfixes
#
#	$Rev: 99262 $
#	$Author: tassotti $
#	$Date: 2015-12-03 17:19:06 +0100 (gio, 03 dic 2015) $

#	$Rev: 99263 $
#	$Author: Di Gangi $
#	$Date: 2025-03-17 10:00:00 +0100 (lun, 17 mar 2025) $
#   Aggiornato per funzionare con snmp v3

#	$Rev: 99264 $
#	$Author: Di Gangi $
#	$Date: 2025-03-17 10:00:00 +0100 (lun, 30 mag 2025) $
#   Ampliata la compatibilita per CISCO 8200-4321-2901-9200L solo temperatura

import os
import sys
from optparse import OptionParser

scriptversion = "1.0"

errors = {
    "OK": 0,
    "WARNING": 1,
    "CRITICAL": 2,
    "UNKNOWN": 3,
    }

# common_options = "snmpwalk -OvQ -v 1"

# userSnmp = ""
# authProto = ""
# authPass = ""
# cryptoProto = ""
# cryptoPass = ""
# hostname = ""

command = ""

# Function for Cisco equipment
def check_cisco(mode,verbose):


    # Richiedo il nome all'interno del quale e' indicato il modello
    
    model = os.popen(command + "1.3.6.1.2.1.1.5.0").read()[:-1].replace('\"', '').split('\n')
    if model[0] == '':
        fail("Name table empty or non-existent.")
        return(desc,valu)
    model=model[0]
    
    if mode == "volt":
    
        if "8200" in model:
            fail("Funzione non ancora implementata")
        elif "4321" in model:
            fail("Funzione non ancora implementata")
        elif "2901" in model:
            fail("Funzione non ancora implementata")
        elif "9200" in model:
            fail("Funzione non ancora implementata")
        else: # Qualsiasi altro modello 
            ciscoDescTable = "1.3.6.1.4.1.9.9.13.1.2.1.2"
            ciscoValuTable = "1.3.6.1.4.1.9.9.13.1.2.1.3"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
    
    elif mode == "temp":
        
        if "8200" in model:
            ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.7003"
            ciscoValuTable = "1.3.6.1.4.1.9.9.91.1.1.1.1.4.7003"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        elif "4321" in model:
            ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.7002"
            ciscoValuTable = "1.3.6.1.4.1.9.9.91.1.1.1.1.4.7002"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        elif "2901" in model:
            ciscoDescTable = "1.3.6.1.4.1.9.9.13.1.3.1.2.2"
            ciscoValuTable = "1.3.6.1.4.1.9.9.13.1.3.1.3.2"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        elif "9200" in model:
            ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.1011"
            ciscoValuTable = "1.3.6.1.4.1.9.9.91.1.1.1.1.4.1011"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        else:
            ciscoDescTable = "1.3.6.1.4.1.9.9.13.1.3.1.2"
            ciscoValuTable = "1.3.6.1.4.1.9.9.13.1.3.1.3"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
            
    elif mode == "fans":
    
        if "8200" in model:
            ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.24"
            ciscoValuTable = "1.3.6.1.4.1.9.9.91.1.1.1.1.4.24"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        elif "4321" in model:
            ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.24"
            ciscoValuTable = "1.3.6.1.4.1.9.9.91.1.1.1.1.4.24"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        elif "2901" in model:
            ciscoDescTable = "1.3.6.1.4.1.9.9.13.1.4.1.2.2"
            ciscoValuTable = "1.3.6.1.4.1.9.9.13.1.4.1.3.2"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        #elif ("9200" in model or "3560" in model):
            #ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.1008"
            #desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            #desc=desc[0]+" - Questo apparato non espone metriche relative alle ventole."
            #fail("Questo apparato non espone metriche relative alle ventole.")
        else:
            ciscoDescTable = "1.3.6.1.4.1.9.9.13.1.4.1.2"
            ciscoValuTable = "1.3.6.1.4.1.9.9.13.1.4.1.3"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
            
    elif mode == "power":
    
        if "8200" in model:
            ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.26"
            ciscoValuTable = "1.3.6.1.4.1.9.9.91.1.1.1.1.5.26"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        elif "4321" in model:
            ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.25"
            ciscoValuTable = "1.3.6.1.4.1.9.9.91.1.1.1.1.5.25"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        elif "2901" in model:
            ciscoDescTable = "1.3.6.1.4.1.9.9.13.1.5.1.2.1"
            ciscoValuTable = "1.3.6.1.4.1.9.9.13.1.5.1.3.1"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
        elif "9200" in model:
            ciscoDescTable = "1.3.6.1.2.1.47.1.1.1.1.2.1006"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            desc=desc[0]+" - Questo apparato non espone metriche relative all'alimentazione."
            fail(desc)
        else: # Qualsiasi altro modello 
            ciscoDescTable = "1.3.6.1.4.1.9.9.13.1.5.1.2"
            ciscoValuTable = "1.3.6.1.4.1.9.9.13.1.5.1.3"
            desc = os.popen(command + ciscoDescTable).read()[:-1].replace('\"', '').split('\n')
            valu = os.popen(command + ciscoValuTable).read()[:-1].replace('\"', '').split('\n')
    
    if verbose:
        print_verbose(ciscoDescTable,desc,ciscoValuTable,valu)
    if desc[0] == '' or valu[0] == '':
        fail("description / value table empty or non-existent.")
    return(desc,valu)
    

    # Should never get to here
    sys.exit(errors['UNKNOWN'])

# Function for Foundry equipment
def check_foundry(mode,verbose):
    #command = common_options + " -c " + community + " " + hostname + " "
    foundrySNAgent = "1.3.6.1.4.1.1991.1.1"

    if mode == "volt":
        fail("voltage table does not exist in Foundry's MIB.")

    if mode == "temp":
        foundryTempDescTable = foundrySNAgent + ".2.13.1.1.3"
        foundryTempValuTable = foundrySNAgent + ".2.13.1.1.4"
        desc = os.popen(command + foundryTempDescTable).read()[:-1].replace('\"', '').split('\n')
        valu = os.popen(command + foundryTempValuTable).read()[:-1].replace('\"', '').split('\n')
        if verbose:
            print_verbose(foundryTempDescTable,desc,foundryTempValuTable,valu)
        if desc[0] == '' or valu[0] == '':
            fail("description / value table empty or non-existent.")
        return(desc,valu)

    if mode == "fans":
        # Possible values:
        # 1=other,2=normal,3=critical
        foundryFansDescTable = foundrySNAgent + ".1.3.1.1.2"
        foundryFansValuTable = foundrySNAgent + ".1.3.1.1.3"
        desc = os.popen(command + foundryFansDescTable).read()[:-1].replace('\"', '').split('\n')
        valu = os.popen(command + foundryFansValuTable).read()[:-1].replace('\"', '').split('\n')
        if verbose:
            print_verbose(foundryFansDescTable,desc,foundryFansValuTable,valu)
        if desc[0] == '' or valu[0] == '':
            fail("description / value table empty or non-existent.")
        return(desc, valu)

    if mode == "power":
        # Possible values:
        # 1=other,2=normal,3=critical
        foundryPowrDescTable = foundrySNAgent + ".1.2.1.1.2"
        foundryPowrValuTable = foundrySNAgent + ".1.2.1.1.3"
        desc = os.popen(command + foundryPowrDescTable).read()[:-1].replace('\"', '').split('\n')
        valu = os.popen(command + foundryPowrValuTable).read()[:-1].replace('\"', '').split('\n')
        if verbose:
             print_verbose(foundryPowrDescTable,desc,foundryPowrValuTable,valu)
        if desc[0] == '' or valu[0] == '':
            fail("description / value table empty or non-existent.")
        return(desc,valu)

    # Should never get to here
    sys.exit(errors['UNKNOWN'])

# Function for HP equipment
def check_hp(mode,verbose):
    fail("HP functions not yet implemented.")

# Function for Juniper equipment
def check_juniper(mode,verbose):
    fail("Juniper functions not yet implemented.")

# Function to process data from SNMP tables
def process_data(description, value, warning, critical, performance):
    string = ""
    status = "OK"
    perfstring = ""
    
    if critical and warning:
        #if len(critical) != len(description):
            #critical = [critical] * len(description)
            #fail("number of critical values not equal to number of table values.")
        #elif len(warning) != len(description):
            #warning = [warning] * len(description)
            #fail("number of warning values not equal to number of table values.")
        #else:
	
        # Check for integer or string values

        # Check each table value against provided warning & critical values
        #for d, v, w, c in zip(description,value,warning,critical):
        c = int(critical)
        w = int(warning)
        for d, v in zip(description,value):
            #print string # str(d) +" " #+str(v)+" "+str(w)+" "+str(c)
            if len(string) != 0:
                string += ", "
            
            if "UADP" in d:
                string += d + ": " + str(v)
            else:
                if v >= c:
                    status = "CRITICAL"
                    string += d + ": " + str(v) + " (C=" + str(c) + ")"
                elif v >= w:
                    if status != "CRITICAL":
                        status = "WARNING"
                    string += d + ": " + str(v) + " (W=" + str(w) + ")"
                else:
                    string += d + ": " + str(v)

            # Create performance data
            perfstring += d.replace(' ', '_') + "=" + str(v) + " "

    # Used to provide output when no warning & critical values are provided
    else:
         for d, v in zip(description,value):
             if len(string) != 0:
                  string += ", "
             string += d + ": " + str(v)
             
             # Create performance data
             perfstring += d.replace(' ', '_') + "=" + str(v) + " "

    # If requested, include performance data
    if performance:
        string += " | " + perfstring
        
    #FREAKDEBUG
    #string += "Salernitana"
    #----------------------
    # Print status text and return correct value.
    print status + ": " + string
    sys.exit(errors[status])

def print_verbose(oid_A,val_A,oid_B,val_B):
    print "Description Table:\n\t" + str(oid_A) + " = \n\t" + str(val_A)
    print "Value Table:\n\t" + str(oid_B) + " = \n\t" + str(val_B)
    sys.exit(errors['UNKNOWN'])

def fail(message):
    print "Error: " + message	
    sys.exit(errors['UNKNOWN'])

def main():
    global command
    args = None
    options = None	

    # Create command-line options
    parser = OptionParser(version="%prog " + scriptversion)
    parser.add_option("-H", action="store", type="string", dest="hostname", help="hostname or IP of device")
    #parser.add_option("-C", action="store", type="string", dest="community", help="community read-only string [default=%default] for snmp v1-2", default="public")
    parser.add_option("-u", action="store", type="string", dest="user", help="snmp User for snmp v3", default="public")
    parser.add_option("-a", action="store", type="string", dest="authproto", help="Authentication protocol for snmp v3", default="public")
    parser.add_option("-A", action="store", type="string", dest="authpass", help="Authentication password for snmp v3", default="public")
    parser.add_option("-x", action="store", type="string", dest="cryptoproto", help="Encryption  protocol for snmp v3", default="public")
    parser.add_option("-X", action="store", type="string", dest="cryptopass", help="Encryption  password for snmp v3", default="public")
    parser.add_option("-T", action="store", type="string", dest="type", help="hardware type (cisco,foundry,hp,juniper)")
    parser.add_option("-M", action="store", type="string", dest="mode", help="type of statistics to gather (temp,fans,power,volt)")
    parser.add_option("-w", action="store", type="string", dest="warn", help="comma-seperated list of values at which to set warning")
    parser.add_option("-c", action="store", type="string", dest="crit", help="comma-seperated list of values at which to set critical")
    parser.add_option("-p", action="store_true", dest="perf", help="include perfmon output")
    parser.add_option("-v", action="store_true", dest="verb", help="enable verbose output")
    (options, args) = parser.parse_args(args)

    # Map parser values to variables
    userSnmp = options.user
    authProto = options.authproto
    authPass = options.authpass
    cryptoProto = options.cryptoproto
    cryptoPass = options.cryptopass

    host = options.hostname
    #comm = options.community
    type = options.type
    mode = options.mode
    warn = options.warn
    crit = options.crit
    command = "snmpwalk -v3 -OvQ -l authPriv -u " + userSnmp + " -a " + authProto + " -A " + authPass + " -x " + cryptoProto + " -X " + cryptoPass + " " + host + " "
    # -OvQ limita l'output del comando snmpwalk

    perf = options.perf
    verb = options.verb

    # Check for required "-H" option
    if host:
        pass
    else:
        fail("-H is a required argument")
        
    if userSnmp and authProto and authPass and cryptoProto and cryptoPass:
        pass
    else:
        fail("-u -a -A -x -X are required arguments")

    # Check for required "-M" option and verify value is supported
    if mode:
        if mode == "temp" or mode == "fans" or mode == "power" or mode == "volt":
            pass
        else:
            fail("-M only supports modes of temp, fans, power, volt")
    else:
        fail("-M is a required argument")

    # Check for required "-T" option
    if type:
        pass
    else:
        fail("-T is a required argument")

    # Check for valid "-T" option and execute appropriate check
    if type == "cisco": 
        (desc, value) = check_cisco(mode,verb)
        if "No Such" in str(desc):
            print("Questo apparato non espone dati riguardanti: "+mode)
            sys.exit(0)
        process_data(desc, map(int,value), warn, crit, perf)
    if type == "foundry": 
        (desc, value) = check_foundry(mode,verb)
        process_data(desc, map(int,value), warn, crit, perf)
    if type == "hp":
        (desc, value) = check_hp(mode,verb)
        process_data(desc, map(int,value), warn, crit, perf)
    if type == "juniper":
        (desc, value) = check_juniper(mode,verb)
        process_data(desc, map(int,value), warn, crit, perf)
    else:
        fail("-T only supports types of cisco, foundry, hp, or juniper") 

    # Should never get here
    sys.exit(errors['UNKNOWN'])

# Execute main() function
if __name__ == "__main__":
	main()
