#!/bin/bash

#   Manuel Di Gangi
#   Comando per le operazioni in Rete
#   Interroga switch CISCO per ricavarne la configurazione tramite CDP (Interfacce, neighbour, ecc..)
#   06/03/2025 - Creazione script 


RESULT=""

# Controllo argomenti
if [ $# -lt 2 ]; then
    echo "Utilizzo: $0 <indirizzo_ip> <community>"
    exit 1
fi

# Variabile con indirizzo IP passato come argomento
TARGET_IP=$1
COMUNITY=$2

# Funzione di conversione MAC in IP
mac_to_ip() {
    local hex_mac=$1
    printf "%d.%d.%d.%d" \
        $((16#${hex_mac:0:2})) \
        $((16#${hex_mac:2:2})) \
        $((16#${hex_mac:4:2})) \
        $((16#${hex_mac:6:2}))
}

# Ottengo tutti gli ID interfaccia dei vicini
INTERFACE_IDS=$(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.4.1.9.9.23.1.2.1.1.7 | awk -F'\\.' '{print $(NF-1)}')

# Verifico se ci sono vicini
if [ -z "$INTERFACE_IDS" ]; then
    RESULT="$RESULT Nome apparato interrogat: " $(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.2.1.1.5.0 | awk -F: '{print $(NF)}')
    RESULT="$RESULT Nessun vicino trovato."
    exit 1
fi

# Stampo nome Apparato interrogato
RESULT="Nome apparato interrogat:<b>  $(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.2.1.1.5.0 | awk -F: '{print $(NF)}')</b>"
# Ciclo attraverso gli ID interfaccia dei vicini
RESULT="$RESULT <br>Dettagli dei vicini:"
RESULT="$RESULT <br>-------------------"

for INTERFACE_ID in $INTERFACE_IDS; do
    # Ottengo indirizzo MAC
    mac_hex=$(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.4.1.9.9.23.1.2.1.1.4.$INTERFACE_ID | awk -F: '{print $NF}' | tr -d ' ')
    
    # Conversione MAC in indirizzo IP
    NEIGHBOR_IP=$(mac_to_ip "$mac_hex")
    
    # Ottengo nome apparato
    NEIGHBOR_NAME=$(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.4.1.9.9.23.1.2.1.1.6.$INTERFACE_ID | awk -F: '{print $NF}' | tr -d '"')
    
    # Ottengo interfaccia neighbour
    NEIGHBOR_INTERFACE=$(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.4.1.9.9.23.1.2.1.1.7.$INTERFACE_ID | awk -F: '{print $NF}' | tr -d '"')
    
    # Ottengo interfaccia locale VS neighbour
    CONNECTED_INTERFACE=$(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.4.1.9.9.23.1.1.1.1.6.$INTERFACE_ID | awk -F: '{print $NF}' | tr -d '"')
    
    # Ottengo ALIAS interfaccia locale VS neighbour
    ALIAS_INTERFACE=$(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.2.1.31.1.1.1.18.$INTERFACE_ID | awk -F: '{print $NF}' | tr -d '"')
    
    # Ottengo la data dell'ultima modifica dell'interfaccia
    LAST_CHANGE=$(snmpwalk -v2c -c "$COMUNITY" "$TARGET_IP" 1.3.6.1.4.1.9.9.23.1.2.1.1.24.$INTERFACE_ID | awk '{print $5 " giorni, " $7 " ore fa"}' | tr -d '"')
    
    # Stampo risultati
    RESULT="$RESULT <br>Nome Apparato Neighbour: <b>$NEIGHBOR_NAME</b>"
    RESULT="$RESULT <br>Indirizzo IP Neighbour: $NEIGHBOR_IP"
    RESULT="$RESULT <br>Interfaccia Neighbour: $NEIGHBOR_INTERFACE"
    RESULT="$RESULT <br>Interfaccia locale VS Neighbour: $CONNECTED_INTERFACE"
    RESULT="$RESULT <br>Alias interfaccia locale VS Neighbour: $ALIAS_INTERFACE"
    RESULT="$RESULT <br>Ultima modifica effettuata: $LAST_CHANGE"
    RESULT="$RESULT <br>-------------------"
done

RESULT=$(echo "${RESULT//$'\n'/<br />}")
echo $RESULT
exit 0