# Servidor FTP con ProFTPD
Guia paso a paso para montar un servidor FTP en Ubuntu Server 24.04 con **ProFTPD** uusarios por grupos, jaula chroot acceso anónimo de solo lectura, TLS y proteccion con fail2ban.

> **Valores ficticios.** IPs, dominio, usuario y purtos son ejemplos. '<Contraseña segurad>': elige las tuyas.

## Datos del ejemplo
| Dato | Valor |
| Maquina | VM 104 en Proxmox, hostname 'ftp-demo' |
| SO | Ubutnu Server 24.04 LTS |
| IP | '192.168.50.24' |
| Dominio | 'homelab-demo.duckdns.org` |
| Puerto de control | '50000-50100' |
|Raiz del FTP | '/srv/ftp'|

## Que vamos a conseguir

| Usuarios | Grupo | Carpetas accesibles |
| ftpadmin | - | Todas (es el propietario) |
| 'dev1', 'dev2' | 'dev' | 'desarrollo' y 'publico'|
| 'tecnico1' | 'sistemas' | 'sistemas' y 'publico' |
| 'anonymous' | - | Solo 'publico' en solo lectura |

## 1. Instalación 

```bash
sudo apt update
sudo apt install proftpd-basic tree -y
sudo systemctl status proftpd
```

## 2. Estructura de carpetas
 
```bash
sudo mkdir -p /srv/ftp/{desarrollo,publico,sistemas}
tree /srv/ftp
```
## 3. Grupos y usuarios
 
```bash
# Grupos de trabajo
sudo groupadd dev
sudo groupadd sistemas
sudo groupadd ftpusers   # todos los usuarios con acceso a la carpeta pública
 
# Administrador del FTP
sudo useradd ftpadmin -s /bin/false -M -N
 
# Desarrolladores
sudo useradd dev1 -s /bin/false -g dev -G ftpusers -M -N
sudo useradd dev2 -s /bin/false -g dev -G ftpusers -M -N
 
# Técnico de sistemas
sudo useradd tecnico1 -s /bin/false -g sistemas -G ftpusers -M -N
 
# Contraseñas (se piden por teclado)
sudo passwd ftpadmin
sudo passwd dev1
sudo passwd dev2
sudo passwd tecnico1

**Que singnifica cada accion**
| Opción | Efecto |
|---|---|
| '-s /bin/false' | El usuario no puede abrir una shell: Solo sirve para FTP'
| '-M' | No crea carpeta '/home' |
| '-N' | No crea grupo |
| '-g' / '-G' | Grupo principal / grupo secundario |

> `useradd` **no asigna contraseña**. Sin el `passwd` posterior, la cuenta no puede iniciar sesión.

## 4. Propietarios y permisos
 
```bash
sudo chown ftpadmin:ftpadmin /srv/ftp
sudo chmod 755 /srv/ftp
 
sudo chown ftpadmin:dev       /srv/ftp/desarrollo
sudo chown ftpadmin:sistemas  /srv/ftp/sistemas
sudo chown ftpadmin:ftpusers  /srv/ftp/publico
 
sudo chmod 770  /srv/ftp/desarrollo
sudo chmod 770  /srv/ftp/sistemas
sudo chmod 2775 /srv/ftp/publico
 
ls -la /srv/ftp
```
## 5. Configuración de ProFTPD
 
Haz una copia de seguridad y edita el fichero:
 
```bash
sudo cp /etc/proftpd/proftpd.conf /etc/proftpd/proftpd.conf.bak
sudo nano /etc/proftpd/proftpd.conf

Deja estas directivas (el resto del fichero puede quedar por defecto):

```apache
UseIPv6              off
ServerName           "Servidor FTP | Servicios Tecnicos"
ServerType           standalone
DefaultServer        on
 
# Puerto de control y puertos pasivos
Port                 2221
PassivePorts         50000 50100
MasqueradeAddress    homelab-demo.duckdns.org
 
# Jaula: cada usuario queda confinado en /srv/ftp
DefaultRoot          /srv/ftp
 
# Permite usuarios con shell /bin/false
RequireValidShell    off
 
# Límite de procesos simultáneos
MaxInstances         10
 
# Permisos de archivos nuevos: 664 para ficheros, 775 para carpetas
Umask                002 002
AllowOverwrite       on
 
# Solo pueden iniciar sesión el admin y los grupos dev y sistemas
<Limit LOGIN>
  AllowUser   ftpadmin
  AllowGroup  OR dev,sistemas
  DenyAll
</Limit>
 
# Acceso anónimo: solo lectura y solo la carpeta pública
<Anonymous /srv/ftp/publico>
  User          ftp
  Group         nogroup
  UserAlias     anonymous ftp
  DirFakeUser   on ftp
  DirFakeGroup  on ftp
  MaxClients    5
 
  <Limit LOGIN>
    AllowAll
  </Limit>
 
  <Directory *>
    <Limit WRITE>
      DenyAll
    </Limit>
  </Directory>
</Anonymous>
```

**Explicacíon de las directivas clave**
| Directiva | Que hace |
|---|---|
| 'DefaultRoot /srv/ftp' | Chroot: el usuario ve '/srv/ftp' como si fuera '/'. No puedo salir al resto del sistema |
| 'RequireValidShell off' | Por defecto ProFTPD rechaza usuarios cuya shell no esté en '/etc/shells'. Con '/bin/false' hace falta desactivarlo. |
| 'PassivePort' | Rango Fijo de puertos en modo pasivo, **Nota:** estos mismos puertos luego hay que abrirlos en el router |
| 'MasqueradeAddress' | va detras de NAT, y se utiliza para definir el nombre de domino o ip publica.
| 'AllowGroup OR' | es suficiente con cumplir las condiciones (ser 'ftpadmin' **o** estar 'dev' o 'sistemas') |
| '<Anonymous /srv/ftp/publico>' | El anónimo queda enjaulado en 'publico', sin ver las demás carpetas |

Valida la sintaxis y reinicia:

```bash
sudo proftpd -t
sudo systemctl restart proftpd
sudo systemctl status proftpd
ss -tlnp | grep 2221
```

## 6. Cifrado con TLS 
Es necesario si el usuario se expone a internet.

### 6.1 Certificado autofirmado 

```bash
sudo openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /etc/ssl/private/proftpd.key \
  -out /etc/ssl/certs/proftpd.crt \
  -subj "/CN=homelab-demo.duckdns.org"
sudo chmod 600 /etc/ssl/private/proftpd.key
``
## 6.2 Activacion de modulo 

```apache
<IfModule mod_tls.c>
  TLSEngine                 on
  TLSLog                    /var/log/proftpd/tls.log
  TLSProtocol               TLSv1.2 TLSv1.3
  TLSRSACertificateFile     /etc/ssl/certs/proftpd.crt
  TLSRSACertificateKeyFile  /etc/ssl/private/proftpd.key
  TLSOptions                NoSessionReuseRequired
  TLSVerifyClient           off
  TLSRequired               on
</IfModule>
```

Inclúyelo al final de `proftpd.conf`:

 
```apache
Include /etc/proftpd/tls.conf
```

### 6.3 Instalar y cargar el módulo

El paquete base de ProFTPD **no incluye** el modulo TLS:

```bash
sudo apt install proftpd-mod-crypto
ls /usr/lib/proftpd/ | grep tls    # debe aparecer mod_tls.so
```
Antes de reiniciar, da permiso al perfil de AppArmor para leer el certificado y clave. Son esto, ProFTPD puede no arrancar.
Los pasos están en la [sección 10.6](#106-apparmor-y-los-ficheros-de-tls).

### 6.5 Validar y reiniciar

```bash
sudo proftpd -t && sudo systemctl restart proftpd
```

### 7.1 En el servidor (ufw)
 
```bash
sudo ufw allow 2221/tcp
sudo ufw allow 50000:50100/tcp
sudo ufw enable
sudo ufw status
```
### 7.2 En el router (reenvío de puertos)
| Puertos externos | Protocolo | IP destino | Puertos interno |
| --- | --- | --- |
| 2221  | TCP | 192.168.50.24 | 2221 |
| 50000-50100  | TCP | 192.168.50.24 | 50000-50100 |

Para que el nombre `homelab-demo.duckdns.org` apunte siempre a tu IP pública, mantén el cliente de actualización de DuckDNS en ejecución (por ejemplo, con una tarea de `cron`).

Bloquea las IPs que fallan el inicio de sesión varias veces seguidas.

```bash
sudo apt install fail2ban -y
sudo nano /etc/fail2ban/jail.local
```

```ini
[proftpd]
enabled  = true
port     = 2221
logpath  = /var/log/proftpd/proftpd.log
maxretry = 5
findtime = 10m
bantime  = 1h
```

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status proftpd
```

Verificación los logs del servidor:
 
```bash
ls -la /srv/ftp/publico
sudo tail -f /var/log/proftpd/proftpd.log
```

### 10.1 Qué es

**AppArmor** es un modulo de seguridad del kernel de Linux que limita lo que puede hacer cada programa, **aunque el usuario tenga permisos*. Cada programa protegido tiene un *perfil* cin una lista de rutas, capacidades y accessos de red permitidos. Lo que no está en la lista , se bloquea

Por eso hay **dos capas** y ambas deben permitir el acceso:

| Capa | Quién decide | Ejemplo |
| Permisos Unix ('chmod','chown') | el propietarion de cada archivo | 'drwxrwx--- ftpadmin dev' |
| AppAmor | El perfil del programa | "'proftpd' solo puede leer '/srv/ftp su el perfil lo dice" |

Un perfil puede estar en dos modos:

| Modo | Comportamiento |
| --- | --- |
| 'enforce' | Bloquea lo no permitido y lo registra en el log |
| 'complain' | Solo registra, no bloquea (sirve para depuerar) |

Recarga el perfil y reinicia el servicio:

```bash
sudo apparmor_parser -r /etc/apparmor.d/proftpd
sudo systemctl restart proftpd
```

> En este servidor (Ubuntu 24.04) el perfil se llama 'proftpd' y sus reglas locales están en '/etc/apparmor.d/local/proftpd'. En estas versiones puede llamarse 'usr.sbin.proftpd': lista '/etc/apparmor.d/' para comprobarlo.

### 10.5 Lo que no comviene hacer
- **No desctivar AppArmor entero** para "arreglarlo": pierdes esa protección en toda el sistema.
- Para comporbar si de verdad es la causa, pon el perfil en modo `complain` de forma temporal:

```bash
sudo aa-complain /usr/sbin/proftpd
# probar el FTP...
sudo aa-enforce /usr/sbin/proftpd   # volver a bloquear
```

### 10.6 AppArmor y ficheros de TLSs

Reglas necesarias:
 
| Fichero | Regla | Motivo |
|---|---|---|
| `/etc/ssl/certs/proftpd.crt` | `r,` | Leer el certificado |
| `/etc/ssl/private/proftpd.key` | `r,` | Leer la clave privada |
| `/var/log/proftpd/tls.log` | `rw,` | Escribir el log de TLS |

 
```bash
echo '/etc/ssl/certs/proftpd.crt r,' | sudo tee -a /etc/apparmor.d/local/proftpd
echo '/etc/ssl/private/proftpd.key r,' | sudo tee -a /etc/apparmor.d/local/proftpd
echo '/var/log/proftpd/tls.log rw,' | sudo tee -a /etc/apparmor.d/local/proftpd
 
sudo apparmor_parser -r /etc/apparmor.d/proftpd
```

**Si el servicio no arranca**, mira primero el log del servicio y después los bloqueos de AppArmor:
 
```bash
sudo journalctl -u proftpd -n 30
sudo journalctl -k | grep -i denied | tail
```

**Renovación del certificado:** las reglas se definen por ruta, no por contenido. Si renuevas el certificado con **los mismos nombres de fichero**, no hace falta tocar AppArmor: basta con reiniciar ProFTPD.

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| `530 Login incorrect` | Contraseña sin asignar, usuario fuera de los grupos permitidos o `RequireValidShell` activo | `sudo passwd usuario`, revisar `<Limit LOGIN>` |
| Conecta pero **no lista** el directorio (se queda colgado) | Puertos pasivos cerrados o `MasqueradeAddress` mal definido | Revisar `PassivePorts`, ufw y reenvío del router |
| `550 Permission denied` al listar con `MLSD` | Permisos de la raíz o AppArmor bloqueando la ruta | Revisar `ls -la /srv/ftp` y, si están bien, seguir la [sección 10](#10-apparmor-cuando-los-permisos-están-bien-y-aun-así-falla) |
| El servicio no arranca tras activar TLS | Falta `proftpd-mod-crypto` (error `unable to load 'mod_tls.c'`) o AppArmor bloquea el certificado, la clave o el log | `sudo journalctl -u proftpd -n 30` y `sudo journalctl -k \| grep -i denied \| tail`; ver [10.6](#106-apparmor-y-los-ficheros-de-tls) |
| `530 ... maximum number of allowed clients` | Se alcanzó `MaxClients` o `MaxInstances` | Es el comportamiento esperado; sube el límite si procede |
| `Can't open PID file` al arrancar | Aviso de systemd por el orden de arranque | Si el servicio queda `active (running)`, es inofensivo |
| `proftpd -t` da error de sintaxis | Directiva mal escrita | Leer la línea que indica y compararla con esta guía |
