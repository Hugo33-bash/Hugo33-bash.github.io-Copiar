#!/bin/bash
#
# Health check de Nextcloud y Collabora Online
# Si alguno de los dos no responde correctamente, envía un aviso por email.
#
# REQUISITO: necesitas tener configurado un comando "mail" funcional en el
# sistema (ssmtp, msmtp o mailutils apuntando a un relay SMTP, por ejemplo
# Gmail). Más abajo tienes instrucciones para instalar msmtp si no lo tienes.

# ============ CONFIGURACIÓN: rellena con tus datos ============

# URLs a comprobar (ajusta si usas otro dominio/puerto)
NEXTCLOUD_URL="https://minextcloud2.duckdns.org/status.php"
COLLABORA_URL="https://minextcloud2-docx01.duckdns.org/hosting/discovery"

# Destinatario del aviso
EMAIL_TO="tu-correo@gmail.com"
EMAIL_FROM="alertas@tudominio.com"

# Log de la última comprobación
LOGFILE="/var/log/healthcheck-nextcloud.log"

# Archivo para no enviar el mismo aviso repetidamente cada 5 minutos.
# Solo avisa la primera vez que detecta la caída, y una vez cuando se recupera.
STATE_NEXTCLOUD="/tmp/.nextcloud_down"
STATE_COLLABORA="/tmp/.collabora_down"

# Archivo para controlar el envío del resumen diario (solo una vez al día)
LAST_SUMMARY_FILE="/tmp/.healthcheck_last_summary"

# ============ FUNCIONES ============

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TODAY=$(date '+%Y-%m-%d')

log() {
    echo "${TIMESTAMP} - $1" >> "${LOGFILE}"
}

send_alert() {
    local subject="$1"
    local body="$2"
    echo -e "${body}" | mail -s "${subject}" -r "${EMAIL_FROM}" "${EMAIL_TO}"
}

check_service() {
    local name="$1"
    local url="$2"
    local state_file="$3"

    # -s silencioso, -o descarta el cuerpo, -w solo imprime el código HTTP,
    # --max-time 10 evita que el script se quede colgado si no responde
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${url}")

    if [ "${HTTP_CODE}" = "200" ]; then
        log "${name} OK (HTTP ${HTTP_CODE})"
        # Si antes estaba caído y ahora responde, avisa de la recuperación
        if [ -f "${state_file}" ]; then
            send_alert " ${name} recuperado" "${name} ha vuelto a responder correctamente (HTTP ${HTTP_CODE}) a las ${TIMESTAMP}."
            rm -f "${state_file}"
        fi
        echo "OK"
    else
        log "${name} FALLO (HTTP ${HTTP_CODE})"
        # Solo avisa la primera vez que detecta el fallo, no cada 5 minutos
        if [ ! -f "${state_file}" ]; then
            send_alert " ${name} no responde" "${name} no está respondiendo correctamente.\n\nURL: ${url}\nCódigo HTTP recibido: ${HTTP_CODE}\nHora: ${TIMESTAMP}"
            touch "${state_file}"
        fi
        echo "FALLO (HTTP ${HTTP_CODE})"
    fi
}

# ============ EJECUCIÓN ============

RESULT_NEXTCLOUD=$(check_service "Nextcloud" "${NEXTCLOUD_URL}" "${STATE_NEXTCLOUD}")
RESULT_COLLABORA=$(check_service "Collabora" "${COLLABORA_URL}" "${STATE_COLLABORA}")

# ============ RESUMEN DIARIO ============
# Envía un correo una vez al día (la primera vez que se ejecuta el script
# ese día) confirmando el estado, aunque no haya habido ningún fallo.

LAST_SUMMARY=""
if [ -f "${LAST_SUMMARY_FILE}" ]; then
    LAST_SUMMARY=$(cat "${LAST_SUMMARY_FILE}")
fi

if [ "${LAST_SUMMARY}" != "${TODAY}" ]; then
    send_alert "📋 Resumen diario - Nextcloud/Collabora" "Resumen del estado a las ${TIMESTAMP}:\n\n- Nextcloud: ${RESULT_NEXTCLOUD}\n- Collabora: ${RESULT_COLLABORA}"
    echo "${TODAY}" > "${LAST_SUMMARY_FILE}"
    log "Resumen diario enviado"
fi
