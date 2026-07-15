#!/bin/bash
# Script pour compiler et lancer TorMenu en arrière-plan

# Dossier de travail
cd "$(dirname "$0")"

# Tue l'instance existante si elle tourne
killall TorMenu 2>/dev/null

# Recompile (pour appliquer d'éventuels changements)
swiftc TorMenu.swift -o TorMenu

# Lance en arrière-plan sans bloquer le terminal
nohup ./TorMenu >/dev/null 2>&1 &

echo "[+] TorMenu a été démarré avec succès !"
