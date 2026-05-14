#!/bin/bash -x
#
#   check_snmp_cisco_memfree.sh
#
#   $Rev: 0001 $
#   $Author: Manuel DI Gagni $
#   $Date: 28/05/2025 $





SNMPGET="/usr/bin/snmpget"
SNMPWALK="/usr/bin/snmpwalk"

PROGNAME=`basename $0`
PROGPATH=`echo $0 |sed -e 's,[\\/][^\\/][^\\/]*$,,'`
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
RESULT=""
EXIT_CODE=0

HOST=""
CRITLEVEL=90
WARNLEVEL=80

user=""
authproto="SHA"
authkey=""
privproto="DES"
privkey=""
type="cpu"

re='^[0-9]+$'

# Write output and return result
theend() {
       echo $RESULT
       exit $EXIT_CODE
}

usage(){
    echo "usage: $PROGNAME -H <host address> -u <snmp user> -a <auth proto> -A <auth key> -x <priv proto> -X <priv key>"
}

print_help() {
    usage
}

doopts() {
    if ( `test 0 -lt $#` )
    then
        while getopts hH:w:c:u:a:A:x:X:t:\? myarg ; do
		case $myarg in
                h|\?|\:)
                    print_help
					exit;;
				H)
                    HOST=$OPTARG
                    ;;
				c)
                    CRITLEVEL=$OPTARG
                    ;;
                w)
                    WARNLEVEL=$OPTARG
                    ;;
                u)
                    user=$OPTARG;;
                a)
                    authproto=$OPTARG;;
                A)
                    authkey=$OPTARG;;
                x)
                    privproto=$OPTARG;;
                X)
                    privkey=$OPTARG;;
                t)
                    type=$OPTARG;;
                 *)      # Default
                    usage							   
			       exit;;
		    esac
	done
	else
		print_help
		exit $STATE_UNKNOWN
	fi
}

doopts $@


check_cpu(){
    LOAD_5S=$($SNMPWALK -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.6)
    LOAD_1M=$($SNMPWALK -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.7)
    LOAD_5M=$($SNMPWALK -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.8)
    
    #   Se l'apparato ha una versione 12.0 o precedente
    if [[ $LOAD_5S == *"No Such"* || $LOAD_1M == *"No Such"* || $LOAD_5M == *"No Such"* ]]; then
        LOAD_5S=$($SNMPGET -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.3)
        LOAD_1M=$($SNMPGET -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.4)
        LOAD_5M=$($SNMPGET -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.5)
        
    elif ! [[ $LOAD_5S =~ $re ]]; then
        LOAD_5S=$($SNMPWALK -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.6.20)
        LOAD_1M=$($SNMPWALK -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.7.20)
        LOAD_5M=$($SNMPWALK -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.109.1.1.1.1.8.20)

    fi
    
    if [[ $LOAD_5S == *"No Such"* || $LOAD_1M == *"No Such"* || $LOAD_5M == *"No Such"* ]]; then
        RESULT="OID non disponibile su questo apparato" 
        EXIT_CODE=$STATE_UNKNOWN
        
    elif ! [[ $LOAD_5S =~ $re ]]; then
        RESULT="$LOAD_5S" 
        EXIT_CODE=$STATE_UNKNOWN
    else
        if [ ${LOAD_5S} -lt ${WARNLEVEL} ]; then
            RESULT="CPU OK - Cpu load ${LOAD_5S}% ${LOAD_1M}% ${LOAD_5M}% | cpu_5s=$LOAD_5S cpu_1m=$LOAD_1M cpu_5m=$LOAD_5M"
            EXIT_CODE=$STATE_OK
        elif [ ${LOAD_5S} -gt ${CRITLEVEL} ]; then
            RESULT="CPU CRITICAL - Cpu load ${LOAD_5S}% ${LOAD_1M}% ${LOAD_5M}% | cpu_5s=$LOAD_5S cpu_1m=$LOAD_1M cpu_5m=$LOAD_5M"
            EXIT_CODE=$STATE_CRITICAL
        elif [ ${LOAD_5S} -gt ${WARNLEVEL} ]; then
            RESULT="CPU WARNING - Cpu load ${LOAD_5S}% ${LOAD_1M}% ${LOAD_5M}% | cpu_5s=$LOAD_5S cpu_1m=$LOAD_1M cpu_5m=$LOAD_5M"
            EXIT_CODE=$STATE_WARNING
        else
            RESULT="No output returned | cpu_5s=$LOAD_5S cpu_1m=$LOAD_1M cpu_5m=$LOAD_5M"
            EXIT_CODE=$STATE_CRITICAL
        fi
    fi
    
    
}

check_mem(){
    USED=$($SNMPGET -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.48.1.1.1.5.1)
    FREE=$($SNMPGET -v3 -OQv -l AuthPriv -u $user -a $authproto -A $authkey -x $privproto -X $privkey $HOST 1.3.6.1.4.1.9.9.48.1.1.1.6.1)
    
     if [[ $USED == *"No Such"* || $FREE == *"No Such"* ]]; then
        RESULT="OID non disponibile su questo apparato" 
        EXIT_CODE=$STATE_UNKNOWN
        
    elif ! [[ $USED =~ $re ]]; then
        RESULT="$USED" 
        EXIT_CODE=$STATE_UNKNOWN
    else
        USED=$(( USED / 1024 / 1024))
        FREE=$(( FREE / 1024 / 1024))
        WHOLE=$(( FREE + USED ))
        
        
        # Calcolo memoria utilizzata
        PCT=$(( 100 * USED / WHOLE ))
        
        if [ ${PCT} -lt ${WARNLEVEL} ]; then
        	RESULT="MEM OK - ${PCT}% utilizzati - liberi ${FREE}Mb / ${WHOLE}Mb | Utilizzo=$PCT"
        	EXIT_CODE=${STATE_OK}
        elif [ ${PCT} -gt ${CRITLEVEL} ]; then
        	RESULT="MEM CRITICAL - ${PCT}% utilizzati - liberi ${FREE}Mb / ${WHOLE}Mb | Utilizzo=$PCT"
        	EXIT_CODE=${STATE_CRITICAL}
        elif [ ${PCT} -gt ${WARNLEVEL} ]; then
        	RESULT="MEM WARNING - ${PCT}% utilizzati - liberi ${FREE}Mb / ${WHOLE}Mb | Utilizzo=$PCT"
        	EXIT_CODE=${STATE_WARNING}
        else
            RESULT="No output returned | cpu_5s=$LOAD_5S cpu_1m=$LOAD_1M cpu_5m=$LOAD_5M"
            EXIT_CODE=$STATE_CRITICAL
        fi
    fi
}


###     MAIN 

# Sanity Check
if [ -z "${HOST}" ]; then
	echo "Host mancante"
	exit ${STATE_UNKNOWN}
fi

if [ "${WARNLEVEL}" -gt "${CRITLEVEL}" ]; then
	echo "La soglia di Warning deve essere minore di Critical"
	exit 3
fi

case $type in
    "cpu"|"CPU")
        check_cpu
    ;;
    "mem"|"MEM")
        check_mem
    ;;
esac

theend



# EOF
