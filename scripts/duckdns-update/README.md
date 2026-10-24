# DuckDns-update

Es un script que funciona en bash que mantiene actualizado tu direccion IP pública de mis dominios de [DuckDNS].

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
<br/>
`echo "url=..."`Escribe una linea cone formato 'url=Direccion', que es lo que 'curl' espera leer de un archivo de configuración.
<br/>
`domains=a,b` Subdominios a actulizar sin .duckdns.org separados por comas y sin espacios. Una sola llamada actuliza todos.
<br/>
`token=...` Credencial d mi cuenta DuckDNS.
<br/>
`ip=` Al dejar la IP vacía, DuckDNS usa la IP desde la que llega la petición, es decir, mi IP pública actual. No hace falta averiguarla.
<br/>
| `\` | Continúa la orden en la línea siguiente, solo para que sea más legible. |
<br/>
| `\|` (tubería) | Envía lo que escribe `echo` como entrada de `curl`. |
<br/>
| `curl -K -` | `-K` indica que la configuración viene de un archivo, y el `-` significa "léelo de la entrada estándar". Por eso la URL llega por la tubería. |
<br/>
| `-o ~/duckdns.log` | Guarda la respuesta de DuckDNS en `~/duckdns.log` en vez de mostrarla por pantalla. |
<br/>
| `-k` | Desactiva la comprobación del certificado HTTPS (ver [limitaciones](#limitaciones-conocidas)). |

### ¿Por qué pàsar la URL por la tubería?

Si el token fuera el agumento `curl` (`curl "https://...token=..."`), cualquier usuario del servidor prodria verlo ejecutado 'ps' Al pasarlo por la entrada estándar, no apparece en la lista de procesos.

### ¿Que es lo que responde duckDNS?
- 'OK': La actulizacion se hico bien.
- 'KO': hubo un problema. Casi siempre es el tocke incorrecto o un nombre de dominipo mal escrito.

## Instalacion
```bash
sudo cp duckdns-update.sh /usr/local/bin/duckdns-update.sh
sudo chmod 700 /usr/local/bin/duckdns-update.sh```

Con 'chmod 700'm siki el propietario puede leer y ejecutar el archivo, lo que protege el tokende otros usuarios.

## Cómo probarlo

 ```bash
/usr/local/bin/duckdns-update.sh
cat ~/duckdns.log
```
## Automatizarlo con cron

```bash
crontab -e
```

*/5 * * * * /usr/local/bin/duckdns-update.sh >/dev/null 2>&1
*/5 * * * * Lo ejecuta cada 5 minutos.
>/dev/null 2>&1 descarta la salida de la terminal. El resultado real queda guardado en `~/duckdns.log`.

### ¿Cómo sé que el cron funciona?

Cada ejecución **sobrescribe** `~/duckdns.log`, así que la fecha de modificación del archivo indica cuándo se ejecutó el script por última vez:

```bash
ls -l ~/duckdns.log
cat ~/duckdns.log
```
 
Si la fecha es de hace pocos minutos y el contenido es `OK`, todo va bien.
 
## Limitaciones conocidas
 
- **`-k` desactiva la verificación del certificado.** Con DuckDNS no hace falta, porque su certificado es válido, y debilita la conexión: permitiría un ataque de intermediario. Quitar el `-k` es seguro y recomendable.
- **El log se sobrescribe en cada ejecución.** Solo conserva la última respuesta, sin historial. Si hay un `KO` y luego un `OK`, el fallo se pierde.
- **No avisa si falla.** Si DuckDNS responde `KO`, nadie se entera.
- **No tiene tiempo máximo de espera.** Si DuckDNS no responde, `curl` puede quedarse esperando mucho tiempo.
- **El token está dentro del script.** Es sencillo, pero quien pueda leer el archivo puede ver el token.
- **Los nombres tienen que coincidir exactamente** con los de DuckDNS. Una letra de diferencia produce `KO`.
- **No funciona con CGNAT.** Si el operador no da una IP pública real, DuckDNS apuntará a una IP que no es accesible desde fuera.
## Posibles mejoras
 
- Quitar `-k` y añadir `--max-time 20`.
- Añadir fecha a cada respuesta y guardarla con `>>` para tener historial.
- Registrar los errores con `logger` para verlos con `journalctl`.
- Enviar un correo si la respuesta no es `OK`.
- Separar el token en un archivo de configuración con permisos `600`.



Debe aparecer 'OK'. Para comprobar que detecta errores, cambia un carácter del token y repite la prueba: debe aparecer KO
