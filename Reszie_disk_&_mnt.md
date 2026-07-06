# AUMENTO DELLO SPAZIO DISCO
Operazioni da effettuare dopo aver aumentato lo spazio disco sul virtualizzatore (Vsphere, vmware ecc..)

Tutti i comandi vanno eseguiti con sudo
---
### Aggiorna la tabella degli spazi di memoria

```
parted /dev/sda -> fix		
```

### Visualizzare il layout della partizione, serve a verificare la dimensione del disco ed il settore finale
```
print
```

Es. output
	number	start	end	size	filesystem	name
	1										sda 1
	2										sda 2
	3										sda 3

### Estensione del disco
Il comando sposta il settore finale, in questo caso gli diamo il 100% dello spazio aggiunto
```
resizepart <numero della partizione presa dalla tabella sopra> 100%	
```
### Usciamo dallo strumento parted
```
quit
```
	
### Aggiornare il Phisical Volume lvm e rendere lo spazio visibile al Volume Group
```
pvresize /dev/sda
```

### Assegnare gli extents liberi nel Volume Group al Logical Volume
Il comando varia in base alla versione di Rhel

N.B. per verificare il nome della partizione utilizzare il comando lsblk
	
**Se lo spazio va assegnato ad un nuovo mount (Es. /opt) passare alla seconda parte del file -> lvcreate -l 100%FREE -n <nome mnt> rhel
Es. lvcreate -l 100%FREE -n opt rhel**
	
####Comando 1
```
lvextend -l +100%FREE /dev/mapper/<partizione da espandere Es. rhel-root>
```
####Se il precedente comando è deprecato (sono su una nuova versione)
```
lvresizize -L +100%FREE /dev/mapper/<partizione da espandere Es. rhel-root>
```

###Espandere il File System senza smontare il mount
```
xfs_growfs <mount>  -> / per il mount root oppure /mount_di_interesse
``` 	 

---

# MANIPOLAZIONE DEI MOUNT		
										
### Copiamo tutte le home directory che ci interessa mantenere in /mnt/backup/home
```
sudo mkdir -p /mnt/backup/home
sudo rsync -aHAX --numeric-ids /path/dir_sorgente/ /path/dir_destinazione/  attenzione a mettere l'ultimo /
```

### Verifica se i file copiati sono effettivamente allineati
```
rsync -aHAXn --numeric-ids --delete /home/glide/ /mnt/backup/home/glide/
rsync -aHAXn --numeric-ids --delete /home/servicenow/ /mnt/backup/home/servicenow/
```
### Entro in modalità single user
N.B. rescue.target non cambia il target di default permanente, isola solo temporaneamente il sistema in modalità manutenzione.
```
systemctl isolate rescue.target
```
### Controllo i processi che utilizzqano ancora il mnt
```
sudo lsof /home
```
### Forzo la chiusura
```
sudo fuser -km /home
```
### Smonto ed elimino rhel-home
```
sudo umount /home
lvremove /dev/rhel/home
```
### Ricreiamo e montiamo il mnt
```
sudo lvcreate -L 15G -n home rhel
sudo mkfs.xfs /dev/rhel/home  cancella tutti i vecchi dati e crea il nuovo file system XFS
mount /home

lvcreate -l 100%FREE -n opt rhel	 # fai il mount di una directory vuota, altrimenti i file che ci sono diventeranno "invisibili"
mkfs.xfs /dev/rhel/opt
```

### Modifica il file /etc/fstab e aggiungi:
```
/dev/mapper/rhel-opt /opt xfs defaults 0 0
mount -a  	# refresha file e applica modifiche
```

### Ricreiamo le home directory dello step 2
servicenow la rimettiamo in /home
glide andrà dentro /opt
```
sudo mkdir -p /home/servicenow/
sudo mkdir -p /opt/glide/
```
		
### Copiamo i file nelle dir di destinazione
```
sudo rsync -aHAX --numeric-ids /path/dir_sorgente/ /path/dir_destinazione/  attenzione a mettere l'ultimo /
```

### Per uscire e tornare al normale avvio multiutente
```
systemctl default
```	
Oppure, scelta più pulita dopo manipolazione mount/LVM: reboot
