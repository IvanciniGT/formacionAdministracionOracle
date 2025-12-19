
# Temas

- Almacenamiento interno: Tablespace, Segmento, Extent, **Bloque**
- Índices: Tipos, clustering factor
- Estadísticas: Tipos, como regenerarlas
- Particionamiento: Tipos, ventajas y desventajas
- Planes de ejecución.
- Memoria: SGA, PGA, Shared Pool, Buffer Cache, Redo Log Buffer
- Procesos
- Configuración
- Instalación

## Configuración

### Configuración de instancia

Esta en un archivo llamado spfile.ora.
El nombre de spfile: Server Parameter File.
Es un archivo binario.. no lo podemos tocar a mano.
Se gestiona con queries.
Si podemos sacar una vista a texto plano -> pfile.ora

Podemos pasar de un spfile a un pfile y viceversa.
Ese archivo suele estar en la raíz del ORACLE_HOME/dbs (en linux). Si estamos en windows estará en ORACLE_HOME\database.

PAra verificar el archivo que estamos usando:

```sql
SHOW PARAMETER spfile;
```

Para generar una copia en pfile:

```sql
CREATE PFILE='/ruta/del/archivo/pfile.ora' FROM SPFILE;
```

Esto es instancia:
- Memoria del servidor: SGA, PGA
- Procesos del servidor: background processes (DBWR, LGWR, SMON, PMON, etc)
- Cursors
- Conexiones

Los parametros de configuración del servidor / instancia, los podemos ver mediante unas vistas:
- V$PARAMETER: muestra los parámetros actuales de la instancia.
- V$SPPARAMETER: muestra los parámetros almacenados en el spfile.

En ocasiones tocamos estos parámetros y podeemos modificarlos en:
- Memoria (cambios temporales, se pierden al reiniciar la instancia)
- Spfile (cambios permanentes, se mantienen al reiniciar la instancia)
- Ambos (dependiendo del parámetro)

Para cambiar un parámetro:

```sql
ALTER SYSTEM SET nombre_parametro=valor [SCOPE=MEMORY|SPFILE|BOTH];
```

Siempre que vayamos a hacer un cambio en el spfile, lo primero una copia de seguridad del archivo.

A priori de esos parámetros no tocamos nada. Lo mínimo de localización, idioma, etc.
El resto nada. 
Los calculos de RAM se hacen automáticamente por Oracle. Del total que hay Oracle toma un trozo para él y lo reparte entre SGA y PGA.
Tiene 2 estrategias: 
- Automatic Memory Management (AMM): Oracle gestiona todo automáticamente.
- Automatic Shared Memory Management (ASMM): Oracle gestiona automáticamente la SGA, pero la PGA la gestionamos nosotros.

Vamos a ver que no toma mucha, y nos parece raro.
En nuestro caso tenemos 16 Gbs de RAM: SGA: 5 gigas y el agregado (total) de PGA: 1.5 Gbs.
Ha parte que consume y se reserva para SO.
Hay una parte importante de RAM que se usa por el SO... pero de la que se beneficia Oracle: caches del SO, buffers de disco, etc.
Los bloques de datos, parte los cachea Oracle en su buffer cache, pero otra parte la deja en el SO para que si se vuelve a pedir, el SO lo sirva desde ahí y no tenga que ir a disco.

A priori no tocamos nada. Simplemente cuando hay problemas de rendimiento, podemos tocar algunos parámetros.

### Parametros que solemos cambiar con más frecuencia

PROCESSES: número máximo de procesos que se pueden conectar a la instancia. ORA-00020: maximum number of processes (xxx) exceeded.
Con cuidado cuando lo toco... cada proceso usa memoria del PGA... y si me paso, dejo a los procesos sin RAM.. y:
- SWAP del SO (rendimiento pésimo)
- ORA-4031: unable to allocate memory in the user global area.

OPEN_CURSORS: número máximo de cursores abiertos por sesión. ORA-01000: maximum open cursors exceeded.

Configuraciones de memoria.. pero jugamos poco:
SGA_TARGET y PGA_AGGREGATE_TARGET: tamaño total de SGA y PGA. Si usamos AMM, no los tocamos. Si usamos ASMM, podemos tocar SGA_TARGET.

DB_RECOVERY_FILE_DEST_SIZE: tamaño máximo del área de recuperación rápida (Fast Recovery Area). Si usamos FRA, podemos tocar este parámetro.

UNDO_RETENTION: tiempo en segundos que se retienen los datos de deshacer (undo) en la base de datos. Si tenemos transacciones largas, podemos tocar este parámetro. Por defecto 900 segundos (15 minutos). Puedo subirlo si tengo transacciones largas. Prepara espacio en disco para undo.

CONTROL_FILES: ubicación de los archivos de control. Podemos tocarlo si movemos los archivos de control a otra ubicación.

---

Los problemas de memoria:

- RENDIMIENTO AL TRASTE -> El hit de la cache bajo. 90-95% es lo normal.
  -> Bloques con un pctfree incorrecto. 20% de la ram esta en la basura! 
  -> Fragmentación de los bloques -> 5-10% de la ram en la basura!
  -> Tablas sucias (entradas que no están eliminadas pero ocupan en los bloques) SHRINK TABLE. -> 30% de la ram en la basura!
  -> Tipos de datos (NUMBER, VARCHAR2)
  -> Mi servidor tiene poca RAM. (MAS SENCILLO Y RAPIDO, no barato) 

    Otro tema diferente es el PGA: (es un % mucho más pequeño de la RAM total).
    Si el servidor tiene mucha carga de trabajo concurrente, necesito más PGA.                                      MAS PROCESOS
    Si el servidor recibe consultas que necesiten mucha memoria (ordenaciones, hash joins), necesito más PGA.       CONSULTAS MÁS COMPLEJAS
                                                                                                                    QUE DEVUELVAN MUCHOS RESULTADOS
    Necesito PGA.. y necesito más RAM... la puedo quitar del SGA... pero me puedo cargar el hit de la cache.
    Si tengo un ratio del 95% de hit en la cache, puedo bajar un poco el SGA y subir el PGA.
    O subo PGA quitando RAM a SO para buffers y cache... si el hit ratio lo tengo alto, puedo permitirme bajar un poco la RAM del SO.

Queremos un nuevo tablespace con bloques de 32K en vez de 8K.
Eso implica crear un nuevo DBWR con bloques de 32K (con un buffer cache de 32K). Me viene por algo funcional.

Necesito tener 4 DBWR (Database Writer): Porque tengo varios HDD/tablespaces y quiero optimizar la escritura en disco (paralelismo).

- Memoria
- Procesos
- Estadísticas

I/O... en una BBDD bien configurada, el I debe de ser muy bajo. No leo de los HDD más que cuando arranco la BBDD o cuando la RAM no me da para todo. CACHE! 90-95%

El O.... puede ser un problema.. pero saturar hoy en día el O de un sistema es complicado. Los HDD son muy rápidos. 
Necesito un sistema con una cantidad de transacciones gigante para saturar el O... y en ese caso... Más discos y más DBWRs.
No soy capaz de escribir tanto como me piden escribir.


### Configuración de base de datos

#### Archivos de control de la base de datos

Son los que necesita la BBDD para arrancar. Conviene tenerles copia de seguridad.

```sql
SHOW PARAMETER control_files;
```

#### Archivos de redo, archive log 

Hoy en día, solemos configurar el Oracle FRA (Fast Recovery Area).

En ese área, Oracle guarda: (ubicación en disco) se guardan:
- Archivos de redo log
- Archivos de archive log
- Archivos de backup RMAN

Ese área tiene un tamaño definido (DB_RECOVERY_FILE_DEST_SIZE).
Hay otro parámetro que indica la ubicación (DB_RECOVERY_FILE_DEST).

```sql
SHOW PARAMETER db_recovery_file_dest;
SHOW PARAMETER db_recovery_file_dest_size;
```

Oracle gestiona el FRA.. Si se queda sin espacio, borra archivos antiguos de archive log y backup RMAN.
Si yo quiero tener más tiempo de recuperación con los archive log, 
    - tengo que aumentar el tamaño del FRA
    - o hacer copias de seguridad de los archive log a otro sitio y borrarlos del FRA.

---

# Instalación de Oracle

Hay varias opciones y varios productos.

Versiónes de Oracle Database:
- Enterprise Edition: versión completa, con todas las funcionalidades.
- Standard Edition: versión con funcionalidades limitadas, adecuada para pequeñas y medianas empresas.
- XE (Express Edition): versión gratuita y ligera, ideal para desarrollo y aprendizaje.
- FREE. Más funcionalidad que la XE. Limitada en CPU, RAM y tamaño de BBDD.
- RAC (Real Application Clusters): permite la creación de clústeres de bases de datos para alta disponibilidad y escalabilidad.

Una instalación la podemos hacer de 3 formas:
- Standalone: instalación en un solo servidor.
- Oracle RAC: instalación en un clúster de servidores. ACTIVO/ACTIVO. HA+Escalabilidad.
- Oracle Data Guard: configuración de alta disponibilidad y recuperación ante desastres mediante la replicación de datos entre una base de datos primaria y una o más bases de datos secundarias. ACTIVO/PASIVO.
  Las secundarias no puedo usarlas para inserciones, solo para consultas si lo habilito.

## A la hora de hacer la instalación.

### Sistema operativo:
- Linux (Red Hat, Oracle Linux, SUSE)
- Windows Server
- Solaris (menos común hoy en día) --> Linux

Solaris ha sido la apuesta de Oracle durante muchos años. Hoy en día, Linux es el SO más usado para Oracle.
Solaris tenía una gracia importante: zonas de solaris. 
  Me permitían en un único servidor físico, tener varias instancias de Oracle aisladas unas de otras.
  Esto tiene sentido en los servidores gordos de Oracle (T8, Exadata, etc).

La apuesta hoy en día es conseguir esto mismo pero en SO Linux -> Contenedores como alternativa a las zonas de Solaris.

Siempre puedo hacer una instalación a hierro!

---

# Contenedores

Un contenedor es un entorno aislado dentro de un SO Linux donde correr procesos...
Es algo así como eran las zonas de Solaris... pero más potente y más estandarizado.

Cuando trabajamos con contenedores, lo que hacemos no es instalar software. Lo que hacemos es desplegar software ya instalado de antemano en una imagen de contenedor.

Oracle nos da una serie de imágenes base para contenedores con Oracle Database ya instalado (y de paso de todo el resto de productos Oracle -que operan en servidor (los desktop no)-que queramos usar).

Ahora bien. Esas imágenes de contenedor, que descargo del registry oficial de Oracle, vienen preinstaladas como a ellos les ha venido bien.
En la mayor parte de los casos, lo tuneamos a nuestra necesidad.

Para eso nos ofrecen una serie de Dockerfiles (archivos de texto plano) junto con scripts que contienen las instrucciones para crear nuevas imágenes de contenedor a partir de las imágenes base oficiales. Esto lo ofrecen en GITHUB.

Donde sea que instale, acabo con un Linux o un Solaris... o un Windows Server.
En Windows hoy en día podemos levantar un kernel Linux y correr contenedores Linux ahí dentro (WSL2).

Otro tema.. que es lo habitual es usar kubernetes para ofrecer la HA de los contenedores. Pero esto no siempre es así en el caso de Oracle Database.

Una instalación de Oracle Database no es un Postgres o un MySQL. Son mucho más grandes! Esto requiere mucho HIERRO!
Hoy en día, es muy habitual tener BBDD postgres con 2 vCPU y 4 Gbs de RAM. para un microservicio.. y las orquesto en contenedores flotando entre nodos kubernetes.
Con Oracle NO.
Entre otras cosas, porque en las instalaciones luego tenemos restricciones a nivel de infra: Cabina de almacenamiento por fibra.
Entonces: SI TIRAMOS MUCHO DE CONTENEDORES, NO TIRAMOS DE KUBERNETES.

Los contenedores tienen ventajas claras:
- Aislamiento sin la sobrecarga de una VM.
- Reinstalación del software completa en nada de tiempo.
- Actualizaciones rápidas.
- Poder llevar la BBDD a otro entorno (producción) en poco tiempo.
- Replicar entorno

Lo que es la BBDD (archivos) van a un almacenamiento externo (NFS, cabina SAN, etc).
La instancia de Oracle corre en el contenedor.


Sigo teniendo los programas de instalación tradicionales, pero se usan para hacer las instalaciones dentro de los contenedores.

Oracle Linux es una distribución Linux basada en Red Hat Enterprise Linux (RHEL) y optimizada para ejecutar productos Oracle.
Y esa no viene con docker instalado de serie. Lo que vienes es con "podman".

La instalación la quiero automatizar como todo hoy en día... y sistematizar.

Al trabajar con contenedores, necesitaré para mi Oracle varios volúmenes.

## Volumen en contenedor.

Punto de montaje en el FS del contenedor apuntando a un almacenamiento externo al contenedor.

Los contenedores NO SON EFIMEROS. Tienen persistencia de serie! La misma que un hierro o una VM.
El problema es si borro el contenedor.. que pierdo su FS y los datos.
Lo mismo que si borro la VM.
Lo mismo que si borro el hierro.

En el Oracle normalmente trabajamos con varios volúmenes:
- Volumen para los archivos de datos (datafiles)
- Volumen para el área de recuperación rápida (FRA)
- Volumen para los archivos de redo log
- Volumen para los archivos de control backups

## La memoria RAM

No me meto tanto a gestionarla a nivel de Oracle... Oracle sabe y determina la mejor forma de usar la RAM que tiene disponible.
Lo que si hago es asignar al contenedor la RAM que quiero que use.

---

# Conexiones a una BBDD Oracle.

Antiguamente los clientes se solían conectar directamente a la instancia de Oracle.
Y los clientes tenían la responsabilidad de gestionar la conexión (pooling, reconexiones, etc).

Hoy en día lo normal (o al menos más habitual) es un usar un gestor de conexiones (connection manager) entre los clientes y la BBDD Oracle.
Ese gestor de conexiones puede ser un software específico (Oracle Connection Manager) .
Ese connection manager me gestiona en automático las conexiones, los pools, las reconexiones, etc.

Si trabajamos con un Oracle RAC, el connection manager es obligatorio.

En este connection manager se abren N conexiones a BBDD que se mantienen abiertas de continuo (300).

Cuando un cliente se quiere conectar, se le da acceso a una conexión del pool del connection manager, hace su trabajo y cuando termina, la conexión vuelve al pool del connection manager para que otro cliente la use.
Esto es mucho más eficiente que abrir y cerrar conexiones directas a la BBDD Oracle.
Y no solo más eficiente en rendimiento, sino que también en consumo de recursos (memoria, CPU) en la BBDD Oracle.

Y luego la gracia es que si el día de mañana llevo mi BBDD Oracle a otro servidor (de una instancia a otra), los clientes no tienen que cambiar nada. Siguen trabajando contra el connection manager. Me hace de enrutador

En el caso de un Oracle RAC, el connection manager es obligatorio y nos hacee además la función de balanceador de carga entre los nodos del RAC.

Es muy sencillo.
- Le abro el puerto 1521 al connection manager.
- Le configuro los servicios de BBDD a los que puede conectar por detrás.. Y les asocio un nombre lógico (service name).
- Lo que puedo configurar es un pooling de conexiones:
  - mínimo
  - máximo
  - tiempo de vida
  - tiempo de vida de inactividad
  - incrementos

Si trabajo la BBDD solo desde una app web (Weblogic) entonces el pool y la gesitón de conexiones lo hace Weblogic.... y puedo pasar de usar un connection manager.

Weblogic hoy en día está totalmente obsoleto.