#!/bin/bash
# Skript nainstaluje rtlsdr OGN

# Pojmenovani prijimace (max. 9 znaku). Obratte se prosim na http://wiki.glidernet.org/receiver-naming-convention
STATION_NAME="ogn"
# Jmeno uzivatele pod kterym se spusti rtlsdr OGN
OGN_USER="ogn"
# levne" R820T maji opravny faktory 40-80ppm, meri se pomoci gsm_scan
OGN_PPM="40"


# Skontroluj parametr umisteni konfiguracniho souboru z parametry prijimace
if [[ -n $1 ]] && [[ -s $1 ]];then
    OGN_CFG=$1
    # Prevezmy, prednastav uzivatele
    [ ! -z ${CZADSB_USER} ] && OGN_USER=${CZADSB_USER}
elif [[ -n ${CFG} ]] && [[ -s ${CFG} ]];then
    OGN_CFG=${CFG}
    # Prevezmy, prednastav uzivatele
    [ ! -z ${CZADSB_USER} ] && OGN_USER=${CZADSB_USER}
fi
# Nasci jiz vytvorenou konfiguraci
if [[ -s ${OGN_CFG} ]];then
    echo "* Konfigurace se prednastavi z \"${OGN_CFG}\""
    . ${OGN_CFG}
fi


# Over prava na uzivatele root
[ -z ${SUDO} ] && SUDO=""
if [[ "$(id -u)" != "0" ]] && [[ ${SUDO} == "" ]];then
    echo "ERRROR: Instalaci je nutne spustit pod uzivatele root nebo z root pravy !"
    echo
    exit 3
fi

# Over a vytvor uzivatele pro rtlsdr OGN
grep "^${OGN_USER}:" /etc/passwd > /dev/null
if [[ "$?" == "1" ]];then
    echo "* Vytvoreni uzivatele \"${OGN_USER}\" pro spusteni rtlsdr OGN"
    $SUDO adduser --system --no-create-home --shell /usr/sbin/nologin ${OGN_USER}
else
    echo "* Uzivatel \"${OGN_USER}\" jiz existuje"
fi

echo "* Instalace zavislosti"
echo "------------------------------------->"
$SUDO apt-get install -y --no-install-suggests --no-install-recommends libconfig9 libjpeg-dev libfftw3-dev lynx telnet ntpdate procserv
if [[  "$(command -v ntpd)" == "" ]] && [[ "$(command -v chronyd)" == "" ]] ;then
    $SUDO apt install -y --no-install-suggests --no-install-recommends chrony
fi
echo "-------------------------------------<"

cd ~
MACHINE=$(uname -m)
#STATION_ARCH=$(dpkg --print-architecture) # arm64 / armhf
echo "* Detekovan system ${MACHINE}, stazeni rtlsdr-ogn-bin"
if [[ "$MACHINE" == "armv7l" ]];then
    wget -nv http://download.glidernet.org/rpi-gpu/rtlsdr-ogn-bin-RPI-GPU-latest.tgz -O rtlsdr-ogn-bin-latest.tgz
elif [[ "$MACHINE" == "aarch64" ]];then
    wget -nv http://download.glidernet.org/arm64/rtlsdr-ogn-bin-arm64-latest.tgz -O rtlsdr-ogn-bin-latest.tgz
elif [[ "$MACHINE" == "aarch" ]];then
    wget -nv http://download.glidernet.org/arm/rtlsdr-ogn-bin-ARM-latest.tgz -O rtlsdr-ogn-bin-latest.tgz
elif [[ "$MACHINE" == "x86_64" ]];then
    wget -nv http://download.glidernet.org/x64/rtlsdr-ogn-bin-x64-latest.tgz -O rtlsdr-ogn-bin-latest.tgz
elif [[ "$MACHINE" == "x386" ]];then
    wget -nv http://download.glidernet.org/x86/rtlsdr-ogn-bin-x86-latest.tgz -O rtlsdr-ogn-bin-latest.tgz
else
    echo "Pro system \"${MACHINE}\" nebyl detekovan program rtlsdr-ogn. Prosim o zaslani teto informace autorovi skriptu."
fi

echo "* Instalace rtlsdr-ogn-bin"
tar -xvzf rtlsdr-ogn-bin-latest.tgz
$SUDO cp -rp ~/rtlsdr-ogn* /opt/
$SUDO rm /opt/rtlsdr-ogn-bin-*.tgz
$SUDO chown ${OGN_USER}:${OGN_USER} -R /opt/rtlsdr-ogn*
$SUDO chown ${OGN_USER}:${OGN_USER} -R /opt/rtlsdr-ogn/
cd /opt/rtlsdr-ogn
$SUDO chown root gsm_scan
$SUDO chmod a+s gsm_scan
$SUDO chown root ogn-rf
$SUDO chmod a+s  ogn-rf
$SUDO cp /opt/rtlsdr-ogn/rtlsdr-ogn /etc/init.d/
$SUDO cp /opt/rtlsdr-ogn/rtlsdr-ogn.conf /etc/
$SUDO rm rtlsdr-ogn
$SUDO rm rtlsdr-ogn.conf
$SUDO chown root /etc/init.d/rtlsdr-ogn
$SUDO chmod +x /etc/init.d/rtlsdr-ogn
$SUDO chmod a+s  /etc/init.d/rtlsdr-ogn
$SUDO update-rc.d rtlsdr-ogn defaults

cd /opt/rtlsdr-ogn
$SUDO mknod gpu_dev c 100 0
$SUDO mkfifo ogn-rf.fifo

echo "* Nastaveni GeoidSepar"
$SUDO rm -f /opt/rtlsdr-ogn/WW15MGH.DAC
$SUDO wget -nv --no-check-certificate https://earth-info.nga.mil/GandG/wgs84/gravitymod/egm96/binary/WW15MGH.DAC -U /opt/rtlsdr-ogn/WW15MGH.DAC

echo "* Konfigurace rtlsdr-ogn-bin"
CONFIG_FILE=/opt/rtlsdr-ogn/OGNstation.conf
$SUDO touch ${CONFIG_FILE}
$SUDO chmod 666 ${CONFIG_FILE}

/bin/cat <<EOM >${CONFIG_FILE}
RF:
{
  FreqCorr = ${OGN_PPM};           # [ppm]  "levne" R820T maji opravny faktory 40-80ppm, meri se pomoci gsm_scan
  Device   = 1;             # rtl-sdr device index
# DeviceSerial = "00000002";# seriove cslo zarizeni rtl-sdr, ktere chcete vybrat
# BiasTee      = 1;         # zapne napajeni 5V pro predzesilovac - Jen pro v3 dongle
  SampleRate   = 2.0;       # [MHz] 1.0 nebo 2.0MHz, provoz 2MHz ma vetci zatez CPU, ale pro zachytit PilotAware je potreba

  GSM:                      # frekvence pro kalibraci kmitoctu zalozenou na GSM signulu
  {
    CenterFreq  = 930.4;    # [MHz] nejlepsi GSM frekvenci zjiitsna pomoci gsm_scan
    Gain        =  2.7;     # [dB]  RF vstupni zesileni (dejte pozor, ze GSM signaly jsou velmi silne!)
                            # platna nastaveni pro zisk : 0.0 1.4 3.7 7.7 8.7 12.5 14.4 15.7 16.6 19.7 20.7 22.9 25.4 28.0 29.7 32.8 33.8 36.4 37.2 38.6 40.2 42.1 43.4 43.9 44.5 48.0 49.6
  } ;

  OGN:
  {
    CenterFreq  = 868.8;    # [MHz] ze sirkou pasma 868,8 MHz a 2 MHz muzeme zachytit vsechny systemy: FLARM / OGN / FANET / PilotAware
    Gain        = 49.6;     # [0.1dB] Rx zesileni OGN prijimace
  };
} ;

Demodulator:
{
  ScanMargin = 30.0;       # [kHz] frekvencni tolerance pro prijem, vetsina signalu by normalne mela byt +/-15 kHz, ale nektere jsou vice mimo frekvenci
  DetectSNR  = 10.0;       # [dB]  prah detekce pro FLARM/OGN
}

Position:
{
  Latitude   =   +${STATION_LAT} ; # [deg] Souradnice anteny ve stupnich
  Longitude  =   +${STATION_LON} ; # [deg]
  Altitude   =   ${STATION_ALT} ;        # [m]   Nadmorska vvyska nad morem v metrech
# GeoidSepar =   10;           # [m]   Geoid separation: FLARM vysila GPS nadmorskou vyku, APRS pouziva prostredky nadmorske vysky
} ;

APRS:
{
  Call   = "${STATION_NAME}";  # APRS oznaceni (max. 9 znaku). Obratte se prosim na http://wiki.glidernet.org/receiver-naming-convention
# Server = "aprs.glidernet.org:14580";
} ;

HTTP:
{
  Port=8180;                 # Nastaveni pocatecniho http portu
} ;
EOM
$SUDO chmod 644 ${CONFIG_FILE}
$SUDO chown ${OGN_USER}:${OGN_USER} ${CONFIG_FILE}

CONFIG_SERVICE="/etc/rtlsdr-ogn.conf"
[[ -z ${CONFIG_SERVICE} ]] && $SUDO touch ${CONFIG_SERVICE}
$SUDO chmod 777 ${CONFIG_SERVICE}

/bin/cat <<EOM > ${CONFIG_SERVICE}
50000  ${OGN_USER} /opt/rtlsdr-ogn    ./ogn-rf     OGNstation.conf
50001  ${OGN_USER} /opt/rtlsdr-ogn    ./ogn-decode OGNstation.conf
EOM
$SUDO chmod 644 ${CONFIG_FILE}

echo "* Zapnuti rtlsdr-ogn-bin jako sluzby"
$SUDO service rtlsdr-ogn start

