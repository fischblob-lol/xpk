#!/usr/bin/env bash
echo "[!] This file is not meant to be ran on its own, rather it is executed from the install script."
echo "[!] Quit if you are running the script standalone by pressing CTRL + C"
echo "[*] Begin in 5 seconds."
sleep 5
echo "[*] Getting the XPK binary"
curl -o /tmp/xpkbin https://github.com/fischblob-lol/xpk/releases/download/beta/xpk
echo "[*] Setting up XPK"
sudo mv /tmp/xpkbin /usr/bin
sudo mkdir -p /opt/xpk
sudo mkdir -p /opt/xpk/repos
sudo mkdir -p /opt/xpk/db
echo "[*] Done"
