#!/bin/bash
# Skript vytvori konfiguraci pro N2N VPN pro CzADSB

# Spousteni po startu
N2NADSB="disabled"
# Nazev programu / sluzby
N2NADSB_NAME="vpn-czadsb"
# Jmeno uzivatele pod kterym se spusti ADSBfwd 
N2NADSB_USER="adsb"
# Cesta ke konfiguracnimu souboru
N2NADSB_CFG="/etc/default/${N2NADSB_NAME}"
# Adresar pro instalaci ADSBfwd
N2NADSB_FOLDER="/opt/vpn-czadsb"

# Lokalni prirazena adresa
N2NADSB_LOCAL=""
# Maska pro lokalni sit
N2NADSB_MASK="255.255.254.0"
# Adresa n2n serveru vcetne portu
N2NADSB_SERVER="n2n.czadsb.cz:82"

# Skripty:
# vpn-czadsb
# vpn-czadsb-start
# vpn-czadsb-stop

# Skontroluj parametr umisteni konfiguracniho souboru a pripadne jej nacti
if [[ -n $1 ]] && [[ -s $1 ]];then
    N2NADSB_CFG=$1
    N2NADSB_FILE="true"
    # Prevezmy, prednastav uzivatele a instalacni adresar
    [ ! -z ${CZADSB_USER} ] && N2NADSB_USER=${CZADSB_USER}
    [ ! -z ${CZADSB_FOLDER} ] && N2NADSB_FOLDER=${CZADSB_FOLDER}
elif [[ -n ${CFG} ]] && [[ -s ${CFG} ]];then
    N2NADSB_CFG=${CFG}
    N2NADSB_FILE="true"
    # Prevezmy, prednastav uzivatele a instalacni adresar
    [ ! -z ${CZADSB_USER} ] && N2NADSB_USER=${CZADSB_USER}
    [ ! -z ${CZADSB_FOLDER} ] && N2NADSB_FOLDER=${CZADSB_FOLDER}
else
    N2NADSB_FILE="false"
fi
# Nacti jiz vytvorenou konfiguraci
if [[ -s ${N2NADSB_CFG} ]];then
    echo "* Konfigurace se nacte z \"${N2NADSB_CFG}\""
    . ${N2NADSB_CFG}
fi

# Over prava na uzivatele root
[ -z ${SUDO} ] && SUDO=""
if [[ "$(id -u)" != "0" ]] && [[ ${SUDO} == "" ]];then
    echo "ERRROR: Instalaci je nutne spustit pod uzivatele root nebo z root pravy !"
    echo
    exit 3
fi

echo "* Instalace n2n vpn"
if ! command -v edge > /dev/null ;then
    $SUDO apt update
    $SUDO apt install -y --no-install-suggests --no-install-recommends n2n
fi

# Over a vytvor uzivatele
grep "^${N2NADSB_USER}:" /etc/passwd > /dev/null
if [[ "$?" == "1" ]];then
    echo "* Vytvoreni uzivatele \"${N2NADSB_USER}\" pro spusteni ${N2NADSB_NAME}"
    $SUDO adduser --system --no-create-home --shell /usr/sbin/nologin ${N2NADSB_USER}
else
    echo "* Uzivatel \"${N2NADSB_USER}\" jiz existuje"
fi

echo "* Nastaveni uzivatelskych prav pro slozku ${N2NADSB_FOLDER}"
$SUDO mkdir -p ${N2NADSB_FOLDER}
$SUDO chown ${N2NADSB_USER}:${N2NADSB_USER} -R ${N2NADSB_FOLDER}


echo
echo "* Vytvorim konfiguracni soubor pro ${N2NADSB_NAME}"
CONFIG_SAVE="false"
if ${N2NADSB_FILE} ;then
    echo "  - pouzije se ${N2NADSB_CFG}"
else
    echo "  - vytvori se ${N2NADSB_CFG}"
    if [ -e ${CONFIG_FILE} ];then
        echo -n "Konfiguracni soubor ${N2NADSB_NAME} jiz existuje. Chcete skutecne soubor prepsat ? [a/N]";
        read X
        echo
        [ "$X" == "a" ] || [ "$X" == "y" ] && CONFIG_SAVE="true"
    else
        CONFIG_SAVE="true"
    fi
    if [ "${CONFIG_SAVE}" == "true" ];then
        $SUDO touch ${N2NADSB_CFG}
        $SUDO chmod 666 ${N2NADSB_CFG}
        echo "* Nastaveni vychozi konfigurace ${N2NADSB_NAME}"
        /bin/cat <<EOM >${N2NADSB_CFG}
# Konfigurace pro N2N VPN Edge pro CzADSB

# Lokalni prirazena IP adresa
N2NADSB_LOCAL="${N2NADSB_LOCAL}"

# Maska pro lokalni sit
N2NADSB_MASK="${N2NADSB_MASK}"

# Adresa n2n serveru vcetne portu
N2NADSB_SERVER="${N2NADSB_SERVER}"

# Uzivatel pod kterym je sluzba spustena - NEMENIT
N2NADSB_USER="${N2NADSB_USER}"
# Cesta k vlastnimu programu - NEMENIT
N2NADSB_FOLDER="${N2NADSB_FOLDER}"

EOM
    fi
fi


echo "* Nastaveni VPN jako slozby"
SERVICE_FILE=/lib/systemd/system/${N2NADSB_NAME}.service
$SUDO touch ${SERVICE_FILE}
$SUDO chmod 777 ${SERVICE_FILE}

/bin/cat <<EOM >${SERVICE_FILE}
[Unit]
Description=N2n vpn edge for CZADSB
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
EnvironmentFile=${N2NADSB_CFG}
ExecStart=/usr/sbin/edge -a \${N2NADSB_LOCAL} -s ${N2NADSB_MASK} -l ${N2NADSB_SERVER} -c adsb -k adsb123 -b
Restart=on-failure
RestartSec=30
RestartPreventExitStatus=64

[Install]
WantedBy=multi-user.target
EOM

$SUDO chmod 644 ${SERVICE_FILE}
$SUDO systemctl daemon-reload
if [[ -z ${N2NADSB} ]] || [[ "${N2NADSB}" == "enabled" ]];then
    $SUDO systemctl enable ${N2NADSB}.service
    $SUDO systemctl restart ${N2NADSB}.service
fi
echo "Instalace N2N VPN Edge pro CzADSB ukoncena"
echo "Umisteni skriptu: ${N2NADSB_FOLDER}"
if ${CONFIG_SAVE};then
    echo "Nastavte konfiguracni soubor: ${N2NADSB_CFG}"
else
    echo "Umisteni konfigurace: ${N2NADSB_CFG}"
fi
echo
