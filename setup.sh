#!/bin/bash

# Farben
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# IP-Adresse ermitteln
ip_address=$(hostname -I | awk '{print $1}')

# --- Statische IP setzen ---
echo -n "Möchtest du eine statische IP-Adresse konfigurieren? (j/n): "
read -r static_ip_choice
if [[ "$static_ip_choice" == "j" ]]; then
    interface=$(ip -o -4 route show to default | awk '{print $5}')
    detected_gw=$(ip route | grep default | awk '{print $3}')
    echo -e "${GREEN}Gefundenes Gateway: $detected_gw${RESET}"

    read -p "Statische IP (z. B. 192.168.10.100/24): " static_ip
    read -p "Gateway [$detected_gw]: " custom_gw
    gateway=${custom_gw:-$detected_gw}

    read -p "Primärer DNS-Server (leer = $gateway): " dns1
    dns1=${dns1:-$gateway}
    read -p "Sekundärer DNS-Server (leer = keiner): " dns2

    echo -e "${GREEN}Konfiguriere Netzwerkschnittstelle $interface...${RESET}"
    cat <<EOF | sudo tee /etc/network/interfaces.d/$interface.cfg > /dev/null
auto $interface
iface $interface inet static
    address $static_ip
    gateway $gateway
    dns-nameservers $dns1${dns2:+ $dns2}
EOF

    echo -e "${GREEN}Netzwerk wird neu gestartet...${RESET}"
    sudo ifdown "$interface" && sudo ifup "$interface"
else
    echo -e "${RED}Statische IP wird nicht gesetzt.${RESET}"
fi

# --- System-Update & Upgrade ---
echo -e "${GREEN}System wird aktualisiert...${RESET}"
sudo apt update && sudo apt upgrade -y

# Funktion zum Installieren von APT-Paketen
installiere_paket() {
    local paket=$1
    echo -e "${GREEN}Installiere ${paket}...${RESET}"
    sudo apt install -y "$paket"
}

# --- curl ---
echo -n "Möchtest du curl installieren? (j/n): "
read -r curl_antwort
if [[ "$curl_antwort" == "j" ]]; then
    installiere_paket "curl"
else
    echo -e "${RED}curl wird nicht installiert.${RESET}"
fi

# --- Docker ---
echo -n "Möchtest du Docker installieren? (j/n): "
read -r docker_antwort
if [[ "$docker_antwort" == "j" ]]; then
    echo -e "${GREEN}Installiere Docker...${RESET}"
    sudo apt install -y apt-transport-https ca-certificates gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker "$USER"
else
    echo -e "${RED}Docker wird nicht installiert.${RESET}"
fi

# --- Docker Compose ---
echo -n "Möchtest du Docker Compose installieren? (j/n): "
read -r compose_antwort
if [[ "$compose_antwort" == "j" ]]; then
    echo -e "${GREEN}Installiere Docker Compose...${RESET}"
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose --version
else
    echo -e "${RED}Docker Compose wird nicht installiert.${RESET}"
fi

# --- Portainer ---
echo -n "Möchtest du Portainer installieren? (j/n): "
read -r portainer_install
if [[ "$portainer_install" == "j" ]]; then
    mkdir -p ~/portainer
    cat <<EOF > ~/portainer/docker-compose.yml
version: '3'
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9443:9443"
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
volumes:
  portainer_data:
EOF

    echo -n "Portainer jetzt starten? (j/n): "
    read -r start_portainer
    if [[ "$start_portainer" == "j" ]]; then
        cd ~/portainer || exit
        docker-compose up -d
    fi
fi

# --- VDSM ---
echo -n "Möchtest du VDSM (Virtual DSM) einrichten? (j/n): "
read -r vdsm_antwort
if [[ "$vdsm_antwort" == "j" ]]; then
    read -p "Größe der virtuellen Festplatte (z. B. 512G): " DISK_SIZE
    read -p "RAM-Größe (z. B. 2G): " RAM_SIZE
    read -p "Anzahl CPU-Kerne (z. B. 2): " CPU_CORES
    mkdir -p ~/vdsm
    cat <<EOF > ~/vdsm/docker-compose.yml
version: '3.7'
services:
  dsm:
    image: vdsm/virtual-dsm:latest
    container_name: vdsm
    environment:
      DISK_SIZE: "${DISK_SIZE}"
      DISK_FMT: "qcow2"
      RAM_SIZE: "${RAM_SIZE}"
      CPU_CORES: "${CPU_CORES}"
    devices:
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - "5000:5000"
      - "6690:6690"
    volumes:
      - /var/dsm:/storage
    restart: always
    stop_grace_period: 2m
EOF

    echo -n "VDSM jetzt starten? (j/n): "
    read -r start_vdsm
    if [[ "$start_vdsm" == "j" ]]; then
        cd ~/vdsm || exit
        docker-compose up -d
    fi
fi

# --- AdGuard Home ---
echo -n "Möchtest du AdGuard Home einrichten? (j/n): "
read -r adguard_install
if [[ "$adguard_install" == "j" ]]; then
    mkdir -p ~/adguard/{work,conf}
    cat <<EOF > ~/adguard/docker-compose.yml
version: '3'
services:
  adguardhome:
    image: adguard/adguardhome
    container_name: adguardhome
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "67:67/udp"
      - "68:68/udp"
      - "80:80/tcp"
      - "443:443/tcp"
      - "3000:3000/tcp"
    volumes:
      - ./work:/opt/adguardhome/work
      - ./conf:/opt/adguardhome/conf
EOF

    echo -n "AdGuard Home jetzt starten? (j/n): "
    read -r start_adguard
    if [[ "$start_adguard" == "j" ]]; then
        cd ~/adguard || exit
        docker-compose up -d
    fi
fi

# --- Tailscale ---
echo -n "Möchtest du Tailscale installieren und einrichten? (j/n): "
read -r tailscale_install
if [[ "$tailscale_install" == "j" ]]; then
    curl -fsSL https://tailscale.com/install.sh | sh

    advertise_arg=""
    exitnode_arg=""
    dns_arg=""

    echo -n "Welches Subnetz soll für Tailscale freigegeben werden (z. B. 192.168.10.0/24)? (leer = kein Subnet-Routing): "
    read -r user_subnet
    [[ -n "$user_subnet" ]] && advertise_arg="--advertise-routes=${user_subnet}"

    echo -n "Als Exit Node fungieren? (j/n): "
    read -r exitnode_answer
    [[ "$exitnode_answer" == "j" ]] && exitnode_arg="--advertise-exit-node"

    echo -n "Tailscale DNS aktivieren? (j/n): "
    read -r dns_answer
    [[ "$dns_answer" == "j" ]] && dns_arg="--accept-dns=true" || dns_arg="--accept-dns=false"

    echo -e "${GREEN}Aktiviere IPv4 & IPv6 Forwarding...${RESET}"
    sudo sysctl -w net.ipv4.ip_forward=1
    sudo sysctl -w net.ipv6.conf.all.forwarding=1
    sudo sed -i 's/^#\?net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sudo sed -i 's/^#\?net.ipv6.conf.all.forwarding=.*/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf

    sudo systemctl enable --now tailscaled
    sudo tailscale up $advertise_arg $exitnode_arg $dns_arg
    echo -e "${GREEN}Tailscale wurde gestartet. Jetzt ggf. im Browser autorisieren.${RESET}"
fi

# --- DynDNS mit ipv64.net ---
echo -n "Möchtest du DynDNS mit ipv64.net einrichten? (j/n): "
read -r dyndns_answer
if [[ "$dyndns_answer" == "j" ]]; then

    # Sicherstellen, dass curl vorhanden ist
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${YELLOW}curl ist erforderlich für DynDNS und wird jetzt installiert...${RESET}"
        apt update && apt install -y curl
    fi

    read -p "Key: " ipv64_key
    read -p "Domain (z. B. meine-domain.ipv64.net): " ipv64_domain
    read -p "Update-Intervall in Minuten (z. B. 5): " ipv64_interval
    read -p "Ordner zum Speichern des Update-Scripts (z. B. /home/deinuser/scripts): " ipv64_folder
    read -p "Möchtest du auch IPv6 mit aktualisieren (falls vorhanden)? (j/n): " ipv6_enable

    # Ordner erstellen, falls nicht vorhanden
    if [[ ! -d "$ipv64_folder" ]]; then
        echo -e "${GREEN}Ordner $ipv64_folder wird erstellt...${RESET}"
        mkdir -p "$ipv64_folder"
    fi

    # Pfad zur Datei
    ipv64_script_path="$ipv64_folder/update_ipv64.sh"

    echo -e "${GREEN}Erstelle DynDNS-Update-Script unter ${ipv64_script_path}...${RESET}"
    cat <<EOF > "$ipv64_script_path"
#!/bin/bash

IP_FILE="/tmp/last_public_ip.txt"
CURRENT_IP=\$(curl -s https://api64.ipify.org)

if [ ! -f "\$IP_FILE" ]; then
  echo "\$CURRENT_IP" > "\$IP_FILE"
fi

LAST_IP=\$(cat "\$IP_FILE")

if [ "\$CURRENT_IP" != "\$LAST_IP" ]; then
  echo "IP hat sich geändert: \$LAST_IP → \$CURRENT_IP"
  curl -sSL "https://ipv64.net/nic/update?key=${ipv64_key}&domain=${ipv64_domain}"
  echo "\$CURRENT_IP" > "\$IP_FILE"
else
  echo "IP ist gleich geblieben: \$CURRENT_IP"
fi
EOF

    # IPv6-Erweiterung ergänzen
    if [[ "$ipv6_enable" == "j" ]]; then
        cat <<'EOF' >> "$ipv64_script_path"

# IPv6 aktualisieren
CURRENT_IPV6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n1)

if [[ -n "$CURRENT_IPV6" ]]; then
  echo "IPv6 erkannt: $CURRENT_IPV6 – Sende Update an ipv64.net"
  curl -sSL "https://ipv64.net/nic/update?key=${ipv64_key}&domain=${ipv64_domain}&ipv6=1"
fi
EOF
    fi

    chmod +x "$ipv64_script_path"

    # Cronjob hinzufügen, wenn noch nicht vorhanden
    if ! crontab -l 2>/dev/null | grep -q "$ipv64_script_path"; then
        (crontab -l 2>/dev/null; echo "*/$ipv64_interval * * * * $ipv64_script_path") | crontab -
        echo -e "${GREEN}Cronjob wurde hinzugefügt (alle $ipv64_interval Minuten).${RESET}"
    else
        echo -e "${YELLOW}Cronjob existiert bereits – wird nicht erneut hinzugefügt.${RESET}"
    fi

    # Temporäres einmaliges Update-Script
    echo -e "${GREEN}Sende sofortiges Initial-Update an ipv64.net...${RESET}"
    temp_update_script="/tmp/ipv64_temp_update.sh"

    cat <<EOF > "$temp_update_script"
#!/bin/bash
curl -sSL "https://ipv64.net/nic/update?key=${ipv64_key}&domain=${ipv64_domain}"
EOF

    if [[ "$ipv6_enable" == "j" ]]; then
        cat <<EOF >> "$temp_update_script"
curl -sSL "https://ipv64.net/nic/update?key=${ipv64_key}&domain=${ipv64_domain}&ipv6=1"
EOF
    fi

    chmod +x "$temp_update_script"
    "$temp_update_script"
    rm -f "$temp_update_script"

    echo -e "${GREEN}DynDNS-Update mit ipv64.net eingerichtet.${RESET}"
else
    echo -e "${RED}DynDNS wird nicht eingerichtet.${RESET}"
fi

# --- Zusammenfassung ---
echo -e "\n${GREEN}╔════════════════════════════════════╗"
echo -e "║         SETUP-ZUSAMMENFASSUNG      ║"
echo -e "╚════════════════════════════════════╝${RESET}"

if [[ "$static_ip_choice" == "j" ]]; then
  echo -e "🌐 Statische IP gesetzt: $static_ip"
  echo -e "🛣  Gateway: $gateway"
  echo -e "🧭 DNS: $dns1${dns2:+, $dns2}"
else
  echo -e "🌐 Statische IP nicht konfiguriert"
fi

[[ "$curl_antwort" == "j" ]] && echo -e "✅ curl installiert"
[[ "$docker_antwort" == "j" ]] && echo -e "✅ Docker installiert"
[[ "$compose_antwort" == "j" ]] && echo -e "✅ Docker Compose installiert"
[[ "$portainer_install" == "j" ]] && echo -e "✅ Portainer installiert"
[[ "$portainer_install" == "j" && "$start_portainer" == "j" ]] && echo -e "🟢 Portainer läuft unter https://${ip_address}:9443"
[[ "$vdsm_antwort" == "j" && "$start_vdsm" == "j" ]] && echo -e "🟢 VDSM läuft unter http://${ip_address}:5000"
[[ "$adguard_install" == "j" && "$start_adguard" == "j" ]] && echo -e "🟢 AdGuard läuft unter http://${ip_address}:3000"
[[ "$tailscale_install" == "j" ]] && echo -e "🟢 Tailscale läuft $( [[ -n "$user_subnet" ]] && echo "| Subnet: $user_subnet" ) $( [[ "$exitnode_answer" == "j" ]] && echo "| Exit Node" ) $( [[ "$dns_answer" == "j" ]] && echo "| DNS aktiv" || echo "| DNS aus" )"
[[ "$dyndns_answer" == "j" ]] && echo -e "🔁 DynDNS aktiv für ${ipv64_domain} (alle ${ipv64_interval} Min) → $ipv64_script_path"
