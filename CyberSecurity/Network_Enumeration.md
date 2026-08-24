# 1 - Network enumeration
## Enumerazione NetBIOS-SMB

NetBios, è un protocollo di sessione - LISTEN TCP 139
SMB, è un procollo che ha lo scopo di condividere file, stampanti, porte seriali. (Le nuove versioni funzionano senza NetBIOS - LISTEN TCP 445

### Nmap e NetBIOS
Nmap fornisce degli script NSE collocati nella path
``` markdown
/usr/share/nmap/scripts/smb-...
```
N.B.: per effettuare un'enumerazione necessitiamo di credenziali (non amministrative), dal momento che la null session è una misconfiguration ormai rara.
 - Lab.1 - Semplice scansione
   sudo nmap -sS -sU -pT:139,T:445,U:137 <ip/range>

 - Lab.2 - Enumerazione anonima utenti
   sudo nmap -sS -p 445 --script=smb-enum-users <ip/range>

 - Lab.3 - Enumerazione utenti autenticata
   sudo nmap -sS -p 445 --script=smb-enum-user --script-args smbusername='utenteglobale', smbpassword='Pa$$word' <ip/range>

 - Lab.4 - Enumerazione anonima dei gruppi
   sudo nmap -sS - p 445 --script-enum-groups <ip/range>

 - Lab.5 - Enumerazione autenticata dei gruppi (per i DC utilizzare il -Pn in quanto non ripondono al ping)
   sudo nmap -Pn -sS -p 445 --script=smb-enum-groups --script-args smbusername='utenteglobale', smbpassword='Pa$$word' <ip/range>

- Lab.6 - Enumerazione anonima attraverso delle share di rete
  sudo nmap -sS -p 445 --script=smb-enum-shares <ip/range>

- Lab.7 - Enumerazione autenticata attraverso delle share di rete
  sudo nmap -Pn -sS -p 445 --script=smb-enum-shares --script-args smbusername='utenteglobale', smbpassword='Pa$$word' <ip/range>

- Lab.8 - Enumerazione autenticata delle sessioni
  sudo nmap -Pn - sS -p 445 --script=smb-enum-sessions --script-args smbusername='utenteglobale', smbpassword='Pa$$word' <ip/range>

---

### NFS
Tutte le versioni si basano su RPC (Remote Procedure Calls), le versioni precedenti la v4 si basano su port mapper (rpcbind), un servizio che accetta prenotazioni alle porte dei servizi, risponde alle richieste e imposta le connessioni assegnando dinamicamente le porte (per questo era un grosso problema per la configurazione di ACL firewall).
NFS v4, il servizio RPC ascolta sulla porta TCP 2049

Servizi rpc ancora richiesti
 * rpc.mountd - riceve richieste di montaggio dai client e verifica che il FS richiesto sia attualmente esportato
 * rpc.nfsd - consente la definizione di versioni e protocolli NFS espliciti che il server annuncia per soddisfare le richieste dinamiche dei client NFS
 * rpc.lockd (ormai integrato nel protocollo) - consente ai client NFS di bloccare i file (implementa Network Lock Manager)
 * rcp.statd (ormai integrato nel protocollo) - implementa il procotollo RPC Network Status Monitor, il quale notifica ai client quando un server NFS viene riavviato senza essere arrestato normalemnte
 * rpc.rqoutad - fornisce informazioni sulla qutoa utente per gli utenti remoti
 * rpc.idmapd - questo processo fornisce un servizio di mappatura tra nomi utente e UID e GID locali (principio AAA)

Nmap fornisce degli script NSE utilizzabili nell'enumerazione 
``` markdown
/usr/share/nmap/scripts/rpcinfo.nse
                        nfs-ls.nse
                        nfs-showmount.nse
                        nsf-statfs.nse
```

 - Lab.1 - identificazione host con portmapper/rpcbind
   nmap -v -p 111 -Pn <ip>

- Lab.2 - ottenere i servizi registrati
  nmap -sV -p 111 -Pn --script=rcpinfo <ip>

- Lab.3 - verificare le esportazioni (equivale al comando showmount)
  nmap -sV -p 111 -Pn --scripts=nfs-showmount <ip/range>

- Lab.4 - enumerazione dei file
  sudo nmap -sV -p 111 --script=nfs-ls <ip/range>

- Lab.5 - informazioni e statisstiche del disco
  sudo nmap -sV -p 111 --script=nfs-statfs <ip/range>

--- 

### RPC su windows
Enumerazione con RPC client, uno strumento interattivo e bach(parte non interattiva)

- Lab.1 - connessione al DC
  rpcclient -U 'utenteglobale%Pa$w0rd' <ip_target>
   'questo comando avvierà il tool dal quale sarà possibile lanciare i comandi, come ad esempio help'
  'querydominfo': otterremo info del dominio
  'enumdomuser': enumereremo gli utenti del dominio + gli utenti locali
  'enumdomgroups': enumerazione dei gruppi del dominio
  'querygroup <RID>': richiederemo informazioni dettagliate sugli utenti/gruppi
  
| Principio | Requisito |
|---|---|
| Creare e gestire una rete protetta | **Requisito 1:** installare e gestire una configurazione firewall per proteggere i dati sui titolari di carta |
|  | **Requisito 2:** non utilizzare i valori predefiniti dal produttore per password del sistema e altri parametri di protezione. |
| Proteggere i dati sui titolari di carta | **Requisito 3:** proteggere i dati sui titolari di carta presenti negli archivi |
|   | **Requisito 4:** crittografare la trasmissione dei dati sui titolari di carta sulle reti pubbliche e aperte |
| Adottare un programma di gestione delle vulnerabilità | **Requisito 5:** utilizzare e aggiornare regolarmente un software antivirus | 
|  | **Requisito 6:** sviluppare e gestire sistemi e applicazioni sicuri |
| ecc.. | ecc.. |

Defalut:
``` markdown
These settings are required to test cross-site scripting and SQL injection flaws:
Web applications tests are disabled
CGI scanning is disabled
The timeout for web application tests is 0 seconds.
```
