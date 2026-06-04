# Monitoraggio latenze in reti enterprise

In infrastrutture enterprise distribuite a livello mondiale le latenze di rete non si monitorano con un solo metodo, ma con una combinazione di monitoraggio attivo, passivo, telemetria dagli apparati, NetFlow, synthetic monitoring e correlazione con eventi di routing.

## 1. Monitoraggio attivo: probe tra sedi

Il metodo più classico  è installare dei probe/agent in ogni sede, datacenter o regione cloud.
Es:
```markdown
Milano -> Londra
Singapore -> Tokyo
...
```
Ogni probe misura periodicamente:
```markdown
ICMP latency
TCP latency
UDP jitter
packet loss
DNS response time
HTTP/S response time
traceroute/path change
```
| Punto                            | Obiettivo                         | Comando shell                                                                                                                                                          | Check Nagios/SentiNet equivalente                                                       | Cosa misura                                                                                     |
| -------------------------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1 - Probe ICMP tra sedi          | Ping con statistiche base         | `ping -c 20 10.10.10.1`                                                                                                                                                | `check_ping -H 10.10.10.1 -w 100,5% -c 200,15%`                                         | Latenza min/avg/max e packet loss                                                               |
| 1 - TCP verso servizio           | Test su porta reale               | `nc -vz -w 3 app.example.com 443`                                                                                                                                      | `check_tcp -H app.example.com -p 443 -w 0.2 -c 0.5`                                     | Tempo/riuscita connessione TCP                                                                  |
| 1 - DNS latency                  | Tempo risposta DNS                | `dig @10.10.10.53 www.example.com +stats`                                                                                                                              | `check_dns -H www.example.com -s 10.10.10.53 -w 1 -c 3`                                 | Tempo risposta DNS                                                                              |
| 1 - Path monitoring              | Analisi path + loss hop-by-hop    | `mtr -rwzc 100 10.10.10.1`                                                                                                                                             | Plugin custom basato su `mtr`/`traceroute`                                              | Latenza e packet loss per hop                                                                   |

---

## 2. Synthetic monitoring

In ambienti mondiali si usano sonde che simulano traffico reale da diverse regioni.
Es:
```markdown
Sonda Europa  -> login applicazione
Sonda USA     -> login applicazione
...
```
Misurando:
```markdown
DNS lookup time
TCP connect time
TLS handshke time
TTFB
download time
HTTP status
```
| Punto                            | Obiettivo                         | Comando shell                                                                                                                                                          | Check Nagios/SentiNet equivalente                                                       | Cosa misura                                                                                     |
| -------------------------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Synthetic HTTPS dettagliato  | Scomposizione tempi richiesta web | `curl -o /dev/null -s -w "DNS:%{time_namelookup} TCP:%{time_connect} TLS:%{time_appconnect} TTFB:%{time_starttransfer} TOTAL:%{time_total}\n" https://app.example.com` | `check_http -H app.example.com -S -u / -w 2 -c 5`                                       | `curl` separa DNS/TCP/TLS/TTFB/TOTAL; `check_http` misura soprattutto tempo totale e stato HTTP |
| Synthetic verso IP specifico | Test HTTPS forzando VIP/backend   | `curl --resolve app.example.com:443:10.10.10.20 -o /dev/null -s -w "HTTP:%{http_code} TOTAL:%{time_total}\n" https://app.example.com`                                  | `check_http -H app.example.com -I 10.10.10.20 -S -u / -w 2 -c 5`                        | Test HTTPS verso IP specifico mantenendo hostname/SNI                                           |
| Synthetic login/API          | Test transazione applicativa      | `curl -k -s -o /dev/null -w "HTTP:%{http_code} TOTAL:%{time_total}\n" -X POST -d "username=test&password=test" https://app.example.com/login`                          | `check_http -H app.example.com -S -u /login -P "username=test&password=test" -w 2 -c 5` | Tempo risposta di una POST applicativa                                                          |
| Download test                | Test throughput lato client       | `curl -o /dev/null -s -w "SIZE:%{size_download} SPEED:%{speed_download} TOTAL:%{time_total}\n" https://app.example.com/file.test`                                      | `check_http -H app.example.com -S -u /file.test -w 5 -c 10`                             | Download file e tempo totale                                                                    |

---

## 3. Telemetria degli apparati di rete

Su router, switch, firewall, SD-WAN e load balancer si raccolgono metriche come:
```markdown
interface utilization
interface errors/discards
CRC errors
queue drops
buffer drops
CPU appurato
memory
BGP/OSPF adjacency changes
route flapping
tunnel status
VPN latency
SD-WAN path score
```
Es:
```markdown
OSPF neighbor state
numero cambiamenti adjacency
route table changes
BGP session reset
SD-WAN path switch
WAN tunnel latency/jitter/loss
```
| Punto                            | Obiettivo                         | Comando shell                                                                                                                                                          | Check Nagios/SentiNet equivalente                                                       | Cosa misura                                                                                     |
| -------------------------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| | | | |
| Neighbor list | Avere visione dei neighbor dell'apparato (solo CISCO) | | |
Per i check approfondire: https://github.com/jorgeluiztaioque/nagios-router-plugin/tree/master
| Punto | Obiettivo | Comando/Check | Note |
|---|---|---|
| Probe ICMP | `ping -c 20 <ip>` | Latenza min/avg/max e  |

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
