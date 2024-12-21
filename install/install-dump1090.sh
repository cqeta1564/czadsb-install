#!/bin/bash
# Skript pro instalaci dump1090 z git repozitare

# Over prava na uzivatele root
[ -z ${SUDO} ] && SUDO=""
if [[ "$(id -u)" != "0" ]] && [[ ${SUDO} == "" ]];then
    echo "ERRROR: Instalaci je nutne spustit pod uzivatele root nebo z root pravy !"
    echo
    exit 3
fi

echo "* Instalace zavislosti"
echo "------------------------------------->"
$SUDO apt-get update
$SUDO apt install -y --no-install-suggests --no-install-recommends git lighttpd librtlsdr-dev libbladerf-dev libhackrf-dev liblimesuite-dev libsoapysdr-dev libusb-1.0-0-dev libncurses5-dev debhelper pkg-config
$SUDO apt install -y --no-install-suggests --no-install-recommends rtl-sdr
if ! [[ -s /etc/udev/rules.d/rtl-sdr.rules ]];then
    $SUDO wget -q https://raw.githubusercontent.com/osmocom/rtl-sdr/master/rtl-sdr.rules -O /etc/udev/rules.d/rtl-sdr.rules
    REBOOT=true
fi
echo "-------------------------------------<"
echo "* Stazeni program z gitu a kompilace"
echo
cd ~
git clone https://github.com/flightaware/dump1090 dump1090-fa
cd dump1090-fa
$SUDO dpkg-buildpackage -b --no-sign
cd ..
mkdir ~/install
cp dump1090-fa_*.deb ~/install/
echo "-------------------------------------<"
echo "* Instalace dump1090"
echo
$SUDO dpkg -i dump1090-fa_*.deb
$SUDO service dump1090-fa start
$SUDO systemctl enable dump1090-fa.service
$SUDO rm -rf ./dump1090-fa*

echo "* Instalace dump1090 ukoncena"

