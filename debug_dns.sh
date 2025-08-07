#!/bin/bash
# IP discovery script

echo "=== Raspberry Pi IP Discovery ==="

# Browser'da çalışan URL'den IP'yi öğren
echo "1. nslookup ile kontrol:"
nslookup raspberrypi.local

echo ""
echo "2. ping ile kontrol:"
ping -c 3 raspberrypi.local

echo ""
echo "3. avahi-resolve ile kontrol:"
avahi-resolve -n raspberrypi.local

echo ""
echo "4. arp tablosundan kontrol:"
arp -a | grep raspberrypi
