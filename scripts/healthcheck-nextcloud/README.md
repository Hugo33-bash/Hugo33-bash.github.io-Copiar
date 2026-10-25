# nextcloud-healhcheck

Script en bash que vigila **Nextcloud** y **Collabora Online** y envia un correo cuando alguno deja de responder.

## ¿Qué problema resuelve?

Si Nextcloud o Collabora sea caen, no me entero hasta que intento usarlo. Este escript comprueba cada 5 minutos y el me avisa.

- **Avisa una sola vez** Cuado es servicio se cae.
- **Avisa una sola vez** Cuando el servicio se levanta.
- Con un **resumen diario** que confirma que la vigilancia sigua funcionado. Si un dia no llega ese correo, es la señal de que falla el propio sistema de avisos.

## Como funciona 

```mermaid
flowchart TD
    A[cron cada 5 min] --> B[curl a la URL del servicio]
    B --> C{¿Responde HTTP 200?}
    C -- Sí --> D{¿Existe el archivo de estado?}
    D -- Sí --> E[Correo de recuperación<br/>y borra el archivo de estado]
    D -- No --> F[Solo escribe en el log]
    C -- No --> G{¿Existe el archivo de estado?}
    G -- No --> H[Correo de caída<br/>y crea el archivo de estado]
    G -- Sí --> I[Solo escribe en el log]
