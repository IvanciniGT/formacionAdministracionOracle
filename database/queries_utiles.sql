-- Ver el usuario con el que estoy conectado
SELECT USER FROM DUAL;

-- Ver la BBDD a la que estoy conectado
SHOW con_name;

-- Ver las PDBs de la instancia CDB
SELECT PDB_NAME, STATUS FROM DBA_PDBS;
-- Hay una vista llamada v$pdbs que tiene bastante información sobre las PDBs
SELECT NAME, OPEN_MODE FROM V$PDBS;
-- Enchufar una PDB
--ALTER PLUGGABLE DATABASE <NAME> OPEN;
--ALTER PLUGGABLE DATABASE <NAME> CLOSE;
--ALTER PLUGGABLE DATABASE <NAME> CLOSE IMMEDIATE;
--ALTER PLUGGABLE DATABASE ALL OPEN;

-- Cambiar de PDB
ALTER SESSION SET CONTAINER =ORCLPDB1;
SHOW con_name;

-- Miramos los ficheros que tenemos en la base de datos
DESC DBA_DATA_FILES;

SELECT * FROM DBA_DATA_FILES;

-- Nuestro fichero users01.dbf del tablespace USERS
-- Tiene:
-- Tamaño: 592445440 bytes (565 MB)
-- Bloques: 72320
-- Si sivido uno entre otro: 592445440 / 72320 = 8192 bytes por bloque = 8 KB por bloque

-- Los datos (indices, tablas, etc) se almacenan en segmentos.
-- Un segmento es un conjunto de extents.

SELECT 
    segment_name,
    segment_type,
    tablespace_name,
    owner,
    bytes/1024/1024 AS size_mb,
    blocks, 
    extents
FROM DBA_SEGMENTS
WHERE tablespace_name = 'USERS'
ORDER BY segment_name, owner
;

-- 384 bloques x 8 KB = 3 MB = size_mb TAMAÑO FISICO EN DISCO DE LA TABLA / INDICE

-- 17 x 8 
-- Un extent es un conjunto de 8 bloques contiguos en el fichero de datos (y por ende en disco)
SELECT 
    segment_name,
    owner,
    extent_id,
    file_id,
    block_id,
    blocks
FROM
    DBA_EXTENTS
WHERE 
    segment_name = 'CURSOS'
    AND OWNER = 'PROFESOR'
ORDER BY extent_id;

-- Mi tabla cursos (200 cursos) está guardada en 256 bloques
-- Esos bloques están agrupados en 17 extents
-- Cada extent tiene 8 bloques (salvo el último que tiene 128 bloques)
-- Cuanto más juntos estén los bloques en disco, mejor rendimiento tendremos al leerlos

-- Si tenemos los bloques agrupados en muchos extents, la tabla queda muy fragmentada en disco.
-- Eso hace que la lectura sea menos eficiente.

-- Tamaño lógico de la tabla
SELECT
    TABLE_NAME,
    OWNER,
    BLOCKS,
    EMPTY_BLOCKS,
    AVG_SPACE,
    AVG_ROW_LEN,
    NUM_ROWS
FROM 
    DBA_TABLES
WHERE 
    TABLE_NAME = 'CURSOS'
    AND OWNER = 'PROFESOR';


SELECT 
 ROWID,
 DBMS_ROWID.ROWID_RELATIVE_FNO(ROWID) AS FICHERO,
 DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) AS BLOQUE,
 DBMS_ROWID.ROWID_ROW_NUMBER(ROWID) AS POSICION_EN_BLOQUE,
 ID,
 NOMBRE
FROM PROFESOR.CURSOS
ORDER BY ID;
--WHERE ID = 1;
--- 
-- ROWID: FICHERO DE DATOS + BLOQUE + POSICION EN BLOQUE

SELECT 
 COUNT(*) AS TOTAL_REGISTROS,
 DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) AS BLOQUE
FROM PROFESOR.CURSOS
GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID)
ORDER BY TOTAL_REGISTROS DESC
;


SELECT 
 ROWID,
 DBMS_ROWID.ROWID_RELATIVE_FNO(ROWID) AS FICHERO,
 DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) AS BLOQUE,
 DBMS_ROWID.ROWID_ROW_NUMBER(ROWID) AS POSICION_EN_BLOQUE,
 ID,
 NOMBRE
FROM PROFESOR.CURSOS
WHERE ID = 1;

-- volcar (TRAZA) de un bloque concreto de un fichero de datos
--                         FILE     BLOCK  
ALTER SYSTEM DUMP DATAFILE 12 BLOCK 262;

-- Donde se ha guardado? En un fichero de traza del servidor Oracle

SELECT value FROM v$diag_info WHERE name = 'Default Trace File';
--/opt/oracle/diag/rdbms/orclcdb/ORCLCDB/trace/ORCLCDB_ora_1840.trc

SELECT 
 ROWID,
 DBMS_ROWID.ROWID_RELATIVE_FNO(ROWID) AS FICHERO,
 DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) AS BLOQUE,
 DBMS_ROWID.ROWID_ROW_NUMBER(ROWID) AS POSICION_EN_BLOQUE,
 ID,
 NOMBRE
FROM PROFESOR.PROFESORES
WHERE ID = 1;

ALTER SYSTEM DUMP DATAFILE 12 BLOCK 430;

DESC PROFESOR.PROFESORES;

-- Datos del profesor 1: Héctor:
--col  0: [ 2]  c1 02
--col  1: [ 7]  48 c3 a9 63 74 6f 72
--col  2: [15]  4d 65 72 69 6e 6f 20 52 c3 b3 64 65 6e 61 73
--col  3: [ 9]  37 36 37 31 35 34 35 34 4e

-- El nombre es la segunda columna.. y ocupa 7 bytes: H É C T O R
-- H -> 48 (HEX) -> 72 (DEC)
-- É -> C3 A9 (HEX) -> 195 169 (DEC)

UPDATE PROFESOR.PROFESORES SET NOMBRE = 'Federico' WHERE ID = 1;
COMMIT;

DROP TABLE PROFESOR.TABLA_PRUEBA PURGE;
-- Vamos a crear una tabla de prueba con una columna VARCHAR2(20)
CREATE TABLE PROFESOR.TABLA_PRUEBA (
    ID NUMBER PRIMARY KEY,
    NOMBRE VARCHAR2(20)
) PCTFREE 0;

-- Vamos a insertarle datos hasta que ocupe más de un bloque.. Datos de ancho fijo 20 bytes
DECLARE
    v_id NUMBER := 1;
    v_nombre VARCHAR2(20) := RPAD('A', 10, 'A');
BEGIN
    WHILE v_id <= 5000 LOOP
        INSERT INTO PROFESOR.TABLA_PRUEBA (ID, NOMBRE) VALUES (v_id, v_nombre);
        v_id := v_id + 1;
    END LOOP;
    COMMIT;
END;
/
SELECT 
    segment_name,
    owner,
    extent_id,
    file_id,
    block_id,
    blocks
FROM
    DBA_EXTENTS
WHERE 
    segment_name = 'TABLA_PRUEBA'
    AND OWNER = 'PROFESOR'
ORDER BY extent_id;


SELECT 
 COUNT(*) AS TOTAL_REGISTROS,
 DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) AS BLOQUE
FROM PROFESOR.TABLA_PRUEBA
GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID)
ORDER BY TOTAL_REGISTROS DESC
;

SELECT 
 ROWID,
 DBMS_ROWID.ROWID_RELATIVE_FNO(ROWID) AS FICHERO,
 DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) AS BLOQUE,
 DBMS_ROWID.ROWID_ROW_NUMBER(ROWID) AS POSICION_EN_BLOQUE,
 ID,
 NOMBRE
FROM PROFESOR.TABLA_PRUEBA
WHERE ID <400;

UPDATE PROFESOR.TABLA_PRUEBA SET NOMBRE = 'BBBBBBBBBBBBBBBBBBBB' WHERE ID < 800;

--20 bytes por fila + 2 bytes del id = 22 bytes por fila
--8192 bytes por bloque / 22 bytes por fila = 372 filas por bloque
--Y eso sin contar el overhead: cabecera del bloque, el row directory, y la cabecera de fila


SELECT 
 COUNT(*) AS TOTAL_REGISTROS,
 DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID) AS BLOQUE
FROM PROFESOR.TABLA_PRUEBA
GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID)
ORDER BY TOTAL_REGISTROS DESC
;
COMMIT;

ALTER SYSTEM DUMP DATAFILE 12 BLOCK 68868;

-- Aqui vemos el efecto llamado row migration
-- Cuando actualizamos una fila, si no cabe en el mismo bloque, Oracle la mueve a otro bloque
-- Y en el bloque original deja un puntero a la nueva ubicación de la fila
-- Ese puntero viene marcado con nrid en el volcado del bloque

-- Otra cosa que puede pasar el es row chaining
-- Si una fila es muy grande (más grande que un bloque), Oracle la divide en varios bloques
-- Y en cada bloque deja un puntero al siguiente bloque donde continúa la fila


-- Si pasan cualquiera de las 2 cosas, el rendimiento de lectura de la tabla se ve afectado negativamente.
-- Y además, los datos en fichero nos ocupan más espacio del necesario.

-- Esto necesitaría una operación de mantenimiento llamada SHRINK para volver a compactar los datos en los bloques.

-- ALTER TABLE PROFESOR.TABLA_PRUEBA SHRINK SPACE;
-- Para hacer eso, Oracle reescribe los datos en los bloques y depende de la tabla, eso puede llevar mucho tiempo.

-- Hay que tratar de evitarlo: 
-- - Buena organización de datos en tablas. Intentar que las filas sean lo más pequeñas posibles.
--   Incluso separando datos del mismo registro en distintas tablas si es necesario.
--   Como hemos hecho nosotros en nuestro modelo de datos : Matrículas y Evaluaciones.
--   De forma que separemos por frecuencia de acceso a los datos.
-- - Establecer muy bien el PCTFREE de las tablas.

-- Cuando actualizamos datos en una tabla, muchas veces hacemos un bloqueo.
SELECT * FROM PROFESOR.CURSOS WHERE ID = 1 FOR UPDATE;
-- Eso bloquea la fila para que ningún otro usuario pueda modificarla hasta que hagamos COMMIT o ROLLBACK.
-- Si otro usuario intenta hacer un UPDATE o DELETE sobre esa fila, se quedará esperando hasta que hagamos COMMIT o ROLLBACK.
-- Pregunta, Oracle bloquea a nivel de fila o a nivel de bloque?
-- Oracle bloquea a nivel de fila. No bloquea el bloque completo.
-- Pero... la información de bloqueo se guarda en el bloque donde está la fila.
-- Y en ocasiones esto puede provocar casos raros.
 
SELECT * FROM PROFESOR.CURSOS WHERE ID = 1 FOR UPDATE; -- Ivan       √
SELECT * FROM PROFESOR.CURSOS WHERE ID = 2 FOR UPDATE; -- David      x
SELECT * FROM PROFESOR.CURSOS WHERE ID = 3 FOR UPDATE; -- Cristina   √
SELECT * FROM PROFESOR.CURSOS WHERE ID = 4 FOR UPDATE; -- Antonio    x
SELECT * FROM PROFESOR.CURSOS WHERE ID = 5 FOR UPDATE; -- Diego      √

commit;

-- INIT TRANS

SELECT 
* 
FROM DBA_TABLES
WHERE 
    TABLE_NAME = 'CURSOS'
    AND OWNER = 'PROFESOR';

-- Cuando hacemos unn select for update, o directamente un update o delete, Oracle bloquea la fila,
-- para que nadie pueda estar haciendo cambios en paralelo en ella.
-- Esto va a nivel de transaccion:
-- Puedo hacer un select for update, y posteriormente ejecutar otros 4 updates en la misma transacción,
-- y todo eso va a estar bloqueado hasta que haga commit o rollback.

-- La información de qué fila está bloqueada se guarda en el bloque donde está la fila.... en la cabecera!
-- En el bloque, en la cabecera hay un espacio reservado para guardar información de bloqueo.
-- Itl           Xid                  Uba         Flag  Lck        Scn/Fsc
-- 0x01   0x0001.01e.000002c4  0x0240be1f.0127.15  --U-    1  fsc 0x0000.002b4db3
-- 0x02   0x0005.016.000002b7  0x024049a7.0132.19  C---    0  scn  0x00000000002b4d72

-- El SCN es un número de secuencia que Oracle usa para controlar la concurrencia y la consistencia de los datos.

-- Si no hay hueco en el bloque para guardar la información de bloqueo, oracle no puede bloquear la fila
-- Y directamente espera a que se libere el bloqueo de la fila.
-- Esto puede provocar bloqueos inesperados.
-- Estoy tratando de hacer un select for update de la fila 1, que no está bloqueada,
-- Y el sistema se me queda esperando...
-- Y lo que ocurre es que quizás no hay hueco en el bloque para guardar la información de bloqueo.
-- Oracle garantiza un mínimo de espacio para guardar información de bloqueo en cada bloque.
-- Ese espacio viene definido por el INITRANS de la tabla.
-- Cada registro que meto en la infoormación de bloqueo ocupa espacio: unos 20 bytes.
-- Si hago muchas transacciones concurrentes sobre filas que están en el mismo bloque,
-- Y el bloque está muy lleno de datos, puede que no haya espacio para guardar la información de bloqueo.
-- Y la petición queda encolada. No es un bloqueo lo que se produce.. es solo 
-- que mi petición queda encolada a la espera de que haya espacio en el bloque para guardar la info de bloqueo.
-- Como digo, Oracle prereserva un mínimo de espacio en cada bloque para guardar información de bloqueo.
-- Ese espacio viene definido por el INITRANS de la tabla.
-- El INITRANS por defecto es 1 y establece la cantidad de registros de bloqueo que se
-- garantizan en cada bloque. 
-- Esa tabla de bloqueos puede crecer hasta el MAXTRANS de la tabla....
-- Pero solo crecerá si hay espacio en el bloque. Si no hay hueco no... Y se produce encolamiento.
-- En general, del maxtrans no hay que preocuparse mucho, no estamos perdiendo espacio en disco.
-- Ese maxtrans es dinámico y Oracle lo ajusta según las necesidades.
-- Pero el INITRANS si que es importante.
-- Si espero mucha concurrencia en una tabla, y las filas de esa tabla son pequeñas
-- tendré muchas filas por bloque... y puede pasarme que en un momento dado, varias de esas filas
-- estén intentando ser modificadas en distintas transacciones concurrentes.
-- Y si no hay espacio en el bloque para guardar la información de bloqueo, las peticiones quedan encoladas.
-- Por tanto, en tablas con mucha concurrencia, es recomendable aumentar el INITRANS
-- Pero cuanto más lo aumente, más espacio en cada bloque estaré perdiendo para guardar datos.
-- Hay que buscar un equilibrio.
-- Hay tablas que de antemano sé que van a tener mucha concurrencia...
-- Y otras lo contrario, van a tener poca concurrencia.

SELECT * FROM PROFESOR.CURSOS WHERE ID = 3 FOR UPDATE; 

ALTER SYSTEM DUMP DATAFILE 12 BLOCK 262;
commit;

-- En nuestro caso, qué tabla se podría ver afectada fácilmente por esto?


SELECT
  ROUND(
    (1 - (phys.value / (dbbg.value + cons.value))) * 100
  , 2) AS buffer_cache_hit_ratio_pct
FROM
  (SELECT value FROM v$sysstat WHERE name = 'physical reads') phys,
  (SELECT value FROM v$sysstat WHERE name = 'db block gets') dbbg,
  (SELECT value FROM v$sysstat WHERE name = 'consistent gets') cons;

-- en nuestro caso, nos informa que el 99,83% de las lecturas se hacen 
-- desde el buffer cache. Eso es una locura.. eso si, tenemos una BBDD pequeña.

-- De hecho, el % ha bajado del 100% por la lectura inicial de los datos

-- Ese estudio, le podemos hacer por tabla: Hay que hacerlo con los segmentos

-- Si una tabla o un indice pute (da un hit ratio bajo), hay que mirar por qué?
-- - Lo principal será ver el PCTFREE (porcentaje de espacio libre) los bloques de las tablas e índices.
-- - Si es muy alto, o tiene muchos bloques sucios (borrados, actualizados), necesitaremos:
--    - Reescribir tabla o índice (ALTER TABLE ... MOVE / ALTER INDEX ... REBUILD)
--    - O bajar el PCTFREE (ALTER TABLE ... PCTFREE n / ALTER INDEX ... PCTFREE n)

SELECT
  s.owner,
  s.object_name AS tablename,
  s.object_type,
  SUM(CASE WHEN s.statistic_name = 'logical reads' THEN s.value ELSE 0 END) AS logical_reads,
  SUM(CASE WHEN s.statistic_name = 'physical reads' THEN s.value ELSE 0 END) AS physical_reads,
  ROUND(
    (1 - (SUM(CASE WHEN s.statistic_name = 'physical reads' THEN s.value ELSE 0 END) /
           NULLIF(SUM(CASE WHEN s.statistic_name = 'logical reads' THEN s.value ELSE 0 END), 0))
    ) * 100, 2
  ) AS cache_hit_ratio_percent
FROM
  v$segment_statistics s
WHERE
  s.object_type = 'TABLE'
  AND s.owner = 'PROFESOR'
GROUP BY
  s.owner, s.object_name, s.object_type
ORDER BY
  tablename
  ;


---


-- CONSULTA / GESTION DE ESTADISTICAS
ALTER SESSION SET CONTAINER = ORCLPDB1;

DESC DBA_TABLES;

SELECT * FROM DBA_TABLES WHERE TABLE_NAME = 'CURSOS' AND OWNER = 'PROFESOR';

DESC DBA_TAB_COL_STATISTICS;

SELECT * FROM DBA_TAB_COL_STATISTICS WHERE TABLE_NAME = 'CURSOS' AND OWNER = 'PROFESOR';



SELECT 
    i.index_name,
    t.table_name,
    i.clustering_factor,
    t.blocks AS table_blocks,
    t.num_rows AS table_rows,
    CASE 
        WHEN i.clustering_factor < t.blocks * 1.5 THEN 'EXCELENTE (Cerca de Bloques)'
        WHEN i.clustering_factor > t.num_rows * 0.8 THEN 'MALO (Cerca de Filas)'
        ELSE 'REGULAR (Intermedio)'
    END AS calidad_cf
FROM dba_indexes i
JOIN dba_tables t ON i.table_name = t.table_name
WHERE i.table_name = 'CURSOS' -- Opcional: filtra por tabla
      AND i.owner = 'PROFESOR' -- Opcional: filtra por esquema
      AND t.owner = 'PROFESOR' -- Opcional: filtra por esquema
ORDER BY i.table_name, i.index_name;

-- En nuestro caso, los datos están trucados. Son aleatorios
-- En una BBDD Real, si los datos están bien organizados, el clustering factor de muchas columnas irá será bueno
-- Ya que los índices estarán ordenados de forma similar a como están los datos en la tabla... por ejemplo:
-- ID -> Guarda una relación perfecta entre el índice y la tabla. Los datos en el índice EXACTAMENTE están en el mismo orden que en la tabla.
-- Fecha de alta -> Si los datos se insertan en orden cronológico, el índice estará muy bien organizado respecto a la tabla (quizás no perfecto, pero si muy bueno)
-- CODIGO: CUR-001, CUR-002, CUR-003, ... -> En este caso, el índice estará bastante muy organizado respecto a la tabla.
-- Estado de gestión --> OBSOLETO, VIGENTE --> En este caso, los cursos más antiguos (los primeros en insertarse) 
--    son lo que tendrán más probabilidad de estar obsoletos.
--    Por tanto, el índice estará razonablemente bien organizado respecto a la tabla.
--    Dicho de otra forma: La mayor parte de los cursos obsoletos estarán juntos en la tabla (al principio) 
--    y los cursos vigentes estarán juntos en la tabla (al final)
-- Nombre --> En este caso, el índice estará muy mal organizado respecto a la tabla.
-- Duración --> En este caso, el índice estará muy mal organizado respecto a la tabla.
-- Precio --> En este caso, más o menos....Cuersos más nuevos, serán más caros (aunque solo sea por efecto de la inflación)

-- Esto es una pista de si un índice va a ser eficiente o no, en según que consultas.
-- Para consultas que devuelvan muy pocos datos, al optimizador de consultas no le importa mucho el clustering factor.
-- Pero para consultas que devuelvan muchos datos, un clustering factor malo puede hacer que el índice no sea eficiente y no se use.