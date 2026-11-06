# Montaje e instlacion de Proxmox Backups Server

*Guia resumida paso a paso*

Preparar un servidor PBS y conectarlo con Proxmox VE para disponer de un destino centralizado donde almacenar copias de seguridad.

## 0. Requistios

Para montar un Servidor de BAckups necesitamos un disco duro donde volcar las backups, yo en mi caso usare un disco de 1TB HDD.

## 1. Introducción

En esta guía explica cómo montar un servidor Proxmox Backups Server (PBS) dentro de un entrono Proxmox VE. LA idea es perparar una maquina virtual,  instalar PBS, configuurar un disco para guardar las copias de seguridad y, por último, concectar con ese servidor con Proxmox Ve para poder utilizar como almacenamiento de backups.

![Descarga de la ISO de Proxmox Backup Server](imagenes/01-descarga-iso-pbs.png)

## 2. Descargar y cargar las ISO

El primer paso es descargar la imagen ISO de Proxmox Backups Server desde la página oficial de descargas de Proxmox: *https://www.proxmox.com/en/downloads*. Una vez descargada, entramos en la interfaz web de proxmo Ve ya vamos al almacenamiento local de nodo (local/pve) > Imágenes ISO > Cargar: Seleccionamos la ISO de PBS y esperamos a quie termine la subida.

![Carga de la ISO en el almacenamiento local de Proxmox VE](imagenes/02-cargar-iso-proxmox.png)

##3. Crear la máquina virtual

Con la ISO ya donsponible,creamos una máquina virtual desde «Crear VM» En el ejemplo de las capturas se utiliza el nombre «Pbs-backups», el ID 105, 2 núcleos de CPU, 2048 MB de memoria y un disco virtual de 32 GB sobre el almacenamiento RAID1. En la pestaña de sistema se selecciona la ISO de Proxmox Backup Server como media de instalación. Esto valores son los del ejemplo y se pueden adaptar a los recursos del equipo.

![Resumen de la creación de la máquina virtual](imagenes/03-crear-vm-confirmar.png)

## 4. Instalar Proxmox Backups Server

Arrancamos la máquina virtual y seguimos el asistente de instalación.
Primero aceptamos el acuerdo de licencia y continuamos.

![Acuerdo de licencia (EULA)](imagenes/04-eula.png)

Después revisamos el disco de destino donde se instalará PBS. Hay que comprobarlo con cuidado, porque el instalador indica que los datos del disco seleccionado se eliminaran.
![Selección del disco de destino en el instalador de PBS](imagenes/05-instalador-pbs.png)

## 5. Configurar la red

Durante la instalación configuramos los datos de red que permitirán acceder al servidor desde el navegador, siendo estos la IP local + la máscara en formatos CIDR, la puerta de enlace.

![Configuración de red de gestión](imagenes/06-configuracion-red.png)

## 6. Crear el almacenamiento de copias 

Una vez dentro de la interaz web del PBS, entramos en «Administration» > «Storage / Disks» y comprbamos los discos disponibles.

![Storage / Disks en la interfaz web de PBS](imagenes/07-storage-disks-zfs.png)

En el ejemplo se utiliza el disco /dev/sdb, de 1TB para crear un almacenamiento ZFS. Pulsamos «Create: ZFS», indicamos un nombre en este caso Pbs-backups1

![Ventana Create: ZFS](imagenes/08-crear-zfs.png)
![Datastore Pbs-backups1 en el menú lateral de PBS](imagenes/09-menu-datastore.png)

## 7. Comprobar el DataStore

Después de crearlo, el nuevo almacenamiento aparece ene el apartado «Datastore» en el menú lateral de PBS.

## 8. Añadir PBS a Proxmox VE 

Para que Proxmox pueda enviar copias de seguridad al servidor PBS volvemos a la interfaz de Proxmox Ve y entramos en DataCenter > Almacenamiento > Agregar Proxmox Backup Server.

![Menú Agregar en Datacenter > Almacenamiento](imagenes/10-agregar-almacenamiento-pbs-menu.png)

Luego de eso rellenamos el campo: ID para identificar el almacenamiento, dirección IP del servidor PBS, usuario con @pem y contraseña del servidor, y el mismo nombre datasotre que le pusimos dentro del servidor PBS.

![Formulario Agregar: Proxmox Backup Server](imagenes/11-agregar-pbs-formulario.png)

## 9. Programación de Backups

### 9.1 Explicación 

En este tutorial, explicaremos como hacer algo tan sencillo, como una programación de backups en proxmox backups server.

### 9.2 Configuración

Nos vamos a nivel de DataCenter > respaldo > y le damos Agegar:

![Apartado Respaldo en Datacenter](imagenes/12-respaldo-datacenter.png)


Una vez dando a agregar, veremos nodo, el almacenamiento que estamos usando, una de las cosas mas importantes que es cuando vamos a hacer la programación:

![Opciones de programación del trabajo de respaldo](imagenes/13-opciones-programacion.png)

En mi caso lo pondré cada Lunes a Viernes: por hora, luego nos saldrá que maquinas virtuales queremos que se haga el backup, yo incluiré el servidor NAs que tengo una Nube Privada en el cual subo documentos diariamnte , Una vez incluida las maquinas virtuales que queremos que se haga backup, le damos a crear progrmación.

![Crear: Trabajo de respaldo](imagenes/14-trabajo-respaldo.png)
