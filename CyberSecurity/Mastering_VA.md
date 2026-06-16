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
1. PCI-DSS Internal Scano
Di default questa scansione non prende in esame applicazioni web hostate dalla macchine, è possibile abilitare tale opzinoe dalle impostazioni della scansione.

` markdown
These settings are required to test cross-site scripting and SQL injection
flaws:
Web applications tests are disabled
CGI scanning is disabled
The timeout for web application tests is 0 seconds.
`

**Quando usarlo:** scenario operativo.
**Tag ricerca:** `tag1`, `tag2`, `tag3`.
