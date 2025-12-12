

    INDICE -> Guarda Nodos + ROWIDs
    TABLA  -> Guarda Filas completas

    Cualquiera de ellos guarda los datos en bloques.
    Esos bloque están en ficheros de datos en disco.
    
    Pero siempre que accedamos a un bloque, se carga en memoria (SGA: data buffer cache).
    Da igual que el bloque venga de un índice o de una tabla.

## OPCION 1

    INDICE CONVOCATORIAS
    --------------------------------------------------
    CODIGO             ROWID DE LA TABLA CONVOCATORIAS
    --------------------------------------------------
    CONVOCATORIA-1 ->  AAA001003   Bloque 1
    CONVOCATORIA-2 ->  AAA003007
     -----------------------------------------------
    CONVOCATORIA-3 ->  AAA001002   Bloque 2
    CONVOCATORIA-4 ->  AAA005005
    --------------------------------------------------


    TABLA CONVOCATORIAS (AAA)
    ---------------------------------------------------------------------------------
    ID   CODIGO          CURSO_ID  FECHA_INICIO  FECHA_FIN    ESTADO_ID 
    ---------------------------------------------------------------------------------
                                Bloque 003
    1  CONVOCATORIA-1      10     01-JAN-2024   31-JAN-2024     1
    ...
    ...
    ...
    ...
    ...
    2  CONVOCATORIA-2      12     15-FEB-2024   15-MAR-2024     2        Fila 007
     --------------------------------------------------------------------
    3  CONVOCATORIA-3      10     01-MAR-2024   31-MAR-2024     1
    4  CONVOCATORIA-4      15     01-APR-2024   30-APR-2024     3   
    ---------------------------------------------------------------------------------

## OPCION 2


    INDICE CONVOCATORIAS
    --------------------------------------------------------
    CODIGO             ROWID DE LA TABLA CONVOCATORIAS + ID
    --------------------------------------------------------
    CONVOCATORIA-1 ->  AAA001003   1                Bloque 1
    CONVOCATORIA-2 ->  AAA003007   2
     ----------------------------------------------------
    CONVOCATORIA-3 ->  AAA001002   3                Bloque 2
    CONVOCATORIA-4 ->  AAA005005   4
    --------------------------------------------------------

    Al entrar al índice, por el código de la convocatoria, ya tenemos toda la información que necesitamos (ID)... ya no tengo que ir a la tabla... el rowid no hace falta


---

# BBDD

Memoria <- SGA - CACHE! 
        <- PGA - SORTS, JOINS, ETC

Disco   <- Cache
        <- Número de escritores y buffers

Planes de ejecución
        <- Índices
        <- Estadísticas

Bloques 
        <- Fragmentación
        <- Row Movement y Row Chaining
        <- PCTFREE, PCTUSED, FILLFACTOR

CPU. No suele ser problema


---


-- Caso hipotético de uso de la app:
-- Quiero nombre, apellidos, dni de los alumnos matriculados en la convocatoria con código X
-- SELECT a.Nombre, a.Apellidos, a.DNI
-- FROM
--     Alumnos a
--     INNER JOIN Matriculas m ON a.ID = m.ALUMNO_ID
--     INNER JOIN Convocatorias c ON m.CONVOCATORIA_ID = c.ID
-- WHERE c.CODIGO = HEXTORAW('...');

-- Esa query... cómo se resuelve?
-- - Primero se busca la convocatoria con el código X -> ID convocatoria (1)
--        Para ello, Oracle entra en el índice de CODIGO? -> ROWID de la convocatoria (1): DATAFILE + BLOQUE + OFFSET
--        Después Oracle va al bloque concreto, y de la fila (identificada por el OFFSET) saca el ID convocatoria
--        Pregunta 1, podríamos optimizar eso? Teniendo un índice compuesto sobre CODIGO + ID
--             CREATE INDEX IX_Convocatorias_Codigo_ID ON Convocatorias(CODIGO, ID);
--             En este caso, Oracle entra en el Indice con el CODIGO --> ID convocatoria
--        Pregunta 2, merece la pena hacer eso? En este caso NO, ni de coña!
--        Por qué? El bloque de la tabla Convocatorias estará ya en cache, fijo.
--                 Si no, de donde ostias he sacado el CODIGO de la convocatoria?
--                 Es 1 operación: IR al bloque (que ya está en cache) y sacar el ID convocatoria
--                     Eso son nanosegundos
--                 Tener ese otro índice, me obliga a mantener 2 índices en cada INSERT/UPDATE/DELETE
--                     Además, es mucho más espacio en disco
--                     Me complica la vida en las operaciones de mantenimiento de índices (rebuild, reorganize, etc)
--                 Distinto sería que fuese a buscar cientos de miles de cursos por el código, que me viene en unos EXCEL
-- - Después se buscan las matrículas con ese ID convocatoria (FK) -> ID alumno (muchos)
--      Oracle usará una estrategia de NESTED LOOPS JOIN para resolver el JOIN: FOR (BUCLE)
-- - Después se buscan los alumnos con esos IDs(PK) de Alumno -> Nombre, Apellidos, DNI (muchos)

-- SELECT a.Nombre, a.Apellidos, a.DNI
-- FROM
--     Alumnos a
--     INNER JOIN Matriculas m ON a.ID = m.ALUMNO_ID
--     INNER JOIN Convocatorias c ON m.CONVOCATORIA_ID = c.ID
-- WHERE c.CODIGO = HEXTORAW('...');

Plan de ejecución:

    Ir al índice de CODIGO Convocatorias por el código -> obtener ROWID de la convocatoria 
        -> Operacion INDEX RANGE SCAN: Instantánea (1 sola fila)
    Con el ROWID vamos a la tabla Convocatorias -> obtenemos ID de la convocatoria
        -> Operacion TABLE ACCESS BY ROWID: Instantánea (1 sola fila)
    ---
    # OPCION 1
    Con el ID de la convocatoria, entramos en en el índice de Matriculas por CONVOCATORIA_ID -> ROWIDs de los alumnos matriculados
        -> Operacion INDEX RANGE SCAN (tendrá que hacer 20) = Instantánea (20 filas)
        -> NESTED LOOPS JOIN
            -> ACCESS BY INDEX ROWID para cada matricula -> obtener ALUMNO_ID
    # OPCION 2
    Con el ID de la convocatoria, entramos en en el índice de Matriculas por CONVOCATORIA_ID y alumno -> ALUMNO_IDs
        -> Operacion INDEX RANGE SCAN (tendrá que hacer 20) = Instantánea (20 filas)
    ---
    Con los ALUMNO_IDs, entramos en el índice de PK Alumnos -> obtenemos ROWIDs de los alumnos
        -> Nested Loops Joins
        -> Operacion INDEX RANGE SCAN (tendrá que hacer 20) = Instantánea (20 filas)
    Con los ROWIDs, entramos en la tabla Alumnos -> obtenemos NOMBRE, APELLIDOS, DNI
        -> Table ACCESS BY ROWID (tendrá que hacer 20) = Instantánea (20 filas)

Cuando tengo una tabla muy grande y de ella saco pocos datos, Oracle (y cualquier otro SGBD) va a aplicar este tipo de estrategias: Nested Loops Joins 

Una CPU moderna es capaz de hacer miles de millones de operaciones por segundo.

---
Los 2 me aportan un montón.
CREATE INDEX idx_matriculas_convocatoria ON Matriculas(CONVOCATORIA_ID);
CREATE INDEX idx_matriculas_convocatoria_alumnos ON Matriculas(CONVOCATORIA_ID, ALUMNO_ID);

---

# Particionado de tablas.

Esto no son conceptos que se manejen desde desarrollo. Son puros de administración de bases de datos.

En qué consiste?
La idea es partir una tabla grande en varias tablas más pequeñas, llamadas particiones.
Al particionar una tabla, cada partición puede tener su propio almacenamiento, sus propios índices, etc.
A nivel interno de Oracle, cada partición va a ser un SEGMENTO diferente.

Para qué interesa particionar una tabla?
- Vamos a ganar en rendimiento... pero me temo que no tanto porque la BBDD necesite hacer menos operaciones.
  
  CONVOCATORIAS.
    Tengo 10 millones de convocatorias.
    Quiero las convocatorias del año 2023. -> 1 millón de convocatorias.
      Si las busco en un índice creado sobre la tabla completa, Oracle debe buscar mi millón de convocatorias entre los 10 millones.
      Si la tabla estuviera particionada por año, Para cada partición (subtabla) tendría un índice diferente.
      Eso implica que ya tengo un índice que solo contiene el millón de convocatorias del 2023.

      Realmente gano mucho rendimiento con eso? Me temo que no.
      En el índice sobre 10M de filas, para sacar los 1M de 2023, Oracle hará un INDEX RANGE SCAN.
      Y saca esos datos en NADA.

      Cuál es la gracia entonces?

NOSOTROS LO QUE NO QUEREMOS PERMITIR BAJO NINGUN , NINGUN, **** NINGUN **** CONCEPTO es que sobre esta tabla se haga un FULL TABLE SCAN. Aquí tendremos los índices que sean necesarios. 
En optras tablas, que tienen 4 datos (o 10000, que siguen siendo 4 datos), pues no hay problema en que se haga un FULL TABLE SCAN. Pero en tablas grandes, NUNCA.

Entonces... Dado que NUNCA haré un Fullscan, el tener los datos particionados no me va a aportar nada en rendimiento.. si acaso que tendré índices más pequeños (por partición)... pero tener un índice el doble dee grande que otro, me evita 2/3 de operaciones? No más. Operaciones de nanosegundos.

Indice 10 Millones de entradas. Búsqueda -> log2(10,000,000) = ~24 operaciones
Indice 1 Millón de entradas. Búsqueda -> log2(1,000,000) = ~20 operaciones
Indice 100 M de entradas. Búsqueda -> log2(100,000,000) = ~27 operaciones

La diferencia es ridícula! NO HAY UNA MEJORA REAL EN RENDIMIENTO DEBIDO AL NUMERO DE OPERACIONES POR HABER PARTICIONADO.

Aunque a nivel global del sistema, SI PUEDO TENER UNA MEJORA IMPRESIONANTE en RENDIMIENTO. Por qué?
- Posiblemente si estoy en 2025, cuántas búsquedas voy a hacer de datos del 2023? Pocas
- Y del 2024? Pocas
- Y del 2022? Pocas
- Y del 2025? Muchas ---> Esos datos son los que quiero en CACHE!
- El resto de datos NO quiero que estén en CACHE.
- Voy a liberar mucha memoria en la SGA, para tener más datos actuales en CACHE.

Otra gracia es que puedo generar índices diferentes por partición.

Una partición ideal para esta tabla NO SERIA POR AÑO, sino por ESTADO de la matricula.
Dee forma que las matrículas con estado "ACTIVA" estén en una partición.
Las matrículas con estado "FINALIZADA" en otra partición.
Las matrículas con estado "CANCELADA" en otra partición.
Las matrículas con estado "PENDIENTES DE PAGO" en otra partición.

Sobre las matriculas que lleguen a estado finalizada, casí no haré consultas.
Sobre las activas, haré muchas consultas.
  Quizás sobre estas creo más índices (FECHA)
Sobre las finalizadas creo otros índices (EMPRESA para facturar, ahora que ya pasó el curso y ya tengo que cobrarlo)

---

Al particionar:
- Cada partición es un segmento diferente -> que puede ir a un tablespace diferente
- Cada partición puede tener sus propios índices
- Cada partición puede tener sus propias estadísticas

Eso me permite:
- Tener los datos actuales en tablaspace rápido (SSD) y los antiguos en tablaspace lento (HDD)
  Tener distintos almacenamientos rápidos (SSD) para los datos (todos) .. y tengo más ancho de banda 
- Tener los datos actuales con más índices y los antiguos con menos índices
- Mantenimiento por separado de índices y estadísticas en cada partición
  - Habrá particiones que no se toquen nunca (2023, 2024)
  - Habrá particiones que se toquen mucho (2025)

---

Todas las matrículas las puedo repartir entre 4 almacenamientos diferentes (tablespaces diferentes).
- Eso me permite de repente escribir x4 veces más rápido en la tabla de matrículas.
- Eso me permite de repente leer x4 veces más rápido en la tabla de matrículas.
En un caso como este, particionaría en base a qué criterio? NINGUNO = ALEATORIO.
Puedo generar una huella hash del ID de la matrícula y en base a eso repartir las filas entre 4 particiones diferentes.

---  
# Tipos de particionado

## Por rangos

Ideal por ejemplo para fechas.
Cada partición contiene un rango de valores.

CREATE TABLE MATRICULAS (
    ID               NUMBER      GENERATED BY DEFAULT AS IDENTITY,
    ALUMNO_ID        NUMBER      NOT NULL,
    EMPRESA_ID       NUMBER,
    CONVOCATORIA_ID  NUMBER      NOT NULL,
    ESTADO_ID        NUMBER      NOT NULL,
    FECHA_MATRICULA  DATE        NOT NULL,
    PRECIO           NUMBER(10,2) NOT NULL,
    DESCUENTO        NUMBER(5,2)  NOT NULL,
    PRECIO_FINAL     NUMBER(10,2) NOT NULL
) PARTITION BY RANGE (FECHA_MATRICULA) (
    PARTITION P_2023 VALUES LESS THAN (TO_DATE('01-JAN-2024','DD-MON-YYYY')),
    PARTITION P_2024 VALUES LESS THAN (TO_DATE('01-JAN-2025','DD-MON-YYYY')),
    PARTITION P_2025 VALUES LESS THAN (TO_DATE('01-JAN-2026','DD-MON-YYYY')),
    PARTITION P_2026 VALUES LESS THAN (TO_DATE('01-JAN-2027','DD-MON-YYYY')),
    PARTITION P_FUTURO VALUES LESS THAN (MAXVALUE)
);

Podríamos ir añadiendo particiones según vayamos necesitando.

Si quisiera un particionado más fino, podría particionar por meses:
CREATE TABLE MATRICULAS (
    ID               NUMBER      GENERATED BY DEFAULT AS IDENTITY,
    ALUMNO_ID        NUMBER      NOT NULL,
    EMPRESA_ID       NUMBER,
    CONVOCATORIA_ID  NUMBER      NOT NULL,
    ESTADO_ID        NUMBER      NOT NULL,
    FECHA_MATRICULA  DATE        NOT NULL,
    PRECIO           NUMBER(10,2) NOT NULL,
    DESCUENTO        NUMBER(5,2)  NOT NULL,
    PRECIO_FINAL     NUMBER(10,2) NOT NULL
) PARTITION BY RANGE (FECHA_MATRICULA)  INTERVAL (NUMTOYMINTERVAL(1,'MONTH')) (
    PARTITION P_2023_01 VALUES LESS THAN (TO_DATE('01-FEB-2023','DD-MON-YYYY'))
); 

El INTERVAL me permite que se creen particiones automáticamente según se vayan necesitando.

## Por lista de valores

En nuestro caso nos vendría bien para el estado de la matrícula.

CREATE TABLE MATRICULAS (
    ID               NUMBER      GENERATED BY DEFAULT AS IDENTITY,
    ALUMNO_ID        NUMBER      NOT NULL,
    EMPRESA_ID       NUMBER,
    CONVOCATORIA_ID  NUMBER      NOT NULL,
    ESTADO_ID        NUMBER      NOT NULL,
    FECHA_MATRICULA  DATE        NOT NULL,
    PRECIO           NUMBER(10,2) NOT NULL,
    DESCUENTO        NUMBER(5,2)  NOT NULL,
    PRECIO_FINAL     NUMBER(10,2) NOT NULL
) PARTITION BY LIST (ESTADO_ID) (
    PARTITION P_EN_GESTION VALUES (1,2,3),
    PARTITION P_FINALIZADA VALUES (DEFAULT)
);

Si me interesa es:
ALTER TABLE MATRICULAS ENABLE ROW MOVEMENT;
Eso me permite mover filas entre particiones cuando se actualiza el ESTADO_ID.

OJO CON ESTO! Tiene implicaciones importantes:
- Al hacerlo, si o si hay un row_movement... es decir, el dato se mueve de un bloque de un segmento de la tabla a otro bloque de otro segmento de la tabla.
- Eso implica que el ROWID del dato cambia.
- Eso implica que si tengo índices sobre esa tabla, esos índices deben actualizarse para reflejar el nuevo ROWID.
- Eso implica que las operaciones de UPDATE serán más costosas (más I/Os, más CPU)

Si hay pocos cambios de estado, no es problema.

En un caso como el nuestro, me podría interesar incluso, si la tabla fuese muy grande, particionar por rangos de fecha y por lista de estado a la vez (particionado compuesto).

CREATE TABLE MATRICULAS (
    ID               NUMBER      GENERATED BY DEFAULT AS IDENTITY,
    ALUMNO_ID        NUMBER      NOT NULL,
    EMPRESA_ID       NUMBER,
    CONVOCATORIA_ID  NUMBER      NOT NULL,
    ESTADO_ID        NUMBER      NOT NULL,
    FECHA_MATRICULA  DATE        NOT NULL,
    PRECIO           NUMBER(10,2) NOT NULL,
    DESCUENTO        NUMBER(5,2)  NOT NULL,
    PRECIO_FINAL     NUMBER(10,2) NOT NULL
) PARTITION BY RANGE (FECHA_MATRICULA) SUBPARTITION BY LIST (ESTADO_ID) (
    PARTITION P_2023 VALUES LESS THAN (TO_DATE('01-JAN-2024','DD-MON-YYYY')) (
        SUBPARTITION P_2023_EN_GESTION VALUES (1,2,3),
        SUBPARTITION P_2023_FINALIZADA VALUES (DEFAULT)
    ),
    PARTITION P_2024 VALUES LESS THAN (TO_DATE('01-JAN-2025','DD-MON-YYYY')) (
        SUBPARTITION P_2024_EN_GESTION VALUES (1,2,3),
        SUBPARTITION P_2024_FINALIZADA VALUES (DEFAULT)
    )
    -- Y así sucesivamente
);

## Reparto aleatorio: Particionado por hash

CREATE TABLE MATRICULAS (
    ID               NUMBER      GENERATED BY DEFAULT AS IDENTITY,
    ALUMNO_ID        NUMBER      NOT NULL,
    EMPRESA_ID       NUMBER,
    CONVOCATORIA_ID  NUMBER      NOT NULL,
    ESTADO_ID        NUMBER      NOT NULL,
    FECHA_MATRICULA  DATE        NOT NULL,
    PRECIO           NUMBER(10,2) NOT NULL,
    DESCUENTO        NUMBER(5,2)  NOT NULL,
    PRECIO_FINAL     NUMBER(10,2) NOT NULL
) PARTITION BY HASH (ID) PARTITIONS 4;

ID ( Número )... se hace algo parecido a lo que pasaba con la letra de los DNIs.
Tomo el número, lo divido entre 4 y según el resto (0,1,2,3) lo meto en una partición u otra.
Esto hace un round robin entre las particiones.

## Particionado por años (Intervalo de tiempo fijo), pero con almacenamiento de tipos diferentes

CREATE TABLE MATRICULAS (
    ID               NUMBER      GENERATED BY DEFAULT AS IDENTITY,
    ALUMNO_ID        NUMBER      NOT NULL,
    EMPRESA_ID       NUMBER,
    CONVOCATORIA_ID  NUMBER      NOT NULL,
    ESTADO_ID        NUMBER      NOT NULL,
    FECHA_MATRICULA  DATE        NOT NULL,
    PRECIO           NUMBER(10,2) NOT NULL,
    DESCUENTO        NUMBER(5,2)  NOT NULL,
    PRECIO_FINAL     NUMBER(10,2) NOT NULL
) PARTITION BY RANGE (FECHA_MATRICULA)  (
    PARTITION P_2023 VALUES LESS THAN (TO_DATE('01-JAN-2024','DD-MON-YYYY')) TABLESPACE SLOW_TS,
    PARTITION P_2024 VALUES LESS THAN (TO_DATE('01-JAN-2025','DD-MON-YYYY')) TABLESPACE SLOW_TS,
    PARTITION P_2025 VALUES LESS THAN (TO_DATE('01-JAN-2026','DD-MON-YYYY')) TABLESPACE MEDIUM_TS,
    PARTITION P_2026 VALUES LESS THAN (TO_DATE('01-JAN-2027','DD-MON-YYYY')) TABLESPACE FAST_TS,
    PARTITION P_FUTURO VALUES LESS THAN (MAXVALUE) TABLESPACE FAST_TS
);

Cuando acabe el 2025:
ALTER TABLE MATRICULAS
    MODIFY PARTITION P_2025 TABLESPACE SLOW_TS;

---

Tener índices globales y locales en tablas particionadas.

CREATE INDEX IDX_MATRICULAS_CONVOCATORIA       ON MATRICULAS(CONVOCATORIA_ID) GLOBAL; -- Índice global
CREATE INDEX IDX_MATRICULAS_CONVOCATORIA_LOCAL ON MATRICULAS(CONVOCATORIA_ID) LOCAL;  -- Índice local

El índice local se crea por partición. De esa forma, si hago un mantenimiento de una partición, solo afecta a los índices de esa partición.