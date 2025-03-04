#!/bim/bash

# Manual: https://github.com/sdrmap/docs/wiki
# Web :   https://sdrmap.org

sudo wget -q -O /usr/share/keyrings/sdrmap.key https://repo.sdrmap.org/sdrmap.pgp.key

# Pro Rasberry - arm
#echo "deb [signed-by=/usr/share/keyrings/sdrmap.key] https://repo.sdrmap.org/debian bullseye main" | sudo tee -a /etc/apt/sources.list.d/sdrmap.list
#echo "deb [signed-by=/usr/share/keyrings/sdrmap.key] https://repo.sdrmap.org/debian bookworm main" | sudo tee -a /etc/apt/sources.list.d/sdrmap.list
# pro ostatni
#echo "deb [signed-by=/usr/share/keyrings/sdrmap.key] https://repo.sdrmap.org/ubuntu jammy main" | sudo tee -a /etc/apt/sources.list.d/sdrmap.list
#echo "deb [signed-by=/usr/share/keyrings/sdrmap.key] https://repo.sdrmap.org/ubuntu noble main" | sudo tee -a /etc/apt/sources.list.d/sdrmap.list

# N: Pøeskakuje se stažení souboru „main/binary-amd64/Packages“, protože repositáø „https://repo.sdrmap.org/debian bookworm InRelease“ nepodporuje architekturu „amd64“

echo "deb [signed-by=/usr/share/keyrings/sdrmap.key] https://repo.sdrmap.org/${ID} ${VERSION_CODENAME} main" | sudo tee -a /etc/apt/sources.list.d/sdrmap.list

sudo apt update

# ---------------------
# --write-json /run/dump1090.json 

sudo apt install sdrmapfeeder

sudo nano /etc/default/sdrmapfeeder

sudo systemctl restart sdrmapfeeder

# ---------------------

sudo apt install mlat-client-sdrmap

sudo nano /etc/default/mlat-client-sdrmap

sudo systemctl restart mlat-client-sdrmap

# --------------------- AIS se nakonfiguruje ze primo data odesila    161.975 MHz a 162.025 MHz
sudo apt install ais-catcher
sudo cp /etc/ais-catcher.d/rtlsdr.conf.example /etc/ais-catcher.d/20000001.conf
sudo nano /etc/ais-catcher.d/20000001.conf
sudo systemctl start ais-catcher@20000001.service
sudo systemctl enable ais-catcher@20000001.service

# --------------------- https://github.com/projecthorus/radiosonde_auto_rx/wiki/Configuration-Settings   400 - 406 MHz
sudo apt install radiosondeautorx
sudo systemctl restart radiosondeautorx
