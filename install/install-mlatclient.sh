#!/bin/bash
# Skript pro nainstalovani MLAT clienta

# https://discussions.flightaware.com/t/solved-post-26-the-piaware-has-been-built-without-fa-mlat-client-due-to-cx-freeze-issue/89490/3

# Nazev programu / sluzby
MLAT_NAME="mlat-client"
# Jmeno uzivatele pod kterym se spusti ADS-Bfwd
MLAT_USER="adsb"
# Cesta ke konfiguracnimu souboru
MLAT_CFG="/etc/default/${MLAT_NAME}"

# Adresa MLAT Serveru ( czadsb.cz:40147 )
MLAT_SERVER=""
# Adresa pro preposilani zpracovanych dat ( czadsb.cz:31003 | 31003)
MLAT_RESULT=""
# Format zpracovanych dat (basestation,connect | basestation,listen)
MLAT_FORMAT="basestation,connect"


# Skontroluj parametr umisteni konfiguracniho souboru a pripadne jej nacti
if [[ -n $1 ]] && [[ -s $1 ]];then
    MLAT_CFG=$1
    MLAT_FILE="true"
    # Prevezmy, prednastav uzivatele
    [ ! -z ${CZADSB_USER} ] && MLAT_USER=${CZADSB_USER}
elif [[ -n ${CFG} ]] && [[ -s ${CFG} ]];then
    MLAT_CFG=${CFG}
    MLAT_FILE="true"
    # Prevezmy, prednastav uzivatele
    [ ! -z ${CZADSB_USER} ] && MLAT_USER=${CZADSB_USER}
else
    MLAT_FILE="false"
fi
# Nasci jiz vytvorenou konfiguraci
if [[ -s ${MLAT_CFG} ]];then
    echo "* Konfigurace se nacte z \"${MLAT_CFG}\""
    . ${MLAT_CFG}
fi

# Over prava na uzivatele root
[ -z ${SUDO} ] && SUDO=""
if [[ "$(id -u)" != "0" ]] && [[ ${SUDO} == "" ]];then
    echo "ERRROR: Instalaci je nutne spustit pod uzivatele root nebo z root pravy !"
    echo
    exit 3
fi

# Over a vytvor uzivatele
grep "^${MLAT_USER}:" /etc/passwd > /dev/null
if [[ "$?" == "1" ]];then
    echo "* Vytvoreni uzivatele \"${MLAT_USER}\" pro spusteni ${MLAT_NAME}"
    $SUDO adduser --system --no-create-home --shell /usr/sbin/nologin ${MLAT_USER}
else
    echo "* Uzivatel \"${MLAT_USER}\" jiz existuje"
fi

echo "* Instalace zavislosti"
echo "------------------------------------->"
$SUDO apt-get update
$SUDO apt-get install -y --no-install-suggests --no-install-recommends git python3-dev debhelper dh-python python3-setuptools
#$SUDO apt-get install -y build-essential python3-pip
#$SUDO pip3 install setuptools --break-system-packages
#$SUDO pip3 install . --break-system-packages
echo "-------------------------------------<"

echo "* Stazeni program z gitu a instalace"
echo
cd ~
$SUDO rm -rf ./mlat-client
git clone https://github.com/mutability/mlat-client.git
cd mlat-client
# pip3 install . --break-system-packages
# dpkg-buildpackage -b -uc
$SUDO ./setup.py install
cd ..
INSTALL_FILE=$(command -v mlat-client)
if [[ "${INSTALL_FILE}" == "" ]];then
    echo "ERROR: Program mlat-client nebyl nainstalovan !"
    exit 3
fi
$SUDO rm -rf ./mlat-client
echo "-------------------------------------<"


echo
echo "* Vytvorim konfiguracni soubor pro ${MLAT_NAME}"
CONFIG_SAVE="false"
if ${MLAT_FILE} ;then
    echo "  - pouzije se ${MLAT_CFG}"
else
    echo "  - vytvori se ${MLAT_CFG}"
    if [ -e ${MLAT_CFG} ];then
        echo -n "Konfiguracni soubor ${MLAT_NAME} jiz existuje. Chcete skutecne soubor prepsat ? [a/N]";
        read X
        echo
        [ "$X" == "a" ] || [ "$X" == "y" ] && CONFIG_SAVE="true"
    else
        CONFIG_SAVE="true"
    fi
    if [ "${CONFIG_SAVE}" == "true" ];then
        $SUDO touch ${MLAT_CFG}
        $SUDO chmod 666 ${MLAT_CFG}
        echo "* Nastaveni vychozi konfigurace ${MLAT_NAME}.conf"
        /bin/cat <<EOM >${MLAT_CFG}
# Konfigurace pro MLAT client
# Oznaceni / pojmenovani prijimace (bez mezer, max 9 znaku)
STATION_NAME="${STATION_NAME}"

# Zemepisne souradnice umisteni ve stupnich
STATION_LAT="${STATION_LAT}"
STATION_LON="${STATION_LON}"
# Nadmorska vyska umisteni anteny v metrech
STATION_ALT="${STATION_ALT}"

# URL adresa a port MLAT Serveru
MLAT_SERVER="${MLAT_SERVER}"

# URL adresa a port pro preposilani zpracovanych dat
MLAT_RESULT="${MLAT_RESULT}"

# Format preposilanych zpracovanych zprav
MLAT_FORMAT="${MLAT_FORMAT}"

# Uzivatel pod kterym je sluzba spustena - NEMENIT
MLAT_USER="${MLAT_USER}"

EOM
    fi
fi


echo "* Nastaveni MLAT klienta jako sluzby"
SERVICE_FILE=/lib/systemd/system/${MLAT_NAME}.service
$SUDO touch ${SERVICE_FILE}
$SUDO chmod 777 ${SERVICE_FILE}

/bin/cat <<EOM >${SERVICE_FILE}
[Unit]
Description=MLAT client for CZ ADSB
Documentation=https://github.com/mutability/mlat-client
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=${MLAT_USER}
EnvironmentFile=${MLAT_CFG}
ExecStart=${INSTALL_FILE} --input-type dump1090 --input-connect localhost:30005 --lat \${STATION_LAT} --lon \${STATION_LON} --alt \${STATION_ALT} --server \${MLAT_SERVER} --results \${MLAT_FORMAT},\${MLAT_RESULT} --user \${STATION_NAME}
SyslogIdentifier=${MLAT_NAME}
Restart=on-failure
RestartSec=30
RestartPreventExitStatus=64

[Install]
WantedBy=multi-user.target
EOM

$SUDO chmod 644 ${SERVICE_FILE}
if [[ -z ${MLAT} ]] || [[ "${MLAT}" == "enable" ]];then
    $SUDO systemctl enable ${MLAT_NAME}.service
fi
! ${CONFIG_SAVE} && $SUDO systemctl restart ${MLAT_NAME}.service
echo "Instalace MLAT klienta ukoncena"
echo "Umisteni skriptu: ${INSTALL_FILE}"
if ${CONFIG_SAVE};then
    echo "Nastavte konfiguracni soubor: ${MLAT_CFG}"
else
    echo "Umisteni konfigurace: ${MLAT_CFG}"
fi
echo
