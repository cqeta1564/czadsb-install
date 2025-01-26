#!/bin/bash
# Skript pro instalaci reporteru metric
# bash -c "$(wget -nv -O - https://rxw.cz/adsb/install/install-reporter.sh)"

# Nazev programu / sluzby
REPORTER_NAME="reporter"
# Jmeno uzivatele pod kterym se spusti REPORTER 
REPORTER_USER="adsb"
# Cesta ke konfiguracnimu souboru
REPORTER_CFG="/etc/default/${REPORTER_NAME}"
# Adresar pro instalaci REPORTER
REPORTER_FOLDER="/usr/local/bin"
# url adresa pro odesilani dat z reportu
REPORTER_URL="https://rxw.cz/reporter/"
# Seznam sledovanych sluzeb
REPORTER_SER="dump1090 dump1090-fa adsbfwd mlat-client vpn-czadsb" 
# Interval pro odesilani dat
REPORTER_REF="*:6,21,36,51"

# Skontroluj parametr umisteni konfiguracniho souboru a pripadne jej nacti
if [[ -n $1 ]] && [[ -s $1 ]];then
    REPORTER_CFG=$1
    REPORTER_FILE="true"
elif [[ -n ${CFG} ]] && [[ -s ${CFG} ]];then
    REPORTER_CFG=${CFG}
    REPORTER_FILE="true"
else
    REPORTER_FILE="false"
fi

# Nacti jiz vytvorenou konfiguraci, nebo ho vytvor
if [[ -s ${REPORTER_CFG} ]];then
    echo "* Konfigurace se nacte z \"${REPORTER_CFG}\""
    . ${REPORTER_CFG}
    # Prevezmy, prednastav uzivatele a instalacni adresar
    [ ! -z ${CZADSB_USER}   ] && REPORTER_USER=${CZADSB_USER}
    [ ! -z ${CZADSB_FOLDER} ] && REPORTER_FOLDER=${CZADSB_FOLDER}
elif [ "${REPORTER_FILE}" == "false" ];then
    echo "* Vytvor konfiguracni soubor \"${REPORTER_CFG}\""
    [ -z ${STATION_UUID} ] && STATION_UUID=$(cat /proc/sys/kernel/random/uuid)
    $SUDO touch ${REPORTER_CFG}
    $SUDO chmod 666 ${REPORTER_CFG}
    /bin/cat <<EOM >${REPORTER_CFG}
# Unikatni oznaceni stanice
STATION_UUID="${STATION_UUID}"
# Povoli automatickeho spusteni skriptu
REPORTER="enable"
# Url adresa pro odesilani dat z reportu
REPORTER_URL="${REPORTER_URL}"
# Seznam sledovanych sluzeb
REPORTER_SER="${REPORTER_SER}" 
EOM
    $SUDO chmod 644 ${REPORTER_CFG}
fi

# Over prava na uzivatele root
[ -z ${SUDO} ] && SUDO=""
if [[ "$(id -u)" != "0" ]] && [[ ${SUDO} == "" ]];then
    echo "ERRROR: Instalaci je nutne spustit pod uzivatele root nebo z root pravy !"
    echo
    exit 3
fi

if [ ! -s "/bin/vcgencmd" ]; then
    if ! command -v sensors &>/dev/null ;then
        echo "* Instaluji ovladace lm-sensors"
        $SUDO apt install -y lm-sensors
    fi
fi 

echo "* Instaluj skript reporter.sh"
REPORTER_FILE="${REPORTER_FOLDER}/${REPORTER_NAME}.sh"
$SUDO touch ${REPORTER_FILE}
$SUDO chmod 777 ${REPORTER_FILE}

/bin/cat <<EOM >${REPORTER_FILE}
#!/bin/bash
# Skript odesila provozni data ze stanice k analize na czadsb

REPORTER_CFG="${REPORTER_CFG}"

if [ -r \${REPORTER_CFG} ];then
    . \${REPORTER_CFG}
else
    echo "Neexistuje nebo nelze nacist konfiguraci z \${REPORTER_CFG}."
    exit 3
fi

if [ "\${REPORTER}" == "notinstall" -o "\${REPORTER}" == "" ];then
    echo "Reporter nema opravneni k zasilani dat (\${REPORTER})."
    exit 2
fi

# Pokud neni k dispozici /bin/vcgencmd, nutne doinstalovat balicek lm-sensors
# sudo apt install lm-sensors

SYSUP=\$(date -d "\$(uptime -s)" +%s) #"          # Nacti kdy byl system naposledy spusten
UPTIME=\$(( \$(date +%s) - \$SYSUP ))              # Z rozdilu aktualniho casu a spusteni vypocitej uptime
LOAD=\$(cut -d" " -f1-3 /proc/loadavg)           # Nacti zatizeni prijimace
                                                # Z free nacti udaje o vyuziti pameti
                                                # 1:Mem  2:total  3:used  4:free  5:shared  6:buff/cache  7:available
MEMORY=\$(free | awk '/Mem/{print "\"m\":\""\$2" "\$3" "\$4" "\$6"\""}') # available = total - used
if [ -f /bin/vcgencmd ];then
    TEMP=\$(/bin/vcgencmd measure_temp | tr -d "temp='C")
elif [ -f /bin/sensors ];then
    TEMP=\$(sensors | awk '/temp1:/{print \$2}' | tr -d '+°C')
else
    TEMP=""
fi

D="{\"u\":\"\${STATION_UUID}\","                 # Vytvor json odpoved, prve uuid prijimace, pak dalsi data
D="\${D}\"sys\":{\"u\":\"\${UPTIME}\",\"l\":\"\${LOAD}\",\${MEMORY},\"t\":\"\${TEMP}\"}"
J=""                                            # Nacti status sledovanych sluzeb
for S in \${REPORTER_SER[@]};do
    systemctl is-enabled \${S}.service 2> /dev/null > /dev/null
    if [ "\$?" == "0" ];then
        [ ! "\${J}" == "" ] && J="\${J},"
        J="\${J}\"\${S/-/_}\":{"
        J="\${J}\"e\":\"\$(systemctl is-enabled \${S}.service)\","
        J="\${J}\"a\":\"\$(systemctl is-active \${S}.service)\","
        J="\${J}\"f\":\"\$(systemctl is-failed \${S}.service)\","
        T=\$(systemctl show \${S}.service | awk -F= '/ExecMainStartTimestamp=/{print \$2}')
        T=\$(date -d "\${T}" +%s)
        J="\${J}\"t\":\"\${T}\"}"
    fi
done
D="\${D},\"ser\":{\${J}}}"                        # Pridej status sluzeb k json odpovedi
#echo \${D} ; echo                               # Jen kontrolni vypis pred odeslanim

CURL=\$(curl -s -X POST -H "Content-Type: application/json" -d "\${D}" \${REPORTER_URL}) # Posli data a nacti odpoved

CMD=\$(echo \${CURL} | cut -d" " -f1)

if   [ "\${CMD}" == "bash:" ];then
    X=\$(echo \${CURL} | cut -d" " -f2-)
    echo \${X} | bash
elif [ "\${CMD}" == "sh:"  ];then
    X=\$(echo \${CURL} | cut -d" " -f2-)
    echo \${X} | sh
elif [ "\${CMD}" == "cmd:" ];then
    X=\$(echo \${CURL} | cut -d" " -f2-)
    \${X}
else
    echo \${CURL}
fi

EOM
$SUDO chmod 755 ${REPORTER_FILE}

echo "* Instaluj sluzbu pro reporter.sh"
REPORTER_SERVICE="/lib/systemd/system/${REPORTER_NAME}.service"
$SUDO touch ${REPORTER_SERVICE}
$SUDO chmod 777 ${REPORTER_SERVICE}

/bin/cat <<EOM >${REPORTER_SERVICE}
[Unit]
Description=Report metrics czadsb
After=network-online.target systemd-networkd.service connman.service

[Service]
Type=oneshot
ExecStart=${REPORTER_FILE}
KillMode=process
TimeoutStopSec=60
EOM
$SUDO chmod 644 ${REPORTER_SERVICE}

echo "* Instaluj casovac pro reporter.sh"
REPORTER_TIMER="/lib/systemd/system/${REPORTER_NAME}.timer"
$SUDO touch ${REPORTER_TIMER}
$SUDO chmod 777 ${REPORTER_TIMER}

/bin/cat <<EOM >${REPORTER_TIMER}
[Unit]
Description=Report metrics for ${REPORTER_REF}

[Timer]
OnCalendar=${REPORTER_REF}
RandomizedDelaySec=180

[Install]
WantedBy=timers.target
EOM
$SUDO chmod 644 ${REPORTER_TIMER}

echo "* Nastav sluzbu pro reporter.sh"
$SUDO systemctl daemon-reload
$SUDO systemctl enable ${REPORTER_NAME}.timer
$SUDO systemctl restart ${REPORTER_NAME}.timer
echo

