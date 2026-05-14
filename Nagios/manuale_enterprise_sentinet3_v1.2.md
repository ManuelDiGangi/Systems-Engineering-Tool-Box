# Manuale Operativo - Gestione Enterprise Sentinet3

## Introduzione
La gestione Enterprise in Sentinet3 consente di centralizzare il monitoraggio di piÃ¹ istanze remote tramite una **Master Console**.  
Questa funzionalitÃ  Ã¨ disponibile tramite l'acquisto di un modulo aggiuntivo.

---

## 1. Configurazione della Connessione Enterprise

### 1.1 Aggiunta Sentinet3 Remoto
Per configurare una nuova connessione:

1. Accedere alla **Master Console**
2. Navigare in:
   - `Configurazione`
   - `Enterprise`
3. Selezionare **Nuova Connessione**
4. Inserire i dati del Sentinet3 remoto:
   - Indirizzo IP / Hostname
   - Credenziali di accesso
   - Parametri richiesti

5. Salvare la configurazione

---

## 2. Gestione dei Sistemi Remoti

Una volta configurata la connessione:

- La gestione operativa resta **sul Sentinet3 remoto**
- La Master Console fornisce una vista centralizzata **in sola lettura**

---

## 3. Esportazione degli HOST

Per esportare un HOST nella Master Console:

1. Accedere al Sentinet3 remoto
2. Modificare l'HOST desiderato
3. Abilitare il flag:

   **"Esportabile in enterprise console"**

### âš ï¸ ATTENZIONE
Un HOST sarÃ  visibile nella Master Console **solo se contiene almeno un servizio associato**.

---

## 4. Visualizzazione nella Master Console

Per rendere visibili gli HOST importati:

- Aggiungerli ad un gruppo nella Mater Console
- Per una piÃ¹ facile gestione, si consiglia di aggiungere come prefisso l'alias del Sentinet3 remoto al nome del gruppo

### Nota Bene
Dopo aver inserito l'Host in un gruppo sulla Master verificare che le modifiche siano state memorizzate, in caso contrario ripetere l'operazione

---

## 5. Esportazione delle Mappe

Per rendere esportabile una mappa:

1. Accedere al Sentinet3 remoto
2. Accedere alle proprietÃ  della mappa
3. Abilitare il flag:

   **"Esportabile in enterprise console"**

4. Accedere alla Master Console
5. Aprire il menu Mappe
6. Sincronizzare le mappe mediante l'apposito bottone **"Sincronizza Mappe"** posto in alto a destra

### Nota Bene
Gli Host presenti nelle mappe importate verranno automaticamente inseriti nel gruppo **MAP ENTERPRISE HOSTS**

---

## 6. Limitazioni della Master Console

Ãˆ importante considerare che:

- La Master Console Ã¨ **solo in lettura**
- Non Ã¨ possibile effettuare modifiche dirette su:
  - HOST
  - Servizi
  - Mappe importate

### Per modifiche:
âž¡ï¸ Accedere sempre al Sentinet3 remoto

---

## 7. Best Practice

- Verificare sempre la presenza di almeno un servizio sugli HOST esportati
- Utilizzare naming coerente per alias e gruppi
- Validare le connessioni Enterprise dopo la configurazione
- Documentare le connessioni tra Master e nodi remoti

---

## Conclusioni

La funzionalitÃ  Enterprise di Sentinet3 permette una gestione centralizzata efficace, mantenendo perÃ² la configurazione distribuita sui nodi remoti.  
Un corretto utilizzo dei flag di esportazione e una configurazione accurata garantiscono una visibilitÃ  completa e affidabile.

---
  

