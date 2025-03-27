#!/bin/bash

ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
  echo -e "\e[31m❌ Dieses Setup-Script ist nur für ARM64-Systeme vorgesehen. Beendet.\e[0m"
  exit 1
fi

# Farben
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# ── Statische IP-Konfiguration über API ---
echo -n "Möchtest du eine statische IP-Adresse konfigurieren (via API)? (j/n): "
read -r ip_antwort
if [[ "$ip_antwort" == "j" ]]; then
    read -p "Gib die IP-Adresse ein: " STATIC_IP
    read -p "Gib das Subnetz ein (CIDR, z. B. 24): " CIDR
    read -p "Gib das Gateway ein: " GATEWAY
    read -p "Gib das Interface ein (z. B. eth0): " INTERFACE

    echo "Sende Konfigurationsdaten an lokale API oder Konfigurationsdienst..."
    curl -X POST http://localhost:8000/set-static-ip \
      -H "Content-Type: application/json" \
      -d '{
            "interface": "'$INTERFACE'",
            "ip": "'$STATIC_IP'",
            "cidr": "'$CIDR'",
            "gateway": "'$GATEWAY'"
          }'
fi

# ── System aktualisieren ──────────────────────────────────────
echo -n "Möchtest du ein Update und Upgrade durchführen? (j/n): "
read -r update_system
if [[ "$update_system" == "j" ]]; then
  echo -e "\n🔄 System wird aktualisiert..."
  sudo apt update && sudo apt upgrade -y
else
  echo "⏩ System-Update übersprungen."
fi

# ── Installation von curl ---
echo -n "Möchtest du curl installieren? (j/n): "
read -r curl_antwort
if [[ "$curl_antwort" == "j" ]]; then
    sudo apt install -y curl
fi

# ── Installation von Docker und Docker Compose ---
echo -n "Möchtest du Docker und Docker Compose installieren? (j/n): "
read -r docker_antwort
if [[ "$docker_antwort" == "j" ]]; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo apt install -y docker-compose
fi

# ── Portainer ---
echo -n "Möchtest du Portainer einrichten? (j/n): "
read -r portainer_antwort
if [[ "$portainer_antwort" == "j" ]]; then
    docker volume create portainer_data
    docker run -d -p 9000:9000 --name portainer --restart always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data portainer/portainer-ce
fi

# ── VDSM ---
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

# ── Tailscale ──────────────────────────────────────────────────
echo -n "Möchtest du Tailscale installieren und einrichten? (j/n): "
read -r tailscale_install
if [[ "$tailscale_install" == "j" ]]; then

  # curl installieren falls nicht vorhanden
  if ! command -v curl >/dev/null 2>&1; then
    echo -e "\n⚠️  'curl' ist nicht installiert. Wird jetzt automatisch installiert..."
    sudo apt update && sudo apt install -y curl
  fi

  # Tailscale installieren
  curl -fsSL https://tailscale.com/install.sh | sh

  # Parameter vorbereiten
  advertise_arg=""
  exitnode_arg=""
  dns_arg=""

  # Subnet-Routing abfragen (inkl. Vorschlag & Validierung)
  echo -n "Möchtest du Subnet-Routing aktivieren? (j/n): "
  read -r subnet_enable

  if [[ "$subnet_enable" == "j" ]]; then
    auto_subnet=$(ip -o -f inet addr show | awk '/scope global/ {
        split($4, a, "/");
        split(a[1], ip, ".");
        printf "%s.%s.%s.0/24", ip[1], ip[2], ip[3];
        exit
    }')
    echo -e "\n🔍 Vorgeschlagenes Subnetz: ${auto_subnet}"
    echo -n "Möchtest du dieses Subnetz verwenden? (j/n): "
    read -r use_auto_subnet

    if [[ "$use_auto_subnet" == "j" ]]; then
      advertise_arg="--advertise-routes=${auto_subnet}"
    else
      echo -n "Bitte Subnetz manuell eingeben (z. B. 192.168.178.0/24): "
      read -r user_subnet

      if [[ "$user_subnet" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
        advertise_arg="--advertise-routes=${user_subnet}"
      else
        echo "⚠️ Ungültiges Subnetz – Subnet-Routing wird übersprungen."
      fi
    fi
  fi

  # Exit Node abfragen
  echo -n "Als Exit Node fungieren? (j/n): "
  read -r exitnode_answer
  [[ "$exitnode_answer" == "j" ]] && exitnode_arg="--advertise-exit-node"

  # DNS aktivieren?
  echo -n "Tailscale DNS aktivieren? (j/n): "
  read -r dns_answer
  [[ "$dns_answer" == "j" ]] && dns_arg="--accept-dns=true" || dns_arg="--accept-dns=false"

  # IPv4/IPv6 Forwarding aktivieren – nur wenn Subnet-Routing aktiv ist
  if [[ -n "$advertise_arg" ]]; then
    echo -e "\n🌐 Subnet-Routing aktiv – aktiviere IPv4 & IPv6 Forwarding..."
    sudo sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
    sudo sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
  fi

  # Zusammenfassung anzeigen
  echo -e "\n🚀 Tailscale wird mit folgenden Optionen gestartet:"
  [[ -n "$advertise_arg" ]] && echo "   ➤ Subnet Routing: ${advertise_arg#--advertise-routes=}"
  [[ -n "$exitnode_arg" ]] && echo "   ➤ Exit Node: aktiviert"
  echo "   ➤ DNS: $( [[ "$dns_arg" == "--accept-dns=true" ]] && echo "aktiviert" || echo "deaktiviert" )"

  echo -n "Möchtest du Tailscale jetzt mit diesen Einstellungen starten? (j/n): "
  read -r confirm_tailscale
  if [[ "$confirm_tailscale" == "j" ]]; then
    echo -e "\n🌐 Bitte öffne den folgenden Link im Browser, um dich mit Tailscale zu verbinden:"
    sudo tailscale up $advertise_arg $exitnode_arg $dns_arg --qr 2>&1 | tee tailscale-login.log
    echo -e "\n✅ Tailscale wurde gestartet (Login-Link oben oder QR-Code)."
  else
    echo -e "⏩ Start von Tailscale wurde abgebrochen."
  fi

  [[ "$tailscale_install" == "j" ]] && echo -e "\n🟢 Tailscale läuft $( [[ -n "$advertise_arg" ]] && echo "| Subnet Routing aktiv" ) $( [[ "$exitnode_answer" == "j" ]] && echo "| Exit Node" ) $( [[ "$dns_answer" == "j" ]] && echo "| DNS aktiv" || echo "| DNS aus" )"
else
  echo "⏩ Tailscale wird nicht installiert."
fi

# ── DynDNS ---
echo -n "Möchtest du DynDNS einrichten? (j/n): "
read -r dyndns_antwort
if [[ "$dyndns_antwort" == "j" ]]; then
    read -p "Gib deinen DynDNS-Namen ein: " DYNDNS_NAME
    read -p "Gib deinen DynDNS-Benutzernamen ein: " DYNDNS_USER
    read -p "Gib dein DynDNS-Passwort ein: " DYNDNS_PASS
    # Beispiel für die DynDNS-Implementierung
    echo "DynDNS wird mit den folgenden Informationen eingerichtet:"
    echo "Name: $DYNDNS_NAME"
    echo "Benutzer: $DYNDNS_USER"
    # Hier würde der Befehl zur Aktualisierung des DynDNS stehen
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
[[ "$tailscale_install" == "j" ]] && echo -e "🟢 Tailscale läuft $( [[ -n "$advertise_arg" ]] && echo "| Subnet Routing aktiv" ) $( [[ "$exitnode_answer" == "j" ]] && echo "| Exit Node" ) $( [[ "$dns_answer" == "j" ]] && echo "| DNS aktiv" || echo "| DNS aus" )"
[[ "$dyndns_answer" == "j" ]] && echo -e "🔁 DynDNS aktiv für ${ipv64_domain} (alle ${ipv64_interval} Min) → $ipv64_script_path"

# Falls VDSM installiert und gestartet wurde, Logs anzeigen
if [[ "$vdsm_antwort" == "j" && "$start_vdsm" == "j" ]]; then
  echo -n "Logs von VDSM jetzt anzeigen? (j/n): "
  read -r final_logs_vdsm
  if [[ "$final_logs_vdsm" == "j" ]]; then
      echo -e "${GREEN}Öffne Logs für VDSM...${RESET}"
      docker logs -f vdsm
  fi
fi

