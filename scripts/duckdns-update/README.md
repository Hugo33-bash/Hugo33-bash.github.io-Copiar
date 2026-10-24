# DuckDns-update

Es un script que funciona en basj que mantiene actualizado tu direccion IP pública de mis dominios de [DuckDNS].

# ¿Qué problema resuelve?

Unos de los mayores problemas de la IP publica que nos da nuestra operadora es que puede cambiar por el tiempo sin avisar. Mis servicios (Nextcloud, Colabora) se ppublican con dominios de DuckDNS y si la IP publica cambia mi dominio sige apuntando a la IP publica antigua, dejando de ser accesible fuerra de intenet.

El script le dice a DuckDNS cuál es mi IP publica actual. Se ejecuta cada pocos minutos con cron asi que el dominio siempre apunta al sitio correcto.

## Requisitos minimos
- Linux con 'bash' y 'curl'.
- Una cuenta de DuckDNS con su **token** y al menos un **subdominio**.

## El script

```bash
#!/bin/bash
echo "url=https://www.duckdns.org/update?domains=tu-subdominio,otro-subdominio&token=TU_TOKEN_AQUI&ip=" \
  | curl -k -o ~/duckdns.log -K -
```
## Explicación
`#!/bin/bash` Indica al sistema dearchivos que se ejecuta en bash.
`echo "url=..."`Escribe una linea cone formato 'url=Direccion', que es lo que 'curl' espera leer de un archivo de configuración.
`domains=a,b` Subdominios a actulizar sin .duckdns.org separados por comas y sin espacios. Una sola llamada actuliza todos.
`token=...` Credencial d mi cuenta DuckDNS.
`ip=` Al dejar la IP vacía, DuckDNS usa la IP desde la que llega la petición, es decir, mi IP pública actual. No hace falta averiguarla.
| `\` | Continúa la orden en la línea siguiente, solo para que sea más legible. |
| `\|` (tubería) | Envía lo que escribe `echo` como entrada de `curl`. |
| `curl -K -` | `-K` indica que la configuración viene de un archivo, y el `-` significa "léelo de la entrada estándar". Por eso la URL llega por la tubería. |
| `-o ~/duckdns.log` | Guarda la respuesta de DuckDNS en `~/duckdns.log` en vez de mostrarla por pantalla. |
| `-k` | Desactiva la comprobación del certificado HTTPS (ver [limitaciones](#limitaciones-conocidas)). |

### ¿Por qué pàsar la URL por la tubería?

Si el token fuera el agumento `curl` (`curl "https://...token=..."`), cualquier usuario del servidor prodria verlo ejecutado 'ps' Al pasarlo por la entrada estándar, no apparece en la lista de procesos.

### ¿Que es lo que responde duckDNS?
- 'OK': La actulizacion se hico bien.
- 'KO': hubo un problema. Casi siempre es el tocke incorrecto o un nombre de dominipo mal escrito.
