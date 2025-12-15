SELECT COUNT(*) FROM CURSOS;

---------------------------------------------------------------------------
--| Id  | Operation             | Name      | Rows  | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
--|   0 | SELECT STATEMENT      |           |     1 |     5   (0)| 00:00:01 |
--|   1 |  SORT AGGREGATE       |           |     1 |            |          |
--|   2 |   INDEX FAST FULL SCAN| PK_CURSOS |  1844 |     5   (0)| 00:00:01 |
---------------------------------------------------------------------------

-- Está sacando mal el número de resultados en el plan de ejecución.
-- El la query va bien (2000)... pero en el plan de ejecución está estimando mal el número de filas (1844).
-- La pista la tenemos un poco más abajo:
-- Note
-----
--   - dynamic statistics used: dynamic sampling (level=2)

-- Ahí indica quee ha usado estadísticas dinámicas (ESTIMADAS) (sampling level 2).
-- Por qué ha usado estadísticas dinámicas? Porque no hay estadísticas estáticas (reales) de la tabla CURSOS.

-- Podríamos generar estadísticas reales con:
BEGIN 
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PROFESOR',
    tabname => 'CURSOS',
    estimate_percent => NULL,
    block_sample => FALSE,
    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
    cascade => TRUE
  );
END;
/
-- Después de esto, al mirar el plan de ejecución:
---------------------------------------------------------------------------
--| Id  | Operation             | Name      | Rows  | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
--|   0 | SELECT STATEMENT      |           |     1 |     3   (0)| 00:00:01 |
--|   1 |  SORT AGGREGATE       |           |     1 |            |          |
--|   2 |   INDEX FAST FULL SCAN| PK_CURSOS |  2000 |     3   (0)| 00:00:01 |
---------------------------------------------------------------------------
-- Ahora si vemos que el número de filas estimadas (2000) coincide con el real (2000).
-- Al mirar planes de ejecución lo que vemos es la estimación que hace el optimizador... Esa estimación la saca en base a las estadísticas
--  que tiene. Si no tiene estadísticas... medio estima unas (dinámicas) que pueden ser erróneas.
-- No lee había ido mal (1844 vs 2000)... pero podría haber ido peor. Esto es un 1844/2000 = 92.2% de acierto.

-- Si hace una mala estimación (y esto pasa mucho cuando empezamos a meter filtros), puede ser que el plan de ejecución que elija 
-- no sea el óptimo. Cosas que pueden ocurrir:
-- - Que empiece filtrando por una columna que no filtre tanto, cuando hay otra columna que filtra más.
-- - Que decida uno usar un índice cuando podría haberlo usado.
-- - Que cambie la estrategia de join entre tablas (nested loops, hash join, merge join, etc).

-- Generar estadísticas de todas las tablas:
BEGIN 
  DBMS_STATS.GATHER_SCHEMA_STATS(
    ownname => 'PROFESOR',
    estimate_percent => NULL,
    block_sample => FALSE,
    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
    cascade => TRUE
  );
END;
/

-- Generar estadísticas puede llevar rato en tablas grandes. Hay que tener cuidado.
-- Opciones: 
-- Generar estadñisticas pero sin usar todos los datos... solo una muestra (estimate_percent)
BEGIN 
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PROFESOR',
    tabname => 'CURSOS',
    estimate_percent => 10, -- Solo el 10% de los datos
    block_sample => TRUE,   -- Muestra por bloques (más rápido)
    method_opt => 'FOR ALL COLUMNS SIZE AUTO',
    cascade => TRUE
  );
END;
/
-- No son estadísticas de tanta calidad... pero es mejor que nada y se generan más rápido.
-- Más adelante hablaremos de las estadísticas en más detalle:
-- - Formas de regenerarlas automáticamente
-- - Distintos tipos de estadísticas (estadísticos (media, min, max..) o histogramas)

-- OTRO POTENCIAL MOTIVO (que no es en nuestro caso)... que hubiera muchas filas con valores duplicados en el campo/indice
-- Tabla Cursos... pero un índice en TIPO_CURSO
-- Tipo de curso son 5 potenciales valores (1 a 5)
-- En el índice solo habría 5 entradas, cada una apuntando a muchos cursos
-- Ejemplo de como sería el índice:
-- TIPO_CURSO | CURSOS_ID
-- ---------------------------------------
--     1      | 1, 4, 7, 10, ...
--     2      | 2, 5, 8, 11, ...
--     3      | 3, 6, 9, 12, ...
--     4      | 13, 16, 19, ...
--     5      | 14, 17, 20, ...

-- Al hacer un select COUNT(*) FROM CURSOS ; // Si decidiera usar el índice dee tipo curso (NOTA: PODRIAMOS FORZARLO CON UN HINT)
-- El plan de ejecución sería del tipo:
-- 0  SELECT STATEMENT
-- 1.   SORT AGGREGATE                             Suma: 2000
-- 1      INDEX FAST FULL SCAN TIPO_CURSO_IDX      2000 (Realmente en el índice solo hay 5 entradas)... le va muy rápido 
SELECT * FROM CURSOS WHERE ROWNUM <= 5;

SELECT COUNT(*) FROM CURSOS WHERE CODIGO = 'CUR_A1ALNAIUJZ';
---------------------------------------------------------------------------------------
--| Id  | Operation          | Name             | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------
--|   0 | SELECT STATEMENT   |                  |     1 |    15 |     1   (0)| 00:00:01 |
--|   1 |  SORT AGGREGATE    |                  |     1 |    15 |            |          |
--|*  2 |   INDEX UNIQUE SCAN| UQ_CURSOS_CODIGO |     1 |    15 |     1   (0)| 00:00:01 |
---------------------------------------------------------------------------------------
-- INDEX UNIQUE SCAN : Se basa en búsqueda binaria en un índice único (UQ_CURSOS_CODIGO)
-- Va como un tiro!

SELECT * FROM CURSOS WHERE CODIGO = 'CUR_A1ALNAIUJZ';
---------------------------------------------------------------------------------------
--| Id  | Operation          | Name             | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------
--|   0 | SELECT STATEMENT   |                  |     1 |   688 |     1   (0)| 00:00:01 |
--|   1 |  TABLE ACCESS BY INDEX ROWID| CURSOS  |     1 |   688 |     1   (0)| 00:00:01 |
--|*  2 |   INDEX UNIQUE SCAN| UQ_CURSOS_CODIGO |     1 |    15 |     1   (0)| 00:00:01 |
---------------------------------------------------------------------------------------

SELECT TIPO, COUNT(*) FROM CURSOS GROUP BY TIPO;
-- Tenemos 6 tipos... y más o menos 1/6 de los cursos en cada tipo.

-----------------------------------------------------------------------------
--| Id  | Operation          | Name   | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
--|   0 | SELECT STATEMENT   |        |     6 |    18 |    69   (2)| 00:00:01 |
--|   1 |  HASH GROUP BY     |        |     6 |    18 |    69   (2)| 00:00:01 |
--|   2 |   TABLE ACCESS FULL| CURSOS |  2000 |  6000 |    68   (0)| 00:00:01 |
-----------------------------------------------------------------------------

-- Aquñi nos acaba de hacer un FULL SCAN de la tabla CURSOS.
-- Por qué? Porque no hay índice en el campo TIPO.
-- Ese campo es un Foreign Key a la tabla TIPOS_CURSOS... 
-- pero Oracle por defecto no añade índices a las Foreign Keys (a diferencia de otras bases de datos como MySQL).

SELECT c.*, t.* FROM CURSOS c JOIN TIPOS_CURSOS t ON c.TIPO = t.ID;
-----------------------------------------------------------------------------------
--| Id  | Operation          | Name         | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------
--|   0 | SELECT STATEMENT   |              |  2000 |  1435K|    71   (0)| 00:00:01 |
--|*  1 |  HASH JOIN         |              |  2000 |  1435K|    71   (0)| 00:00:01 |
--|   2 |   TABLE ACCESS FULL| TIPOS_CURSOS |     6 |   282 |     3   (0)| 00:00:01 |
--|   3 |   TABLE ACCESS FULL| CURSOS       |  2000 |  1343K|    68   (0)| 00:00:01 |
-----------------------------------------------------------------------------------
-- En este caso está haciendo un hash join entre las dos tablas.
-- Eso es una de las varias estrategias de join que tiene Oracle.
-- De entrada, para hacer eso, lee las 2 tablas completas (full scan).
-- No está mal... ya que le estamos pidiendo todos los campos de todas las filas.

SELECT c.*, t.* 
FROM CURSOS c JOIN TIPOS_CURSOS t ON c.TIPO = t.ID
WHERE c.tipo = 3;

------------------------------------------------------------------------------------------------
--| Id  | Operation                    | Name            | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
--|   0 | SELECT STATEMENT             |                 |   333 |   239K|    69   (0)| 00:00:01 |
--|   1 |  NESTED LOOPS                |                 |   333 |   239K|    69   (0)| 00:00:01 |
--|   2 |   TABLE ACCESS BY INDEX ROWID| TIPOS_CURSOS    |     1 |    47 |     1   (0)| 00:00:01 |
--|*  3 |    INDEX UNIQUE SCAN         | PK_TIPOS_CURSOS |     1 |       |     0   (0)| 00:00:01 |
--|*  4 |   TABLE ACCESS FULL          | CURSOS          |   333 |   223K|    68   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------
  
--Predicate Information (identified by operation id):
---------------------------------------------------
 
--   3 - access("T"."ID"=3)
--   4 - filter("C"."TIPO"=3)

--Se está haciendo un loop anidado (nested loops).
-- Lo que hace es:
-- FullScan de CURSOS (filtrando por TIPO=3, que son 333 filas)
-- En paralelo entra en tipos de cursos... por el pk: INDEX UNIQUE SCAN en PK_TIPOS_CURSOS
--  y con el ROWID entra en la tabla TIPOS_CURSOS para sacar los datos de ese tipo (ID=3): NOMBRE, CODIGO y DESCRIPCION.
-- Hace un bucle por cada fila de CURSOS (333 veces): NESTED LOOPS

-- Creamos un índice sobre el campo tipo... a ver qué pasa?
CREATE INDEX IDX_CURSOS_TIPO ON CURSOS(TIPO);

SELECT TIPO, COUNT(*) FROM CURSOS GROUP BY TIPO;

SELECT c.*, t.* 
FROM CURSOS c JOIN TIPOS_CURSOS t ON c.TIPO = t.ID
WHERE c.tipo = 3;

-- A pesar de haber creado un índice en CURSOS.TIPO... 
-- el optimizador decide no usarlo... prefiere seguir haciendo un full scan de CURSOS.
-- Tenemos 2000 cursos en total
-- Tenemos 333 de tipo 3
-- 333/2000 = 16.65%
-- Si Oracle fuera al índice entrando por tipo=3, 
-- tendría que leer 333 entradas del índice, que le darían 333 ROWID,
-- y con esos ROWID tendría que ir a la tabla CURSOS a buscar 333 filas
-- Para sacar las columnas que le hemos pedido (c.*)

-- Decide que tarda menos hacer un full scan de CURSOS (leyendo las 2000 filas)
-- y filtrar por TIPO=3, que usar el índice.

-- Puedo forzarle a usar el índice con un hint:
SELECT /*+ INDEX(c IDX_CURSOS_TIPO) */ c.*, t.* 
FROM CURSOS c JOIN TIPOS_CURSOS t ON c.TIPO = t.ID
WHERE c.tipo = 3;

-- NOTA: HINTS DE ORACLE
-- Me permite dar "sugerencias" al optimizador para que use ciertas estrategias.
-- El optimizador en cualquier caso decide... y puede ignorar el hint.
-- Hay hints para forzar uso de índices, evitar uso de índices, forzar tipos de joins...
-- Los hints se pasan después del SELECT, entre /*+  y  */

-- Si un query no filtra y se queda con menos de un 4-5% de las filas, el índice aporta poco.
-- Hay más fatcores a tener en cuenta.. no es tan sencillo.
-- Depende del tamaño de bloque, del tamaño de cada registro (y por ende de la cantidad de registros por bloque)...
-- Hay consultas que pueden no verse afectadas por el índice y otras que si.

-- Ese índice, por ser tan poco discriminativo (solo 6 valores posibles), no aporta mucho.
-- Nos toca mantenerlo, reservarle espacio en disco, penaliza los inserts/updates/deletes...
-- Y si se usa, oracle estima que tarda más que sin usarlo.

SELECT  c.*, t.* 
FROM CURSOS c JOIN TIPOS_CURSOS t ON c.TIPO = t.ID
WHERE c.tipo = 3;

-- El coste estimado del query sin usar el índice es 69...
-- El fullscan le supone un coste de 68.
-- Al usar el índice la query se va a 179.
-- Y el ACCESS BY INDEX ROWID le suma 178.

DROP INDEX IDX_CURSOS_TIPO;
-- Al final lo borramos porque no ha aportado nada.


SELECT COUNT(*) FROM CURSOS WHERE PRECIO_PARA_PARTICULARES < 220;
-- Por defecto, al no haber índice, se va a hacer un full scan de CURSOS.
-- Creamos el índice:
CREATE INDEX IDX_CURSOS_PRECIO_PARTICULARES ON CURSOS(PRECIO_PARA_PARTICULARES);

SELECT * FROM CURSOS WHERE PRECIO_PARA_PARTICULARES < 220;
-- En este caso, si se está usndo el índice.
-- Vemos lo mismo que pasaba con el tipo de curso.
-- Se hace un range scan del índice (INDEX RANGE SCAN) (MUY RAPIDO)
-- Saca los ROWIds de las filas que cumplen la condición = 26
-- Y con esos ROWIDs va a la tabla CURSOS a sacar los datos (TABLE ACCESS BY INDEX ROWID)

-- Como la búsqueda es muy discriminativa (solo 26 filas de 2000, 1.3%)
-- El índice aporta mucho y el optimizador decide usarlo.
-- El coste que estima oracle es de 28.

-- Si forzamos a no usar el índice:
SELECT /*+ NO_INDEX(c IDX_CURSOS_PRECIO_PARTICULARES) */ * 
FROM CURSOS c WHERE PRECIO_PARA_PARTICULARES < 220;
-- El coste sube a 68 (full scan de CURSOS)

-- Habrá un punto de equilibrio (umbral) en el que el optimizador decidirá usar o no el índice
SELECT * FROM CURSOS WHERE PRECIO_PARA_PARTICULARES < 1000;
-- En este caso, son 799 filas (39.95%)
-- El optimizador decide no usar el índice... y hacer un full scan de CURSOS.
-- El coste estimado es 68 (full scan de CURSOS)
-- Si forzamos a usar el índice:
SELECT /*+ INDEX(c IDX_CURSOS_PRECIO_PARTICULARES) */ * 
FROM CURSOS c WHERE PRECIO_PARA_PARTICULARES < 1000;
-- En este caso el coste se dispara a 799.. x10

SELECT * FROM CURSOS WHERE PRECIO_PARA_PARTICULARES < 260;
-- Recupera 66 filas, que supone 3.3%
-- Encaja muy bien con lo que os comenté.. Un 4%/5%

SELECT * FROM CURSOS ORDER BY PRECIO_PARA_PARTICULARES;
-- A pesar de tener un índice en PRECIO_PARA_PARTICULARES, donde los datos
-- están ordenados por ese campo... no lo usa para ordenar.
-- Hace un full scan de CURSOS y luego ordena (SORT ORDER BY)

SELECT * FROM CURSOS 
WHERE PRECIO_PARA_PARTICULARES < 300
ORDER BY PRECIO_PARA_PARTICULARES ;
-- Coste 68 (FULL SCAN de CURSOS) + 1 (SORT ORDER BY)

--
-- Si forzamos el índice:
SELECT 
/*+ INDEX(c IDX_CURSOS_PRECIO_PARTICULARES) */ * 
FROM CURSOS c
WHERE PRECIO_PARA_PARTICULARES < 300
ORDER BY PRECIO_PARA_PARTICULARES ;
-- Coste 2 (INDEX RANGE SCAN) + 107 (TABLE ACCESS BY INDEX ROWID) 
-- En este caso no hay sort, porque el índice ya está ordenado por PRECIO_PARA_PARTICULARES


--

SELECT DNI FROM PROFESORES WHERE DNI LIKE '8%';

SELECT COUNT(*) FROM PROFESORES ;

-- La query posiblemente no es tan restrictiva: 101/800 = 12.625%
-- Por qué si usa el índice? El único que pido, está en el índice.

SELECT * FROM PROFESORES WHERE DNI LIKE '8%';  -- Coste 3
-- Aquí al pedir todos los campos, tiene que ir a la tabla
-- Y decide no usar el índice.
-- Si fuerzo el índice:
SELECT /*+ INDEX(p PK_PROFESORES) */ *
FROM PROFESORES p WHERE DNI LIKE '8%';  -- Coste 8

SELECT * FROM PROFESORES WHERE DNI LIKE '83%';  -- Coste 3
SELECT /*+ INDEX(p PK_PROFESORES) */ *
FROM PROFESORES p WHERE DNI LIKE '83%';  -- Coste 8

-- El problema es que aunque use el índice,
-- lo está usando para hacer búsqueda binaria? NO
-- Está haciendo un full scan del índice (INDEX FULL SCAN)


SELECT a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID;

-- En convocatorias no hay índice para el campo CURSO_ID.
-- Si se usa aquñi el índice de matrículas (ALUMNO_ID), 
-- Ya que no estamos sacando datos de esa tabla, solo la usamos para hacer el join.
-- El hecho es que de la tabla convocatorias tampoco estamos sacando campos.
-- Y podría aprovecharse de un índice
-- Vamos a ver la diferencia. Sin índice en CONVOCATORIAS.CURSO_ID: Coste: 371
-- La parte de convocatorias (la lectura). Coste 68
-- Hace primero de nada un join entre cursos y convocatorias
-- Seguido del join con matrículas

-- Un primer índice que podríamos crear es solo con el campo CURSO_ID
CREATE INDEX IDX_CONVOCATORIAS_CURSO_ID ON CONVOCATORIAS(CURSO_ID);


SELECT a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID;
-- No usa el índice para nada...
-- Porqué? Necesita de esa tabla 2 campos: ID y CURSO_ID
-- Y en el índice solo tiene CURSO_ID
-- Por lo que tiene que ir a la tabla igualmente (TABLE ACCESS BY INDEX ROWID)

-- Forcemoslo:
SELECT /*+ INDEX(cv IDX_CONVOCATORIAS_CURSO_ID) */ 
a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID;

-- Borramos el índice:
DROP INDEX IDX_CONVOCATORIAS_CURSO_ID;
-- Y vamos a crearlo con los dos campos:
CREATE INDEX IDX_CONVOCATORIAS_CURSO_ID_PK ON CONVOCATORIAS(CURSO_ID, ID);

SELECT 
a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID;
-- 51 hemos ahorrado de 371 = 51/371 = 13.75% de mejora.
-- Forzar a que no se use el índice:IDX_CONVOCATORIAS_CURSO_ID_PK
SELECT /*+ NO_INDEX(cv IDX_CONVOCATORIAS_CURSO_ID_PK) */
a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID;        

-- Borramos el índice:
DROP INDEX IDX_CONVOCATORIAS_CURSO_ID_PK;
-- Y lo vamos a crear de nuevo, en este caso con los campos invertidos:
CREATE INDEX IDX_CONVOCATORIAS_PK_CURSO_ID ON CONVOCATORIAS(ID, CURSO_ID);

SELECT 
a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID;

-- Al filtrar es cuando vamos a notar diferencia

SELECT 
a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID
WHERE c.PRECIO_PARA_PARTICULARES < 300;

-- Coste 319
-- Ha pasado de devolver 120000 filas a devolver 6317 filas..
-- Y el coste es básicamente el mismo que sin el filtro (320 vs 319)


SELECT 
a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID
WHERE cv.FECHA_INICIO > TO_DATE('2026-01-01', 'YYYY-MM-DD');


SELECT 
a.nombre || ' ' || a.apellidos AS nombre_completo, c.nombre AS curso_nombre
FROM 
ALUMNOS a
JOIN MATRICULAS m ON a.ID = m.ALUMNO_ID
JOIN CONVOCATORIAS cv ON m.CONVOCATORIA_ID = cv.ID
JOIN CURSOS c ON cv.CURSO_ID = c.ID
WHERE m.FECHA_MATRICULA > TO_DATE('2025-12-01', 'YYYY-MM-DD');

SELECT MIN(m.FECHA_MATRICULA), MAX(m.FECHA_MATRICULA)
FROM MATRICULAS m;

CREATE INDEX IDX_MATRICULAS_FECHA_MATRICULA ON MATRICULAS(FECHA_MATRICULA);
DROP INDEX IDX_MATRICULAS_FECHA_MATRICULA;
-- Lo creamos con todos los campos necesarios para query
CREATE INDEX IDX_MATRICULAS_FECHA_MATRICULA_ALUMNO_ID_CONVOCATORIA_ID 
ON MATRICULAS(FECHA_MATRICULA, ALUMNO_ID, CONVOCATORIA_ID);

-- Resumen:
-- - Hay que tener mucho cuidado con los índices que creamos.
-- - La misma query, usará o no un índice en función de lo discriminativa que sea la búsqueda.
-- - Os dije, a priori, no me interesa crear ni un índice.. salvo algunos muy evidentes, que se usen uen muchas joins de tablas grandes.
-- - Hay que analizar los planes de ejecución para ver que queries podrían beneficiarse de índices.
-- - Y probarlos.

-- Este es el punto 1 donde mirar, de cara al rendimiento del oracle.
-- Desarrollo nunca me va a decir queries necesitan índices. 
-- NO TIENEN LOS DATOS REALES DE USO DE LA BASE DE DATOS.
-- No saben que filtros ponen los usuarios.
-- Y la misma query con muy poca diferencia en el filtro, puede cambiar mucho el plan de ejecución.
-- Lo hemos visto con el precio. 
-- - 260 Si usa índice
-- - 270 No usa índice

-- SOLO SALE DE MONITORIZACION.

-- Se tirarán miles de queries diferentes.
-- Tendré que buscar las que más veces se ejecutan y las que más tiempo consumen.
-- Y de esas, ver cuales podrían beneficiarse de índices.

-- Una vez hecho todo este trabajo.

-- Los datos que ahi estamos sacando son estimaciones del optimizador.
-- No hemos sacado ni un dato real de lo que ocurre.

-- Eso es lo siguiente.
-- Una vez idenficados los planes de ejecución más óptimos
-- para las queries más importantes (más frecuentes /oy más costosas)
-- Lo siguiente es ver los datos reales, y compararlo con las estimaciones del optimizador.

-- Si los datos reales son muy similares a las estimaciones del optimizador
-- GUAY
-- Pero si no lo son... tenemos un problema:
-- - Estadísticas desactualizadas o inexistentes
-- - Uso de RAM (cache)


-- Uso de la cache de Oracle
-- A nivel de instancia:
SELECT
  ROUND(
    (1 - (phys.value / (dbbg.value + cons.value))) * 100
  , 2) AS buffer_cache_hit_ratio_pct
FROM
  (SELECT value FROM v$sysstat WHERE name = 'physical reads') phys,
  (SELECT value FROM v$sysstat WHERE name = 'db block gets') dbbg,
  (SELECT value FROM v$sysstat WHERE name = 'consistent gets') cons;

-- Si una tabla o un indice pute (da un hit ratio bajo), hay que mirar por qué?
-- - Lo principal será ver el PCTFREE (porcentaje de espacio libre) los bloques de las tablas e índices.
-- - Si es muy alto, o tiene muchos bloques sucios (borrados, actualizados), necesitaremos:
--    - Reescribir tabla o índice (ALTER TABLE ... MOVE / ALTER INDEX ... REBUILD)
--    - O bajar el PCTFREE (ALTER TABLE ... PCTFREE n / ALTER INDEX ... PCTFREE n)
