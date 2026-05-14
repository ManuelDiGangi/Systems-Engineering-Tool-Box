#!/usr/bin/php
<?php
#Manuel Di Gangi - Comando per le operazioni in rete, Sez IOC -  30/01/2025 v.1.0
#Controllo delle operazioni effettuate sulle vm del virtualizzatore VMware, tramite le info prese da Log Insight
#controllo effettuato via API

error_reporting(0);
ini_set("display_errors","on");
ob_start();

setLocale(LC_TIME, 'it_IT');
date_default_timezone_set('Europe/Rome');

$oraCorrente = date("H:i");
$giornoLavorativo = date('N'); //Giorni della settimana da 1 (Lunedi) a 7 (Domenica)
$nChar=66; # N caratteri +1

$hostAddress='';
$username='';
$password='';
$oraInizioLavoro= "08:00";
$oraFineLavoro= "16:30";
$EventType='';
$INPUTValido=true;

$RESULT="Errore \n";
$EXIT_STATUS=3;
$STATE_OK=0;
$STATE_WARNING=1;
$STATE_CRITICAL=2;
$STATE_UNKNOWN=3;
$STATE_DEPENDENT=4;
$PERF_DATA=0;

# $Contatti = array("0123456789");

$conta = 0;
#	---		Help	---
function print_help(){
		echo "";
        echo "\n";
        echo "Come si usa: check_vmLog_VMWARE.php -H <Host o IP> -u <username> -p <password> -t [ora inizio] -T [ora fine] -h <HELP>\n";
        echo "\n";
		echo "           	-H  Nome host\n";
        echo "           	-u  Username\n";
        echo "           	-p  password\n";
        echo "           	-t  Inizio fascia oraria lavorativa\n";
		echo "           	-T  Fine fascia oraria lavorativa\n";
        echo "           	-e  Event type da monitorare\n";
		echo "           		# Creazione\n";
		echo "           		# Avvio\n";
		echo "           		# Cancellazione\n";
		echo "           		# Modifica\n";
#		echo "           	-c  Contact group\n";
        echo "           	-h  Visualizza help\n";
	echo "\n";
	echo "Esempio di chiamata: -H 192.168.3.24 -u User -p Password -t 08:00 -T 16:30 -e Cancellazione\n";
#	echo "Esempio di chiamata: -H 192.168.3.24 -u User -p Password -t 08:00 -T 16:30 -e Cancellazione -c Default\n";
        echo "";
}

#	---		The end		---
function theend(){
    
    ob_end_clean();
    global $RESULT;
    global $EXIT_STATUS;
    global $PERF_DATA;
    $PERF_DATA = "$PERF_DATA;1;2;-1;200";
    echo "$RESULT | $PERF_DATA"; 
    exit($EXIT_STATUS);
}

#	---		Options	---
$options = getopt("h::l:H:u:p:t:T:e:c:");


if (isset($options['h'])) {
    print_help();
    exit(0);
}

if (isset($options['H'])) {

	$hostAddress = $options['H']; 
	
} else {

		$RESULT = $RESULT. "L'opzione -H (Hostaddress) è obbligatoria\n";
		$INPUTValido=false;

	}

if (isset($options['u'])) {

	$username = $options['u'];
	
} else {

		$RESULT = $RESULT. "L'opzione -u (username) è obbligatoria\n";
		$INPUTValido=false;
	}
	
if (isset($options['p'])) {

		$password = $options['p'];
} else {

		$RESULT = $RESULT. "L'opzione -p (password) è obbligatoria\n";
		$INPUTValido=false;
	}
	
if (isset($options['t'])) { //Inizio orario lavorativo

	$oraInizioLavoro = $options['t'];
	
}
if (isset($options['T'])) { //Fine orario lavorativo

	$oraFineLavoro = $options['T'];
	
}	
	
if (isset($options['e'])) { //Event Type

	$EventType = $options['e'];
	
} else {

	$RESULT = $RESULT. "L'opzione -e (Event type) è obbligatoria\n";
    $INPUTValido=false;
}
	
if ($INPUTValido == false)
{
    theend();
}

#################################################
#				--- FUNCTIONS ---				#
#################################################


function is_giorno_ora_lavorativo($oraCorrente, $oraFineLavoro, $oraInizioLavoro){  # date, date, date : return bool
	global $giornoLavorativo;
	if ($giornoLavorativo < 6 && ($oraCorrente < $oraFineLavoro && $oraCorrente > $oraInizioLavoro)){
		return true;
	}else{
		return false;
	}
}

function ci_sono_eventi($data)  # string : return bool
{
	if (isset($data['events']) && is_array($data['events']) && count($data['events']) > 0) {
		return true;
	}else{
		return false;
	}
}

function download_eventi($hostAdd, $user, $pass, $evtype)  # string, string, string, string : return array
{
	global $oraInizioLavoro;
	global $oraFineLavoro;
	global $oraCorrente;
	global $RESULT;
    global $EXIT_STATUS;
    global $STATE_UNKNOWN;
    global $PERF_DATA;

	$downloadLogsFrom = date('Y-m-d H:i');
	if ($oraCorrente < $oraFineLavoro)
	{
		$date = new DateTime('yesterday ' . $oraFineLavoro);  #Parametrizzare   -   Da Fare
	}else{
		$date = new DateTime('today ' . $oraFineLavoro);  #Parametrizzare   -   Da Fare
	}
	
	$downloadLogsFrom = (time() - $date->getTimestamp()) *1000;     # Calcolo il numero di millisecondi trascorsi dalla fine dell'orario lavorativo precedente

	#	---		Login	---
	$loginCommand = 'curl -s -k -X POST https://'.$hostAdd.':9543/api/v2/sessions -d \'{"username":"'.$user.'", "password":"'.$pass.'", "provider":"Local"}\' -H "accept: application/json" -H "Content-Type: application/json"';
	
	$loginResponse = shell_exec("$loginCommand");
	$loginResponse = json_decode($loginResponse, true);

	if (isset($loginResponse['sessionId'])) {
	$sessionId = $loginResponse['sessionId'];
	#$eventsCommand = "curl -s -k -X GET 'https://$hostAdd:9543/api/v2/events/text/CONTAINS%20$evtype/timestamp/>$downloadLogsFrom' --header 'Authorization: Bearer $sessionId'";
	$eventsCommand = "curl -s -k -X GET 'https://$hostAdd:9543/api/v2/events/text/CONTAINS%20$evtype/timestamp/LAST%20$downloadLogsFrom' --header 'Authorization: Bearer $sessionId'";
	
	$eventsResponse = shell_exec($eventsCommand);
	# Aggiungere Logout
	$eventsResponse = json_decode($eventsResponse, true);
	return  $eventsResponse;

	}else{
		# Aggiungere Logout
		$RESULT = "Login non riuscito";
		$PERF_DATA = -1;
        $EXIT_STATUS = $STATE_UNKNOWN;
		theend();
	}

}

function is_ultime_ore($time)  # date : return bool  -   is_ultime_ore vuole come parametro il timestamp in secondi
{
	$oraCorrente = time();
	$inizioIntervallo = $oraCorrente - (6*3600);
	if ($time > $oraCorrente)
	{
		# L'orario appartiene al giorno precedente
		$oraCorrente = strtotime('-1 day', $time);
	}

	return ($time >= $inizioIntervallo && $time <= $oraCorrente);
}


function salva_json($path,$dataArray) # string (path\nome.json), array, : return bool
{
    global $RESULT;
	global $PERF_DATA;
	global $EXIT_STATUS; 
	global $STATE_UNKNOWN;   
	
	$jsonData = json_encode($dataArray);
	if ($jsonData === false) {
		$RESULT = "Errore conversione json" . json_last_error_msg();
		$PERF_DATA = -1;
		$EXIT_STATUS = $STATE_UNKNOWN;
		theend();
	}
	
	$esitoSalvataggio = file_put_contents($path, $jsonData);
	if ($esitoSalvataggio === false) {
		$RESULT = "Errore salvataggio file";
		$PERF_DATA =-1;
		$EXIT_STATUS = $STATE_UNKNOWN;
		theend();
	}
}

function assembla_result ($events, $n){ # gli passo l'array proveniente dall'elaborazione del json o dei log, metto i campi in result
	$result = "";
	foreach ($events as $event)
	{
	    // GS 27/01/25 - bypass dell'utente 'svc-bck-comm-pure' quando incontra questo utente tra gli elementi non viene stampato
	    if ($event['user'] == 'svc-bck-comm-pure'){
	        continue;
	    }
		$result = $result . str_pad(" - ".$event['timestamp'], $n, '_') . " ";
		$result = $result . str_pad(" - VM: ".$event['vm'], $n, '_');
		if (isset($event['user']))
		{
			$result = $result . str_pad(" - Apportata da: ".$event['user'], $n, '_');
		}
		$result = $result . str_pad(" - Virtualizzatore: ".$event['virtual'], $n, '_');
		if (isset($event['server']))
		{
			$result = $result . str_pad(" - Server: ".$event['server'], $n, '_');
		}
		if (isset($event['dettagli']))
		{
			foreach ($event['dettagli'] as $riga)
			{
				$result = $result . str_pad($riga, $n, '_');
			}
		}
		$result = $result . str_pad(" ", $n, '*');
	}
	return $result;
}

function filtro_ora_eventi_locali($data) # array: array  prendo l'array con i dati del file locle json e li filtro per data
{
    $arrayfile = array();
	foreach ($data as $evento)
	{
		$time = $evento['timestamp'];   #   Mi ricavo il timestamp compatibile con la funzione is_ultime_ore
		$appo = explode('.', $time);
		$appo = $appo[0];
		$time=strtotime($appo);
	
		if(is_ultime_ore($time))
		{
			array_push($arrayfile,$evento);
		}
	}

	return $arrayfile;
}

function nuovi_log_to_array($DataFileServer, $Evt) #array : array (return $array_json)
{
    global $RESULT;
	global $EXIT_STATUS;
	global $STATE_UNKNOWN;
	global $PERF_DATA;
	$arrayjson= array();	# Array -> New Json
	foreach ($DataFileServer['events'] as $event)	# Operazioni sui log
	{
		$oraEvento = $event['timestamp'];	 
		$eventInSeconds = floor($oraEvento / 1000); #   is_ultime_ore vuole come parametro il timestamp in secondi

		if (is_ultime_ore($eventInSeconds)) # && maggiore data fine lavoro? in teoria no 	# Se il log risale alle ultme x ore
		{
			$eventDetails = explode("[", $event['text']);
			
			$date = new DateTime('@' . $eventInSeconds, new DateTimeZone('UTC'));
			$date->setTimezone(new DateTimeZone('Europe/Rome'));
			$oraEvento = $date->format('Y-m-d H:i:s'). '.' . (substr($event['timestamp'], -3)); # Possiamo ottimizzarlo in quanto $oraEvento è già in millisecondi
			$oraEvento = $oraEvento . " GMT+1";
			
			switch ($Evt)
			{			#	Compongo ll'array 
				case "vim.event.VmBeingCreatedEvent":
					$appo = elabora_log_creazione($eventDetails, $oraEvento);
				break;

				case "Virtual%20machine%20delete%20completed":
					$appo = elabora_log_cancellazione($eventDetails, $oraEvento);
				break;

				case "vim.event.VmReconfiguredEvent":
					$appo = elabora_log_riconfigurazione($eventDetails, $oraEvento);
				break;

				case "vim.event.VmPoweredOnEvent":
					$appo = elabora_log_avvio($eventDetails, $oraEvento);
				break;

				default:
					$RESULT = "Errore chiamata funzione elabora_log";
					$EXIT_STATUS = $STATE_UNKNOWN;
					$PERF_DATA = -1;
					theend();
				break;
			}
			if($appo != false)
			{
				array_push($arrayjson,$appo);
			}
		}
	}
	return $arrayjson;
}

function stampa_vecchio_result($ArrayFileLocale, $n)
{
	global $RESULT;
	global $STATE_WARNING;
	global $STATE_OK;
	global $EXIT_STATUS;
	global $PERF_DATA;
	
	$appo = filtro_ora_eventi_locali($ArrayFileLocale);
	$RESULT = assembla_result($appo, $n);
	if ($RESULT != "")
	{
		$EXIT_STATUS = $STATE_WARNING;
		$PERF_DATA = count($appo);
		theend();
	}else{
		$RESULT = "Nessuna operazione anomala";
		$PERF_DATA = 0;
		$EXIT_STATUS = $STATE_OK;
		theend();
	}
}


function send_notification($eventi)
{
	$messaggio = assembla_result($eventi, 0);
	
}

function array_compare($array1, $array2) {
    $diff = false;
    // Left-to-right
    foreach ($array1 as $key => $value) {
        if (!array_key_exists($key,$array2)) {
            $diff[0][$key] = $value;
        } elseif (is_array($value)) {
             if (!is_array($array2[$key])) {
                    $diff[0][$key] = $value;
                    $diff[1][$key] = $array2[$key];
             } else {
                    $new = array_compare($value, $array2[$key]);
                    if ($new !== false) {
                         if (isset($new[0])) $diff[0][$key] = $new[0];
                         if (isset($new[1])) $diff[1][$key] = $new[1];
                    }
             }
        } elseif ($array2[$key] !== $value) {
             $diff[0][$key] = $value;
             $diff[1][$key] = $array2[$key];
        }
 }
 // Right-to-left
 foreach ($array2 as $key => $value) {
        if (!array_key_exists($key,$array1)) {
             $diff[1][$key] = $value;
        }
        // No direct comparsion because matching keys were compared in the
        // left-to-right loop earlier, recursively.
 }
 return $diff;
}

#############################################
#	---		FUNZIONI ELABRAZIONE LOG 	---	#
#############################################

function elabora_log_creazione($text, $date){ # array, string : return array
	global $conta;
	$dettaglio = array();
	if(substr($text[4], 0, -1) == "vim.event.VmBeingCreatedEvent]")
	{
		$conta++;

			#	Nome VM
		$nomevm=explode(" ", $text[9]);
		$nomevm=$nomevm[1];
			#	Utente
		$user=explode("\\", $text[6]);
		$user=substr($user[count($user)-1], 0, -2);
			#	Virtualizzatore
		$virtual=explode(" ", $text[9]);
		$virtual=substr($virtual[3], 0, -1);
			#	Server
		$server=explode(" ", $text[0]);
		$server=$server[1];

		$dettaglio = array("timestamp" => $date, "vm" => $nomevm, "user"=> $user, "virtual"=>$virtual, "server"=>$server);
	}else{
		return false;
	}
	return $dettaglio;				
}

function elabora_log_cancellazione($text, $date){
	global $conta;
	$dettaglio = array();
	$appo = explode("]", $text[2]);
	if($appo[1] == " Virtual machine delete completed.")
	{
		$conta++;

			#	Nome VM
		$appo=explode("/", $text[2]);
		$nomevm=explode(".vmx", $appo[5]);
		$nomevm=$nomevm[0];
			#	Utente
		$appo=explode("]", $appo[1]);
		$user=explode("\\", $appo[0]);
		$user=$user[1];
			#	Virtualizzatore
		$virtual=explode(" ", $text[0]);
		$virtual=$virtual[1];
			#	Server
		$server=NULL;

		$dettaglio = array("timestamp" => $date, "vm" => $nomevm, "user"=> $user, "virtual"=>$virtual, "server"=>$server);
	}
	else{
		return false;
	}
	return $dettaglio;	
}

function elabora_log_riconfigurazione($text, $date){
	global $conta;
	$dettaglio = array();
	if(substr($text[4], 0, -1) == "vim.event.VmReconfiguredEvent]")
	{
		$conta++;

			#	Nome VM
		$appoMod=explode(" ", $text[9]);
		$nomevm=$appoMod[1];
			#	Utente
		$user=explode("\\", $text[6]);
		$user = substr($user[count($user)-1], 0, -2);
			#	Virtualizzatore
		$virtual=substr($appoMod[3], 0, -1);
			#	Server
		$server=explode(" ", $text[0]);
		$server=$server[1];	

		$modifiche = array();
		$appo=explode("\n", $text[9]);
		$NoTab = array ("Modified:  ", " Added:  ", " Deleted:  ");
		for ($i=1; $i < count($appo)-2; $i++){
			if (($appo[$i] != "") && ($appo[$i] != " "))
			{
				if (in_array($appo[$i], $NoTab))
				{
					$temp= " " . $appo[$i];
					array_push($modifiche,$temp);
				}
				else{
					$temp = " ----" . $appo[$i];
					array_push($modifiche,$temp);							    
				}
			}
		}

		$dettaglio = array("timestamp" => $date, "vm" => $nomevm, "user"=> $user, "virtual"=>$virtual, "server"=>$server, "dettagli" =>$modifiche);
	}
	else{
		return false;
	}
	return $dettaglio;	
}

function elabora_log_avvio($text, $date){
	global $conta;
	$dettaglio = array();
	if(substr($text[4], 0, -1) == "vim.event.VmPoweredOnEvent]")
	{
		$conta++;

			#	Nome VM
		$appoMod=explode(" ", $text[9]);
		$nomevm=$appoMod[0];
			#	Utente
		$user=NULL;
			#	Virtualizzatore
		$virtual=$appoMod[2];
			#	Server
		$server=explode(" ", $text[0]);
		$server=$server[1];	

		#terminare dettaglio modifica

		$dettaglio = array("timestamp" => $date, "vm" => $nomevm, "user"=> $user, "virtual"=>$virtual, "server"=>$server);
	}
	else{
		return false;
	}
	return $dettaglio;	
}




#########################
#	---		Main	---	#
#########################

$FileName="";
$path = "/tmp/";
$jsonData="";
$DataFileLocale="";
$DataFileServer="";
$Evt="vim.event.VmBeingCreatedEvent";

switch (strtolower ($EventType)){
	case "creazione":
		$FileName = $path . "VMware_log_creazione.json";
		$Evt="vim.event.VmBeingCreatedEvent";
	break;
	
	case "cancellazione":
		$FileName = $path . "VMware_log_cancellazione.json";
		$Evt="Virtual%20machine%20delete%20completed";
	break;
	
	case "avvio":
		$FileName = $path . "VMware_log_avvio.json";
		$Evt="vim.event.VmPoweredOnEvent";
	break;
	
	case "riconfigurazione":
	case "modifica":
		$FileName = $path . "VMware_log_riconfigurazione.json";
		$Evt="vim.event.VmReconfiguredEvent";
	break;
	
	default:
		$RESULT = "Event Type non valido";
		$PERF_DATA = -1;
		$EXIT_STATUS = $STATE_UNKNOWN;
		theend();
	break;
}
$jsonData = file_get_contents($FileName); #Provo ad aprire il file, la funzione ritorna false se file ! exist
if(!$jsonData){ 	#se non c'è genera errore e va nel cathc

  /*  try{	
	
	    throw new Exception("File not found");
	
    	#altrimenti lo decodifico
    	#$ArrayFileLocale = json_decode($jsonData, true);

    } catch (Exception $e){*/
    	#****************************************
    	#	---		File json non presente	---	*
    	#	---		Primo avvio del check	---	*
    	#****************************************
    	
    	if (is_giorno_ora_lavorativo($oraCorrente, $oraFineLavoro, $oraInizioLavoro)){ 		# Controllo se siamo in orario lavorativo
    		$RESULT = "In orario lavorativo. Nessun controllo effettuato";
    		$PERF_DATA = 0;
    		$EXIT_STATUS = $STATE_OK;
    		theend();
    	}else{
    	    
    		$DataFileServer=download_eventi($hostAddress, $username, $password, $Evt);		# Scarico i log e li salvo sottoforma di json decode
    		
    		if (!ci_sono_eventi($DataFileServer)) 	
    		{
    			$RESULT = "Nessuna operazione anomala";		# Non ci sono log
    			$EXIT_STATUS = $STATE_OK;
    			$PERF_DATA = 0;
    			theend();
    		}
    		else{ 
    			$RESULT="";
    			$ArrayServer = nuovi_log_to_array($DataFileServer, $Evt); 	# Elaboro gli eventi, li filtro e li inserisco in un nuovo array
    			salva_json($FileName,$ArrayServer);		# Converto array -> Json e salvo il file

    			if(count($ArrayServer) > 0)
    			{
    				$RESULT = assembla_result($ArrayServer, $nChar);
    				$PERF_DATA = count($ArrayServer);
    				$EXIT_STATUS = $STATE_CRITICAL; 	# E' la prima volta che esegue il download dei log, quindi son in critical
    			
    			}else{	# Ho scaricato degli eventi che però non soddisfavano i requisiti e quindi non ci sono eventi validi
    				$RESULT = "Nessuna operazione anomala";
    				$PERF_DATA =0;
    				$EXIT_STATUS = $STATE_OK;
    			}
    
    			#Stampare output e inviare allarme
    			theend();
    		}
    	}
    
    }
//}
#****************************************
#	---		File json esistente		---	*
#****************************************

    
$ArrayFileLocale = json_decode($jsonData, true);

if (is_giorno_ora_lavorativo($oraCorrente, $oraFineLavoro, $oraInizioLavoro)){ 		# Se giorno lavorativo non scarico nuovi log, stampo vecchi	

	stampa_vecchio_result($ArrayFileLocale, $nChar);
	
}else{
	
	#	 Verifico se ci sono nuovi eventi
	$DataFileServer=download_eventi($hostAddress, $username, $password, $Evt);		# Scarico i log e li salvo sottoforma di json decode (array non normalizzato)

	if (!ci_sono_eventi($DataFileServer)) 	
	{

		stampa_vecchio_result($ArrayFileLocale, $nChar);	# se non ci sono eventi ristampo vecchi log filtrati per le ultime x ore

	}
	else{
		$ArrayServer = nuovi_log_to_array($DataFileServer, $Evt);		# normalizzo array	FUNZIONA
		# Confronto i log locali e quelli scaricati
		$differenze = array_compare($ArrayServer, $ArrayFileLocale);     # non funziona array_diff
        
		if (!$differenze)
		{
			stampa_vecchio_result($ArrayFileLocale, $nChar);	# se non ci sono eventi ristampo vecchi log filtrati per le ultime x ore   # Il problema è qui
			
		}
		else{
			# Ci sono nuovi LOG
			#send_notification($differenze);
			salva_json($FileName,$ArrayServer);
 
			$RESULT = assembla_result($ArrayServer, $nChar);
			$PERF_DATA = count($ArrayServer);
			$EXIT_STATUS = $STATE_CRITICAL;
		}
		theend();
	}
}

theend();
?>