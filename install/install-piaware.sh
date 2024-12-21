#!/bin/bash

# Instalace:
#   sudo bash -c "$(wget -nv -O - https://rxw.cz/adsb/install/install-piaware.sh)"
#
# Poznamka:
# Instalace zPiAware repozitare je v dobe psani tohoto skriptu jen pro bullseye !
# Jinak je potreba postupovat dle https://github.com/flightaware/piaware_builder
# kde je mozna i instalace na bookworm (debian id 12). 
# Vyse zmineny postupem byli vytvoreny predkompilovane balicky pro snadnejsi
# instalaci prave na bookworm. 


# ------------------  Definice hodnot pro vlastni instalaci  -------------------
# Odkaz na repozitar PiAware
piaware_repository="piaware-repository_7.2_all.deb"
# Verze debianu podporovana v repozitari PiAware
piaware_version_id="11"
# Odkaz na GIT PiAware
piaware_git="https://github.com/flightaware/piaware_builder.git"
# Cesta na prekompilovane bajicky v ramci komunity
URL_DEB="https://rxw.cz/dists"
# Instalovana verze PiAware
PIA_VER="9.0.1"

# ---------------------  Funkce pro lepsi prehled skriptu  ---------------------
# Instalace repozitare PiAware a instalace jednotlivych komponent
install_piaware_apt(){
    echo "* Install PiAware repository"
    echo "------------------------------------->"
    cd ~
    $SUDO rm -f ./$piaware_repository
    wget https://flightaware.com/adsb/piaware/files/packages/pool/piaware/p/piaware-support/$piaware_repository
    $SUDO dpkg -i $piaware_repository
    $SUDO apt update
    $SUDO rm -f ./$piaware_repository
    echo "-------------------------------------<"
}
install_piaware(){
    echo "* Instalace PiAware"
    echo "------------------------------------->"
    $SUDO apt install -y --no-install-suggests --no-install-recommends piaware
    sleep 1
    $SUDO piaware-config allow-auto-updates yes
    $SUDO piaware-config allow-manual-updates yes
#   $SUDO apt install dump1090-fa
    echo "-------------------------------------<"
}
install_piaware_web(){
    echo "* Instalace PiAware Web"
    echo "------------------------------------->"
    $SUDO apt-get install -y piaware piaware-web
    sleep 1
    if [ ! -f "/etc/armbian-release" ]; then
        $SUDO apt-get install -y piaware-support
    fi
    echo "-------------------------------------<"
}

# Zbildovani PiAware z gitu
install_piaware_builder(){
    echo "* Instalace potrebnych balicku pro bildovani"
    echo "------------------------------------->"
    $SUDO apt-get install -y --no-install-suggests --no-install-recommends python3-dev python3-venv python3-setuptools python3-wheel python3-build python3-pip
    $SUDO apt-get install -y --no-install-suggests --no-install-recommends build-essential git devscripts tcl8.6-dev tclx8.4 tcllib tcl-tls itcl3 debhelper dh-python
# Pro bookworm:
    $SUDO apt-get install -y --no-install-suggests --no-install-recommends autoconf libboost-system-dev libboost-program-options-dev libboost-regex-dev libboost-filesystem-dev patchelf
    echo "-------------------------------------<"
    echo "* Naklonovani PiAware z Gitu"
    git clone ${piaware_git}
    echo "* Priprava pro build ${VERSION_CODENAME}"
    echo "------------------------------------->"
    ./piaware_builder/sensible-build.sh ${VERSION_CODENAME}
    cd ./piaware_builder/package-${VERSION_CODENAME}
    echo "-------------------------------------<"
    echo "* Build PiAware ${VERSION_CODENAME}"
    echo "------------------------------------->"
    dpkg-buildpackage -b --no-sign
    mkdir ~/install
    cp ../piaware*.deb ~/install/
    echo "-------------------------------------<"
    echo "* Instalace PiAware"
    echo "------------------------------------->"
    cd ~/install/
    $SUDO dpkg -i piaware*.deb
    echo "-------------------------------------<"
    $SUDO piaware-config allow-auto-updates yes
    $SUDO piaware-config allow-manual-updates yes
}

# Instalace PiAware z predkompilovanych balicku
dovnload_piaware_deb(){
    echo "* Ztazeni predkompilovanych balicku"
    echo "--------------------------------------"
    WGET=true
    [[ $WGET ]] && wget -nv ${URL_DEB}/${VERSION_CODENAME}/piaware_${PIA_VER}_${ARCH}.deb
    [[ ! "$?" == "0" ]] && WGET=false
    [[ $WGET ]] && wget -nv ${URL_DEB}/${VERSION_CODENAME}/piaware-dbgsym_${PIA_VER}_${ARCH}.deb
    [[ ! "$?" == "0" ]] && WGET=false
    if $WGET ;then
        echo "* Instalace zavislich balicku"
        echo "------------------------------------->"
        $SUDO apt install -y --no-install-suggests --no-install-recommends itcl3 tcl tcl-tls tcl8.6 tcllib tclx8.4 tcl8.6-dev tcl-tclreadline tcllib-critcl
        echo "-------------------------------------<"
        echo "* Instalace PiAware"
        echo "------------------------------------->"
        $SUDO dpkg -i piaware*.deb
        echo "-------------------------------------<"
        $SUDO piaware-config allow-auto-updates yes
        $SUDO piaware-config allow-manual-updates yes
    else
        echo "* Warning: ztazeni predkompilovanych balicku se nezdarilo"
    fi
    rm -f piaware*.deb
}
# -----------------  Konec funkci, zacatek vlastniho skriptu  -----------------

# Over prava na uzivatele root
[ -z ${SUDO} ] && SUDO=""
if [[ "$(id -u)" != "0" ]] && [[ ${SUDO} == "" ]];then
    echo "ERRROR: Instalaci je nutne spustit pod uzivatele root nebo z root pravy !"
    echo
    exit 3
fi
 
# Nacti informace o distribuci a architekture
. /etc/os-release
ARCH=$(dpkg --print-architecture)

# Vyber zpusob instalace
# Pokud se verze debianu zhoduje z podporovanym repozitarem PiAware, pouzi jeho balicky
if [[ "${VERSION_ID}" == "${piaware_version_id}" ]] && [[ "${ARCH}" =~ "arm" ]];then    # armhf, arm64
    install_piaware_apt
    install_piaware
#   install_piaware_web
    PIAWARE_PACK="PiAware"
else
    dovnload_piaware_deb                                    # jinak se pokus nainstalovat z predkompilovanych balicku
    if $WGET ;then
        PIAWARE_PACK="CzADSB"
    else                                                    # pokud se nepovede, proved samoztatnou kompilaci
        install_piaware_builder     
        PIAWARE_PACK="Bilder"
    fi
fi
echo "* Konec instalacniho skriptu (${PIAWARE_PACK})"
# --------------------  Konec celeho instalacniho skriptu  ---------------------

