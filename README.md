# Toolbox Sysadmin & PenTest

> Documento master per consultazione rapida. Usa `CTRL+F` cercando il comando (`dig`, `ss`, `ffuf`) oppure l'esigenza operativa (`record inverso`, `porte in ascolto`, `directory web`, `filesystem pieno`).

**Scope:** usare le sezioni offensive solo in laboratorio, CTF, ambienti propri o attivitÃ  autorizzate. La toolbox è pensata per amministrazione, troubleshooting, hardening e test di sicurezza autorizzati.

---

# 00 - Come usare questo file

## Ricerca rapida consigliata

Cerca per:

- **nome comando:** `dig`, `ffuf`, `ss`, `lsblk`, `hydra`, `smbclient`
- **problema:** `filesystem pieno`, `porte in ascolto`, `record inverso`, `directory web`, `share SMB`, `processo`
- **protocollo:** `DNS`, `SMB`, `NetBIOS`, `SMTP`, `NFS`, `SNMP`, `ARP`, `HTTP`
- **fase operativa:** `enumerazione`, `scansione`, `fuzzing`, `post-exploitation`, `troubleshooting`

## Convenzione sezioni comando

Ogni comando dovrebbe seguire questo schema:

```text
Comando
A cosa serve
Sintassi base
Esempi rapidi
Quando usarlo
Note operative
Tag ricerca
```

---

# 01 - Cookbook operativo: devo fare X

Questa è la sezione da usare quando non ricordi il comando ma ricordi cosa devi ottenere.

## Linux / processi / shell

| Devo fare... | Comando rapido | Note |
|---|---|---|
| mandare un comando in background | `comando &` | Resta agganciato alla shell corrente |
| vedere i job della shell | `jobs` | Mostra job sospesi/background |
| riportare un job in foreground | `fg %1` | `%1` è il numero del job |
| riprendere un job in background | `bg %1` | Utile dopo `CTRL+Z` |
| cercare un processo per nome | `ps -fC nome_processo` | Alternativa pulita a `ps aux \| grep` |
| rieseguire un comando ogni N secondi | `watch -n 5 comando` | Default: 2 secondi |
| creare un alias | `alias ll='ls -lah'` | Valido nella shell corrente o nel profilo |
| rimuovere un alias | `unalias ll` | Rimuove alias corrente |

## File, dati e spazio disco

| Devo fare... | Comando rapido | Note |
|---|---|---|
| confrontare due file | `diff file1 file2` | Mostra differenze riga per riga |
| confrontare file ordinati su 3 colonne | `comm file1 file2` | Richiede file ordinati |
| capire quali directory pesano di piÃ¹ | `du -xh /var --max-depth=1 \| sort -hr` | Prima scelta su filesystem pieno |
| vedere lo spazio dei filesystem | `df -h` | Mostra spazio montato, non singole directory |
| vedere dischi, partizioni e mountpoint | `lsblk -f` | Utile per storage/fstab |
| cercare testo nei file | `rg -i "testo" .` | Migliore di `grep -R` per appunti e repo |

## Networking e porte

| Devo fare... | Comando rapido | Note |
|---|---|---|
| vedere porte TCP in ascolto | `ss -tlpn` | Include PID/processo se permessi adeguati |
| vedere socket TCP connessi e in ascolto | `ss -tapn` | Vista client/server |
| testare una porta TCP remota | `nc -vz host porta` | Test rapido di reachability TCP |
| aprire un listener TCP locale | `nc -l -v -p 4444` | Utile in laboratorio e diagnostica |
| inviare una richiesta HTTP grezza | `printf 'GET / HTTP/1.0\r\n\r\n' \| nc -C host 80` | `-C` aggiunge terminatori CRLF |
| sniffare traffico DHCP/BOOTP | `tcpdump -ni eth0 'udp port 67 or udp port 68'` | Debug assegnazione IP |

## DNS

| Devo fare... | Comando rapido | Note |
|---|---|---|
| interrogare un record specifico | `dig dominio TIPO` | Esempio: `dig example.com MX` |
| interrogare usando un DNS specifico | `dig @8.8.8.8 example.com A` | Bypassa resolver locale |
| ottenere solo il valore | `dig +short example.com A` | Output pulito per script |
| fare reverse lookup/PTR | `dig -x 8.8.8.8` | Risoluzione inversa IP â†’ nome |
| usare nslookup per record specifico | `nslookup -type=MX example.com` | Alternativa classica |
| usare host per query rapida | `host -t ns example.com` | Molto leggibile |
| tentare zone transfer autorizzato | `host -l dominio dns_server` | Solo dove autorizzato |
| enumerare DNS con dnsrecon | `dnsrecon -d dominio -t axfr` | Verifica AXFR |
| enumerare DNS con dnsenum | `dnsenum dominio` | Ricognizione DNS |

## Network discovery / enumeration

| Devo fare... | Comando rapido | Note |
|---|---|---|
| fare host discovery con nmap | `nmap -sn rete/CIDR` | Ping sweep/host discovery |
| fare scansione molto veloce porta 80 | `masscan -p80 192.168.3.0/24` | Attenzione al rate |
| scansione ARP in LAN | `arp-scan --interface=eth0 --localnet` | Funziona solo nel dominio L2 |
| cercare host SNMP con community | `onesixtyone -c community.txt -i ip-list.txt` | Enumerazione SNMP |
| enumerare RPC/portmapper | `rpcinfo -p target` | Utile per NFS/RPC |
| vedere export NFS | `showmount -e target` | Dipende da RPC/NFS |

## Web / HTTP / fuzzing

| Devo fare... | Comando rapido | Note |
|---|---|---|
| enumerare directory web con ffuf | `ffuf -w wordlist.txt:FUZZ -u http://TARGET/FUZZ` | Fuzzing directory |
| cercare estensioni web | `ffuf -w web-extensions.txt:FUZZ -u http://TARGET/indexFUZZ` | Esempio: `.php`, `.html`, `.aspx` |
| fuzzing ricorsivo controllato | `ffuf -w wordlist.txt:FUZZ -u http://TARGET/FUZZ -recursion -recursion-depth 1 -e .php -v` | Limitare sempre profonditÃ  |
| enumerare sottodomini HTTP | `ffuf -w subdomains.txt:FUZZ -u https://FUZZ.example.com/` | Utile per vhost/subdomain |
| enumerare directory con gobuster | `gobuster dir -e -u http://TARGET -w wordlist.txt -x html,php,txt` | Alternativa a ffuf |
| enumerare directory con dirb | `dirb http://TARGET wordlist.txt -X .html,.php` | Classico su Kali |
| fingerprint web server | `httprint -h TARGET -s signatures.txt` | Fingerprint oltre banner |
| test SQL injection con sqlmap | `sqlmap -u 'URL' --dbs` | Solo su target autorizzati |

## SMB / NetBIOS / Windows enumeration

| Devo fare... | Comando rapido | Note |
|---|---|---|
| risoluzione NetBIOS inversa | `nmblookup -A IP` | Linux |
| interrogare NetBIOS da Windows | `nbtstat -A IP` | Windows |
| scansionare NetBIOS | `nbtscan -v IP_o_rete` | Linux |
| elencare share SMB anonime | `smbclient -L //IP -N` | `-N` senza password |
| accedere a una share SMB | `smbclient //IP/SHARE` | Client interattivo SMB |
| enumerare SMB/RPC automaticamente | `enum4linux IP` | Wrapper comodo |
| enumerare servizi Windows | `sc query type= service state= all` | Windows |
| interrogare info Windows via WMI | `wmic process list` | Legacy ma utile |

## Metasploit

| Devo fare... | Comando rapido | Note |
|---|---|---|
| verificare DB Metasploit | `db_status` | Da console msfconsole |
| inizializzare DB | `msfdb init` | Setup DB |
| lanciare nmap salvando nel DB | `db_nmap <opzioni> target` | Popola host/services |
| vedere host trovati | `hosts` | Usa DB Metasploit |
| aggiungere host a RHOSTS | `hosts -R` | Imposta target da DB |
| vedere servizi trovati | `services` | Usa DB Metasploit |
| verificare modulo senza exploit | `check` | Non supportato da tutti i moduli |
| vedere target modulo | `show targets` | Dopo `use modulo` |

---

# 02 - Linux base e shell

Questa sezione è volutamente compatta: un solo blocco per argomento, con comandi in tabella. Gli approfondimenti lunghi vanno nelle sezioni dedicate, non sotto ogni comando.

## Job control, processi e alias

| Comando | Uso rapido | Note |
|---|---|---|
| `comando &` | esegue un comando in background | resta legato alla shell corrente |
| `jobs` | mostra i job della shell | utile dopo `CTRL+Z` o `&` |
| `fg %1` | riporta il job 1 in foreground | `%1` è l'ID del job |
| `bg %1` | riprende il job 1 in background | utile per job sospesi |
| `ps -fC nome_processo` | cerca un processo per nome | piÃ¹ pulito di `ps aux \| grep` |
| `watch -n 5 comando` | riesegue un comando ogni 5 secondi | senza `-n`, default 2 secondi |
| `alias ll='ls -lah'` | crea un alias | persistente solo se salvato nel profilo shell |
| `unalias ll` | rimuove un alias | vale per la sessione corrente |

**Tag ricerca:** `processi`, `jobs`, `background`, `foreground`, `watch`, `ps`, `alias`.

## Zsh: globbing e zmv

| Obiettivo | Comando | Note |
|---|---|---|
| elencare solo file normali | `ls *(.)` | esclude directory |
| elencare solo file eseguibili | `ls *(*)` | glob qualifier zsh |
| escludere link simbolici | `ls *(-.)` | file reali, non symlink |
| trovare link interrotti | `ls *(-@)` | utile per cleanup |
| rinominare `.jpeg` in `.jpg` | `zmv '(*).jpeg' '$1.jpg'` | richiede modulo `zmv` |
| spostare `*-backup.*` in `backup/` | `zmv '(*)-backup.(*)' 'backup/$1.$2'` | rinomina massiva |

**Nota:** `zmv` puÃ² essere distruttivo se usato male. Prima di lanciare rinomine massive, prova con pochi file o usa opzioni di dry-run se disponibili.

**Tag ricerca:** `zsh`, `globbing`, `zmv`, `rename`, `symlink`, `link interrotti`.

---

# 03 - File, dati e ricerca

## Confronto file e ricerca testuale

| Obiettivo | Comando | Note |
|---|---|---|
| confrontare due file | `diff file_1 file_2` | mostra differenze riga per riga |
| confrontare file ordinati su 3 colonne | `comm file_1 file_2` | colonne: solo file1, solo file2, comuni |
| cercare testo nella directory corrente | `rg "PTR"` | ripgrep è rapido e leggibile |
| cercare ignorando maiuscole/minuscole | `rg -i "porta tcp"` | utile per appunti non uniformi |
| mostrare numero riga | `rg -n "dig"` | comodo per file lunghi |
| cercare solo nei Markdown | `rg "dns" -g "*.md"` | limita il rumore |
| escludere directory | `rg "password" -g '!node_modules' -g '!venv'` | utile in repo/progetti |
| cercare piÃ¹ concetti | `rg -i "ptr\|reverse lookup\|record inverso"` | usa regex |
| cercare stringa letterale | `rg -F "bash -i >& /dev/tcp"` | evita interpretazione regex |
| cercare da PowerShell senza rg | `Get-ChildItem -Recurse -Include *.md,*.txt \| Select-String -Pattern "PTR","reverse lookup"` | fallback Windows |

## Installazione ripgrep su Windows

```powershell
winget install BurntSushi.ripgrep.MSVC
```

**Tag ricerca:** `diff`, `comm`, `rg`, `ripgrep`, `grep`, `ricerca`, `markdown`, `Select-String`.

---

# 04 - Storage e filesystem

## Spazio disco, filesystem e device

| Obiettivo | Comando | Note |
|---|---|---|
| vedere spazio filesystem montati | `df -h` | mostra spazio usato/libero dei mount |
| peso totale directory | `du -sh /var/log` | output sintetico |
| peso primo livello directory | `du -h --max-depth=1 /var` | utile per capire dove scavare |
| ordinare directory per dimensione | `du -h --max-depth=1 /var \| sort -hr` | prima scelta su filesystem pieno |
| restare nello stesso filesystem | `du -xh /var \| sort -hr \| head -20` | `-x` evita mount esterni |
| file cancellati ma ancora aperti | `lsof +L1` | quando `df` e `du` non tornano |
| vedere dischi e partizioni | `lsblk` | vista base device |
| vedere filesystem/UUID | `lsblk -f` | utile per `/etc/fstab` |
| colonne storage utili | `lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,UUID` | troubleshooting |
| modello e seriale disco | `lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,MOUNTPOINT` | inventario/storage |
| output JSON | `lsblk -J` | utile per script |
| UUID e filesystem | `blkid` | alternativa/integrazione a `lsblk -f` |
| lista partizioni | `fdisk -l` | richiede privilegi |
| LVM physical volumes | `pvs` | ambiente LVM |
| LVM volume groups | `vgs` | ambiente LVM |
| LVM logical volumes | `lvs` | ambiente LVM |

**Nota:** `lsblk` mostra struttura dei device; `df -h` mostra spazio dei filesystem montati; `du` mostra peso reale di file/directory. Se i numeri non tornano, spesso c'è un file cancellato ma ancora aperto da un processo. Linux non butta niente: lo tiene in ostaggio finchÃ© il processo non molla la presa.

**Tag ricerca:** `du`, `df`, `lsblk`, `spazio disco`, `filesystem pieno`, `directory pesanti`, `lsof`, `lvm`, `uuid`, `fstab`.

---

# 05 - Networking operativo

## Socket, porte e connessioni

| Obiettivo | Comando | Note |
|---|---|---|
| porte TCP in ascolto | `ss -tlpn` | include processo/PID se permessi adeguati |
| socket TCP/UDP in ascolto | `ss -tulpen` | vista completa listening |
| TCP ascolto + connessioni | `ss -tapn` | client/server insieme |
| test porta TCP remota | `nc -vz host porta` | reachability rapida |
| client TCP generico | `nc host 80` | utile per test manuali |
| richiesta HTTP grezza | `printf 'GET / HTTP/1.0\r\n\r\n' \| nc -C host 80` | `-C` aggiunge CRLF |
| listener TCP locale | `nc -l -v -p 4444` | diagnostica/lab |
| client TCP con socat | `echo -en "GET / HTTP/1.0\r\n\r\n" \| socat - TCP4:localhost:80` | `-` indica STDIN/STDOUT |
| server TCP minimale | `socat TCP4-LISTEN:4444 STDOUT` | stampa su STDOUT |
| port forwarder TCP | `socat TCP4-LISTEN:8080,fork TCP4:server_remoto:80` | inoltra traffico locale â†’ remoto |

## Opzioni ss piÃ¹ usate

| Opzione | Significato |
|---|---|
| `-t` | TCP |
| `-u` | UDP |
| `-l` | listening |
| `-p` | processo associato |
| `-n` | non risolve nomi/porte |
| `-a` | tutte le socket |

**Nota su `nc -e`:** alcune versioni lo supportano, altre no. Dove presente, collega STDIN/STDOUT di un programma alla connessione. Ãˆ una lama senza manico: utile in laboratorio, pessima idea in produzione.

**Tag ricerca:** `ss`, `netstat`, `nc`, `netcat`, `socat`, `porte`, `socket`, `listener`, `port forward`.

---

# 06 - DNS

## Record DNS principali

| Record | Significato | Uso |
|---|---|---|
| `A` | hostname â†’ IPv4 | risoluzione base IPv4 |
| `AAAA` | hostname â†’ IPv6 | risoluzione base IPv6 |
| `NS` | name server autorevoli | delega/autoritÃ  zona |
| `MX` | mail exchanger | server di posta del dominio |
| `PTR` | IP â†’ hostname | reverse DNS lookup |
| `CNAME` | alias verso altro nome DNS | alias DNS |
| `TXT` | testo/policy/verifiche | SPF, DKIM, DMARC, verifiche provider |

## Query DNS operative

| Obiettivo | Comando | Note |
|---|---|---|
| interrogare record specifico con dig | `dig example.com A` | sostituisci `A` con `MX`, `TXT`, ecc. |
| usare DNS specifico | `dig @8.8.8.8 example.com MX` | bypass resolver locale |
| output sintetico | `dig +short example.com TXT` | comodo per script |
| reverse lookup PTR | `dig -x 8.8.8.8` | IP â†’ nome |
| interrogare record con nslookup | `nslookup -type=MX example.com` | alternativa classica |
| query NS con host | `host -t ns example.com` | output leggibile |
| zone transfer autorizzato | `host -l example.com ns1.example.com` | solo se autorizzato |
| verifica AXFR con dnsrecon | `dnsrecon -d example.com -t axfr` | enumerazione DNS |
| enumerazione DNS con dnsenum | `dnsenum example.com` | ricognizione DNS |

**Tag ricerca:** `dns`, `dig`, `nslookup`, `host`, `ptr`, `record inverso`, `zone transfer`, `axfr`, `dnsrecon`, `dnsenum`.

---

# 07 - BOOTP, DHCP e boot di rete

## Concetto rapido

BOOTP, Bootstrapping Protocol, è un protocollo storico usato per assegnare informazioni di rete a un host durante l'avvio. Ãˆ il predecessore concettuale di DHCP: DHCP aggiunge lease, rinnovo automatico, assegnazione dinamica e piÃ¹ opzioni.

## Porte e debug

| Obiettivo | Comando / valore | Note |
|---|---|---|
| porta server BOOTP/DHCP | `UDP 67` | server side |
| porta client BOOTP/DHCP | `UDP 68` | client side |
| sniffare traffico DHCP/BOOTP | `tcpdump -ni eth0 'udp port 67 or udp port 68'` | debug discovery/request/offer |
| filtro tcpdump BOOTP | `tcpdump -ni eth0 -vvv 'bootp'` | output piÃ¹ verboso |

## Differenza BOOTP / DHCP

| Aspetto | BOOTP | DHCP |
|---|---|---|
| assegnazione IP | tipicamente statica | dinamica o statica |
| lease | non previsto come in DHCP | previsto |
| uso moderno | legacy/appliance/casi particolari | standard attuale |
| flessibilitÃ  | bassa | alta |
| ambito tipico | boot remoto | configurazione IP generale |

**Tag ricerca:** `bootp`, `dhcp`, `pxe`, `boot`, `udp 67`, `udp 68`, `network boot`.

---

# 08 - Network discovery ed enumerazione servizi

| Obiettivo | Comando | Note |
|---|---|---|
| host discovery con nmap | `nmap -sn 192.168.1.0/24` | no port scan completo |
| scansione veloce porta 80 | `masscan -p80 192.168.3.0/24` | controllare sempre rate e scope |
| masscan con rate/router | `masscan -p80 192.168.5.0/24 --rate=1000 -e tap0 --router-ip 192.168.3.1` | caso routed/lab |
| discovery ARP in LAN | `arp-scan --interface=eth0 --localnet` | solo stesso segmento L2 |
| host SNMP con community | `onesixtyone -c community.txt -i ip-list.txt` | enumerazione SNMP |
| programmi RPC esposti | `rpcinfo -p target` | utile per NFS/RPC |
| export NFS | `showmount -e target` | dipende da RPC/NFS |

**Tag ricerca:** `masscan`, `arp-scan`, `onesixtyone`, `snmp`, `rpcinfo`, `showmount`, `nfs`, `nmap`, `host discovery`.

---

# 09 - Web enumeration e fuzzing

## FFUF

`ffuf` usa la parola chiave `FUZZ` come punto di sostituzione della wordlist. Se stai cercando velocitÃ  di consultazione, questa tabella basta nel 90% dei casi.

| Obiettivo | Comando | Note |
|---|---|---|
| directory fuzzing | `ffuf -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-small.txt:FUZZ -u http://TARGET/FUZZ` | enum directory |
| directory fuzzing con porta | `ffuf -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-small.txt:FUZZ -u http://TARGET:PORT/FUZZ` | target con porta non standard |
| trovare estensione web | `ffuf -w /usr/share/seclists/Discovery/Web-Content/web-extensions.txt:FUZZ -u http://TARGET/blog/indexFUZZ` | cerca `.php`, `.html`, `.aspx`, ecc. |
| fuzzing file dopo estensione | `ffuf -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-small.txt:FUZZ -u http://TARGET/blog/FUZZ.php` | esempio con PHP |
| recursive fuzzing | `ffuf -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-small.txt:FUZZ -u http://TARGET/FUZZ -recursion -recursion-depth 1 -e .php -v` | limitare profonditÃ  |
| subdomain fuzzing | `ffuf -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt:FUZZ -u https://FUZZ.example.com/` | enum subdomain/vhost |
| match status code | `ffuf -w wordlist.txt:FUZZ -u http://TARGET/FUZZ -mc 200,204,301,302,307,401,403` | filtra risposte interessanti |
| escludere size risposta | `ffuf -w wordlist.txt:FUZZ -u http://TARGET/FUZZ -fs 1234` | elimina falso positivo ricorrente |
| output JSON | `ffuf -w wordlist.txt:FUZZ -u http://TARGET/FUZZ -o ffuf-output.json -of json` | utile per parsing/report |

### Opzioni FFUF utili

| Opzione | Uso |
|---|---|
| `-w file:FUZZ` | wordlist associata alla keyword |
| `-u URL/FUZZ` | punto da fuzzare |
| `-recursion` | abilita ricorsione |
| `-recursion-depth N` | limita profonditÃ  |
| `-e .php,.txt` | aggiunge estensioni |
| `-v` | mostra URL completo |
| `-mc` | match HTTP status code |
| `-fs` | filtra per response size |
| `-o file -of json` | salva output |

## Altri tool web

| Tool | Comando | Note |
|---|---|---|
| gobuster | `gobuster dir -e -u http://TARGET -w /usr/share/wordlists/dirbuster/directory-list-1.0.txt -x html,php,txt` | directory enumeration |
| dirb | `dirb http://TARGET /usr/share/wordlists/dirbuster/directory-list-2.3-small.txt -X .html,.php` | enum classica |
| httprint | `httprint -h TARGET -s signatures.txt` | fingerprint web server |

## sqlmap

| Obiettivo | Comando | Note |
|---|---|---|
| database discovery | `sqlmap -u 'URL' --dbs` | elenco database |
| usare cookie | `sqlmap -u 'URL' --cookie 'SESSION=valore' --dbs` | sessioni autenticate autorizzate |
| tabelle DB | `sqlmap -u 'URL' -D nome_db --tables` | enum tabelle |
| colonne tabella | `sqlmap -u 'URL' -D nome_db -T nome_tabella --columns` | enum colonne |
| dump tabella | `sqlmap -u 'URL' -D nome_db -T nome_tabella --dump` | esportazione dati autorizzata |

**Tag ricerca:** `ffuf`, `fuzzing`, `directory fuzzing`, `page fuzzing`, `web enumeration`, `subdomain`, `gobuster`, `dirb`, `sqlmap`.

---

# 10 - SMB, NetBIOS e Samba

## Concetti rapidi

Samba è un'implementazione open source dei protocolli SMB/CIFS usati da Windows per condivisione file e stampanti. Permette a sistemi UNIX/Linux di agire come file server per client Windows e, se configurato, integrarsi con domini Active Directory.

| Componente | Funzione |
|---|---|
| `smbd` | SMB/CIFS, file sharing, stampanti, autenticazione |
| `nmbd` | NetBIOS over IP, nomi NetBIOS, browse service |

| Porta | Servizio |
|---|---|
| `137/UDP` | NetBIOS Name Service |
| `138/UDP` | NetBIOS Datagram Service |
| `139/TCP` | SMB over NetBIOS |
| `445/TCP` | SMB diretto su TCP |

## Comandi SMB/NetBIOS

| Obiettivo | Comando | Note |
|---|---|---|
| risoluzione NetBIOS inversa Linux | `nmblookup -A 192.168.56.240` | nomi NetBIOS da IP |
| risoluzione NetBIOS inversa Windows | `nbtstat -A 192.168.56.240` | equivalente Windows |
| scansione NetBIOS di rete | `nbtscan -v 192.168.56.0/24` | enum rete |
| elencare share anonime | `smbclient -L //192.168.0.101 -N` | `-N` senza password |
| elencare share forzando NT1 | `smbclient -L \\192.168.56.240 --option='client min protocol=NT1'` | legacy SMB |
| accedere a share | `smbclient //192.168.56.240/SharedDocs` | shell interattiva SMB |
| enum automatica | `enum4linux 192.168.56.240` | wrapper SMB/NetBIOS/RPC |

## Codici NetBIOS utili

| Codice | Significato |
|---|---|
| `<00>` | nome host NetBIOS |
| `<03>` | Messenger service |
| `<20>` | file sharing / SMB server |
| `<1D>` | master browser workgroup |
| `<1E>` | browser election/workgroup |

**Nota sicurezza:** controllare share pubbliche, permessi filesystem, guest access, vecchi protocolli SMB, credenziali deboli.

**Tag ricerca:** `samba`, `smb`, `cifs`, `netbios`, `smbclient`, `enum4linux`, `nmblookup`, `nbtstat`, `nbtscan`, `share`.

---

# 11 - Windows enumeration

## WMIC, servizi e PsTools

| Obiettivo | Comando | Note |
|---|---|---|
| utenti e SID | `wmic useraccount get name,sid` | mapping utenti/SID |
| SID di uno specifico utente | `wmic useraccount where name='username' get sid` | filtro per nome |
| nome da SID | `wmic useraccount where sid="S-1-5-21-...-1014" get name` | reverse mapping |
| processi | `wmic process list` | legacy ma utile |
| servizi | `wmic service list` | enum servizi |
| query servizi | `sc query type= service state= all` | servizi Windows |
| cercare servizio | `sc query type= service state= all \| find /i "SERVICE_NAME:nome"` | filtro nome servizio |
| SID servizio | `sc.exe showsid nome_servizio` | SID associato al servizio |
| info host remoto | `psinfo \\targetname` | PsTools |
| servizi remoti | `psservice \\targetname` | PsTools |
| shell remota autorizzata | `psexec \\targetname cmd` | richiede privilegi |

## Prerequisiti comuni PsTools

| Requisito | Note |
|---|---|
| `135/TCP` | RPC endpoint mapper |
| `445/TCP` | SMB |
| `Admin$` e `IPC$` | share amministrative |
| credenziali amministrative | richieste per molte operazioni |

**Tag ricerca:** `windows`, `wmic`, `sc.exe`, `pstools`, `psexec`, `servizi`, `sid`, `admin$`, `ipc$`.

---

# 12 - SMTP, RPC, NFS e servizi specifici

| Servizio | Obiettivo | Comando / uso | Note |
|---|---|---|---|
| SMTP | verificare utente con VRFY | `VRFY user@example.local` | molti server lo disabilitano |
| Finger | info utente locale | `finger username` | servizio raro/legacy |
| Finger | info utente remoto | `finger username@host` | dipende dal servizio attivo |
| Finger | utenti host | `finger @host` | possibile user enumeration |
| RPC | programmi registrati | `rpcinfo -p target` | portmapper |
| NFS | export disponibili | `showmount -e target` | enum export |
| NFS | client e directory montate | `showmount -a target` | vista accessi |
| NFS | directory esportate | `showmount -d target` | riepilogo export |

## Risposte SMTP VRFY tipiche

| Risposta | Significato indicativo |
|---|---|
| `252 2.0.0 user@example.local` | utente probabilmente accettato/verificabile |
| `550 5.1.1 <utente@example.local>: Recipient address rejected` | utente rifiutato/non esistente |

**Tag ricerca:** `smtp`, `vrfy`, `finger`, `rpc`, `portmapper`, `nfs`, `showmount`.

---

# 13 - Password attack tools autorizzati

Usare solo su sistemi autorizzati, lab o CTF. Qui ha senso la forma tabellare perchÃ© serve ricordare rapidamente opzioni e moduli.

## Hydra e Medusa

| Obiettivo | Comando | Note |
|---|---|---|
| SSH utente singolo + password list | `hydra -l musa -P /home/kali/Downloads/password.lst ssh://172.16.4.16` | esempio lab |
| HTTP POST form | `hydra -l fatima -P /home/kali/Downloads/password.lst 172.16.4.16 http-post-form "/path/al/form:username=^USER^&password=^PASS^:Login errata"` | il terzo campo è il messaggio di fallimento |
| FTP con Medusa | `medusa -h 172.16.4.16 -u hassan -P /home/kali/Downloads/password.lst -M ftp` | modulo FTP |

## Opzioni Hydra

| Opzione | Uso |
|---|---|
| `-l` | utente singolo |
| `-L` | file utenti |
| `-p` | password singola |
| `-P` | file password |
| `-C` | file `login:password` |
| `-M` | file host per attacco parallelo |
| `-f` | interrompe al primo match |
| `-R` | riprende sessione `.restore` |

**Tag ricerca:** `hydra`, `medusa`, `password attack`, `bruteforce`, `ssh`, `ftp`, `http-post-form`.

---

# 14 - Metasploit

## Console e database

| Obiettivo | Comando | Note |
|---|---|---|
| stato database | `db_status` | da `msfconsole` |
| inizializzare DB | `msfdb init` | setup database |
| nmap integrato nel DB | `db_nmap -sV target` | popola host/services |
| elencare host | `hosts` | usa DB Metasploit |
| aggiungere host a RHOSTS | `hosts -R` | imposta target da DB |
| pulire host dal DB | `hosts -D` | attenzione: cancella dati |
| elencare servizi | `services` | servizi rilevati |
| pulire servizi dal DB | `services -d` | attenzione: cancella dati |
| check modulo | `check` | non supportato da tutti i moduli |
| mostrare target modulo | `show targets` | dopo `use modulo` |

## WMAP

| Obiettivo | Comando | Note |
|---|---|---|
| caricare WMAP | `load wmap` | plugin web |
| aggiungere sito | `wmap_sites -a IP` | target site |
| impostare target | `wmap_targets -t URL` | target URL |
| elencare moduli | `wmap_run -t` | moduli abilitati |
| eseguire scansione | `wmap_run -e` | scansione |
| report vulnerabilitÃ  | `wmap_vulns -l` | risultati |

**Tag ricerca:** `metasploit`, `msfconsole`, `msfdb`, `db_nmap`, `hosts`, `services`, `check`, `show targets`, `wmap`.

---

# 15 - Exploit research e privilege escalation

| Obiettivo | Comando | Note |
|---|---|---|
| cercare exploit per CVE | `searchsploit --cve CVE-YYYY-NNNN` | database Exploit-DB locale |
| cercare file SUID | `find / -perm -u=s -type f 2>/dev/null` | audit/privesc autorizzata |
| upload file con curl | `curl http://indirizzo/directory/nomefile.php --upload-file file_locale.php` | solo dove il metodo è supportato/autorizzato |

**Tag ricerca:** `searchsploit`, `exploit-db`, `cve`, `privilege escalation`, `suid`, `find`, `curl upload`.

---

# 16 - ARP spoofing / MiTM in laboratorio

## Concetto rapido

ARP spoofing/ARP poisoning consiste nell'inviare risposte ARP manipolate per far associare il MAC dell'attaccante all'IP di un altro host, tipicamente gateway o vittima. Da usare solo in laboratorio o attivitÃ  autorizzate.

## Comandi e parametri

| Obiettivo | Comando | Note |
|---|---|---|
| abilitare IP forwarding | `echo 1 > /proc/sys/net/ipv4/ip_forward` | tunable corretto Linux |
| ARP spoofing | `arpspoof -i <interfaccia> -t <target> [-r] <host>` | lab/autorizzato |
| sniffing passivo | `tcpdump -ni interfaccia` | alternativa CLI a Wireshark |
| redirect HTTP | `iptables -t nat -A PREROUTING -s 192.168.56.0/24 -p tcp --dport 80 -j REDIRECT --to-ports 10080` | lab |
| redirect HTTPS | `iptables -t nat -A PREROUTING -s 192.168.56.0/24 -p tcp --dport 443 -j REDIRECT --to-ports 10443` | TLS rende tutto piÃ¹ complesso |

## Parametri arpspoof

| Parametro | Significato |
|---|---|
| `-i` | interfaccia attestata sulla rete |
| `-t` | target/vittima |
| `-r` | poisoning bidirezionale |
| `host` | generalmente gateway o seconda vittima |

**Nota TLS:** HSTS, certificate pinning, TLS inspection policy e trust store possono impedire o rendere evidente l'intercettazione.

**Tag ricerca:** `arp poisoning`, `arpspoof`, `mitm`, `ip_forward`, `iptables`, `sslstrip`, `sslsplit`, `wireshark`, `tcpdump`.

---

# 17 - Python e pip

## pip e virtual environment

| Obiettivo | Comando | Note |
|---|---|---|
| installare pacchetto | `python3 -m pip install requests` | preferibile a `pip install` |
| installare da requirements | `python3 -m pip install -r requirements.txt` | dipendenze progetto |
| generare requirements | `python3 -m pip freeze > requirements.txt` | snapshot ambiente |
| vedere pacchetti installati | `python3 -m pip list` | elenco pacchetti |
| aggiornare pacchetto | `python3 -m pip install --upgrade pacchetto` | upgrade mirato |
| disinstallare pacchetto | `python3 -m pip uninstall pacchetto` | rimozione pacchetto |
| creare venv Linux | `python3 -m venv .venv` | ambiente isolato |
| attivare venv Linux | `source .venv/bin/activate` | shell corrente |
| creare venv Windows | `python -m venv .venv` | PowerShell/CMD |
| attivare venv PowerShell | `.\.venv\Scripts\Activate.ps1` | puÃ² richiedere ExecutionPolicy adeguata |

## Errori tipici pip

| Errore | Causa probabile | Soluzione |
|---|---|---|
| `pip: command not found` | pip non installato o non nel PATH | usare `python3 -m pip` o installare `python3-pip` |
| `Permission denied` | installazione su path di sistema | usare venv oppure `--user` |
| pacchetto installato ma non importabile | pip legato a Python diverso | usare `python -m pip` con interprete corretto |

**Tag ricerca:** `pip`, `python`, `requirements.txt`, `venv`, `moduli python`, `package manager`.

---

# 18 - Recon-ng

| Obiettivo | Comando | Note |
|---|---|---|
| clonare repository | `git clone https://github.com/lanmaster53/recon-ng.git` | sorgente GitHub |
| entrare nella directory | `cd recon-ng` | directory progetto |
| installare dipendenze | `python3 -m pip install -r REQUIREMENTS` | usa venv se possibile |

**Nota:** Recon-ng è un framework di ricognizione. La sua utilitÃ  dipende molto dai moduli configurati e dalle API key disponibili.

**Tag ricerca:** `recon-ng`, `osint`, `recon`, `requirements`, `pip`.

---

# 19 - Template per aggiungere nuovi comandi

Per evitare che il file torni a diventare un blocco di appunti disomogeneo, usa preferibilmente questa forma compatta.

## Template comando singolo

| Obiettivo | Comando | Note |
|---|---|---|
| cosa devo ottenere | `comando opzioni target` | nota operativa breve |

**Tag ricerca:** `tag1`, `tag2`, `tag3`.

## Template approfondimento

```markdown
## Nome argomento

Descrizione breve e concreta.

| Aspetto | Dettaglio |
|---|---|
| porta/protocollo | valore |
| file/config | path |
| comando utile | `comando` |

**Quando usarlo:** scenario operativo.
**Tag ricerca:** `tag1`, `tag2`, `tag3`.
```

---

# 20 - Backlog approfondimenti futuri

Da sviluppare quando aggiungerai nuovi appunti:

- Nmap: scan TCP/UDP, script NSE, output grepable/XML
- TLS: openssl s_client, test certificati, chain, SNI
- HTTP: curl avanzato, header, upload/download, proxy
- Linux logs: journalctl, rsyslog, auth.log/secure, auditd
- Active Directory: LDAP, Kerberos, DNS AD, SMB signing
- Nagios/SentiNet: macro, plugin, soglie, output parsing
- Firewall troubleshooting: iptables/nftables/firewalld
- SELinux: audit2why, audit2allow, restorecon, semanage fcontext
