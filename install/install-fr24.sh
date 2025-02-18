#!/bin/bash

# Skript provede instalaci fr24feed pro Flightradar24 / FR24
# Oproti ostatnim skriptum je koncipovan jen jako doplnek pro CzADSB a neleze
# jej spustet automaticky !

# Dle dokumentace puvodni postup instalace
# wget -qO- https://fr24.com/install.sh | sudo bash -s


# Konfiguracni soubor pro fr24feed
[[ -z ${FR24_CFG} ]] && FR24_CFG="/etc/fr24feed.ini"
# Nazev vlastni sluzby
[[ -z ${FR24_NAME} ]] && FR24_NAME="fr24feed"
# Cesta na originalni instalacni skript
[[ -z ${FR24_INSTALL} ]] && FR24_INSTALL="https://fr24.com/install.sh"
# Typ protokolu ADSB
[[ -z ${FR24_RECEIVER} ]] && FR24_RECEIVER="beast-tcp"
# Zdroj dat ADSB
[[ -z ${FR24_HOST} ]] && FR24_HOST="127.0.0.1:30005"
# Uroven logovani
[[ -z ${FR24_LOGLEV} ]] && FR24_LOGLEV="2"
# Cesta na log soubor
[[ -z ${FR24_LOGFIL} ]] && FR24_LOGFIL="/var/log/fr24feed"

SUDO="sudo"

# Over prava na uzivatele root
[ -z ${SUDO} ] && SUDO=""
if [[ "$(id -u)" != "0" ]] && [[ ${SUDO} == "" ]];then
    echo "ERRROR: Instalaci je nutne spustit pod uzivatele root nebo z root pravy !"
    echo
    exit 3
fi

echo "* Instalace fr24feed"
echo "------------------------------------->"
# Stahni a spust instalaci fr24feed (bez registrace -> a)
wget ${FR24_INSTALL} -O ~/install-flightradar24.sh
chmod +x ~/install-flightradar24.sh
$SUDO ~/install-flightradar24.sh -a -s adsb
rm -f ~/install-flightradar24.sh
echo "-------------------------------------<"

if [[ "${FR24_KEY}" != "" ]];then                       # Pokud je zadan key, tak nastav konfig soubor
    echo "* Nastaveni fr24feed"
    $SUDO touch ${FR24_CFG}
    $SUDO chmod 777 ${FR24_CFG}
    /bin/cat <<EOM >${FR24_CFG}
receiver="${FR24_RECEIVER}"
fr24key="${FR24_KEY}"
host="${FR24_HOST}"
bs="no"
raw="no"
#logmode="${FR24_LOGLEV}"
#logpath="${FR24_LOGFIL}"
#mpx="no"
mlat="no"
mlat-without-gps="no"
EOM

else                                                    # Pokud neni zadan key, vypis napovedu a spust registracniho pruvodce
    [[ -z ${STATION_ALT} ]] && STATION_ALT="0"
    FR24_ALT=$(( ${STATION_ALT} * 328084 / 100000 ))      # preved z m na stopy
    printf "┌────────────────────── Registrace na Flightradar24 ───────────────────────┐\n"
    printf "│ Zadali jste novou registraci na Flightradar24, ktera bude ted spustena.  │\n"
    printf "│ V prubehu registrrace budete vyzvani k zadani nasledujicich dat:         │\n"
    printf "│                                                                          │\n"
    printf "│ * Registracni ! email na Flightradar24: %-32s │\n" "${USER_EMAIL}"
    printf "│ * Na sharing key jen potvrtdime 'Enter'                                  │\n"
    printf "│ * Podilet se na odesilani MLAT dat: no                                   │\n"
    printf "│ * Souradnice umisteni prijimace Lat: %7.4f, Lon: %8.4f              │\n" "${STATION_LAT}" "${STATION_LON}"
    printf "│ * Nadmorskou vysku umisteni anteny ve stopach: %5d (feet)              │\n" "${FR24_ALT}"
    printf "│ * Overime nejblizsi zjistene letiste a pokud souhlasi potvrdime: yes     │\n"
    printf "│ * Potvrzeni autoconfigu: yes                                             │\n"
    printf "└──────────────────────────────────────────────────────────────────────────┘\n"

    $SUDO fr24feed-signup-adsb
fi
