# Migración de esa tabla a Oracle

## Sobre los tipos de datos

En Oracle, los tipos de datos son un poco más flexibles que en Postgres. Para los número usualmente usamos NUMBER. NUMBER es un tipo de datos que ocupará más o menos en función del valor que se guarde. El tipo de dato no se pone solo para controlar el tamaó en disco... también para asegurar la calidad del dato. La BBDD es la garante del dato... y debe velar por ellos. No podemos permitir que entren en BBDD datos podridos.

Dejar un campo como NUMBER (o NUMERIC en el caso de Postgres), es dejar la puerta abierta a que entren datos que no tengan sentido.

   > EDAD. Si lo defino como NUMBER, podría entrar 25.5, o 3000, o -5. Ninguno de esos datos tiene sentido para una edad. 
   
     Para ese campo, una buena definición sería: Si lo defino como NUMBER(3) (Aquí garantizo que no podrán entrar más de 3 dígitos, y además aseguro lo que van a ocupar los datos). En Oracle, los number ocupan 1 bytes por cada 2 dígitos, redondeando hacia arriba. Así que un NUMBER(3) ocupará 2 bytes en disco. Un NUMBER(4) ocuparía 2 bytes también, pero ya permitiría entrar 4 dígitos.
     Además, me interesa controlar el número de decimales. Definiré el campo como NUMBER(3,0)... sin decimales. Así, ya no podrían entrar 25.5.
     
     Como en cualquier caso, no puedo guardar ni edades negativas, ni edades imposibles (más de 120 años), añadiré una restricción CHECK (EDAD BETWEEN 0 AND 120).

     Muchos problemas a lo largo de los años vienen por no definir bien los tipos de datos.

     Una BBDD dura años/décadas.

- En ORACLE hay DEMASIADOS tipos de datos para todo! Es mucho desmadre.
  - Textos: CHAR: Son de tamaño fijo.
            VARCHAR: Es un sinónimo de VARCHAR2 hoy en día (ORACLE me dice que no lo use por si el día de mañana cambia su comportamiento).
            VARCHAR2: Es el tipo de campo que debo usar para textos de tamaño variable... que me asegura Oracle compatibilidad futura.
                      En oracle por defeeecto está limitado a 4000 bytes (en versiones viejas era de 2000 bytes). Hoy en día, se puede establecer una prop a nivel de BBDD (MAX_STRING_SIZE=EXTENDED|STANDARD) para que los VARCHAR2 puedan tener hasta 32767 bytes.
            NCHAR, NVARCHAR2: Son tipos de datos para textos Unicode (UTF-8). Si voy a guardar textos en varios idiomas, debo usar estos tipos de datos. En general los usamos poco.... controlamos el set de caracteres a nivel de BBDD. Para los americanos puede tener cierto sentido... que no tienen acentos ni caracteres especiales.
            CLOB: Character Large Object. Textos muy grandes (más de varios miles de caracteres). Oracle los guarda fuera del bloque, en otra zona de almacenamiento. Se usan para guardar DOCUMENTOS, TEXTOS MUY GRANDES, ETC. JSON, XML, YAML, ICONO GRANDE EN BASE64, ETC.
                  Aunque luego ORacle tiene tipos de datos más específicos para JSON y XML.
                  Esos campos solicitamos incluso en muchas ocasiones que no vayan a CACHE (NO CACHE) para no llenar la cache con datos que no se van a usar mucho.
                  CREATE TABLE DOCS (ID NUMBER, CONTENIDO CLOB NO CACHE);
            VARYING: No lo usamos en ORACLE. VARYNG es en oracle sinonimo de VARCHAR2. Se mantiene por compatibilidad con ANSI SQL.
                     En ANSI SQL existe el tipo de datos VARYING, pero en Oracle es sinónimo de VARCHAR2. Y NO LO USAMOS.
  - Números: 
    - NUMBER(n,m): Números. Puedo definir:
      - n: Número total de dígitos (enteros + decimales)
      - m: Número de dígitos decimales.
          Ejemplo: NUMBER(5,2) -> 999.99 es el valor máximo
        Todo número en Oracle se guarda como un tipo de dato NUMBER. Dependiendo del valor que se guarde, ocupará más o menos espacio en disco.
    - INTEGER, INT: Son sinónimos de NUMBER(38) en Oracle.
    - DECIMAL, DEC, NUMERIC: Son sinónimos de NUMBER(n,m) en Oracle. 
    - FLOAT, BINARY_FLOAT, BINARY_DOUBLE: Estos son razonablemente nuevos en ORACLE. 
                                          Son tipos de datos para números en coma flotante. Se usan poco en bases de datos OLTP. 
                                          Más en bases de datos orientadas a cálculos científicos o de ingeniería, machine learning, etc.
                                          Ofrecen mucho mejor rendimiento para cálculos matemáticos complejos que NUMBER.
                                          NUMBER guarda los datos con un formato más raro.. que hay que decodificar paraconvertir en número.
                                          PERO.. cuidado con estos... Al ser coma flotante, pueden tener problemas de precisión en ciertos cálculos.... desde el punto de vista de operaciónes de ingeniería o científicas no es relevante: 3/3=0.9999999999999999 es perfecto. "0.99999999 periodico = 1"
                                          Desde el punto de vista humano, es un sentido ver el número 1 como 0.9999999999999999.

## ORDEN DE LAS COLUMNAS EN ORACLE

El orden de las columnas en Oracle no es tyan crítico como en Postgres (por el tema del padding 8 bytes). En Oracle, las filas se guardan en bloques de datos (normalmente de 8KB). Dentro de esos bloques, las filas se guardan de forma que ocupen el menor espacio posible.

No obstante, puede haber otro problema... row chaining. Si una fila no cabe en un bloque, Oracle la divide en varias partes y las guarda en varios bloques. Eso es malo para el rendimiento.
Puede ser que un campo VARCHAR2 inicialmente sea pequeño, pero con el tiempo crezca mucho (por ejemplo un campo de comentarios, o una descripción larga). Si ese campo crece mucho, puede hacer que la fila no quepa en un bloque y se produzca row chaining, donde parte de la fila se guarda queda en el bloque original y otra parte en otro bloque. Si esto ocurre, todos los campos que hubiera detrás de ese campo grande, también se verán afectados y se guardarán en otro bloque. Si son campos que se usan con más frecuencia que el campo que tiene el texto grande, el rendimiento se verá afectado negativamente. En general, campos cuyo tamaño no va a cambiar, los ponemos al principio de la tabla. Campos que pueden crecer mucho, al final, de forma que si se produce row chaining, afecte al menor número de campos posibles.

Pero hay que tenerlo en cuenta cuando tengo campos grandes (2000 eso es grande... 15 bytes no es grande).

## Tipos de datos planteados para la tabla en Oracle
 
 id  NUMBER       GENERATED BY DEFAULT AS IDENTITY, -- Como yo no gestiono el campo, meter restricciones por cuestión de calidad de dato al tipo NUMBER no tiene sentido.

 tipo_documento   NUMBER(2,0) NOT NULL -- Hoy en día se usa solo 1 dígito. Puedo poner 2 dígitos por si en el futuro se añade alguno más.
                                          Como me da igual 1 que 2 en términos de almacenamiento (ambos ocupan 1 byte), pongo 2 dígitos para tener margen.
                                          La limitación vendrá por tener una tabla de tipos de documentos que controle los valores posibles.
 cod_documento    VARCHAR2(15) NOT NULL -- En Oracle, VARCHAR2 es el tipo de dato que debo usar para textos de tamaño variable.
 
 id_generada      NUMBER(2,0) NOT NULL
 cod_aplicacion   NUMBER(2,0) NOT NULL
 cod_solicitud    NUMBER(4,0) NOT NULL -- Por si el día de mañana crece del 777 actual. En GENERAL Esto no es una buena práctica 
                                          Antiguamente, en el mundo del desarrollo de software se consideraba una buena práctica hacer cosas "por si acaso". 
                                            > Voy a poner en la tabla de contacto las columnas TELEFONO y TELEFONO2. Por si acaso el día de mañana necesito un segundo teléfono. Hoy en día no la relleno, pero por si acaso, ya la tengo allí.
                                            > Hoy en día eso es una mala práctica. Escribo y hago lo mínimo necesario HOY -> SISTEMA MENOS COMPLEJO -> MENOS ERRORES -> MENOS MANTENIMIENTO. Además que de producirse ese cambio que estoy anticipando, puede ser que ocurra de formas que ahora mismo ni imagino... por ejemplo, el día de mañana se decide que hace falta más telefonos.. pero no solo 1 más ... sino los que quieran...
                                            Y me tocaria deshacer esto y poner una tabla de teléfonos asociada al contacto.

 pais_estudio     NUMBER(3,0)           -- Esto debería tener una tabla asociada donde apliquemos restricciones de integridad referencial (FOREIGN KEY) para asegurar la calidad del dato.
 centro           VARCHAR2(150) 
 titulo           VARCHAR2(160)
 fecha_inicio     DATE
 fecha_fin        DATE
 centro_profesional     VARCHAR2(150)
 titulo_profesional     VARCHAR2(160)
 cod_profesion          NUMBER (2,0)
 cod_titulo             NUMBER (4,0)
 fecha_inicio_profesion DATE
 fecha_fin_profesion    DATE

POSIBLEMENTE a muchos de estos campos numeric haya que ponerle otras restricciones ... con foreign keys o checks... para asegurar la calidad del dato.

## Hecho eso....

Lo siguiente sería hacer un estudio de cúanto me va a ocupar de media cada fila.
Y ese estudio lo hacemos a nivel de cada campo:
    ID  -> 150.000 solicitudes: 6 dígitos -> NUMBER -> 3 bytes
    TIPO_DOCUMENTO -> Valores entre 1 y 6 -> NUMBER(2,0) -> 1 byte
    COD_DOCUMENTO -> VARCHAR2(15) -> Longitud media 9 bytes -> 9 + 1 byte (longitud) = 10 bytes
    ID_GENERADA -> Valores entre 1 y 43 -> NUMBER(2,0) -> 1 byte
    COD_APLICACION -> Valores entre 1 y 5 -> NUMBER(2,0) -> 1 byte
    COD_SOLICITUD -> Valores entre 1 y 777 -> NUMBER(4,0) -> 2 bytes
    PAIS_ESTUDIO -> Valores entre 1 y 200 -> NUMBER(3,0) -> 2 bytes
    CENTRO -> VARCHAR2(150) -> Longitud media 37 bytes -> 37 + 1 byte (longitud) = 38 bytes
    TITULO -> VARCHAR2(160) -> Longitud media 30 bytes -> 30 + 1 byte (longitud) = 31 bytes
    FECHA_INICIO -> DATE -> 7 bytes
    FECHA_FIN -> DATE -> 7 bytes
    CENTRO_PROFESIONAL -> VARCHAR2(150) -> Longitud media 34 bytes -> 34 + 1 byte (longitud) = 35 bytes
    TITULO_PROFESIONAL -> VARCHAR2(160) -> Longitud media 36 bytes -> 36 + 1 byte (longitud) = 37 bytes
    COD_PROFESION -> Valores entre 1 y 99 -> NUMBER(2,0) -> 1 byte
    COD_TITULO -> Valores entre 1 y 9999 -> NUMBER(4,0) -> 2 bytes
    FECHA_INICIO_PROFESION -> DATE -> 7 bytes
    FECHA_FIN_PROFESION -> DATE -> 7 bytes  

    ** En este caso tenemos suerte que hay muchos datos y tenemos información muy precisa... Si no la tengo, tendría que estimar los tamaños.

    TOTAL:  3 + 1 + 10 + 1 + 1 + 2 + 2 + 38 + 31 + 7 + 7 + 35 + 37 + 1 + 2 + 7 + 7 = 193 bytes por fila de media.
    CABECERA DE CADA FILA:  3 bytes
    CABECERA DE BLOQUE:  84 bytes (suponiendo bloques de 8KB)
    ROW DICTIONARY: 6 bytes por fila
    TABLA DE TRANSACCIONES:  10 bytes por fila -> INITRANS , MAXTRANS  ??

    Por fila al final: 193 + 3 + 6  ~= 200 bytes por fila
    Por bloque: 8192 - 84 = 8108 bytes útiles por bloque
    Filas por bloque: 8108 / 200 = 40 filas por bloque.. si lo aprieto

    Tamaño máximo de fila:
    ID  -> 6 bytes
    TIPO_DOCUMENTO -> 2 bytes
    COD_DOCUMENTO -> 15 + 1 byte (longitud) = 16 bytes
    ID_GENERADA -> 2 bytes
    COD_APLICACION -> 2 bytes
    COD_SOLICITUD -> 4 bytes
    PAIS_ESTUDIO -> 3 bytes
    CENTRO -> 150 + 1 byte (longitud) = 151 bytes
    TITULO -> 160 + 1 byte (longitud) = 161 bytes
    FECHA_INICIO -> 7 bytes
    FECHA_FIN -> 7 bytes
    CENTRO_PROFESIONAL -> 150 + 1 byte (longitud) = 151 bytes
    TITULO_PROFESIONAL -> 160 + 1 byte (longitud) = 161 bytes
    COD_PROFESION -> 2 bytes
    COD_TITULO -> 4 bytes
    FECHA_INICIO_PROFESION -> 7 bytes
    FECHA_FIN_PROFESION -> 7 bytes

    TOTAL MÁXIMO:  6 + 2 + 16 + 2 + 2 + 4 + 3 + 151 + 161 + 7 + 7 + 151 + 161 + 2 + 4 + 7 + 7 = 785 bytes por fila máximo.
    Pasará mucho... posiblemente no... tenemos los datos reales: MEDIA 193 bytes por fila.
    Pero hay 600 bytes de diferencia... si un campo crece mucho, podría hacer que la fila no quepa en el bloque.


## Hecho este trabajo:

- Preguntas que quizás ahora mismo, sobre esta tabla no podemos responder, ya que no tenemos acceso a negocio que es quien conoce el funcionamiento de esa tabla:
  - Todos los campos se rellenan a la vez? o hay campos que se rellenan en momentos diferentes?
  - Las filas sufren cambios de tamaño importantes a lo largo de su vida? (podrían llegar hasta 600 bytes de diferencia)

Esto va a condicionar el PCT FREE que le pongamos a la tabla. Si tengo muchas de esas actualizaciones que hacen que las filas crezcan mucho, me interesa poner un PCT FREE alto (20-30%) para dejar espacio libre en cada bloque y evitar row chaining. Si no hay muchas actualizaciones de ese tipo, puedo poner un PCT FREE bajo (5-10%) para aprovechar mejor el espacio en disco. NOS FALTA INFO.

Lo ideal es que esto lo hiciera desarrollo... que es quien esta más en comunicación con negocio y puede obtener esa información. Pero desarrollo, por suerte o por desgracia, no suele tener npi de como funciona Oracle a bajo nivel... eso lo debo saber yo como DBA DE ORACLE.

- El otro tema es el INITRANS y MAXTRANS. Por defecto Oracle pone INITRANS 1 y MAXTRANS 255.
  Si esta tabla sufre de muchas actualizaciones concurrentes, me interesará subir INITRANS a 2 o 3 para que haya más espacio prereservado para transacciones concurrentes. Al final en el bloque tengo unas 40 filas... Probabilidad de que 2 filas de la tabla estén en el mismo bloque y se editen a la vez es baja... pero puede pasar. Si espero que haya muchas actualizaciones concurrentes, pondré INITRANS 2 o 3. En general, si tengo un buen PCTFREE, con INITRANS 1 suele ser suficiente.... ya se busca espacio luego del PCTFREE para nuevas transacciones (hasta MAXTRANS).
  Pero si configuro un PCTFREE bajo (5-10%), incluso como nosotros hemos osado hacer en algunas tablas de nuestros ejemplos de 0%, entonces es recomendable subir INITRANS a 2 o 3 para evitar problemas de concurrencia.

PCT FREE es espacio que se deja en la tabla para futuras actualizaciones , incluyendo espacio que se necesite adicional para anotar información de transacciones en curso.
Para lo que no se usa ese espacio es para INSERTS nuevos. Lo que dejemos como PCT FREE no estará disponible para nuevos INSERTS... si para el resto de operaciones que se hagan sobre el bloque.

INITRANS es cuántas entradas PRERESERVO en el bloque para transacciones sobre los datos (registros) de ese bloque.
Si hacen falta más filas en esa tabla de transacciones vigentes, se tira de ESPACIO LIBRE EN EL BLOQUE... hasta poder llegar al limite establecido en el MAXTRANS.

Aquí cuidado... INITRANS y MAXTRANS no hablan en bytes... son NUMERO DE FILAS EN ESA TABLA!
PCTFREE no habla de bytes... habla de %... Pero el cálculo es sencillo: Tamaño de bloque de 8Kbs y PCTFREE de 20% -> 8192 * 20% = 1638 bytes reservados para futuras actualizaciones y transacciones vigentes.

RESUMIENDO: Me tengo que preocupar del INIRANS cuando:
- Tengo un PCTFREE muy bajo
- Y tengo filas muy cortas (muchas filas por bloque ~400 filas por bloque)
- Y espero muchas actualizaciones concurrentes sobre la tabla.
En estos casos subo el INITRANS... a 2-10.

Tenemos queries que nos ayudan a ver cuántas transacciones tstán bloqueando durante tiempo grande.

## Estadísticas de la tabla en Oracle

id  NUMBER                  GENERATED BY DEFAULT AS IDENTITY --
tipo_documento              NUMBER(2,0)  NOT NULL 
cod_documento               VARCHAR2(15) NOT NULL 
id_generada                 NUMBER(2,0)  NOT NULL
cod_aplicacion              NUMBER(2,0)  NOT NULL
cod_solicitud               NUMBER(4,0)  NOT NULL
pais_estudio                NUMBER(3,0)
centro                      VARCHAR2(150) COLLATE XSPANISH_AI
titulo                      VARCHAR2(160) COLLATE XSPANISH_AI
fecha_inicio                DATE
fecha_fin                   DATE
centro_profesional          VARCHAR2(150) COLLATE XSPANISH_AI
titulo_profesional          VARCHAR2(160) COLLATE XSPANISH_AI
cod_profesion               NUMBER (2,0)
cod_titulo                  NUMBER (4,0)
fecha_inicio_profesion      DATE
fecha_fin_profesion         DATE

Ya dijimos que en cualquier BBDD relacional el tener una buenas estadísticas es CRUCIAL para que el optimizador de consultas pueda hacer bien su trabajo.

A priori, solo nos tendríamos que preocupar de aquellas columnas que se vayan a utilizar como filtros en las consultas (WHERE, JOIN, HAVING, etc).
- ID: Este es interno de Oracle. 
    Si tengo 10.000 filas... y hago 100 buckets... cuantos registros tengo por bucket?
        1     - 100 -> 100 filas
        101   - 200 -> 100 filas
        ...
        9.901 - 10.000 -> 100 filas
    Esta columna tiene una distribución UNIFORME.
    Si tengo 27893 documentos y me piden buscar los documentos cuyo id está entre el 1267 y el 17893, cuántos hay?
        17.893 - 1.267 = 16.626 filas -> 16.626 / 27.893 = 59.6% de la tabla.
    No necesito buckets ni % En este caso no hacen falta unas buenas estadísticas avanzadas con histogramas.

    EXEC DBMS_STATS.GATHER_TABLE_STATS(
       ownname => 'HMWXXADM',
       tabname => 'AEU_ACADEMICOS',
       method_opt => 'FOR COLUMNS SIZE 1 ID',
    );
    Esta columna a pesar de no requerir histograma, si que va tomando valores nuevos con el tiempo que no estaban presentes la vez anterior que se calcularon las estadísticas. Van apareciendo nuevos ids fuera del rango (MIN-MAX que se usaba antes).
    Necesito regenerarla con frecuencia (diaria/semanal). Lo mismo me pasa con los campos de tipo FECHA

- tipo_documento              NUMBER(2,0)  NOT NULL  -> 1º Necesitamos histograma ya que la distribución no es uniforme.
                                                     -> Si la tabla crece con frecuencia (y tiene pinta que si), regeneraré las estadísticas básicas de la tabla con frecuencia (diaria/semanal).
                                                        150.000 filas en 20 años... 150.000/20 = 7.500 filas al año... 625 filas al mes... 20 filas al día... No es mucho.
                                                        625 al mes / 150.000 = 0.4% al mes... No es mucho.
                                                        Cada mes como mucho regenero las estadísticas básicas.
                                                        Si en un mes tenemos 625 filas, la distribución no va a cambiar mucho (los %)
                                                        En un año tenemos 7.500 filas... 5% de la tabla... Puede que cambie algo la distribución.
                                                     -> Recalcularé al año el histograma... y veo si cambia mucho o no.
                                                     -> Si no cambia no lo vuelvo a generar en 10 años! O Si... la tabla es muy chica... y no me complico!
    -- Generamos estadísticas con histograma en tipo_documento (6 buckets)
    EXEC DBMS_STATS.GATHER_TABLE_STATS(
       ownname => 'HMWXXADM',
       tabname => 'AEU_ACADEMICOS',
       method_opt => 'FOR COLUMNS SIZE 6 TIPO_DOCUMENTO',
       estimate_percent => NULL,
       block_sample => FALSE,
       cascade => TRUE
    );
                                    
- cod_documento               VARCHAR2(15) NOT NULL 
    -- En este caso, queremos 254 buckets (máximo) para el histograma, ya que la distribución no es uniforme.
    EXEC DBMS_STATS.GATHER_TABLE_STATS(
       ownname => 'HMWXXADM',
       tabname => 'AEU_ACADEMICOS',
       method_opt => 'FOR COLUMNS SIZE 254 COD_DOCUMENTO',
       estimate_percent => NULL,
       block_sample => FALSE,
       cascade => TRUE
    ); 
    Posiblemente no haya valores nuevos fuera del rango MIN-MAX... pero si que hay muchos valores nuevos dentro del rango.
    Si mantienen % no necesito regenerar el histograma con frecuencia.

    Esto que estamos haciendo, en la mayor parte de las tablas no me complico. 
    Para tablas pequeñas (< 50000 datos) Recalculo estadísticas básicas con frecuencia (diaria) y los histogramas cada cierto tiempo (mensual).

    Pero para las tablas gordas es importante. Cuesta mucho tiempo y recursos calcular estadísticas.
    MERECE LA PENA hacer este análisis. Tardo un par de horas.. dejo todo programado.. y tengo 20 años de tranquilidad!

        EXEC DBMS_STATS.GATHER_TABLE_STATS(
           ownname => 'HMWXXADM',
           tabname => 'AEU_ACADEMICOS',
           method_opt => 'FOR ALL COLUMNS SIZE AUTO',
           estimate_percent => NULL,
           block_sample => FALSE,
           cascade => TRUE
        ); // Esto lo programo para que se haga cada mes o 6 meses.. si es pequeña no crece tanto

- id_generada                 NUMBER(2,0)  NOT NULL
- cod_aplicacion              NUMBER(2,0)  NOT NULL
- cod_solicitud               NUMBER(4,0)  NOT NULL
- centro                      VARCHAR2(150) COLLATE XSPANISH_AI
- titulo                      VARCHAR2(160) COLLATE XSPANISH_AI
- fecha_inicio                DATE
- fecha_fin                   DATE

### Como lo planteamos?

- Cómo va a ser la distribución de los datos en cada campo? UNIFORME o NO? Es interesante el saber cúantos valores distintos hay en cada campo.
    En nuestro caso, es bien fácil... tenemos BBDD real... con datos reales, podemos sacar los datos exactos.
    El día 1 no podré hacerlo en una BBDD nueva... pero el día 1 tampoco me importa mucho... tendré pocos datos y la BBDD irá guay!
    Esto es algo que hacemos con el tiempo... es decir: SIEMRPE VOY A TENER DATOS APRA HACER ESTE ESTUDIO.
- Si esa distribución cambia con el tiempo o no?
- Si la tabla cambia en el número de filas con el tiempo o no?

Dentro de las estadísticas tenemos 2 partes:
- Metadatos de la tabla: Número de filas, bloques usados, avg_row_len, etc.
- Estadísticas de las columnas... pero dentro de estas, tenemos:
  - Estadísticas básicas: num_distinct, num_nulls, etc.
  - Estadísticas avanzadas: histogramas, etc.

En general las estadísticas las programamos para que se actualicen automáticamente según sea necesario en cada caso.
En ocasiones, si nuestra BBDD recibe cargas masivas de datos, podemos programar que tras esas cargas masivas se actualicen las estadísticas de la tabla afectada.

El proceso de cáclulo/actualización de estadísticas puede ser costoso en tiempo y recursos, especialmente en tablas grandes.
Y en muchos casos, hacemos mantenimientos de distinto nivel en la BBDD, en distintos momentos del tiempo.

Por ejemplo, podemos hacer un mantenimiento diario, otro semanal y otro mensual.
- Los datos que supongan mayor problema -> mantenimiento diario  / semanal
- Datos que no cambian tanto            -> mantenimiento semanal / mensual
- Datos que casi no cambian             -> mantenimiento mensual / trimestral / anual

Como no lo haga, con el paso del tiempo, el sistema se degrada y el rendimiento de las consultas empeora.

---
# Tabla en Postgres

## Comentarios

### Tipos de datos

En postgres a diferencia de Oracle, hay que se bastante estricto con los tipos de datos, especialmente los numéricos. Dependiendo del tipo de dato, así lo que van a ocupar en disco y la precisión que van a tener.
En esta tabla, la calidad del dato está NADA CONTROLADA... No se le ha puesto suficiente cariño!

### Clave primaria

Cuál es el objetivo de la clave primaria? es identificar unívocamente cada fila de la tabla... desde el punto de vista interno de Oracle.
Adicional: Es el que se usa para relaciones.
Una cosa es una clave interna en Oracle... y otra cosa es una clave de negocio (o un idenficador público del registro).

Nuestros profesores tienen un identificador único (DNI, correo, etc) que los identifica: IDENTIFICADOR PUBLICO. Pero internamente en la BBDD, para Oracle, necesito otro id único que me identifique la fila y que sea sencillo de manejar por Oracle para referirme a esa fila -> JOINS, BUSQUEDAS, ETC.

Si tengo un ID con 5 campos, cada vez que Oracle tenga que buscar un registro, tendrá que comparar los 5 campos. Si en cambio tengo un ID con 1 campo (un número secuencial), Oracle solo tendrá que comparar 1 campo.

Lo normal en un caso como este es:
- Tener un campo ID (numérico, secuencial) que sea la clave primaria interna de Oracle.
- Tener un índice único (UNIQUE) sobre los campos que identifican al registro desde el punto de vista del negocio (tipo_documento, cod_documento, id_generada, cod_aplicacion, cod_solicitud).

En ocasiones, por ejemplo, si tengo 2 campos... bueno.. usamos esos 2 campos como clave primaria. Casi me sale más caro tener un campo extra (ID) que usar los 2 campos como clave primaria. Más almacenamiento. Hasta 2 cuela. A partir de 3 campos, ya es mejor tener un campo ID.

La diferencia en rendimiento, la diferencia en almacenamiento y la diferencia en complejidad del modelo y de las consultas es muy grande.

### Más pero conceptos específicos de postgres

- Padding de 8 bytes... No se ha tenido en cuenta. Eso hace que la tabla engorde más de lo necesario. -> No solo es almacenamiento: RAM, BUFFERS, BACKUPS...
- Las formas de almacenamiento en postgres (main, extended, plain)... No se ha tenido en cuenta.
   - PLAIN: Los dastos se guardan en la página sin comprimir.
   - MAIN:  Los datos se guardan a priori en la página, y se intentan comprimir si tiene sentido. Si no entran se guardan fuera de la página, en otra zona de almacenamiento que tiene postgres: TOAST.
   - EXTENDED: Extended guarda los fuera de la página más fácilmente que MAIN. Es decir, si un campo es EXTENDED, postgres intentará guardar el dato fuera de la página siempre que pueda.

## Datos sobre la tabla

Universidades=# \d+ hmwxxadm.aeu_academicos;
                                                    Tabla «hmwxxadm.aeu_academicos»
        Columna         |          Tipo          | Ordenamiento | Nulable  | Por omisión | Almacenamiento | Estadísticas | Descripción
------------------------+------------------------+--------------+----------+-------------+----------------+--------------+-------------
 tipo_documento         | numeric                |              | not null |             | main           |              |
 cod_documento          | character varying(15)  |              | not null |             | extended       |              |
 id_generada            | numeric                |              | not null |             | main           |              |
 cod_aplicacion         | numeric                |              | not null |             | main           |              |
 cod_solicitud          | numeric                |              | not null |             | main           |              |
 pais_estudio           | numeric                |              |          |             | main           |              |
 centro                 | character varying(150) |              |          |             | extended       |              |
 titulo                 | character varying(160) |              |          |             | extended       |              |
 fecha_inicio           | date                   |              |          |             | plain          |              |
 fecha_fin              | date                   |              |          |             | plain          |              |
 centro_profesional     | character varying(150) |              |          |             | extended       |              |
 titulo_profesional     | character varying(160) |              |          |             | extended       |              |
 cod_profesion          | numeric                |              |          |             | main           |              |
 cod_titulo             | numeric                |              |          |             | main           |              |
 fecha_inicio_profesion | date                   |              |          |             | plain          |              |
 fecha_fin_profesion    | date                   |              |          |             | plain          |              |
Índices:
    "aeu_academicos_pk" PRIMARY KEY, btree (tipo_documento, cod_documento, id_generada, cod_aplicacion, cod_solicitud)
Restricciones de llave foránea:
    "aeu_academicos_r01" FOREIGN KEY (cod_documento, tipo_documento, id_generada, cod_aplicacion) REFERENCES hmwxxadm.aeu_generadas(cod_documento, tipo_documento, id_generada, cod_aplicacion) ON DELETE CASCADE
Método de acceso: heap

tam_codigo                  tam_centro                  tam_titulo                  tam_centro_profesional      tam_titulo_profesional
9.9668613645691914 bytes	37.3284454399104081 bytes	30.4389491226847305 bytes	34.7627164502164502 bytes	36.5294855708908407 bytes

max_tipo_documento|max_id_generada|max_cod_aplicacion|max_cod_solicitud|
------------------+---------------+------------------+-----------------+
                 6|             43|                 5|              777|
5 bytes

158.000 filas

TIPOS DE CAMPOS
NULL! Debe ser funcional
COLLATES
PCT FREE
INITRANS
MAXTRANS
INDICES







-- Postgres, los datos de cada registro se guardan usando un padding de 8 bytes, que se cierran.
fecha_inicio_profesion

fecha_inicio_profesion | date (4 bytes)
fecha_fin_profesion    | date (4 bytes)
fecha_inicio           | date
fecha_fin              | date
FFFFffff|bbbbJJJJ|


XXXXX...|XXXXXXXX|XX......|XXXXX...|

---

## Queries en postgres sobre la tabla actual para ayudarnos con el estudio de las estadísticas

SELECT tipo_documento, COUNT(*) as total FROM hmwxxadm.aeu_academicos GROUP BY tipo_documento ORDER BY total DESC LIMIT 10;
             1|60730| *1
             2|31914|
             3|20324|
             4|   11|
             5|44625|
             6|  761|
SELECT count(DISTINCT(tipo_documento)) FROM hmwxxadm.aeu_academicos;
             6
SELECT COUNT(*) FROM hmwxxadm.aeu_academicos WHERE tipo_documento IS NULL;
             0

A nivel de la tabla se meterían algunos metados:
    TABLA hmwxxadm.aeu_academicos tiene 158000 filas, ...
A nivel de esta columna:
    COL TIPO_DOCUMENTO tiene 6 valores distintos, 0 nulos, 
    Esa distribución de datos *1.
    Esa distribución de datos es UNIFORME / NO UNIFORME? NADA UNIFORME
        Eso lo que significa es que si todos los valores tienen más o menos el mismo número de apariciones, es UNIFORME.
        Si hay valores que aparecen muchas veces y otros que aparecen pocas veces, es NO UNIFORME.
        Hay valores que casi no aparecen (4,6) y otros que aparecen bastante (2,3) y otros que aparecen mucho (1,5) -> NO UNIFORME

    Las estadísticas básicas de oracle serían:
        NUM_DISTINCT = 6
        NUM_NULLS = 0
        Y por ende, campos informados: 158000

    Sin saber más datos que las estadísticas básicas, cual sería mi mejor estimación para el número de filas que cumplen un filtro tipo_documento=3? 158.000 / 6 = 26.333 filas = 16.67% de las filas.
    Eso se cumple? NADA! Para el 2 y 3 más o menos... con 5000 filas de diferencia... pero para el 1 ,4, 5 y 6 no se cumple nada.
    Hay datos que casi no tienen filas (4,6) y otros que tienen muchísimas filas (1,5).
    Esto es lo que hace el OPTIMIZADOR DE CONSULTAS de ORACLE... si no tiene más datos, hará esa estimación.
        
    Cuando tengo distribuciones de datos que no son uniformes, es interesante tener HISTOGRAMAS para esas columnas.
    Que es el histograma: (realmente es lo que en estadística llamamos una tabla de frecuencias)
             1|60730| *1   -> 60/158 = 38.4%
             2|31914|      -> 32/158 = 20.2%
             3|20324|      -> 20/158 = 12.9%
             4|   11|      -> 0.01%
             5|44625|      -> 44/158 = 28.2%
             6|  761|      -> 0.5%

        Tabla de frecuencias es si tengo pocos valores distintos.
    EN ESTE CASO, claramente necesito unas estadísticas avanzadas (histograma) para esta columna. De lo contrario, el optimizador de consultas hará unas estimaciones RUINOSAS!.. y el rendimiento de la BBDD = KK.

    Siguiente pregunta, cambiarán mucho esos % con el tiempo? Ah! Lo iremos viendo. Cuánto más cambien, más a menudo tendré que actualizar las estadísticas.
    Si cambian poco, con ir regenerando los metadatos de la tabla me vale (Cuántas filas hay) me es suficiente.
    - Los metadatos de la tabla los puedo actualizar con bastante frecuencia (diario/semana)
      - Esto lo haré si la tabla crece.,.. si no crece, no hace falta. TABLA CODIGOS POSTALES... eso no crece ni a ostias!
      - 4 año.
    - El histograma es más costoso de calcular... así que lo haré menos a menudo (año)

    Soy una empresa que de transporte en tren... Registro mis clientes en una tabla. Y tengo un campo SEXO del cliente.
    SEXO: HOMBRE / MUJER.... y tengo entorno al 50% de cada uno.
    El día 365, que tengo 500.000 clientes, el 50% son hombres y el 50% mujeres -> 250.000 hombres y 250.000 mujeres.
    Al año.. día 730, tengo 1.000.000 de clientes... y el 50% son hombres y el 50% mujeres -> 500.000 hombres y 500.000 mujeres.
    Quizás un día tengo 50,2 y otro día un 48,7%... pero más o menos es estable.

    En este caso, el histograma tendrá 6 buckets (uno por cada valor distinto) y los % serán bastante estables con el tiempo.

    ---

    Tengo un sistema de control de incidencias... organizadas por: GRAVE, MEDIA, LEVE.
    Lo normal en mi caso es que tenga: 70% LEVE, 20% MEDIA, 10% GRAVE.
    Al año habré tenido 10.000 incidencias....           y de ellas graves serán: 1.000 (10%)
    Al año siguiente, habré tenido 20.000 incidencias... y de ellas graves serán: 2.114 (10,57%)

SELECT COUNT(*), cod_documento FROM hmwxxadm.aeu_academicos GROUP BY cod_documento ORDER BY COUNT(*) DESC LIMIT 10;
    count|cod_documento|
    -----+-------------+
    32|21682385D    |
    27|50160042D    |
    22|714898256    |
    19|48347870F    |
    18|28971559T    |
    17|33509303M    |
    17|YA2183529    |
    17|77805426Z    |
    16|78547811M    |
    15|27310762X    |
SELECT count(DISTINCT cod_documento) FROM hmwxxadm.aeu_academicos;
    count |
    ------+
    123119|
SELECT COUNT(*) FROM hmwxxadm.aeu_academicos WHERE cod_documento IS NULL;
    count|
    -----+
        0|

    Cuántos valores diferentes tiene esta columna? 123.119 valores diferentes.
    Se parece en algo a la columna de tipo_documento? NO! La otra tenía 6 valores diferentes.
    
    Es uniforme o no? NPI al haber tantos valores diferentes, necesitamos otra estrategia diferente!
    Los valores son textos! Vamos a coger cuántos valores tengo por cada letra inicial del cod_documento (esto es lo que va a necesita el optimizador de consultas para hacer sus estimaciones). Generamos buckets por letra inicial. Lo mismo lo haremos con 2 letras iniciales si vemos que no es suficiente.
    
        SELECT SUBSTRING(cod_documento FROM 1 FOR 1) AS letra_inicial, COUNT(*) as total
        FROM hmwxxadm.aeu_academicos
        GROUP BY letra_inicial
        ORDER BY total DESC;
    En un histograma, metemos no más de 254 buckets (eso si queremos una alta precisión). 
        Y            |28771|
        1            |19148|
        4            |16663|
        A            |15457|
        7            |14652|
        0            |12095|
        5            |11956|
        X            |10035|
        2            | 8596|
        3            | 6682|
        G            | 2387|
        F            | 1750|
        C            | 1690|
        P            | 1362|
        8            |  816|
        6            |  802|
        E            |  780|
        J            |  689|
        I            |  610|
        R            |  463|
        B            |  383|
        S            |  362|
        9            |  348|
        L            |  328|
        N            |  327|
        K            |  269|
        M            |  226|
        H            |  188|
        D            |  157|
        V            |   93|
        U            |   75|
        T            |   68|
        Z            |   51|
        O            |   37|
        Q            |   24|
        W            |   24|
        ¿            |    1|
    De nuevo no es uniforme... hay letras que aparecen mucho (A,1,4,7) y otras que aparecen poco (Q,W,¿)
    Nos toca hacer un histograma con estos datos. Dada la variabilidad de los datos (tenemos 123.119 valores diferentes), haremos un histograma con muchos buckets (254). En cada bucket tendremos un rango de valores
    000000000 - 07654892 -> BUCKET 1 -> % de filas

    Como este campo es de tipo texto, los buckets se ven raros...
    Mejor lo veríamos si tuvieramos un campo de tipo numérico o de tipo fecha.
    Lo que hace la BBDD es ordenar los valores y partirlos en 254 partes iguales (o las que le digamos) y ver cuántas filas hay en cada parte.
    Por ejemplo, tenemos el campo fecha_inicio (tipo fecha)... no sabemos si tiene una distribución uniforme o no.
    Imagimanos que tenemos datos de 20 años. Y tenemos 158.000 filas.
    Pido las fechas por año!
        SELECT EXTRACT(YEAR FROM fecha_inicio) AS anio, COUNT(*) as total
        FROM hmwxxadm.aeu_academicos
        GROUP BY anio
        ORDER BY total DESC;
    Y me sale que cada año hay el mismo % de filas... entonces la distribución es UNIFORME.
    Puede ser que haya meses que tengan más filas que otros... pero a nivel de años es uniforme.. pero quizás a nivel de meses no lo sea.
    En verano estamos de vacaciones... y en invierno tenemos más carga de trabajo.
    En este caso, si genero 20 buckets, me haría 1 bucket por año... y si los datos cambian por meses, no me serviría de nada.
    En este caso, generaría 240 buckets (20 años * 12 meses = 240 meses) y así tendría un bucket por mes.
    Y eso me permitiría llevar mejor las estimaciones del optimizador de consultas.

SELECT COUNT(*), id_generada FROM hmwxxadm.aeu_academicos GROUP BY id_generada ORDER BY COUNT(*) DESC LIMIT 10;
SELECT count(DISTINCT id_generada) FROM hmwxxadm.aeu_academicos;

SELECT COUNT(*), cod_aplicacion FROM hmwxxadm.aeu_academicos GROUP BY cod_aplicacion ORDER BY COUNT(*) DESC LIMIT 10;
SELECT count(DISTINCT cod_aplicacion) FROM hmwxxadm.aeu_academicos;

SELECT COUNT(*), cod_solicitud FROM hmwxxadm.aeu_academicos GROUP BY cod_solicitud ORDER BY COUNT(*) DESC LIMIT 10;
SELECT count(DISTINCT cod_solicitud) FROM hmwxxadm.aeu_academicos;  

SELECT COUNT(*), centro FROM hmwxxadm.aeu_academicos GROUP BY centro ORDER BY COUNT(*) DESC LIMIT 10;
SELECT count(DISTINCT centro) FROM hmwxxadm.aeu_academicos;

SELECT COUNT(*), titulo FROM hmwxxadm.aeu_academicos GROUP BY titulo ORDER BY COUNT(*) DESC LIMIT 10;
SELECT count(DISTINCT titulo) FROM hmwxxadm.aeu_academicos;

SELECT COUNT(*), fecha_inicio FROM hmwxxadm.aeu_academicos GROUP BY fecha_inicio ORDER BY COUNT(*) DESC LIMIT 10;
SELECT count(DISTINCT fecha_inicio) FROM hmwxxadm.aeu_academicos;

SELECT COUNT(*), fecha_fin FROM hmwxxadm.aeu_academicos GROUP BY fecha_fin ORDER BY COUNT(*) DESC LIMIT 10;
SELECT count(DISTINCT fecha_fin) FROM hmwxxadm.aeu_academicos;

---

# Oracle CHAR vs VARCHAR vs VARCHAR2

CHAR es ancho fijo, siempre ocupa el mismo espacio.
VARCHAR y VARCHAR2 son anchos variables, ocupan el espacio necesario más un byte o dos para guardar la longitud.

Si defino un campo CHAR(15) y guardo 'Hola', Oracle guardará 'Hola' más 11 espacios en blanco, para forzar a que ocupe 15 bytes.
Si deefino un campo VARCHAR2(15) y guardo 'Hola', Oracle guardará 'Hola' más un byte extra para guardar la longitud (4), ocupando 5 bytes en total.