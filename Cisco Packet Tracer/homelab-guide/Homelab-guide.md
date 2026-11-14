# Manual de homelab Cisco Packet Tracer

**Guía paso a paso para crear la red del homelab:** VLANs en el switch, un router que hace de OPNSense, un router que hace de operadora y las ACLs entre VLANs. Todo está basado en lo que se configuró y probó en el proyecto.

**Autor:** Hugo Lázaro Lahuerta

---
## Arquitectura

<img width="679" height="717" alt="image" src="https://github.com/user-attachments/assets/1ffba452-fedd-4eb0-9359-79fc0142a9cd" />

## 1. Qué se construye

| Nombre en Packet Tracer | Función real | Qué hace |
| :--- | :--- | :--- |
| R2 | Internet | Conecta PC0 y Server0 |
| R3 | Router de la compañía de Internet | NAT y reenvío de puertos |
| R0 | Router que usa OPNsense | VLANs, NAT, reenvío de puertos y ACLs |
| Switch 1 | Switch TP-Link | Separa las VLANs y las lleva juntas por un cable troncal hasta R0 |

Las tres redes (Internet, operadora y casa) usan doble NAT: los servidores se conectan al exterior a través de R0, y R0 a través de R3.

---

## 2. Plan de direccionamiento

| VLAN | Nombre | Subred | Servidores |
| :---: | :--- | :--- | :--- |
| 10 | DATOS | 192.168.10.0/24 | NAS .2, FTP .3 |
| 20 | MINECRAFT | 192.168.20.0/24 | Minecraft .2 |
| 30 | PROXY | 192.168.30.0/24 | NPM .2 |
| 40 | GESTIÓN | 192.168.40.0/24 | Pve .2, PBS .3 |
| 50 | CLIENTES | 192.168.50.0/24 | PC administración |

### Conexiones entre routers

| Enlace | Un extremo | Otro extremo |
| :--- | :--- | :--- |
| R2 -> R3 | R2: 203.0.114.2 | R3: 203.0.114.1 |
| R3 -> R0 | R3: 192.168.1.1 | R0 (WAN): 192.168.1.2 |

Parte de internet: red `198.168.100.0/24`. R2 `192.168.100.0/24`, Server0 `192.168.100.3`, PC0 `192.168.100.2`, el gateway de PC0 y Server0 es `192.168.100.1`.
Se usa este rango de red en vez de `192.168.x.x` porque las ACLs bloquean todo `192.168.0.0/16`. Si se usara este rango también bloquearía la salida de "internet".

---

## 3. Cableado e interfaces

| Equipo | Interfaz | Conecta con |
| :--- | :--- | :--- |
| R0 | g0/0/0 | R3 (WAN) |
| R0 | g0/0/1 | Switch1 (troncal) |
| R3 | g0/0/0 | R2 |
| R3 | g0/0/1 | R0 |
| Switch 1 | Gi0/1 | R0 |
| Switch 1 | Fa0/1 a Fa0/6 | NPM, Pve, PBS, Minecraft, NAS, FTP (en ese orden) |
| Switch 1 | Fa0/x | PC Administración |

**Regla importante:** la IP debe ponerse en el puerto donde está conectado el cable. Un error común es poner la IP en otro puerto. Para revisarlo, pasa el ratón por cada cable en Packet Tracer (verás los puertos de los dos lados) y compáralos con `show ip interface brief`.

---

## 4. Configuración paso a paso

### Paso 0: Ponle nombre a cada router
Los tres routers muestran el mismo texto (`Router#`), así que es fácil pegar los comandos en el router que no toca. En cada uno, ponle su respectivo nombre:

```text
configure terminal
! Cambia el nombre del prompt. Hazlo con R0, R3 o R2 según el router
hostname R0
```

### Paso 1: Lado de internet (R2, PC0 y Server0)

```text
! En R2
configure terminal
interface g0/0/0
! Gateway de PC0 y Server
ip address 198.51.100.1 255.255.255.0
```

En PC0 pon IP `192.168.100.2` y gateway `192.168.100.1`. En Server0, IP `192.168.100.3` y el gateway `192.168.100.1`. Si el gateway no está en la misma subred que el equipo, este no sale de su red.

### Paso 2: Switch1 (VLANs y troncal)
El switch mantiene separadas las redes. Los puertos de los servidores son de acceso (el servidor no necesita conocer las VLANs). Solo el puerto que va a R0 es troncal, porque transporta varias VLANs al mismo tiempo.

```text
enable
configure terminal
! Crear las 5 VLANs (el nombre es solo una etiqueta)
vlan 10
name DATOS
vlan 20
name MINECRAFT
vlan 30
name PROXY
vlan 40
name GESTION
vlan 50
name CLIENTES
exit

! Cada puerto de servidor se mete en su VLAN
interface fa0/1
! Acceso: el puerto pertenece a una sola VLAN
switchport mode access
! NPM en la VLAN 30
switchport access vlan 30

interface range fa0/2-3
switchport mode access
! Pve y PBS en la VLAN 40
switchport access vlan 40

interface fa0/4
switchport mode access
! Minecraft en la VLAN 20
switchport access vlan 20

interface range fa0/5 - 6
switchport mode access
! NAS y FTP en la VLAN 10
switchport access vlan 10

! Puerto hacia R0
interface gig0/1
! Troncal = lleva varias VLANs etiquetadas (802.1Q)
switchport mode trunk
! Solo permite las 5 VLANs que existen
switchport trunk allowed vlan 10,20,30,40,50

! Puerto del PC de administración (cambia X por el puerto que uses)
interface fa0/X
switchport mode access
switchport access vlan 50
```

### Paso 3: R0 (OPNsense): VLANs, WAN y NAT
Las VLANs necesitan un router para poder comunicarse entre ellas. Como todas pasan por un cable, R0 crea una subinterfaz para cada VLAN (técnica llamada "router-on-a-stick"). El puerto físico no tiene IP; las IP se ponen en las subinterfaces.

Para configurar NAT, cada interfaz se marca como `inside` (red interna) o `outside` (lado de internet). NAT solo funciona con paquetes que van de `inside` a `outside`. Si una marca está mal, no hará la traducción.

```text
configure terminal

! WAN: el cable hacia R3
interface g0/0/0
ip address 192.168.1.2 255.255.255.0
! Este es el lado exterior
ip nat outside
no shutdown

! LAN: el cable hacia el switch
interface g0/0/1
! La interfaz física no lleva IP
no ip address
no shutdown

! Una subinterfaz por VLAN (el gateway de cada red)
interface g0/0/1.10
! El número debe coincidir con la VLAN; si no, esa red queda aislada
encapsulation dot1Q 10
ip address 192.168.10.1 255.255.255.0
! Lado interior del NAT
ip nat inside

interface g0/0/1.20
encapsulation dot1Q 20
ip address 192.168.20.1 255.255.255.0
ip nat inside

interface g0/0/1.30
encapsulation dot1Q 30
ip address 192.168.30.1 255.255.255.0
ip nat inside

interface g0/0/1.40
encapsulation dot1Q 40
ip address 192.168.40.1 255.255.255.0
ip nat inside

interface g0/0/1.50
encapsulation dot1Q 50
ip address 192.168.50.1 255.255.255.0
ip nat inside

! Salida a Internet
! Ruta por defecto: lo que no sea red propia se manda a R3 (el vecino de al lado)
ip route 0.0.0.0 0.0.0.0 192.168.1.1

! Lista 1: indica qué redes se traducen (192.168.x.x). No filtra tráfico
access-list 1 permit 192.168.0.0 0.0.255.255

! NAT con sobrecarga: todas las VLANs salen compartiendo la IP de g0/0/0
ip nat inside source list 1 interface g0/0/0 overload
```

#### Reenvío de puertos (lo que llega a la WAN va a un servidor)
```text
! Formato: ip nat inside source static tcp [IP-local] [puerto] [IP-global] [puerto]
ip nat inside source static tcp 192.168.30.2 80 192.168.1.2 80
ip nat inside source static tcp 192.168.30.2 443 192.168.1.2 443
ip nat inside source static tcp 192.168.20.2 25565 192.168.1.2 25565
```
Si tus servidores tienen otras IP, cambia las direcciones de las tres últimas líneas.

### Paso 4: R3 (operadora): NAT y reenvío, sin VLANs
R3 solo ve un equipo: la conexión WAN de R0. Por eso no necesita rutas a las VLANs, ya que NAT en R0 las oculta.

```text
configure terminal

! Hacia R2 (Internet)
interface g0/0/0
ip address 203.0.114.1 255.255.255.0
ip nat outside
no shutdown

! Hacia R0
interface g0/0/1
ip address 192.168.1.1 255.255.255.0
ip nat inside
no shutdown

! Ruta por defecto hacia R2
ip route 0.0.0.0 0.0.0.0 203.0.114.2

! Red que se traduce: la del enlace con R0
access-list 1 permit 192.168.1.0 0.0.0.255
ip nat inside source list 1 interface g0/0/0 overload

! Reenvíos: lo que llega a la IP pública pasa a la WAN de R0, que a su vez lo manda al servidor final
ip nat inside source static tcp 192.168.1.2 80 203.0.114.1 80
ip nat inside source static tcp 192.168.1.2 443 203.0.114.1 443
ip nat inside source static tcp 192.168.1.2 25565 203.0.114.1 25565
```

### Paso 5: Servidores y PC (interfaz gráfica)
En cada Server-PT entra en **Desktop -> IP Configuration** y configura una IP fija de la tabla del punto 2, máscara `255.255.255.0` y Gateway `192.168.<VLAN>.1`. El PC de administración (VLAN 50) usa `192.168.50.2` con Gateway `192.168.50.1`.

En el Server-PT de NPM, pestaña **Services**, activa HTTP (y HTTPS para el 443); si está apagado, no aceptará las conexiones.

---

## 5. Pruebas de conectividad (antes de las ACLs)
Haz estas pruebas antes de poner las ACLs: cuando estén activadas, un servidor ya no podrá hacer ping a su propio gateway.

| Donde | Prueba | Debe pasar |
| :--- | :--- | :--- |
| Switch 1 | `show vlan brief` | Cada puerto en su VLAN |
| Switch 1 | `show interfaces trunk` | El troncal permite las 5 VLANs |
| R0, R3, R2 | `show ip interface brief` | Cada IP en su interfaz, todo up/up |
| R0 | `ping 192.168.1.1` | Responde (R3) |
| Un servidor | Ping a su Gateway y a un servidor de otra VLAN | Responde (aún no hay ACLs) |
| NAS | `ping 192.168.100.2` | Responde: la salida con doble NAT funciona |
| R0 | `show ip nat translations` justo después | Aparece una entrada de `192.168.10.2` traducida a `192.168.1.2` |
| PC0 | Navegador a `http://203.0.114.1` | Carga la página de NPM |
| PC0 | `ping 203.0.114.1` | Responde, pero solo valida R2 y R3: esa IP es el propio R3 y no pasa por el NAT |

---

## 6. ACLs en R0
Sin ACLs, todas las VLANs pueden comunicarse entre sí. Las ACLs permiten que cada servicio se comunique solo con los equipos que necesita; se coloca una ACL en la entrada (`in`) de cada subinterfaz. Cada ACL indica: ¿qué puede iniciar un equipo de esta VLAN?

| VLAN | Qué puedo iniciar | Por qué |
| :--- | :--- | :--- |
| 10 DATOS | Solo salir a internet | Es almacenamiento: otros le piden cosas |
| 20 MINECRAFT | Solo salir a internet | Es el servicio con más riesgos, se aísla del todo |
| 30 PROXY | VLAN 10 por 80 y 443, e internet | Solo necesita llegar a lo que publica |
| 40 GESTIÓN | VLAN 10 e internet | Los backups necesitan llegar al NAS |
| 50 CLIENTES | TODO | Es la VLAN desde la que se administra |

No hay ACL entre equipos de una misma VLAN, porque ese tráfico no pasa por el router.
Las ACLs se revisan de arriba a abajo y se aplica la primera regla que coincide; por eso el orden es importante.

```text
configure terminal

ip access-list extended ACL_DATOS
! Las ACLs de Cisco no recuerdan conexiones: estas dos líneas dejan pasar
! las RESPUESTAS (si no, nada que se pida entre VLANs volvería)
permit tcp any any established
permit icmp any any echo-reply
! Bloquea cualquier conexión NUEVA hacia cualquier red 192.168.x.x
deny ip any 192.168.0.0 0.0.255.255
! Lo que queda es tráfico hacia Internet, que se permite
permit ip any any

ip access-list extended ACL_MINECRAFT
permit tcp any any established
permit icmp any any echo-reply
! Minecraft no puede iniciar nada hacia ninguna VLAN
deny ip any 192.168.0.0 0.0.255.255
permit ip any any

ip access-list extended ACL_PROXY
permit tcp any any established
permit icmp any any echo-reply
! Excepción: el NPM puede llegar a la VLAN 10 por HTTP y HTTPS
permit tcp 192.168.30.0 0.0.0.255 192.168.10.0 0.0.0.255 eq 80
permit tcp 192.168.30.0 0.0.0.255 192.168.10.0 0.0.0.255 eq 443
deny ip any 192.168.0.0 0.0.255.255
permit ip any any

ip access-list extended ACL_GESTION
permit tcp any any established
permit icmp any any echo-reply
! Excepción: Pve y PBS pueden llegar a la VLAN 10 (backups)
permit ip 192.168.40.0 0.0.0.255 192.168.10.0 0.0.0.255
deny ip any 192.168.0.0 0.0.255.255
permit ip any any

ip access-list extended ACL_CLIENTES
! La VLAN de administración tiene acceso total
permit ip 192.168.50.0 0.0.0.255 any

! Aplicar cada ACL en la entrada de su subinterfaz
interface g0/0/1.10
ip access-group ACL_DATOS in

interface g0/0/1.20
ip access-group ACL_MINECRAFT in

interface g0/0/1.30
ip access-group ACL_PROXY in

interface g0/0/1.40
ip access-group ACL_GESTION in

interface g0/0/1.50
ip access-group ACL_CLIENTES in
```

Antes de copiar estos comandos, comprueba con `show ip interface brief` que existen las 5 subinterfaces y que cada una tenga su IP. Si la subinterfaz no existe, el comando `interface g0/0/1.10` crea una vacía y la ACL no funcionará.

Después comprueba:
```text
! Debe listar las 5 ACLs extendidas, además de la lista 1
show access-lists

! Debe decir "Inbound access list is ACL_DATOS" (repetir con .20, .30, .40 y .50)
show ip interface g0/0/1.10
```

---

## 7. Prueba de seguridad
Lo más importante es comprobar lo que tiene que fallar. Un firewall que permite todo puede parecer que funciona, aunque esté mal configurado.

### Debe funcionar:
| Origen | Prueba |
| :--- | :--- |
| PC (VLAN 50) | Ping al NAS, a Pve y a Minecraft |
| NPM | Abrir por HTTP la web NAS (con HTTP activo en el NAS) |
| Pve | Ping al NAS |
| NAS, NPM y Minecraft | Ping a `192.168.100.2` |
| PC0 | `http://203.0.114.1` |

### Debe fallar:
| Origen | Prueba | Qué demuestra |
| :--- | :--- | :--- |
| Minecraft | Ping al NAS, a Pve y al PC de VLAN 50 | Está aislado |
| NPM | Ping al NAS (pero su HTTP sí funciona) | Un proxy solo tiene abiertos el 80 y el 443 |
| NPM | Ping a Pve | Un proxy comprometido no llega a la gestión |
| NAS | Ping a Pve y al PC de la VLAN 50 | Los datos no inician conexiones hacia dentro |
| Pve | Ping a PC de la VLAN 50 | Gestión solo habla con datos |
| PC0 | Ping a una IP interna (ej. `192.168.30.2`) | Desde internet no se ve el interior |
| PC0 | `ftp 203.0.114.1` | Solo están reenviados el 80, 443 y 25565 |

Para saber qué regla se ha aplicado, ejecuta `show access-list` en R0 antes y después de cada prueba: el número de matches de la regla `deny` aumenta cuando se bloquea una conexión. En el modo simulación de Packet Tracer (icono del reloj) puedes ver por dónde pasa el paquete paso a paso.
