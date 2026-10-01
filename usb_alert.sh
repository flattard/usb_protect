#!/bin/bash
# Le script d'alert usb doit se trouver dans le dossier /usr/local/bin/
#cp ./usb_alert.sh /usr/local/bin/
# Il faut le rendre executable
#chmod +x /usr/local/bin/usb_alert.sh
# Il faut avoir un fichier whitelist.txt dans /etc/usb_security/ il doit contenir les lignes des périphériques de stockage USB à autoriser.
# 
# On peut visualiser les logs dans le fichier /var/log/usb_security.log
#tail -f /var/log/usb_security.log
# Et on peut visualiser les disques en temps réel
#watch -n 0.1 lsblk

USB_PARENT="/sys$1" # Stocke le chemin de la clé transmis par udev

while [ "$USB_PARENT" != "/" ]; do # Boucle pour remonter l'arborescence des dossiers
    if [ -f "${USB_PARENT}/authorized" ]; then # Si le fichier de contrôle du port existe
        USB_PORT=$(/usr/bin/basename "$USB_PARENT") # Isole le nom du port USB parent
        break # Quitte la boucle : port trouvé
    fi
    USB_PARENT=$(/usr/bin/dirname "$USB_PARENT") # Passe au dossier parent supérieur
done

VENDOR="${ID_VENDOR:-${ID_VENDOR_ID:-No_VENDOR}}" # Lit la marque (ou valeur par défaut)
MODEL="${ID_MODEL:-${ID_MODEL_ID:-No_MODEL}}" # Lit le modèle (ou valeur par défaut)
SERIAL="${ID_SERIAL:-${ID_SERIAL_SHORT:-No_SERIAL}}" # Lit le numéro de série (ou valeur par défaut)
USB_ACTUEL="${VENDOR} ${MODEL} ${SERIAL}" # Crée la ligne d'identification de la clé

if /usr/bin/grep -Fxq "$USB_ACTUEL" "/etc/usb_security/whitelist.txt"; then # Cherche la clé dans la liste blanche
    # Clé autorisée : écrit l'autorisation dans les logs
    echo "$(/usr/bin/date '+%Y-%m-%d %H:%M:%S') - ALLOWED $USB_PORT: $USB_ACTUEL" >> /var/log/usb_security.log
else
    # Clé interdite : envoie une alerte réseau SNMP au SOC
    /usr/bin/snmptrap -v 2c -c public localhost "" 1.3.6.1.4.1.9999.1 1.3.6.1.4.1.9999.1.1 s "Stockage USB non autorisé connecté sur ${USB_PORT}: ${USB_ACTUEL}"

    echo 0 > "${USB_PARENT}/authorized" # Coupe l'accès matériel au port USB
    # Écrit le blocage de l'intrus dans les logs
    echo "$(/usr/bin/date '+%Y-%m-%d %H:%M:%S') - UNALLOW & BLOCKED $USB_PORT: $USB_ACTUEL" >> /var/log/usb_security.log
fi

