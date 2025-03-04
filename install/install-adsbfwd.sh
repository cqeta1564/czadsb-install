#!/bin/bash
# Skript pro instalaci ADSBfwd

# https://github.com/juei-dev/adsbmonitor?tab=readme-ov-file

# Nazev programu / sluzby
ADSBFWD_NAME="adsbfwd"
# Jmeno uzivatele pod kterym se spusti ADSBfwd 
ADSBFWD_USER="adsb"
# Cesta ke konfiguracnimu souboru
ADSBFWD_CFG="/etc/default/${ADSBFWD_NAME}"
# Adresar pro instalaci ADSBfwd
ADSBFWD_FOLDER="/usr/bin"

# Adresa a port zdroje dat
ADSBFWD_SRC="127.0.0.1:30005"
# Adresa/y kam data chceme preposilat (oddelene mezerou)
ADSBFWD_DST="czadsb.cz:50000"
# Adresa souboru ADSBfwd pro stazeni
ADSBFWD_RAW="https://github.com/clazzor/Socket-Forwarder/raw/main/socketForwarder.py"


# Skontroluj parametr umisteni konfiguracniho souboru a pripadne jej nacti
if [[ -n $1 ]] && [[ -s $1 ]];then
    ADSBFWD_CFG=$1
    ADSBFWD_FILE="true"
    # Prevezmy, prednastav uzivatele a instalacni adresar
    [ ! -z ${CZADSB_USER} ] && ADSBFWD_USER=${CZADSB_USER}
    [ ! -z ${CZADSB_FOLDER} ] && ADSBFWD_FOLDER=${CZADSB_FOLDER}
elif [[ -n ${CFG} ]] && [[ -s ${CFG} ]];then
    ADSBFWD_CFG=${CFG}
    ADSBFWD_FILE="true"
    # Prevezmy, prednastav uzivatele a instalacni adresar
    [ ! -z ${CZADSB_USER} ] && ADSBFWD_USER=${CZADSB_USER}
    [ ! -z ${CZADSB_FOLDER} ] && ADSBFWD_FOLDER=${CZADSB_FOLDER}
elif [[ -s "/etc/default/czadsb.cfg" ]];then
    ADSBFWD_CFG="/etc/default/czadsb.cfg"
    ADSBFWD_FILE="true"
    # Prevezmy, prednastav uzivatele a instalacni adresar
    [ ! -z ${CZADSB_USER} ] && ADSBFWD_USER=${CZADSB_USER}
    [ ! -z ${CZADSB_FOLDER} ] && ADSBFWD_FOLDER=${CZADSB_FOLDER}
else
    ADSBFWD_FILE="false"
fi
# Nacti jiz vytvorenou konfiguraci
if [[ -s ${ADSBFWD_CFG} ]];then
    echo "* Konfigurace se nacte z \"${ADSBFWD_CFG}\""
    . ${ADSBFWD_CFG}
fi

# Over prava na uzivatele root
[ -z ${SUDO} ] && SUDO=""
if [[ "$(id -u)" != "0" ]] && [[ ${SUDO} == "" ]];then
    echo "ERRROR: Instalaci je nutne spustit pod uzivatele root nebo z root pravy !"
    echo
    exit 3
fi

# Over a vytvor uzivatele
grep "^${ADSBFWD_USER}:" /etc/passwd > /dev/null
if [[ "$?" == "1" ]];then
    echo "* Vytvoreni uzivatele \"${ADSBFWD_USER}\" pro spusteni ${ADSBFWD_NAME}"
    $SUDO adduser --system --group --no-create-home --shell /bin/bash ${ADSBFWD_USER}
else
    echo "* Uzivatel \"${ADSBFWD_USER}\" jiz existuje"
fi

if [[ ! -d ${ADSBFWD_FOLDER} ]];then
    echo "* Nastaveni slozky \"${ADSBFWD_FOLDER}\" pro instalaci"
    $SUDO mkdir -p ${ADSBFWD_FOLDER}
    $SUDO chown ${ADSBFWD_USER}:${ADSBFWD_USER} -R ${ADSBFWD_FOLDER}
fi

echo "* Stazeni programu do urceneho adresare"
cd ~
if ! command -v git > /dev/null ;then
    wget -nv ${ADSBFWD_RAW} -O ./${ADSBFWD_NAME}.py
    $SUDO mv ./${ADSBFWD_NAME}.py ${ADSBFWD_FOLDER}/${ADSBFWD_NAME}.py
else
    echo "------------------------------------->"
    git clone https://github.com/clazzor/Socket-Forwarder.git
    $SUDO cp ./Socket-Forwarder/socketForwarder.py ${ADSBFWD_FOLDER}/${ADSBFWD_NAME}.py
    $SUDO rm -r ./Socket-Forwarder
    echo "-------------------------------------<"
fi
$SUDO chmod +x ${ADSBFWD_FOLDER}/${ADSBFWD_NAME}.py
$SUDO chown ${ADSBFWD_USER}:${ADSBFWD_USER} ${ADSBFWD_FOLDER}/${ADSBFWD_NAME}.py

echo
echo "* Vytvorim konfiguracni soubor pro ${ADSBFWD_NAME}"
CONFIG_SAVE="false"
if ${ADSBFWD_FILE} ;then
    echo "  - pouzije se ${ADSBFWD_CFG}"
else
    echo "  - vytvori se ${ADSBFWD_CFG}"
    CONFIG_SAVE="false"
    if [ -e ${ADSBFWD_CFG} ];then
        echo -n "Konfiguracni soubor pro ${ADSBFWD_NAME} jiz existuje. Chcete skutecne soubor prepsat ? [a/N]";
        read X
        echo
        [ "$X" == "a" ] || [ "$X" == "y" ] && CONFIG_SAVE="true"
    else
        CONFIG_SAVE="true"
    fi
    if [ "${CONFIG_SAVE}" == "true" ];then
        $SUDO touch ${ADSBFWD_CFG}
        $SUDO chmod 666 ${ADSBFWD_CFG}
        echo
        echo "* Nastaveni vychozi konfigurace ${ADSBFWD_NAME}.conf"
        /bin/cat <<EOM >${ADSBFWD_CFG}
# Konfigurace pro ADSBfwd

# Adresa a port zdroje dat
ADSBFWD_SRC="${ADSBFWD_SRC}"

# Adresa/y kam data chceme preposilat (oddelene mezerou)
ADSBFWD_DST="${ADSBFWD_DST}"

# Uzivatel pod kterym je sluzba spustena - NEMENIT
ADSBFWD_USER="${ADSBFWD_USER}"
# Cesta k vlastnimu programu - NEMENIT
ADSBFWD_FOLDER="${ADSBFWD_FOLDER}"

EOM
    fi
fi

echo
echo "* Nastaveni ADS-Bfwd jako slozby"
SERVICE_FILE=/lib/systemd/system/${ADSBFWD_NAME}.service
$SUDO touch ${SERVICE_FILE}
$SUDO chmod 777 ${SERVICE_FILE}

/bin/cat <<EOM >${SERVICE_FILE}
[Unit]
Description=ADSB fwd
Wants=network.target
After=network.target

[Service]
Type=simple
User=${ADSBFWD_USER}
EnvironmentFile=${ADSBFWD_CFG}
ExecStart=${ADSBFWD_FOLDER}/${ADSBFWD_NAME}.py \${ADSBFWD_SRC} \${ADSBFWD_DST}
SyslogIdentifier=${ADSBFWD_NAME}
Restart=on-failure
RestartSec=30
RestartPreventExitStatus=64

[Install]
WantedBy=default.target
EOM

$SUDO chmod 644 ${SERVICE_FILE}
if [[ -z ${ADSBFWD} ]] || [[ "${ADSBFWD}" == "enable" ]];then
    $SUDO systemctl enable ${ADSBFWD_NAME}.service
fi
$SUDO systemctl restart ${ADSBFWD_NAME}.service
echo "Instalace ADSBfwd ukoncena"
echo "Umisteni: ${ADSBFWD_FOLDER}/${ADSBFWD_NAME}.py"
if ${CONFIG_SAVE};then
    echo "Nastavte konfiguracni soubor: ${ADSBFWD_CFG}"
else
    echo "Umisteni konfigurace: ${ADSBFWD_CFG}"
fi
echo

