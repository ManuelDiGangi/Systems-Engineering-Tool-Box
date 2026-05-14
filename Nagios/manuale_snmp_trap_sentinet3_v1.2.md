# Manuale Configurazione SNMP Trap su Sentinet3

## Scopo
Questo documento descrive la procedura per configurare la gestione delle SNMP Trap su Sentinet3, includendo la creazione dell'Host, del Servizio e l'integrazione dei file MIB.

---

## 1. Creazione Host

1. Accedere alla piattaforma Sentinet3.
2. Creare un nuovo Host.
3. Inserire come indirizzo IP quello della macchina che genera le SNMP Trap.
4. Salvare la configurazione.

---

## 2. Creazione Servizio TRAP

1. Accedere alla configurazione dell'Host creato.
2. Creare un nuovo Servizio con le seguenti caratteristiche:

### Monitoraggio Attivo
- Comando: `check_dummy_general`
- Disabilitare i controlli attivi

### Monitoraggio Passivo
- Abilitare i controlli passivi

### Nome Servizio
- Nome consigliato: `TRAP`

3. Salvare la configurazione.

---

## 3. Importazione File MIB

1. Caricare il file MIB dell'apparato nel FileManager:
   ```
   /SNMP/mibs/
   ```

2. Eseguire:
   - **Salva e Applica**

3. Verificare la conversione automatica del file MIB nella directory:
   ```
   /SNMP/TrapSNMP/mibconverted/
   ```

---

## 4. Identificazione OID

1. Accedere alla cartella:
   ```
   /SNMP/TrapSNMP/mibconverted/
   ```

2. Aprire il file convertito.
3. Individuare l'OID della trap di interesse.

---

## 5. Configurazione Mapping Trap

Inserire nel file di configurazione la relazione tra OID e servizio.

### Esempio

```
EVENT linkDown .1.3.6.1.6.3.1.1.5.3 "Status Events" major
FORMAT A linkDown trap signifies that the SNMP entity, acting in $*
EXEC /bin/bash /usr/local/filemanager/Builtin/SNMP/TrapSNMP/check_snmptraphandling_passive.sh $r TRAP $s "A linkDown trap signifies that the SNMP entity, acting in $*"
```
### Descrizione campi

- **EVENT**: Nome evento e OID associato
- **FORMAT**: Descrizione della trap
- **EXEC**: Script eseguito per gestire la trap

### Nota Bene
Nel caso in cui il nome del servizio non sia TRAP, modificare la riga di comando EXEC con il nome corretto, sostituendo TRAP

---

## 6. Verifica Funzionamento

1. Inviare una SNMP Trap dal dispositivo.
2. Accedere all'Host su Sentinet3.
3. Verificare che il servizio `TRAP` venga aggiornato.
4. Controllare eventuali log di errore.

E' possibile verificare la ricezione e l'elaborazione di trap SNMP tramite l'apposito menu **Trap SNMP**

---

## Best Practice

- Utilizzare sempre nomi standard per i servizi (es. `TRAP`)
- Validare i file MIB prima dell'importazione
- Monitorare i log in caso di mancata ricezione trap
- Documentare gli OID utilizzati

---

## Riferimenti

Per ulteriori dettagli, consultare la documentazione ufficiale Fata Informatica relativa alla gestione delle SNMP Trap.
