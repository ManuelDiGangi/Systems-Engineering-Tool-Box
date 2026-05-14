#!/bin/bash
#
#	check_gen_snmp_interface.sh
#
#	$Rev: 136670 $
#	$Author: tassotti $
#	$Date: 2018-11-26 08:42:13 +0100 (lun, 26 nov 2018) $


# DESCRIZIONE:
#	Il Check  invia passivamente l'output e l'exit status ai servizi relativi alle interfacce di ogni singolo dispositivo.
#	Tali servizi verranno creati automaticamente dal wizard che interrogherà questo check con parametro -J.
#	I nomi dei servizi potranno essere modificabili nel wizard.


# Change History
#
#
# 29/04/2024: Gabriele Spaziani - Aggiunta opzione per invertire le soglie di warning e critical relative alla prencentuale di banda passante
# 07/03/2022: Gabriele Spaziani - Modifica al calcolo della velocità massima, ora quando il contatore a 32 bit è pieno (ifSpeed) verrà preso in considerazione il contatore a 64 bit (ifHighspeed)
# 25/09/2019: Gabriele Spaziai - Modifica alla creazione del grafico, anziche creare il grafico del throughput in Kbps creerà il grafico in Mbps
# 18/07/2019: Andrea Tassotti - Aggiunto parametro -b per forzare dimensione bit gauge snmp interfacce da usare. Questo per correggere caso corsa critica su valori 0 dei gauge 64 bit che impedisce autodeterminazione dimensione corretta e può creare spike nel campionamento.
# 14/05/2019: Andrea Tassotti - Corretto calcolo velocità nominale porta nella costruzione JSON per wizard: utilizzato anche il dato di ifHighSpeed
# 18/04/2019: Andrea Tassotti - Gestione nomi con blanks su tabella interfacce
#							  - Gestione interfacce con differenti indirizzi IP
# 17/04/2019: Andrea Tassotti - Workaround per nomi di interfaccia tutti uguai in IF-TABLE (Switch Enterasys)
# 28/02/2019: Andrea Tassotti - Controllo esistenza percorso di base file di confiurazione da wizard. Imposto -r 3 mella lettura tabella IF (per apparati vecchi o lenti)
#                             - Controllo su tempo esecuzione consecutive check (non deve essere < 1sec)
#                             - Controllo prima esecuzione (assenza dati storici)
#                             - Modificato parametro -T affinché possa indicare una lista (separata da virgola) di nomi interfacce da considerare nel conteggio totale della banda
# 27/02/2019: Andrea Tassotti - Introdotta opzione -T per calcolo totale banda occupata; modifica opzione -F per avere unità di scala (KMGTPE). Produce performance data
# 26/02/2019: Andrea Tassotti - Minor bug fix sulla determinazione speed; introduzione parametri per nuova feature calcolo bandwith totale; opzione -r 0 su tutte i SNMPCMD
# 19/12/2018: Andrea Tassotti - Bozza gestione errors & discards nelle interfacce
# 11/12/2018: Andrea Tassotti - Soppressione uso check_traffic.sh a favore di sistema autonomo di calcolo e history
# 30/11/2018: Andrea Tassotti - Correzione gestione rimodulazione parametri di warning e critical se questi superano la banda fisica indicata
#                             - Correzione doppio conteggio numero interfacce.
# 26/11/2018: Andrea Tassotti - Correzione credenziali SNMPv2/3 fornite a check_traffic.sh
# 22/5/2018: Andrea Tassotti - Miglioramento messaggio output controllo padre con contatori interfacce
#							 - Propagate le credenziali SNMPv3 anche al check plugin
# 7/5/2018 : Andrea Tassotti - aggiunto parametro timeout (con default 5 sec) su tutti i comandi NetSNMP
# 4/5/2018 : Andrea Tassotti - introdotto supporto SMNPv3
# 3/4/2017 : Andrea Tassotti - bug fix: apposti correttivi per interfacce > 1GBit
#							 - miglioramento: human readable form per unità misura velocità
#

 
#Definizione di variabili
if test -x /usr/bin/printf; then
	ECHO=/usr/bin/printf
else
	ECHO=echo
fi

PROGNAME=`basename $0`

PROGPATH="/usr/local/filemanager/Builtin/General"
REVISION="1.5.4 (Rev. $Revision: $)"

#TAG = numero arbitrario che verra utilizzato per generare un ID del servizio
TAG="567" 
SERVICEDESC=""
HOSTNAME=""
COMMUNITY=""
WARN_IN="70"
CRIT_IN="90"
WARN_OUT="70"
CRIT_OUT="90"
SERVICEID=""
RESULT=""
EXIT_STATUS="3"
TOTAL_BANDWIDTH=0
INVERTED=false

#dichiarazione array contenteti i valori di in e out di tutte le interfaccie
declare -A INTERF_IN
declare -A INTERF_OUT

RESULT_SONS=""
STATE_SONS="3"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
OUTPUT_MODE=simple
NO_LABEL=false
BASEDIR_ARGOMENTI=/usr/local/filemanager/GeneralChecks
WORD_SIZE=



#
# FUNCTIONS
#


#
#
#
usage()
{
  $ECHO "" 
  $ECHO "$PROGNAME versione: $REVISION - controllo interfacce\n"
  $ECHO "\n"
  $ECHO "\n"
  $ECHO "Come si usa: $PROGNAME -N <Host name> -D <Service name> -H <Host o IP> -C <snmp community> [-i SPEED_IN ]  [-o SPEED_OUT] [-h] [-V]\n"
  $ECHO "\n"
  $ECHO "Parametri necessari\n"
  $ECHO "           	-H  Hostaddress \n"
  $ECHO "           	-N  Hostname \n"
  $ECHO "               -D  Service name\n"
  $ECHO "           	-C  SNMP community\n"
  $ECHO "\n"
  $ECHO "Parametri che modificano il comportamento\n"
  $ECHO "           	-b	Imposta numero bit contatori (Gauge) interfacce (vuole 32 o 64 come parametro)"
  $ECHO "           	-n  Non stampa il nome dell'interfaccia nell'output\n"
  $ECHO "           	-i  Limite effettivo input speed (default=nominale scheda o da file argomenti) in kbps\n"
  $ECHO "           	-o  Limite effettivo output speed (default=nominale scheda o da file argomenti) in kbps\n"
  $ECHO "           	-F  Limite fisico banda (default=nominale scheda o da file argomenti) in Kbps. E' possibile utilizzare formato di scala con suffisso KMGTPE.\n"
  $ECHO "           	-w  Percentuale warning (sovrasta parametri derivanti dalle configurazioni per i check passivi)\n"
  $ECHO "           	-c  Percentuale critical (sovrasta parametri derivanti dalle configurazioni per i check passivi)\n"
  $ECHO "           	-t  Tempo di attesa (in secondi) per i dati via SNMP\n"F
  $ECHO "           	-T  Calcolo della banda totale delle interfacce indicate con nome separato da  virgole. Il calcolo produce grafico totale IN/OUT/BANDWITH ed è sottoposto a soglie date da -w e -c percentualmente rispetto a valore espresso da -F\n"
  $ECHO "\n"
  $ECHO "SNMP Access:\n"
  $ECHO "           	-v STRING\n"
  $ECHO "           	   Protocol version (default: 2c)\n"
  $ECHO "           	-C STRING\n"
  $ECHO "           	   Community name for the host's SNMP agent (default: public)\n"
  $ECHO "           	-u STRING\n"
  $ECHO "           	   SNMPv3 username\n"
  $ECHO "           	-a STRING\n"
  $ECHO "           	   SNMPv3 authentication protocol (MD5, SHA - default: MD5)\n"
  $ECHO "           	-A STRING\n"
  $ECHO "           	   SNMPv3 authentication passphrase\n"
  $ECHO "           	-x STRING\n"
  $ECHO "           	   SNMPv3 privacy protocol (DES, AES - default: DES)\n"
  $ECHO "           	-X STRING\n"
  $ECHO "           	   SNMPv3 privacy passphrase\n"
  $ECHO "           	-z STRING\n"
  $ECHO "           	   SNMPv3 context\n"
  $ECHO "\n"
  $ECHO "Parametri accessori\n"
  $ECHO "           	-J  Info. Se il check viene richiamato con questo parametro restituisce solo dati JSON ed esce\n"
  $ECHO "           	-j <regexp>	Come la precedente ma filtrato da espressione regolare (egrep).\n"
  $ECHO "           	                  Espressione può intercettare nome interfaccia (es, eth1, vlan3) o IANAifType (es. softwareLoopback, ethernetCsmacd, ppp, infiniband, ...)\n"
  $ECHO "           	-h  Visualizza questo help\n"
  $ECHO "           	-?  Visualizza help per il wizard\n"	
  $ECHO "           	-V  Versione\n"
  $ECHO "\n"
  $ECHO "Esempi di chiamata: $PROGNAME -J -C public -H 192.168.3.14\n"
  $ECHO "                    $PROGNAME -j -C public -H 192.168.3.14\n"
  $ECHO "                    $PROGNAME -N router -D \"Fe0/0\" -H 192.168.1.3 -C public\n"
  $ECHO "                    $PROGNAME -N Sentinet3 -H 127.0.0.1 -D NetworkInterface -C public -T eth0 -F 1G -w 80 -c 90\n"
  $ECHO "                    $PROGNAME -N Sentinet3 -H 127.0.0.1 -D NetworkInterface -C public -T eth0,eth2 -F 100K -w 80 -c 90\n"
  $ECHO "\n"
  $ECHO "Esempio linea di comando check command:"
  $ECHO "                    -N $HOSTNAME$ -H $HOSTADDRESS$ -D $SERVICEDESC$ -C $ARG1$"
  $ECHO ""
}


#
# Help del check da richiamare tramite parametro -h
#
print_help() {
  $ECHO "\nCopyright (c) 2011-2019 FataInformatica - plugins are developped with GPL Licence\n";
  $ECHO "Bugs to http://www.Sentinet3.com/\n";
  $ECHO "\n";
  usage
  $ECHO "\n";
}


#
#
#
print_help_gen() {
  $ECHO "\nCopyright (c) 2011-2019 FataInformatica - plugins are developped with GPL Licence\n";
  $ECHO "Bugs to http://www.Sentinet3.com/\n";
  $ECHO "\n";

  $ECHO "" 
  $ECHO "$PROGNAME versione: $REVISION - controllo parametri risorsa\n"
  $ECHO "\n"
  $ECHO "\n"        
  $ECHO " E' possibile personalizzare il nome del servizio ed indicare per ciascuno i seguenti\n"
  $ECHO " parametri:\n" 
  $ECHO "\n"  	
  $ECHO "-Warning IN: indicare il livello di warning per il traffico in entrata (valore numerico\n"
  $ECHO "oltre il quale verra' segnalato lo stato di allerta)\n"
  $ECHO "\n"
  $ECHO "-Warning OUT: Indicare il livello di warning per il traffico in uscita (valore numerico\n"
  $ECHO "oltre il quale verra' segnalato lo stato di allerta)\n"
  $ECHO "\n"
  $ECHO "-Critical IN: indicare il livello di critical per il traffico in entrata (valore numerico\n"
  $ECHO "oltre il quale verra' segnalato lo stato di allerta)\n"
  $ECHO "\n"
  $ECHO "-Critical OUT: indicare il livello di critical per il traffico in uscita (valore numerico\n"
  $ECHO "oltre il quale verra' segnalato lo stato di allerta)\n"
  $ECHO "\n"
  $ECHO ""
  
  $ECHO "\n";
}



#
#	Stampa versione
#
print_version() {
  $ECHO "\nCopyright (c) 2011-2019 FataInformatica\n";
  $ECHO "Bugs to http://www.Sentinet3.com/\n";
  $ECHO "\n";
  $ECHO "$PROGNAME versione: $REVISION - Info sullo stato delle interfacce\n"
  $ECHO "\n";
}
 
#
# Processa gli argomenti
#
doopts() {
	if ( `test 0 -lt $#` )
	then
	while getopts b:C:c:D:F:H:hIi:Jj:N:no:T:t:Vw:u:a:A:x:X:v:z:p:\? myarg ; do
		case $myarg in
			b)
				WORD_SIZE=$OPTARG
				[ $WORD_SIZE -ne 64 -o $WORD_SIZE -ne 32 ] && WORD_SIZE=
				;;
			c)
				CRIT=$OPTARG;;
			D)
				SERVICEDESC=$OPTARG;;				
			F)	
				BANDA_FISICA_ARG=$OPTARG
				OUTPUT_MODE=complex
				;;
			H)
				HOSTADDRESS=$OPTARG;;	
			h)
				print_help
				exit $STATE_OK;;
			i)
				SPEED_IN=$OPTARG
				;;
			I)
			    INVERTED=true
		        ;;
			J)
				INFO=info;;
			j)
				INFO=info
				IF_TABLE_FILTER=$OPTARG;;
			N)
				HOSTNAME=$OPTARG;;
			n)
				NO_LABEL=true;;
			o)
				SPEED_OUT=$OPTARG
				;;
			t)
				TIMEOUT=$OPTARG;;
			T)	# Implica -F per avere un dato complessivo di riferimento
				TOTAL_BANDWIDTH=1
				TOTAL_BANDWIDTH_IF_LIST=$OPTARG
				;;
			V)
				print_version
				exit $STATE_OK;;
			w)
				WARN=$OPTARG;;
			v)
				SNMP_VERSION=$OPTARG	;;
			C)
			    COMMUNITY=$OPTARG
			    ;;
			u)
				snmpv3_username=$OPTARG ;;
			a)
				snmpv3_authproto=$OPTARG
				if [[ "$snmpv3_authproto" != 'MD5' ]] && [[ "$snmpv3_authproto" != 'SHA' ]] && snmpv3_authproto=""
				then
				    echo "Wrong authentication protocol"
					print_help
					exit $STATE_UNKNOWN
				fi
				;;
			A)
				snmpv3_authkey=$OPTARG
				;;
			x)
				snmpv3_privproto=$OPTARG
				if [[ "$snmpv3_privproto" != 'DES' ]] && [[ "$snmpv3_privproto" != 'AES' ]] && snmpv3_privproto=""
				then
				    echo "Wrong privacy protocol"
					print_help
					exit $STATE_UNKNOWN
				fi
				;;
			X)
				snmpv3_privkey=$OPTARG
				;;
			z)
				snmpv3_context=$OPTARG
				;;
			\?)	
				print_help_gen
				exit $STATE_OK;;
			*) # Default
				usage						   
				exit $STATE_UNKNOWN;
			esac
	done
	else
		usage
		exit $STATE_UNKNOWN
	fi
}


#
#	Restituisce informazioni sulle interfacce del dispositivo in formato JSON
#
function RestituisciJSON {
	OLD_IFNAME=""
	for i in $INTERFACE
	do 
		OUTPUT_STATUS=""
		INTERFACE_STATUS=$(printf "$TABLE\n"|awk -F "|" "\$1 == \"$i\"" )
		INTERFACE_NAME=$(printf "$INTERFACE_STATUS\n"|awk -F "|" '{print $2}')
		INTERFACE_NAME=$(printf "$INTERFACE_NAME" | tr '.' '-')
		# Può solo proteggere da nomi interfacce tutte uguali (caso Enterasys)
        if [ "$OLD_IFNAME" == "$INTERFACE_NAME" ]; then
		    OLD_IFNAME=$INTERFACE_NAME
			INTERFACE_NAME="${INTERFACE_NAME}-$i"
		fi
		
		#Gabriele Spaziani - 11/12/2019 - Recupero anche la descrizione dell' interfaccia 
		IF_ALIAS=$(snmpget -v$SNMP_VERSION $CREDENTIALS -t ${TIMEOUT:-20} -r 4  $HOSTADDRESS IF-MIB::ifAlias.$i 2>&1 | cut -d ':' -f 4 )
		#controllo se il parametro esiste 
		if [[ ! -z "${IF_ALIAS// }" ]]; then
		    [[ ${IF_ALIAS:0:1} == " " ]] && IF_ALIAS=$( echo $IF_ALIAS | sed 's/ //')   #controllo se il campo appena preso inzia con uno spazio, in quel caso lo tolgo
		    IF_ALIAS=$(echo '_'${IF_ALIAS// /-} | tr -d \")   #sostituisco tutti gli spazi peresenti nella descrizione dell' interfaccia con dei -
        else
            IF_ALIAS=$( echo $IF_ALIAS | sed 's/ //' | tr -d \")   #Per sicurezza tolgo tutti gli spazi nella variabile
        fi
		
		SPEED=$(printf "$INTERFACE_STATUS\n"|awk -F "|" '{print $3}')
		# Modifica 19/02/2015: Andrea Tassotti
        # gestione limiti di banda non dipendenti dalla scheda
		[ "${SPEED:=0}" -eq 0 ] && SPEED=10000000
		if [ "$SPEED" = "4294967295" ] ; then
		    # High Speed Device
		    # An estimate of the interface's current bandwidth in units of 1,000,000 bits per second.
		    # If this object reports a value of `n' then the speed of the interface is somewhere in the range of `n-500,000' to `n+499,999'
		    SPEED2=$( snmpget -v$SNMP_VERSION $CREDENTIALS -t ${TIMEOUT:-20} -r 4 -O q $HOSTADDRESS IF-MIB::ifHighSpeed.$i 2>&1 | awk '{ print $NF }' )
		else
        	SPEED2=$(echo "$SPEED"/"1000000"|bc)
		fi
		
		MAC=$(printf "$INTERFACE_STATUS\n"|awk -F "|" '{print $4}')
		
		INTERFACE_STATUS3=$(printf "$TABLE_IP\n"|awk -F "|" "\$1 == \"$i\"")
		INTERFACE_IP=$(printf "$INTERFACE_STATUS3\n"|awk -F "|" '{print $2}')
		ADMINSTATUS=$(printf "$INTERFACE_STATUS\n"|awk -F "|" '{print $5}')
		OPERSTATUS=$(printf "$INTERFACE_STATUS\n"|awk -F "|" '{print $6}')
		VERIFY_INT=$(printf "$TABLE\n"|awk -F "|" "\$1 == \"$i\"" )
		if [ -z "$VERIFY_INT" ]; then
			continue 1
		fi
		if [[ "$ADMINSTATUS" = "down" ]] && [[ -n "$VERIFY_INT" ]]; then  
			OUTPUT_STATUS="Service state: DOWN  AdminStatus: DOWN"
			OUTPUT_STATUS_SERVIZIO=" <strong> AdminStatus:</strong> DOWN"
			#Critical
			VERIFY_UP=2 
		elif [[ "$ADMINSTATUS" = "up" ]] && [[ "$OPERSTATUS" = "up" ]] && [[ -n "$VERIFY_INT" ]]; then     	
			OUTPUT_STATUS="Service state: UP - AdminStatus: UP  Link: UP"
			OUTPUT_STATUS_SERVIZIO=" <strong> AdminStatus:</strong> UP - <strong>Link:</strong> UP"		#OK
			VERIFY_UP=0
		elif [[ "$ADMINSTATUS" = "up" ]] && [[ "$OPERSTATUS" = "down" ]] && [[ -n "$VERIFY_INT" ]]; then     	
			OUTPUT_STATUS="Service state: UNKNOWN - AdminStatus: UP  Link: DOWN"
			OUTPUT_STATUS_SERVIZIO="<strong> AdminStatus:</strong> UP - <strong>Link:</strong> DOWN"
			#UNKNOWN
			VERIFY_UP=3
		fi
		
		ID_INTERFACE="$TAG""$i"
		
		#MAC=$MAC+$i        #commentato perche risolto con aggiornamento all' ultima versione di Sentinet
		
		if [ -z "$MAC" ]; then
			MAC=00:00:00:00:00:00
		fi
		if [ -z "$INTERFACE_IP" ]; then
			INTERFACE_IP=0.0.0.0
		fi
		
		#echo $INTERFACE_NAME $IF_ALIAS #- MAC:: $MAC - IP:: $INTERFACE_IP - ID:: $ID_INTERFACE #-- $VERIFY_INT
		
		json_body
		
		
	done
}
			
		
#Attraverso il check passivo vengono inviati l'output e l'exit status ai servizi figli
#
#
#
passive_check(){
        HOST=$1
        SRV=$2
        STATUS=$3
        OUTPUT=$4
        # Supporto macchina sviluppo
		if [ -x /usr/bin/sentinet3_api ] ; then
			sentinet3_api WRITE_PASSIVE_SERVICE "$HOST" "$SRV" $STATUS "$OUTPUT" 2>&1
		else
			EXIT_STATUS=$STATE_UNKNOWN
			RESULT="Running only in Sentinet3 Version >=4.3.6"
			theend
		fi
}


# Recupera il mac address del dispositvo collegato all'interfaccia passata
# GS 29/09/2025
#
#
#
# macs_on_ifindex <IFINDEX>
# Usa le variabili globali: $SNMP_VERSION, $CREDENTIALS, $HOSTADDRESS
macs_on_ifindex() {
  local IFINDEX="$1"
  if [[ -z "$IFINDEX" ]]; then
    echo "uso: macs_on_ifindex <IFINDEX>" >&2
    return 1
  fi
  if [[ -z "$SNMP_VERSION" || -z "$CREDENTIALS" || -z "$HOSTADDRESS" ]]; then
    echo "Variabili SNMP non settate (SNMP_VERSION / CREDENTIALS / HOSTADDRESS)" >&2
    return 1
  fi

  local SNMP_OPTS=(-v"$SNMP_VERSION" -t 30 $CREDENTIALS "$HOSTADDRESS" -On)

  # 1) ifIndex -> bridgePort
  local bp_line bp
  bp_line=$(snmpwalk "${SNMP_OPTS[@]}" 1.3.6.1.2.1.17.1.4.1.2 2>/dev/null \
            | awk -v i="$IFINDEX" '$NF==i {print $1; exit}')
  if [[ -z "$bp_line" ]]; then
    echo "bridgePort non trovato per ifIndex=$IFINDEX" >&2
    return 1
  fi
  bp="${bp_line##*.}"

  # 2) Cerca MAC in dot1qTpFdbPort (VLAN-aware)
  local found=0
  while IFS= read -r oid; do
    local vlan mac
    vlan=$(awk -F. '{print $(NF-6)}' <<< "$oid")
    mac=$(awk -F. '{
      printf "%02X:%02X:%02X:%02X:%02X:%02X",
        $(NF-5),$(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF
    }' <<< "$oid")
    if ((found==0)); then
      echo "MAC address trovati su ifIndex $IFINDEX (bridgePort $bp):"
    fi
    echo " - VLAN $vlan -> $mac"
    found=1
  done < <(snmpwalk "${SNMP_OPTS[@]}" 1.3.6.1.2.1.17.7.1.2.2.1.2 2>/dev/null \
           | awk -v bp="$bp" '$NF==bp {print $1}')

  # 3) Fallback a BRIDGE-MIB (non VLAN-aware)
  if ((found==0)); then
    while IFS= read -r oid; do
      local mac
      mac=$(awk -F. '{
        printf "%02X:%02X:%02X:%02X:%02X:%02X",
          $(NF-5),$(NF-4),$(NF-3),$(NF-2),$(NF-1),$NF
      }' <<< "$oid")
      if ((found==0)); then
        echo "MAC address trovati su ifIndex $IFINDEX (bridgePort $bp):"
      fi
      echo " - VLAN - -> $mac"
      found=1
    done < <(snmpwalk "${SNMP_OPTS[@]}" 1.3.6.1.2.1.17.4.3.1.2 2>/dev/null \
             | awk -v bp="$bp" '$NF==bp {print $1}')
  fi

  if ((found==0)); then
    echo "Nessun MAC trovato su ifIndex $IFINDEX (bridgePort $bp)"
  fi
}




# Output ed exit status del general-connector
#
#
#
theend() {
	echo "$RESULT|$DATA"
	exit $EXIT_STATUS
}

theendNoPerf() {    #Gabriele Spaziani 12-03-2019
	echo "$RESULT"  #modifica necessaria perche quando veniva elaborato il json andava in errore perchè rimaneva il carattere '|' alla fine 
	exit $EXIT_STATUS
}


# Output ed exit status dei servizi figli
#
#
#
theend_sons() {
		
		passive_check "$HOSTNAME" "$SERVICE_NAME" "$STATE_SONS" "$RESULT_SONS"
	#	echo  "$HOSTNAME" "$SERVICE_NAME" "$STATE_SONS" "$RESULT_SONS"
		
		# DEBUG
		#echo $HOSTNAME $SERVICE_NAME $STATE_SONS 
		#echo $RESULT_SONS 
}

#
# Libreria funzioni per formato JSON
#


#
#
#
###il JSON deve seguire la struttura indicata nel file JSON.docx e deve essere richiamato tramite parametro -J
###quando viene richiamato il check con parametro -J il check deve restituire il solo JSON ed uscire
json_start(){
	appo_json="{\"host\":["
	appo_json="$appo_json{\"name\":\"$HOSTNAME\",\"address\":\"$HOSTADDRESS\"}],"
	appo_json="$appo_json\"check\":\"$(basename $0)\",\"resources\":["
}

#
#
#
json_end(){
	appo_json="${appo_json%?}]}"
}

#
#
#
json_body(){
	#info
	
			appo_json="$appo_json{\"name\":\"$INTERFACE_NAME$IF_ALIAS\",\"info\":["		#INTERFACE NAME E INTERFACE ALIAS INSIEME IN QUANTO SE LA DESCRIZIONE NONN C'è NON METTO L'UNDERSCORE
			appo_json="$appo_json{\"name\":\"Speed\",\"value\":\"$SPEED2 Mb/s\"}," 
			appo_json="$appo_json{\"name\":\"MAC\",\"value\":\"$MAC\"}"
			
			if ! [ -z "$INTERFACE_IP" ]; then
			appo_json="$appo_json,{\"name\":\"IP\",\"value\":\"$INTERFACE_IP\"}"
			fi
			
			appo_json="$appo_json],"
			
			#-- servizio Status
			appo_json="$appo_json\"services\":["
			appo_json="$appo_json{\"id\":\"$ID_INTERFACE\",\"name\":\"Status\",\"output\":\"$OUTPUT_STATUS <br> PacketError: $ERROR Traffic: $OUTPUT_TRAFFIC\",\"params\":[" 
			## -----

			appo_json="$appo_json{\"label\":\"Warning IN\",\"default\":\"$WARN_IN\",\"unit\":\"%\",\"type\":\"text\",\"size\":\"2\"},"

			appo_json="$appo_json{\"label\":\"Warning OUT\",\"default\":\"$WARN_OUT\",\"unit\":\"%\",\"type\":\"text\",\"size\":\"2\"},"

			appo_json="$appo_json{\"label\":\"Critical IN\",\"default\":\"$CRIT_IN\",\"unit\":\"%\",\"type\":\"text\",\"size\":\"2\"},"

			appo_json="$appo_json{\"label\":\"Critical OUT\",\"default\":\"$CRIT_OUT\",\"unit\":\"%\",\"type\":\"text\",\"size\":\"2\"}]"
			#-----
			#---Chiusura
			appo_json="$appo_json}]},"
			#---
}



###funzione specifica per i dispositivi windows 
#
#
#
function WIN_TABLE
{
	TABLE_ID=$(printf "$1\n" | cut -d'|' -f 1)
	for i in $TABLE_ID
	do	
		# Per evitare schede ripetute
		verifica_alias="" 
		verifica_alias=$(echo $appo_interfacce |grep $i)
		
		if ! [ -z $verifica_alias ]; then 
			continue
		fi
		appo_interfacce="$appo_interfacce#$i"
				
		TABLE=$TABLE$'\n'$(printf "$TABLE_SNMP\n" | awk -F "|" "\$1 == \"$i\"" | cut -d'|' -f 1,2,5,6,7,8,10,14,16 | sed  's/\//-/g' | sed  's/ //g')
			
	done
	printf "$TABLE\n"
}


#
# Conversione formato output Human readable
#
#
kbitstohr()
{
    # Convert input parameter (number of bytes) 
    # to Human Readable form
    #
    SLIST="bps,Kbps,Mbps,Gbps,Tbps,Pbps,Ebps,Zbps,Ybps"

    POWER=1
    VAL=$( echo "scale=0; $1 * 1000" | bc)
    VINT=$( echo $VAL / 1000 | bc )
    while [ $VINT -gt 0 ]
    do
        let POWER=POWER+1
        VAL=$( echo "scale=0; $VAL / 1000" | bc)
        VINT=$( echo $VAL / 1000 | bc )
    done

    echo $VAL$( echo $SLIST | cut -f$POWER -d, )
}


#
#
#
convert() {
  gawk --use-lc-numeric -v RS='[KMGTPE]' '
    match($0, /[0-9]*['"$(locale decimal_point)"']?[0-9]+$/) {
      $0 = substr($0, 1, RSTART-1) sprintf("%'\''.17g", \
        substr($0,RSTART) * (10**(index(RS,RT)*3-3)))
      RT=""
    }{printf "%s", $0 RT}'
}


#
#   Ricerca un elemento in una lista separata da virgole
#
#   Es.
#       list_include_item "10,11,12" "12"  && echo "yes" || echo "no"
#
function list_include_item {
  local list="$1"
  local item="$2"
  if [[ $list =~ (^|[,])"$item"($|[,]) ]] ; then
    # yes, list include item
    result=0
  else
    result=1
  fi
  return $result
}
#-------------------- Fine libreria funzioni -----------------------------------



#
# Main
#
snmpv3_username="senti_user"
snmpv3_authproto="SHA"
snmpv3_authkey="Senti.Border22"
snmpv3_privproto="DES"
snmpv3_privkey="Senti.Border22"
snmpv3_context=
SNMP_VERSION="3"

#snmpv3_username=""
#snmpv3_authproto=""
#snmpv3_authkey=""
#snmpv3_privproto=""
#snmpv3_privkey=""
#snmpv3_context=
#SNMP_VERSION="2c"

# Verifica requisito strutturale
if [ ! -d "${BASEDIR_ARGOMENTI}" ]; then
		echo -e "ABORT: La cartella configurazioni da wizard non esiste!!!\n"
		exit $STATE_UNKNOWN  
fi

doopts $@


if [[ $TOTAL_BANDWIDTH -eq 1 ]] && [ -z $BANDA_FISICA_ARG ]; then
		echo "ERROR: -T require -F."
		echo -e "\nNon posso determinare un riferimento di banda dalle interfacce. Occorre impostare questo mediante parametro -F\n\n"
		usage
		exit $STATE_UNKNOWN  
fi


case "$SNMP_VERSION" in
1|2c)
	if [ -z "$COMMUNITY" ]; then
		echo 'ERROR: Missing SNMP Community.'
		usage
		exit $STATE_UNKNOWN  
	fi
	CREDENTIALS="-c $COMMUNITY"
	;;
3)
	# Determino il tipo di accesso v3
	#
	if [ -z "$snmpv3_username" ]; then
		echo 'ERROR: Missing SNMPv3 username.'
		usage
		exit $STATE_UNKNOWN  
	fi
	
	if [ -n "$snmpv3_context" ]; then
		CREDENTIALS="-z $snmpv3_context"
	fi
	
	CREDENTIALS="$CREDENTIALS -u $snmpv3_username "
	snmpv3_seclevel="noAuthNoPriv"

	if [ -n "$snmpv3_authproto" -a -n "$snmpv3_authkey" ]; then
		CREDENTIALS="$CREDENTIALS -a $snmpv3_authproto -A $snmpv3_authkey"
		snmpv3_seclevel="authNoPriv"

		if [ -n "$snmpv3_privproto" -a -n "$snmpv3_privkey" ]; then
			CREDENTIALS="$CREDENTIALS -x $snmpv3_privproto -X $snmpv3_privkey"
			snmpv3_seclevel="authPriv"
		fi
	fi
	CREDENTIALS="$CREDENTIALS -l $snmpv3_seclevel" 
	;;
*)
	# default
	SNMP_VERSION="2c"
	CREDENTIALS="-c public"
	;;
esac



# Campi obbligatori
[[ -z "$HOSTADDRESS" ]] && echo 'Host address assente' && exit 1

# File che viene generato dopo aver aggiunto il servizio general-connector su Sentinet3 ed aver effettuato applica e riavvia
# all'interno de file sono riportati i dati di configurazione dei servizi figli scelti dall'utente attraverso l'interfaccia wizard
FILE_ARGOMENTI="${BASEDIR_ARGOMENTI}/$HOSTNAME-$SERVICEDESC-args"

#### DEBUG
#SYS_WIN=`snmpget -m IP-MIB -v$SNMP_VERSION $CREDENTIALS -t ${TIMEOUT:-5} -r 0 $HOSTADDRESS 1.3.6.1.2.1.1.1.0 2>/dev/null | grep -i Windows`
SYS_DESCR=`snmpget -m IP-MIB -v$SNMP_VERSION -t 30 $CREDENTIALS  $HOSTADDRESS 1.3.6.1.2.1.1.1.0 2>/dev/null`
SYS_WIN=$(echo  $SYS_DESCR| grep -i Windows)
if [[ -z "$SYS_DESCR" ]]
then
	RESULT="UNKNOWN - SNMP Timeout: servizio non raggiungibile |"
	STATE=$STATE_UNKNOWN
	#Gabriele Spaziani - controllo per evitare che le interfaccie rimangano verdi quando il servizio va in timeout
	if   [ -f $FILE_ARGOMENTI ]; then	
        while IFS= read -r interf
        do
            #Recupero il nome del servizio dal file argomenti
            SERVICE_NAME=$(echo $interf | awk -F '( *!)' '{print $1}')
            #Scrivo l'output
            RESULT_SONS="UNKNOWN - SNMP Timeout: servizio non raggiungibile |"
            #lo stato del servizio
	        STATE_SONS=$STATE_UNKNOWN
	        
	        #Chiamo la funzione theend per i figli - 6vvero le interfaccie
	        theend_sons
	        
	        
	        ####DEBUG####
	        #echo "Hostname:::$HOSTNAME"
	        #echo "Nome Servizio interfaccia:::: $SERVICE_NAME"
	        #echo "Stato servizio interfaccia::: $STATE_SONS"
	        #echo -e "output servizio interfaccia::: $RESULT_SONS"
        done < $FILE_ARGOMENTI
    fi
	theend
fi

## Determino lista interfacce
# Ricava solo indice numerico in quanto il nome non � sempre chiave
if [[ "$INFO" = "info" ]] ; then
	TABLE_IP=`snmptable -v$SNMP_VERSION $CREDENTIALS -t ${TIMEOUT:-20} -r 6 -m IP-MIB -CH $HOSTADDRESS -Cf "|" ipaddrtable 2>&1 | grep -v "127.0.0.1" |awk -F "|" '{print  $2"|"$1}'`

#echo $TABLE_IP

	# Alcuni dispositivi restituiscono una descrizione di interfaccia con spazi
	# Questi vengono ridotti a carattere undescore per non impattare con algoritmo
	if [ -n "$IF_TABLE_FILTER" ]; then
	    TABLE_SNMP=$(snmptable -v$SNMP_VERSION $CREDENTIALS -t ${TIMEOUT:-20} -r 6 -m IF-MIB -CH -Cf "|" $HOSTADDRESS iftable 2>&1 | egrep "$IF_TABLE_FILTER" | tr ' \t' '_' )
	else
		TABLE_SNMP=$(snmptable -v$SNMP_VERSION $CREDENTIALS -t ${TIMEOUT:-20} -r 6 -m IF-MIB -CH -Cf "|" $HOSTADDRESS iftable 2>&1 | tr ' \t' '_' )
	fi

#echo $TABLE_SNMP
#echo SYS_WIN=$SYS_WIN

	# Per sistemi Windows ci facciamo guidare dalla 
	# presenza di un indirizzo IP per determinare interfaccia
	if  [ -n "$SYS_WIN" ]; then
		# DEBUG echo Idetificato come Windows
		for iface in $TABLE_IP
		do 
			ID=$( echo $iface | awk -F\| '{ print $1 }') 
			INTERFACE="$INTERFACE $ID"
		done
		TABLE=$( WIN_TABLE $TABLE_IP)
	else
		# DEBUG echo Idetificato come Linux o Network Equipment
		# DEBUG i=1
		for LINE in $TABLE_SNMP
		do
			# DEBUG echo "LINE($i)=$LINE"

			IFACE=$( echo $LINE  | awk  -F "|" '{print  $1}' )
			# TYPE=$( echo $LINE  | awk  -F "|" '{print  $3}' )
			HWADDR=$( echo $LINE  | awk  -F "|" '{print  $6}' )
			[[ "$HWADDR" != "00:00:00:00:00:00" ]] &&
				INTERFACE="$INTERFACE $IFACE"
		#	DEBUG i=$((i+1))
		done 
		TABLE=$(printf "$TABLE_SNMP\n"| awk -F "|" '{print  $1"|"$2"|"$5"|"$6"|"$7"|"$8"|"$10"|"$14"|"$16}' | sed  's/\//-/g' | sed  's/ //g')
	fi

	if [ -n "$INTERFACE" ]; then
		json_start
		RestituisciJSON
	fi
	if [ -n "$appo_json" ]; then
		json_end
		RESULT="$appo_json"
		EXIT_STATUS=0
	else
		RESULT="{}"
		EXIT_STATUS=3
	fi 
    	theendNoPerf
fi




#
# Processing data
if  ! [ -f $FILE_ARGOMENTI ]; then
	RESULT="Nessuna Interfaccia Configurata"
	EXIT_STATUS=3
	theend
fi	



# Determina la lista interfacce solo da configurazione
# Modifica 19/02/2015: Andrea Tassotti
if [ "x$INFO" != "xinfo" ] ; then
	INTERFACES=$( awk -F \! -v tag=$TAG 'BEGIN{ tlen=length(tag)+1; }
											 { for(i=1;i<=NF;i++)
												if ( index($i,"#" ) && match($i, tag) )
												print substr($i,tlen, index($i, "#") - tlen) }' $FILE_ARGOMENTI )

	# Itera su tutte le interfacce configurate
	#
	declare -i request=0
    declare -a OIDS
	count=1
	inerrors=0
	outerrors=0
	indiscards=0
	outdiscard=0

	for iface in $INTERFACES
	do
	    #OIDS[request]="${OIDS[request]} IF-MIB::ifAlias.$iface" #recupero anche la descripton dell' interfaccia
        OIDS[request]="${OIDS[request]} IF-MIB::ifDescr.$iface"
	    OIDS[request]="${OIDS[request]} IF-MIB::ifAdminStatus.$iface"
	    OIDS[request]="${OIDS[request]} IF-MIB::ifOperStatus.$iface"
	    OIDS[request]="${OIDS[request]} IF-MIB::ifSpeed.$iface"
	    OIDS[request]="${OIDS[request]} IF-MIB::ifHighSpeed.$iface" 
        OIDS[request]="${OIDS[request]} IF-MIB::ifInOctets.$iface"
        OIDS[request]="${OIDS[request]} IF-MIB::ifOutOctets.$iface"
        OIDS[request]="${OIDS[request]} IF-MIB::ifHCInOctets.$iface"
        OIDS[request]="${OIDS[request]} IF-MIB::ifHCOutOctets.$iface"
        
        # For packet-oriented interfaces, the number of inbound packets that contained errors
        # preventing them from being deliverable to a higher-layer protocol. 
        # For character- oriented or fixed-length interfaces, the number of inbound transmission
        # units that contained errors preventing them from being deliverable to a higher-layer protocol.
        # Discontinuities in the value of this counter can occur at re-initialization of the management 
        # system, and at other times as indicated by the value of ifCounterDiscontinuityTime.
        OIDS[request]="${OIDS[request]} IF-MIB::ifInErrors.$iface"
        # For packet-oriented interfaces, the number of outbound packets that could not be transmitted 
        # because of errors. For character-oriented or fixed-length interfaces, the number of outbound 
        # transmission units that could not be transmitted because of errors. Discontinuities in the 
        # value of this counter can occur at re-initialization of the management system, and at other
        # times as indicated by the value of ifCounterDiscontinuityTime.
        OIDS[request]="${OIDS[request]} IF-MIB::ifOutErrors.$iface"
        # The number of inbound packets which were chosen to be discarded even though no errors had been
        # detected to prevent their being deliverable to a higher-layer protocol. One possible reason for
        # discarding such a packet could be to free up buffer space.
        OIDS[request]="${OIDS[request]} IF-MIB::ifInDiscards.$iface"
        # The number of outbound packets which were chosen to be discarded even though no errors had been
        # detected to prevent their being transmitted. One possible reason for discarding such a packet could be to free up buffer space.
        OIDS[request]="${OIDS[request]} IF-MIB::ifOutDiscards.$iface"
        count=$((count + 1))

        # TODO: Parametrizzare da linea di comando in ragione di eventi (vedi "message would have been too large")
        if [ $(( count % 3 )) -eq 0 ] ; then
	        let request++
	    fi
	done
	
	# DEBUG date +'INIZIO get: %s'
	tLen=${#OIDS[@]}
	for (( i=0; i<${tLen}; i++ ));
    do
        # DEBUG
        # echo execute request $i
   # DEBUG   echo  snmpget -v$SNMP_VERSION $CREDENTIALS -t ${TIMEOUT:-5} -O q $HOSTADDRESS  ${OIDS[$i]} 2>&1 
	    # Iterando sulla risposta itera sostanzialmente sulle interfacce
	    while read ignore variable iface value
	    do
	        #echo $ignore $variable $iface $value
    	    if [ -z "$variable" ] || [ "$ignore" = "Reason" ]; then
	            RESULT="UNKNOWN - SNMP Timeout: servizio non raggiungibile in ${TIMEOUT:-5} sec o OID richiesti sconosciuti|"
	            STATE=$STATE_UNKNOWN
	            theend
	        fi
	        # TODO Vedi parametro numero richieste comuni
	        # [ "$value" = "message would have been too large" ] && echo "TOO LARGE"
	        # Rimuovere i blank per i nomi di interfacce cisco tipo 0/0/1, per cui uno degli / diviene blank
	        	
	        	value=$(echo $value | sed 's/ //g')
	            [ "$variable" = "ifDescr" ] && value="${value/[[:blank:]]//}"
	            eval "$variable[$iface]=\"$value\"" # DEBUG: && echo "OID:::: $variable[$iface]=\"$value\""
	    done < <( snmpget -v$SNMP_VERSION $CREDENTIALS -t ${TIMEOUT:-20} -r 3 -O q $HOSTADDRESS  ${OIDS[$i]} 2>&1 | tr ':.' ' ' )
    done
	# DEBUG date +'FINE get: %s'

	
	TOTALIN=0
	TOTALOUT=0
	
	# DEBUG date +'INIZIO calcolo: %s'
	for iface in $INTERFACES
	do
		# Nel caso restituisca 'No Such Object available on this agent at this OID' o altro messaggio invece che i valori

	    [[ "${ifInOctets[$iface]}"  =~ ^[a-zA-Z]+ ]] || [ -z "${ifInOctets[$iface]}" ] && ifInOctets[$iface]="0"
        [[ "${ifOutOctets[$iface]}" =~ ^[a-zA-Z]+ ]] || [ -z "${ifOutOctets[$iface]}" ] && ifOutOctets[$iface]="0"
	    [[ "${ifHCInOctets[$iface]}"  =~ ^[a-zA-Z]+ ]] || [ -z "${ifHCInOctets[$iface]}" ] && ifHCInOctets[$iface]="0"
        [[ "${ifHCOutOctets[$iface]}" =~ ^[a-zA-Z]+ ]] || [ -z "${ifHCOutOctets[$iface]}" ] && ifHCOutOctets[$iface]="0"

	    # DEBUG
	    #date
	    #echo iface=$iface
	    #echo ifAlias=${ifAlias[$iface]}
        #echo ifAdminStatus=${ifAdminStatus[$iface]}
        #echo ifOperStatus=${ifOperStatus[$iface]}
        #echo ifSpeed=${ifSpeed[$iface]}
        #echo ifHighSpeed=${ifHighSpeed[$iface]}
        #echo ifDescr=${ifDescr[$iface]}
        #echo ifInOctets=${ifInOctets[$iface]}
        #echo ifOutOctets=${ifOutOctets[$iface]}
        #echo ifHCInOctets=${ifHCInOctets[$iface]}
        #echo ifHCOutOctets=${ifHCOutOctets[$iface]}
        #echo ifInErrors=${ifInErrors[$iface]}
        #echo ifOutErrors=${ifOutErrors[$iface]}
        #echo ifInDiscards=${ifInDiscards[$iface]}
        #echo ifOutDiscards=${ifOutDiscards[$iface]}
        #echo -e "\n"
        

		# Leggiamo le soglie (e altri parametri dal file degli argomenti)
		#sample:Status!56712#20!20!50!50

		#$TAG$iface ID del servizio figlio che viene generato dal numero TAG scelto precedentemente e l'ID dell'interfaccia
		if   [ -f $FILE_ARGOMENTI ]; then	
		    ARGOMENTI=$(grep "!$TAG$iface#" $FILE_ARGOMENTI)
		    # DEBUG
            #echo ARGOMENTI=$ARGOMENTI
            
            # Split in un array per separatore #
            TMP=(${ARGOMENTI//#/ })
            
            # Prende il service name dal primo elemento
            TMP=${TMP[0]}
            ID=(${TMP//!/ })
            SERVICE_NAME=${ID[0]}
            
            # DEBUG
            # echo SERVICE_NAME=$SERVICE_NAME

            # Prende il secondo elemento contenente gli argomenti
            TMP=${TMP[1]}
            # Splitta in un array per separatore !
            ARGOMENTI=(${TMP//!/ })
            
            # Ora gli argomenti sono posti ordinatamente su indici da 0 a 5 nell'array ARGOMENTI
            WARN_IN=${ARGOMENTI[0]}
            WARN_OUT=${ARGOMENTI[1]}
            CRIT_IN=${ARGOMENTI[2]}
            CRIT_OUT=${ARGOMENTI[3]}
            SPEED_IN=""
            SPEED_OUT=""
            TMP_SPEED_IN=${ARGOMENTI[4]}
            TMP_SPEED_OUT=${ARGOMENTI[5]}

		else
			SERVICE_NAME="IF"
		fi
        if [[ "${ifOperStatus[$iface]}" = "No Such Instance currently exists at this OID" ]] ; then
        	RESULT_SONS="CRITICAL - Interfaccia $iface inesistente! |"
			STATE_SONS=$STATE_UNKNOWN
			theend_sons
			continue
		fi
	     
        if [ -z "${ifDescr[$iface]}" ]
        then
        	RESULT_SONS="CRITICAL - Unreachable|"
			STATE_SONS=$STATE_UNKNOWN
			theend_sons
			continue
        fi

		# Verifica stato operativo scheda
		if [[ "${ifAdminStatus[$iface]}" = "down" ]] ; then  
			RESULT_SONS="${ifDescr[$iface]} - UNKNOWN - AdminStatus: DOWN|"
			STATE_SONS=$STATE_CRITICAL
			down_interfaces=$((down_interfaces+1))
			theend_sons
			continue
		elif [[ "${ifAdminStatus[$iface]}" = "up" ]] && [[ "${ifOperStatus[$iface]}" = "down" ]] ; then     	
			RESULT_SONS="${ifDescr[$iface]} - CRITICAL - AdminStatus: UP  Link: DOWN|"
			STATE_SONS=$STATE_CRITICAL
			up_interfaces=$((up_interfaces+1))
    		link_down=$((link_down+1))
			theend_sons
			continue
		fi
		
        up_interfaces=$((up_interfaces+1))
    	link_up=$((link_up+1))


		# ifSpeed: bandwidth in units bits per seconds
        ifSpeed=${ifSpeed[$iface]}
        ifHighSpeed=${ifHighSpeed[$iface]}
#        echo ifSpeed=$ifSpeed
#        echo ifHighSpeed=$ifHighSpeed
       
        if [ -n "$ifSpeed" ] && [ $ifSpeed -eq $ifSpeed ] 2>/dev/null; then
        	# Risposta numerica

			# Il alcune circostanze ritorna 0 !! Default 1GBit
			[[ $ifSpeed -eq 0 ]] && ifSpeed=1000000000  # in bps
        
        ##	# 10GBit: caso particolare Cisco
        ##	if [[ $ifSpeed = "4294967295" ]] || [[ $ifHighSpeed = "10000" ]] ; then
        ##    	ifSpeed=10000000000 # in bps
        ##	fi
        	
        	# 10GBit: caso particolare Cisco
        	if [[ $ifSpeed = "4294967295" ]] ; then
            	ifSpeed=$( echo ${ifHighSpeed} \* 1000000 | bc ) # in bps
        	fi
        	

        	# ifHighSpeed bandwidth in units of 1,000,000 bits per second: range of `n-500,000' to `n+499,999'
        	# High Speed IF (>1GBit)
        	if  [ $( bc <<< " if ( $ifHighSpeed > 10000 ) 1 else 0; " ) -eq 1 ]; then
        	    # In bps
        	    ifSpeed=$( echo ${ifHighSpeed} \* 1000000 | bc )
        	fi
        else
            # Risposta non numerica (errore OID)
            # 10GBit: caso particolare Cisco Nexus
            ifSpeed=10000000000
        fi

        # In Kbps
	    SPEED_IN=$( echo ${ifSpeed} / 1000 | bc )
	    SPEED_OUT=$( echo ${ifSpeed} / 1000 | bc )


		[[ -n "$TMP_SPEED_IN" ]] && SPEED_IN=$TMP_SPEED_IN
		[[ -n "$TMP_SPEED_OUT" ]] && SPEED_OUT=$TMP_SPEED_OUT
		
		

        if [ -z "$BANDA_FISICA_ARG" ]; then
            BANDA_FISICA=$SPEED_IN
        else
            # Posibilità di esprimere unità di misura
            BITS=$( echo $BANDA_FISICA_ARG | convert )
            BANDA_FISICA=$( bc <<< "$BITS / 1000" )
            if [ $( bc <<< " if ( $BANDA_FISICA > $SPEED_IN) 1 else 0; " ) -eq 1 ]; then
                BANDA_FISICA=$SPEED_IN
            fi
        fi
        
			# DEBUG
			#echo ${ifDescr[$iface]}
			#echo SERVICE_NAME=$SERVICE_NAME
			#echo WARN_IN=$WARN_IN
			#echo WARN_OUT=$WARN_OUT
			#echo CRIT_IN=$CRIT_IN
			#echo CRIT_OUT=$CRIT_OUT
			#echo SPEED_IN=$SPEED_IN
			#echo SPEED_OUT=$SPEED_OUT
			#echo BANDA_FISICA=$BANDA_FISICA

        # Se ho un dato generale di soglia applico questo in assenza di specifiche puntuali
        if [[ -z "$WARN_IN" || "$WARN_IN" -eq 0 ]] && [[ -z "$WARN_OUT" || "$WARN_OUT" -eq 0 ]] && [[ -n "$WARN" ]]
        then
            WARN_IN=$WARN
            WARN_OUT=$WARN
        fi
        if  [[ -z "$CRIT_IN" || "$CRIT_IN" -eq 0 ]] && [[ -z "$CRIT_OUT" || "$CRIT_OUT" -eq 0 ]] && [[ -n "$CRIT" ]]
        then
            CRIT_IN=$CRIT
            CRIT_OUT=$CRIT
        fi


		# DEBUG
        #echo ifSpeed=$ifSpeed
		#echo SPEED_IN=$SPEED_IN
		#echo SPEED=OUT=$SPEED_OUT
		#echo WARN_IN=$WARN_IN_KBPS kbps
		#echo WARN_OUT=$WARN_OUT_KBPS kbps
		#echo CRIT_IN=$CRIT_IN_KBPS kbps
		#echo CRIT_OUT=$CRIT_OUT_KBPS kbps
        #echo $CREDENTIALS  
        #echo "${ifOperStatus[$iface]}" 
        #echo "${ifInOctets[$iface]}" 
        #echo "${ifOutOctets[$iface]}" 
        #echo "${ifHCInOctets[$iface]}" 
        #echo "${ifHCOutOctets[$iface]}"


		# Bandwidth calculation (eseguita direttamente da RRD)
		#
		#
		# Half duplex :
		#
		#  (DeltaIfInOctets + DeltaIfOutOctets) x 8 x 100
		#  ----------------------------------------------
		#      (number of seconds in Delta) x ifSpeed
		#
		# Full duplex :
		#
		#  max(DeltaIfInOctets, DeltaIfOutOctets) x 8 x 100
		#  -------------------------------------------------
		#        (number of seconds in Delta) x ifSpeed
		#
		# I precedenti metodi sono meno accurati in quanto non tengono conto della direzione
		#
		#                            DeltaIfInOctets x 8 x 100
		#  Input utilization = -------------------------------------
		#                      (number of seconds in Delta) x ifSpeed
		#
		#
		#                            DeltaIfOutOctets x 8 x 100
		#  Output utilization = -------------------------------------
		#                      (number of seconds in Delta) x ifSpeed
		#
		#
		
        # Leggiamo da storico
        #
        #   Importante resettare il tempo ultima lettura in quanto è indicazione di esistenza del file e dei dati per fase successiva
        olddate=
        [ -f /tmp/$HOSTNAME-$SERVICEDESC_$iface.dat ] && read olddate oldin oldout < /tmp/$HOSTNAME-$SERVICEDESC_$iface.dat

		if [[ "$WORD_SIZE" -eq 64 ]]; then
			MaxPkts="2^64"
			In=${ifHCInOctets[$iface]}
			Out=${ifHCOutOctets[$iface]}
		elif [[ "$WORD_SIZE" -eq 32 ]]; then
			In=${ifInOctets[$iface]}
			Out=${ifOutOctets[$iface]}
			MaxPkts="2^32"
		else
			# AUTO
			#		ATTENZIONE: corsa critica se ifHCInOctets == ifHCOutOctets == 0
			if [ ${ifHCInOctets[$iface]} -ne 0 ] || [ ${ifHCOutOctets[$iface]} -ne 0 ]; then
				In=${ifHCInOctets[$iface]}
				Out=${ifHCOutOctets[$iface]}
				MaxPkts="2^64"
			else
				In=${ifInOctets[$iface]}
				Out=${ifOutOctets[$iface]}
				MaxPkts="2^32"
			fi
		fi

  
  		# Storicizza
        now=$( date +'%s' )
		echo  "$now $In $Out" > /tmp/$HOSTNAME-$SERVICEDESC_$iface.dat

        # Prima esecuzione, non abbiamo dati, quindi aspettiamo 
        [ -z "$olddate" ] && continue   # Next IF
        
        # Calcola
        TIME=$((now - olddate))
        
        # Tempo di nuova esecuzione troppo breve 
        [[ $TIME -eq 0 ]] && continue


		DeltaIfInOctets=0
		DeltaIfOutOctets=0
		DeltaIfInOctets=$(bc <<< "scale=4; if ( $In >= $oldin ) ( $In - $oldin ) else ( $MaxPkts - $oldin + $In )" )
		DeltaIfOutOctets=$(bc <<< "scale=4; if ( $Out >= $oldout ) ( $Out - $oldout ) else ( $MaxPkts - $oldout + $Out )" )

		# DEBUG
		#echo ${ifDescr[$iface]}
		#echo  ${ifHCInOctets[$iface]} $oldin64
		#echo DeltaIfInOctets=$DeltaIfInOctets
		#echo DeltaIfOutOctets=$DeltaIfOutOctets

		IN=$( bc <<< " ( $DeltaIfInOctets * 8 ) / ( $TIME ) " )
		OUT=$( bc <<< " ( $DeltaIfOutOctets * 8 ) / ( $TIME  ) " )
		INPERC=$( bc <<< " ( $DeltaIfInOctets * 8 * 100 ) / ( $TIME * $ifSpeed ) " )
		OUTPERC=$( bc <<< " ( $DeltaIfOutOctets * 8 * 100 ) / ( $TIME * $ifSpeed ) " )


    	# Trasformare IN e OUT da bps a Kbps
		#
		IN=$( bc <<< "scale=2; $IN / 1000" )
		OUT=$( bc <<< "scale=2; $OUT / 1000" )

        # Controllo opzionale banda totale su interfacce selezionate
        if [[ $TOTAL_BANDWIDTH -eq 1 ]] && list_include_item "${TOTAL_BANDWIDTH_IF_LIST}" "${ifDescr[$iface]}"; then
            # DEBUG
            #echo Summarize "${ifDescr[$iface]}" data
            TOTALIN=$(  bc <<< " ( $TOTALIN  + $IN ) " )
            TOTALOUT=$( bc <<< " ( $TOTALOUT + $OUT ) " )
        fi

        # DEBUG
        #echo IN=$IN
        #echo OUT=$OUT
        #echo INPERC=$INPERC
        #echo OUTPERC=$OUTPERC
        
# Per consentire limiti oltre 100%			
#   		[ -n "$IN" ] && INPERC=$( echo "scale=3; x=($IN * 100 / $SPEED_IN); if (x>100) x=100; x" | bc )
#			[ -n "$IN" ] && INPERC=$( echo "scale=3; x=($IN * 100 / $SPEED_IN); x" | bc )


# Per consentire limiti oltre 100%
#			[ -n "$OUT" ] && OUTPERC=$( echo "scale=3; x=($OUT * 100 / $SPEED_OUT); if (x>100) x=100; x" | bc )
#			[ -n "$OUT" ] && OUTPERC=$( echo "scale=3; x=($OUT * 100 / $SPEED_OUT); x" | bc )


            #
            #   Valutazione stato
            #
			# TODO: Reintegrare controllo banda fisica
            if $INVERTED; then
                if [ $( bc <<< " if ( $INPERC < $CRIT_IN || $OUTPERC < $CRIT_OUT ) 1 else 0; " ) -eq 1 ]; then
                    STATE_SONS=$STATE_CRITICAL
                else
                    if [ $( bc <<< " if ( $INPERC < $WARN_IN || $OUTPERC < $WARN_OUT ) 1 else 0; " ) -eq 1 ]; then
                        STATE_SONS=$STATE_WARNING
                    else
                        STATE_SONS=$STATE_OK
                    fi
                fi

            else
                if [ $( bc <<< " if ( $INPERC > $CRIT_IN || $OUTPERC > $CRIT_OUT ) 1 else 0; " ) -eq 1 ]; then
                    STATE_SONS=$STATE_CRITICAL
                else
                    if [ $( bc <<< " if ( $INPERC > $WARN_IN || $OUTPERC > $WARN_OUT ) 1 else 0; " ) -eq 1 ]; then
                        STATE_SONS=$STATE_WARNING
                    else
                        STATE_SONS=$STATE_OK
                    fi
                fi

            fi
            
            macs=macs_on_ifindex $iface

			# Applichiamo uno dei possibili output testuali e performance data
			#
			case "$OUTPUT_MODE" in
			simple)
				# Output mode 1 (simple): in/out
				RESULT="- In: $(kbitstohr ${IN:=0}) (${INPERC}%), Out: $(kbitstohr ${OUT:=0}) (${OUTPERC}%) - Bandwidth limit: In $(kbitstohr ${SPEED_IN}) - Out $(kbitstohr ${SPEED_OUT}) - Physical $(kbitstohr ${BANDA_FISICA:=0}) - Mac Address: ${macs}"
#				RESULT="- In: ${IN:=0} (${INPERC}%), Out:${OUT:=0} (${OUTPERC}%) - Bandwidth limit: In ${SPEED_IN} - Out ${SPEED_OUT} - Physical ${BANDA_FISICA:=0}"
                #trasformazione in Mbps
                inMbit=$( bc <<< "scale=2; $IN / 1000" )
                outMbit=$( bc <<< "scale=2; $OUT / 1000" )
				if [ "${ifDescr[$iface]}" = "TenGigE0/0/0/0" ] || [ "${ifDescr[$iface]}" = "BVI1" ] || [ "${ifDescr[$iface]}" = "TenGigE0/1/0/3" ] || [ "${ifDescr[$iface]}" = "TenGigE0/0/0/3" ]; then
					INTERF_IN[${ifDescr[$iface]}]=$inMbit
					INTERF_OUT[${ifDescr[$iface]}]=$outMbit
				fi
				#PERFDATA="in=$inMbit out=$outMbit"
				PERFDATA="in=$inMbit;$WARN_IN;$CRIT_IN;0;$BANDA_FISICA out=$outMbit;$WARN_IN;$CRIT_IN;0;$BANDA_FISICA"
				#PERFDATA="in=$IN out=$OUT"
				;;
			complex)
				# Output mode 2 (complex): in/out/limitin/limitout/bandwidth
				RESULT="- In: $(kbitstohr ${IN:=0}) (${INPERC:-0}%), Out: $(kbitstohr ${OUT:=0}) (${OUTPERC:-0}%) - Bandwidth limit: In $(kbitstohr ${SPEED_IN}) - Out $(kbitstohr ${SPEED_OUT}) - Physical $(kbitstohr ${BANDA_FISICA:=0}) - Mac Address: ${macs}"
#				RESULT="- In: ${IN:=0} (${INPERC:-0}%), Out:  ${OUT:=0} (${OUTPERC:-0}%) - Bandwidth limit: In ${SPEED_IN} - Out ${SPEED_OUT} - Physical ${BANDA_FISICA:=0}"
                #trasformazione in Mbps
                inMbit=$( bc <<< "scale=2; $IN / 1000" )
                outMbit=$( bc <<< "scale=2; $OUT / 1000" )
				if [ "${ifDescr[$iface]}" = "TenGigE0/0/0/0" ] || [ "${ifDescr[$iface]}" = "BVI1" ] || [ "${ifDescr[$iface]}" = "TenGigE0/1/0/3" ] || [ "${ifDescr[$iface]}" = "TenGigE0/0/0/3" ]; then
					INTERF_IN[${ifDescr[$iface]}]=$inMbit
					INTERF_OUT[${ifDescr[$iface]}]=$outMbit
				fi
				PERFDATA="in=$inMbit out=$outMbit"
				PERFDATA="in=$inMbit;$WARN_IN;$CRIT_IN;0;$BANDA_FISICA out=$outMbit;$WARN_IN;$CRIT_IN;0;$BANDA_FISICA"
				#PERFDATA="in=$IN out=$OUT limitin=${SPEED_IN%%.*} limitout=${SPEED_OUT%%.*} bandafisica=${BANDA_FISICA%%.*}"
				;;
			esac
		#fi
		
		
        
        #for i in "${!INTERF_IN[@]}"
        #do
        #    echo -n "key  : $i <br>"
        #    echo -n "value: ${INTERF_IN[$i]}<br>"
        #done
        
		if [[ $NO_LABEL = "true" ]];
		then
			RESULT_SONS="$RESULT| $PERFDATA"
		else
			RESULT_SONS="${ifDescr[$iface]} $RESULT| $PERFDATA"
		fi

		theend_sons
	done
	# DEBUG date +'FINE calcolo: %s'

fi

RESULT="$((count - 1)) interfacce: ${up_interfaces:-0} attive (di cui ${link_up:-0} link up, ${link_down:-0} link down); ${down_interfaces:-0} disattive"



if [[ $INCLUDE_ERROR_STATS -eq 1 ]]; then
	[ $inerrors -gt 0 ] && RESULT="$RESULT; ${inerrors} con errori IN"
	[ $outerrors -gt 0 ] && RESULT="$RESULT; ${outerrors} con errori OUT"
	[ $indiscards -gt 0 ] && RESULT="$RESULT; ${indiscards} con scarti IN"
	[ $outdiscards -gt 0 ] && RESULT="$RESULT; ${outdiscards} con scarti OUT"
fi

EXIT_STATUS=$STATE_OK


#
#   Determinazione stato generale consumo banda totale
#

    
if [[ $TOTAL_BANDWIDTH -eq 1 ]]; then
	TOTALINPERC=$( bc <<< " ( $TOTALIN * 100 ) / $BANDA_FISICA " )
	TOTALOUTPERC=$( bc <<< " ( $TOTALOUT * 100 ) / $BANDA_FISICA " )


    # DEBUG
    #echo TOTALINPERC=${TOTALINPERC}%
    #echo TOTALOUTPERC=${TOTALOUTPERC}%
    #echo BANDAFISICA=${BANDA_FISICA}Kbps

    if [ $( bc <<< " if ( $TOTALINPERC > ${CRIT:-0} || $TOTALOUTPERC > ${CRIT:-0} ) 1 else 0; " ) -eq 1 ]; then
        EXIT_STATUS=$STATE_WARNING
    else
        if [ $( bc <<< " if ( $TOTALINPERC > ${WARN:-0} || $TOTALOUTPERC > ${WARN:-0} ) 1 else 0; " ) -eq 1 ]; then
            EXIT_STATUS=$STATE_WARNING
        else
            EXIT_STATUS=$STATE_OK
        fi
   fi

	case "$OUTPUT_MODE" in
	simple)
        RESULT="$RESULT; Bandwidth(IN) ${TOTALIN}Kbps ; Bandwidth(OUT) ${TOTALOUT}kbps"
		;;
    complex)
        RESULT="$RESULT; Bandwidth(IN) $(kbitstohr ${TOTALIN:=0}) (${TOTALINPERC:-0}%) ; Bandwidth(OUT) $(kbitstohr ${TOTALOUTT:=0}) (${TOTALOUTPERC:-0}%)"
        ;;
    esac

    RESULT="$RESULT| in=$IN out=$OUT bandwidth=$BANDA_FISICA"
fi

#Creazione dei performance data input/output per ogni interfaccia
i=0
in="in"
##INPUT
for x in ${!INTERF_IN[@]};
do
#echo $x
#    
    if [ "$x" = "BVI1" ]; then
                #echo $i
        inv=$(bc <<< $(echo "${INTERF_IN[$x]} * -1")) #inverto il risultato
                #echo $inv
        DATA="$DATA$in$x=$inv "
#                #echo $i
        continue
    fi
    DATA="$DATA$in$x=${INTERF_IN[$x]} "
    ((i++))
    #RESULT=$DATA
done
#
##OUTPUT   #in questo caso l'outout sarà mostrato in negativo
#i=0
out="out"
for x in ${!INTERF_OUT[@]};
do
#    ((i++))
    if [ "$x" = "BVI1" ]; then
        DATA="$DATA$out$x=${INTERF_OUT[$x]} "
        continue
    fi
    inv=$(bc <<< $(echo -n "${INTERF_OUT[$x]} * -1"))
    DATA="$DATA$out$x=$inv "
    #RESULT=$DATA
done

theend
