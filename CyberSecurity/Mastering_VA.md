# 1 - Audit di sicurezza 
## Come migliorare questa fase

L'audito di sicurezza è una forma partricolare di scansione, non punta direttamente ed esclusivamente a verificare la presenza di debolezze/vulnerabilità, ma è orientata all'aderenza a criteri di sicurezza dettati da standard.

Standard di riferimento
* PCI-DSS
* SCAP

Criteri di sicurezza dei vendor
* MSCT

---

## PCI-DSS
E' uno standard per la sicurezza delle informazioni. la conformità è obbligatoria per tutte le organizzazioni che si occupano di dati relativi a transazioni effettuate con carte di pagamento.
Lo standard si basa su 6 principi e 12 requisiti (i quali hanno sotto-requisiti)

| Principio | Requisito |
|---|---|
| Creare e gestire una rete protetta | **Requisito 1:** installare e gestire una configurazione firewall per proteggere i dati sui titolari di carta |
|  | **Requisito 2:** non utilizzare i valori predefiniti dal produttore per password del sistema e altri parametri di protezione. |
| Proteggere i dati sui titolari di carta | **Requisito 3:** proteggere i dati sui titolari di carta presenti negli archivi |
|   | **Requisito 4:** crittografare la trasmissione dei dati sui titolari di carta sulle reti pubbliche e aperte |
| Adottare un programma di gestione delle vulnerabilità | **Requisito 5:** utilizzare e aggiornare regolarmente un software antivirus | 
|  | **Requisito 6:** sviluppare e gestire sistemi e applicazioni sicuri |
| ecc.. | ecc.. |

### Gli obblighi
Il requisito 11.2 afferma la necessità di "eseguire almeno trimestralmente scansioni di vulnerabilità delle reti interne ed esterne e dopo qualsiasi cambiamnto significativo"

|Per una scansione interna|Si deve verificare che negli ultimi 12 mesi siano state eseguite il numero minimo di scansioni e chie siano state effettuate nuove scansioni fino alla risoluzione di tutte le vulnerabilita ad alto richio (Hight e Critical)|
|Per una scasnione esterna | Deve essere eseguita da parte riconosciuta al PCI SSC|

Molti vendor offrono guide complete per applicare questo standard:
- https://docs.microsoft.com/it-it/security-updates/security/15480175#on-this-page
- https://www.oracle.com/assets/security-pci-dss-wp-078843.pdf

### Laboratorio Nessus

Queste scansioni operano in locale, pertanto in fase di configurazione è fondamentale fornire le credenziali di accesso alle macchine nel tab credential. Se la macchina non è a dominio nel campo domain indicare il nome macchina.

1. PCI-DSS Internal Scan
Di default questa scansione non prende in esame applicazioni web hostate dalla macchine, è possibile abilitare tale opzinoe dalle impostazioni della scansione. L

Defalut:
``` markdown
These settings are required to test cross-site scripting and SQL injection flaws:
Web applications tests are disabled
CGI scanning is disabled
The timeout for web application tests is 0 seconds.
```
Abilitare scanisone web app:
Settings -> Assessment -> Web Applicaiton -> ON
Application Test Settings ->
- Enable generic application tests
- Test embedded web servers

``` markdown
These settings are required to test cross-site scripting and SQL
injection flaws:
Web applications tests are enabled.
CGI scanning is enabled.
The timeout for web application tests is 300 seconds.
```

2. PCI-DSS External Scan
L'audit fallisce per tre classi di elementi:
- Rilevamento di qualsiasi vulnerabilità con un punteggio CVSS >=4
- Rilevamento di vulnerabilità XSS o SQLi
- Crittografia SSL non configurata o configurata in modo errato.

3. Usare compliance audit
Selezionando questa voce sarà possibile selezionare manualmente le base line per le quali effettuare l'adit.
Utile nel caso in cui si presenti la necessità di essere compliant a più base line.

## SCAP

E' un metodo per l'utilizzo di standard specifici per consentire la gestione automatizzata delle vulnerabilità, la misurazione e la valutazione della conformità alle politiche dei sistemi implementati nell'organizzazione.

In sostanza sono delle checklist che rendono standard il processo e consentono il collegamento automatica tra configurazioni di sicurezza dei sistemi ed il framework dei controlli della pubblciazione NIST 800-53. Offrono una versione standard delle nomenclature e dei formati utilizzabili da prodotti automatici.

**Dove trovare le chesklist** - Il National Vulnerability Database (NVD) è la fonte per i contenuti SCAP, le check list sono scaricabili dal repository ufficale: https://ncp.nist.gov/repository

**Lo scopo** - Eseguire misurazioni iniziali ed il monitoraggio continuo delle impostazinoi di sicurezza e dei controlli corrispondenti alla SP 800-53

###OpenScap
E' una libreria e strumento a riga di comando utile ad analizzare e valutare ogni componente dello standard SCAP, agisce sul sistema locale eseguendo scansinoi di configurazione e vulnerabilità.

**Quando usarlo:** scenario operativo.
**Tag ricerca:** `tag1`, `tag2`, `tag3`.
