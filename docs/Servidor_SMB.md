# Creación de un servidor SAMBA en Ubuntu Server

| | |
|---|---|
| **Autor** | Hugo Lázaro Lahuerta |
| **Actividad** | Creación y configuración de un servidor SAMBA |
| **Profesor** | Miguel Martínez Ordoñez |
| **Fecha** | 14/11/25 |

## Índice

- [1. Qué es SMB](#1-qué-es-smb)
  - [Versiones de SMB / Samba](#versiones-de-smb--samba)
  - [¿Qué pasa si configuramos versiones obsoletas?](#qué-pasa-si-configuramos-versiones-obsoletas)
  - [¿Qué versión se debe configurar hoy en día?](#qué-versión-se-debe-configurar-hoy-en-día)
- [2. Configurar la red](#2-configurar-la-red)
- [3. Configurar un servidor Ubuntu con SAMBA](#3-configurar-un-servidor-ubuntu-con-samba)
  - [3.1 Instalación de Samba](#31-instalación-de-samba)
  - [3.2 Verificación del servidor](#32-verificación-del-servidor)
  - [3.3 Configuración del firewall](#33-configuración-del-firewall)
  - [3.4 Directorio compartido y usuarios](#34-directorio-compartido-y-usuarios)
  - [3.5 Configuración de Samba](#35-configuración-de-samba)
  - [3.6 Verificar sintaxis y reiniciar](#36-verificar-sintaxis-y-reiniciar)
  - [3.7 Acceder desde Windows](#37-acceder-desde-windows)
- [Fuentes](#fuentes)

---

## 1. Qué es SMB

**SMB** (*Server Message Block*) es un protocolo de red que permite compartir archivos, directorios, impresoras y otros recursos entre equipos dentro de una red local. La idea principal es que varios usuarios o dispositivos puedan acceder a la misma información de forma segura, rápida y controlada.

### Un poco de historia

SMB lo creó originalmente **IBM** y más tarde lo adoptó Microsoft, hasta convertirse en el protocolo principal de carpetas compartidas en sistemas Windows.

**Samba** implementa este protocolo para que los sistemas **Linux** puedan comunicarse y compartir recursos con sistemas **Windows** de forma compatible.

### Versiones de SMB / Samba

A lo largo del tiempo han ido saliendo varias versiones de SMB, con sus equivalentes en Samba:

| Versión SMB | Rama Samba | Resumen |
|---|---|---|
| **SMB1** (CIFS) | Samba 1.x | La más antigua, insegura y lenta. Totalmente desaconsejada hoy |
| **SMB2** | Samba 3.x | Más eficiente y segura que SMB1 |
| **SMB3** (3.0 – 3.1.1) | Samba 4.x | La más segura y la recomendada actualmente |

#### SMB1 (Samba 1.x)

- También se conoce como **CIFS** (*Common Internet File System*).
- Es la versión más antigua de SMB.
- Tiene graves vulnerabilidades, como las que explotó **WannaCry en 2017**.
- Su rendimiento es bajo.
- Hoy en día está totalmente desaconsejada.

#### SMB2 (Samba 3.x)

- Lo introdujo Microsoft con **Windows Vista** y **Windows Server 2008**.
- Es mucho más eficiente y seguro que SMB1.
- Mejora la velocidad y reduce el número de mensajes necesarios para acceder a los recursos.
- Samba añadió compatibilidad en versiones posteriores de la rama 3.x.

#### SMB3 / SMB 3.0 – 3.1.1 (Samba 4.x)

- Se introdujo en **Windows 8, Windows 10** y **Windows Server 2012** en adelante.
- Aporta:
  - Cifrado de datos en la comunicación.
  - Mejor autenticación.
  - Mucho mejor rendimiento.
- Es la versión más segura y la recomendada actualmente.
- Samba 4 implementó casi todas las funciones modernas de SMB3.

### ¿Qué pasa si configuramos versiones obsoletas?

Si configuramos SMB1 o versiones anteriores aparecen varios problemas:

1. **Vulnerabilidades de seguridad**: SMB1 es extremadamente inseguro. Permite ataques como ransomware, escalada de privilegios o accesos no autorizados.
2. **Incompatibilidad con sistemas modernos**: Windows 10/11 vienen con SMBv1 desactivado por defecto.
3. **Peor rendimiento**: los protocolos antiguos consumen más ancho de banda y tardan más en transferir datos.

### ¿Qué versión se debe configurar hoy en día?

- Lo correcto es **SMBv3**, y mejor todavía **SMB v3.1.1**, que es la versión más segura y moderna, y es compatible con equipos Windows y Linux actuales.
- En los servidores SMB se suelen **deshabilitar** las versiones obsoletas para evitar brechas de seguridad.

---

## 2. Configurar la red

Para la interfaz de red hay que modificar el adaptador de red de VirtualBox. En mi caso lo puse en modo **solo anfitrión** (*Host-Only*) para tener conexión entre mi ordenador y la máquina virtual.

Configuración del adaptador en VirtualBox:

| Opción | Valor |
|---|---|
| Adaptador | Adaptador 1 |
| Conectado a | Adaptador sólo anfitrión |
| Nombre | VirtualBox Host-Only Ethernet Adapter |
| Tipo de adaptador | Intel PRO/1000 MT Desktop (82540EM) |
| Modo promiscuo | Denegar |
| Cable conectado | Sí |

<!-- Captura: configuración del adaptador de red en VirtualBox -->

Después configuramos la tarjeta de red dentro del servidor, editando `/etc/netplan/01-network-manager-all.yaml` (o el fichero que tengáis en vuestro equipo):

```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
```

---

## 3. Configurar un servidor Ubuntu con SAMBA

### 3.1 Instalación de Samba

Lo primero es instalar Samba con el gestor de paquetes `apt`. Para poder hacerlo, antes hay que **cambiar la interfaz a modo red NAT**, para que la máquina tenga salida a internet. Así instalamos **samba** y el **firewall** (`ufw`):

```bash
sudo apt install samba ufw -y
```

### 3.2 Verificación del servidor

Para comprobar que Samba funciona bien y sin errores:

```bash
sudo systemctl status samba
```

En la captura se ve que el servicio `samba-ad-dc.service` (Samba AD Daemon) aparece como `inactive (dead)` por una condición no cumplida (`exec-condition`). Es normal en este caso: ese servicio es el de controlador de dominio y aquí montamos un servidor de archivos independiente.

<!-- Captura: systemctl status samba -->

### 3.3 Configuración del firewall

Lo siguiente es permitir las conexiones SSH y Samba, y activar el firewall:

```bash
sudo ufw allow ssh          # permitimos conexiones SSH por el puerto 22/TCP
sudo ufw allow samba        # permitimos el tráfico de Samba (entrada y salida)
sudo ufw enable             # activamos el firewall
```

Revisamos el estado del firewall:

```bash
sudo ufw status
```

```text
Firewall is active and enabled on system startup
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
Samba                      ALLOW       Anywhere
22/tcp (v6)                ALLOW       Anywhere (v6)
Samba (v6)                 ALLOW       Anywhere (v6)
```

### 3.4 Directorio compartido y usuarios

Creamos la carpeta que vamos a compartir:

```bash
sudo mkdir /home/hugo/carpeta_compartida
```

Para compartirla en la red necesitamos crear un usuario en el servidor de archivos:

```bash
sudo adduser user_smb
```

Comprobamos que se ha creado en `/etc/passwd`:

```text
user_smb:x:1001:1001:,,,:/home/user_smb:/bin/bash
```

Damos de alta el usuario en Samba y le asignamos una contraseña, que será la que nos permita acceder al directorio compartido desde Windows:

```bash
sudo smbpasswd -a user_smb
```

```text
New SMB password:
Retype new SMB password:
Added user user_smb.
```

Por último, damos permisos sobre la carpeta para que solo `user_smb` y `hugo` tengan control sobre ella (propietario `user_smb`, grupo `hugo`):

```bash
sudo chown -R user_smb:hugo ./carpeta_compartida/
```

### 3.5 Configuración de Samba

Con los permisos de la carpeta listos, editamos el archivo de configuración principal de Samba:

```bash
sudo nano /etc/samba/smb.conf
```

Nos vamos al **final del todo** del archivo y añadimos la configuración de la carpeta que queremos compartir:

```ini
[carpetacompartida]
    comment = Samba en Ubuntu Server
    path = /home/hugo/carpeta_compartida/
    read only = no
    writable = yes
    blowsable = yes
    guest ok = no
    public = no
```

> ⚠️ **Ojo con el typo:** en mi captura puse `blowsable` en vez de `browsable`. Samba lo ignora y lo avisa en el `testparm` (lo vemos en el paso siguiente). El parámetro correcto es `browsable = yes`.

#### Explicación de parámetros

| Parámetro | Qué hace |
|---|---|
| `path` | Ruta de la carpeta que se comparte |
| `read only = no` / `writable = yes` | Permite acceso de lectura **y escritura** |
| `browsable` | Hace que la carpeta sea visible en la red |
| `guest ok = no` | No se permite acceso de invitados |
| `public = no` | El recurso no es público (hace falta autenticarse) |

### 3.6 Verificar sintaxis y reiniciar

Comprobamos que el archivo de configuración no tiene errores con `testparm`:

```bash
sudo testparm
```

```text
Load smb config files from /etc/samba/smb.conf
Unknown parameter encountered: "blowsable"
Ignoring unknown parameter "blowsable"
Loaded services file OK.
Weak crypto is allowed by GnuTLS (e.g. NTLM as a compatibility fallback)

Server role: ROLE_STANDALONE

Press enter to see a dump of your service definitions
```

Aquí aparece el aviso del parámetro mal escrito (`blowsable`), pero el fichero carga bien (`Loaded services file OK`) y el rol del servidor es `ROLE_STANDALONE`.

Si no hay errores, comprobamos el estado del servicio `smbd`:

```bash
sudo systemctl status smbd
```

```text
● smbd.service - Samba SMB Daemon
     Loaded: loaded (/usr/lib/systemd/system/smbd.service; enabled; preset: enabled)
     Active: active (running) since Sat 2025-11-22 15:12:29 UTC; 7s ago
     Status: "smbd: ready to serve connections..."
```

> 💡 Para aplicar cambios en `smb.conf` hay que reiniciar el servicio con `sudo systemctl restart smbd`. El `status` solo sirve para ver que está corriendo.

### 3.7 Acceder desde Windows

En el explorador de archivos (o en la línea de comandos) escribimos y ejecutamos:

```text
\\192.168.56.102\carpeta_compartida
```

Nos pedirá las credenciales de red. Introducimos el usuario y la contraseña que asignamos con `smbpasswd`. En mi caso: usuario `hugo` y contraseña `1234` (solo para pruebas en laboratorio, nunca uses una contraseña así en un servidor real).

Si las credenciales son correctas, se abre la carpeta compartida (en la captura aparece vacía, ya que todavía no habíamos metido nada).

<!-- Capturas: ventana "Seguridad de Windows" pidiendo credenciales y carpeta compartida abierta -->

---

## Fuentes

- [Install and configure Samba — Ubuntu tutorials](https://ubuntu.com/tutorials/install-and-configure-samba#1-overview)
