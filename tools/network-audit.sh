#!/usr/bin/env bash
# Быстрый аудит сетевой безопасности: что слушает, куда смотрит, чем защищено.
set -uo pipefail

echo "== Внешние слушатели (TCP, не loopback) =="
ss -H -tln 2>/dev/null | awk '$4 !~ /^127\./ && $4 !~ /^\[::1\]/ {print "  "$4}' | sort -u || true

echo "== UDP не-loopback =="
ss -H -uln 2>/dev/null | awk '$4 !~ /^127\./ {print "  "$4}' | sort -u | head -10 || true

echo "== Firewall =="
systemctl is-active lanblock.service 2>/dev/null | sed 's/^/  lanblock: /'
if command -v nft >/dev/null && nft list table inet lanblock >/dev/null 2>&1; then
  echo "  правила lanblock: загружены"
else
  echo "  правила lanblock: нет доступа (нужен root) или не загружены"
fi

echo "== Wi-Fi соединение =="
nmcli -t -f NAME,TYPE,SECURITY connection show --active 2>/dev/null | sed 's/^/  /' | head -5

echo "== DNS =="
if command -v resolvectl >/dev/null; then resolvectl status 2>/dev/null | grep -E 'DNS Servers|DNS Domain' | head -3 | sed 's/^/  /'; else grep nameserver /etc/resolv.conf 2>/dev/null | head -3 | sed 's/^/  /'; fi

echo "== Входящие по netwatch =="
tail -1 /home/j0schi/Program/Strata/netwatch/netwatch.log 2>/dev/null | sed 's/^/  /'
echo "  INBOUND событий: $(grep -c "INBOUND" /home/j0schi/Program/Strata/netwatch/alerts.log 2>/dev/null || echo 0)"
