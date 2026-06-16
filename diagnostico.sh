#!/bin/bash
# diagnostico.sh — Diagnóstico básico para ejecución remota
# Uso: ./diagnostico.sh
# Recopila datos sin depender de config.txt ni requerir privilegios

trap 'echo "Diagnóstico interrumpido"; exit 1' SIGINT SIGTERM

echo "════════════════════════════════════════════════════"
echo "DIAGNÓSTICO REMOTO"
echo "════════════════════════════════════════════════════"
echo "Fecha: $(date +"%Y-%m-%d %H:%M:%S")"
echo "Host: $(hostname)"
echo "Usuario: $(id -un)"
echo "Sistema: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Desconocido}")"
echo "Kernel: $(uname -r)"
echo "Núcleos CPU: $(nproc 2>/dev/null || echo "N/A")"
echo "Memoria:"
free -h 2>/dev/null || echo "  No disponible"
echo "Disco raíz:"
df -h / 2>/dev/null || echo "  No disponible"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "════════════════════════════════════════════════════"

exit 0
