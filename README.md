## Dieses Shell-Script richtet einen Debian-Server automatisiert und interaktiv ein – mit Fokus auf Heimserver, Docker, Tailscale, VDSM, ipv64.net und mehr.


## ⚠️ Dieses Setup-Script ist nur für Systeme mit ARM64-Architektur geeignet.

## Features

- Optional: statische IP-Adresse konfigurieren
- System-Update & Upgrade
- Interaktive Installation von:
  - curl
  - Docker + Docker Compose
  - Portainer
  - VDSM (Virtual DSM)
  - AdGuard Home
  - Tailscale inkl. Subnet Routing, DNS, Exit Node
- Dynamisches DNS mit [ipv64.net](https://ipv64.net):
  - frei wählbares Update-Intervall in Minuten
  - optionales IPv6-Update
  - automatische Erstellung von Script und Cronjob
  - sofortiges Initial-Update beim Setup
- Übersichtliche Zusammenfassung am Ende


---
## 🛠️ Installation (manuell)

Script herunterladen
```
wget https://raw.githubusercontent.com/ra5on/debian-setup-autoinstall/refs/heads/main/setup.sh
```
Script ausführbar machen
```
chmod +x setup.sh
```
Script Starten
```
./setup.sh
```
---

## 🧰 Erklärung: Script ausführbar machen & starten

Wenn du das Script heruntergeladen oder mit `nano` erstellt hast, musst du es zunächst **ausführbar machen**, damit du es direkt starten kannst.

### 🔹 1. Rechte setzen mit `chmod +x`

```bash
chmod +x setup.sh
```

Dieser Befehl macht das Script „ausführbar“. Ohne das würdest du beim Start eine Fehlermeldung bekommen wie: `Permission denied`.

### 🔹 2. Script starten

```bash
./setup.sh
```

Das `./` bedeutet: **"führe die Datei im aktuellen Ordner aus"**.  
Du musst es so schreiben, da der aktuelle Ordner (.) normalerweise nicht automatisch im Suchpfad liegt.

---

## 🧾 Beispielhafte Zusammenfassung:

```
╔════════════════════════════════════╗
║         SETUP-ZUSAMMENFASSUNG      ║
╚════════════════════════════════════╝
🌐 Statische IP gesetzt: 192.168.x.x/24
🛣  Gateway: 192.168.x.1
🧭 DNS: 1.1.1.1, 8.8.8.8
✅ Docker installiert
✅ Docker Compose installiert
🟢 Portainer läuft unter https://192.168.x.x:9443
🔁 DynDNS aktiv für beispiel.ipv64.net (alle 5 Min)
```

## Voraussetzungen

- Debian 12 ("Bookworm") empfohlen
- Root-Rechte ("sudo" oder direkt als root)
- Aktive Internetverbindung

## Motivation

Das Ziel dieses Scripts ist es, einen neuen Debian-Server in wenigen Minuten vollständig einsatzbereit zu machen – ohne Copy-Paste, ohne ständiges Googlen und mit maximaler Transparenz.

 
Bei Fragen, Verbesserungsvorschlägen oder Pull Requests freue ich mich.










## ⚠️ Hinweis zur Nutzung

Dieses Skript wird ohne jegliche Garantie bereitgestellt und dient ausschließlich zu Lern-, Test- und Demonstrationszwecken.  
Die Ausführung erfolgt auf eigene Gefahr.

Der Autor (alias „ra5on“) übernimmt keine Verantwortung für:
- Schäden am System
- Fehlfunktionen
- Datenverluste
- rechtliche Konsequenzen

---

## 🧩 Drittsoftware & Rechte

Dieses Skript kann Drittsoftware installieren oder konfigurieren  
(z. B. Docker, Tailscale, AdGuard, VDSM usw.).

Der Autor:
- übernimmt keine Verantwortung für diese Software,
- macht sich deren Inhalte, Funktionen oder Lizenzen nicht zu eigen,
- beansprucht keine Rechte an fremder Software.

> **Alle Rechte, Marken und Verantwortlichkeiten verbleiben bei den jeweiligen Rechteinhabern.**

---

## ❗ Lizenzbedingungen beachten

Die Nutzung oder Weitergabe dieses Skripts bedeutet **keine Übertragung von Nutzungsrechten oder Garantien**.

> Besonders bei der Installation von **Synologys Virtual DSM** ist zu beachten:  
> Die Endbenutzer-Lizenzvereinbarung von Synology **verbietet** den Einsatz auf Nicht-Synology-Hardware.  
> → Verwende diesen Container ausschließlich auf offiziellen Synology NAS-Systemen.

---

## 📌 Abschluss

Die Verwendung dieses Skripts sowie aller damit ausgeführten Aktionen erfolgt **vollständig auf eigenes Risiko**.

Es ist **nicht für den produktiven Einsatz** gedacht, ohne **eigene Prüfung und Anpassung** durch den Nutzer.  
Auch bei Änderung, Erweiterung oder Automatisierung bleibt der Haftungsausschluss bestehen.
