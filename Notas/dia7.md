

# Transacciones y bloqueos a nivel de fila

Durante una transacción, podemos solicitar el bloqueo de una fila para evitar que otras transacciones la modifiquen mientras nosotros estamos trabajando con ella.

SELECT * FROM EMPLEADOS WHERE ID = 10 FOR UPDATE;

Y oracle guarda que esa fila está bloqueada por nuestra transacción... en el bloque donde la fila está almacenada: Dentro de ese bloque en la cabecera, en la tabla de transacciones activas.

Esa tabla tiene un tamaño prereservado (INITRANS). Ese espacio está garantizado... pero ojo, en oracle el valor por defecto es 1. Si tenemos muchas transacciones que bloquean filas en el mismo bloque, oracle va usando espacio libre que tenga en el bloque (PCTFREE) para ampliar esa tabla de transacciones activas.
Cuando me quedo sin espacio en el bloque (y con el timpo puede ocurrir con independencia del pctfree que tenga establecido), oracle pausa (encola) la transacción que quiere bloquear la nueva fila, a la espera de que alguna otra transacción termine y libere espacio en la tabla de transacciones activas del bloque.

Con independencia del hueco que haya en el bloque, Oracle nunca ampliará la tabla de transacciones activas más allá del MAXTRANS (valor por defecto 255, Y NO SOLEMOS TOCAR NUNCA ESTO).

En situaciones raras, podemos tener un deadlock (bloqueo mutuo entre transacciones) por este motivo:
- Transacción A bloquea fila 1 en bloque X... y en ese bloque ya no hay espacio para más bloqueos.
- Transacción B bloquea fila 2 en bloque Y... y en ese bloque ya no hay espacio para más bloqueos.
- Transacción A intenta bloquear fila 3 en bloque Y... pero no puede porque no hay espacio (está bloqueada por B)... queda encolada a la espera de que B libere espacio.
- Transacción B intenta bloquear fila 4 en bloque X... pero no puede porque no hay espacio (está bloqueada por A)... queda encolada a la espera de que A libere espacio.

Ninguna terminará. Situación: Deadlock.

Esto son casos raros... de probabilidad baja. Pero.. habla con Murphy... si algo puede salir mal, saldrá mal.

En sistema con tablas de alta concurrencia de escrituras (muchas transacciones intentando bloquear filas en la misma tabla), es recomendable aumentar INITRANS a 2 o 3 o 10 para evitar estos problemas, sobre todo cuando es previsible que el bloque pueda quedarse sin espacio libre.

---

# HINTS (pistas para el optimizador)

Hemos visto como las estadísticas influyen mucho en el plan de ejecución que el optimizador elige para una consulta.
Como he dicho en más de una ocasión, el hacer análisis de planes de ejecución es la tarea clave para el mnto adecuado de una base de datos oracle.
Al final, todo se reduce a si mis consultas son rápidas o lentas... y eso depende de los planes de ejecución.
NOTA: NO TODO... otras cosas que me preocupan son el ALMACENAMIENTO (OPTIMIZARLO), Problemas de CONCURRENCIA (INITRANS...)

Hemos visto que del análisis de esos planes de ejecución saco:
- Si me faltan índices.
- Si me sobran índices.
- Si me falta memoria en PGA.
- Si las estadísticas están desactualizadas.
- Si las estadísticas son erróneas (por ejemplo, si tengo datos muy desbalanceados y no he usado histogramas).

Otros espectos a analizar en paralelo son:
- HIT RATIO DE BUFFER CACHE.
- El estado de los bloques (fragmentación, espacio libre, row migrations...).

Incluso con todo esto, puede que haya consultas lentas... por decisiones erróneas del optimizador que no se pueden arreglar con estadísticas.

## Por qué?

Tengo un índice creado sobre una columna que uso en los filtros WHERE.
Veo que Oracle no usa ese índice... y en su lugar hace un FULL TABLE SCAN.
Y la verdad que no veo que tenga mucho sentido... Tengo una query de bastante selectividad (cantidad no muy grande de filas devueltas respecto al total de filas de la tabla), pero aún así se pone cabezón y decide hacer un FULL TABLE SCAN.

Por qué motivo puede pasr algo así.

-- En este caso si está usando el índice
SELECT * FROM PROFESOR.CURSOS WHERE PRECIO_PARA_PARTICULARES < 260;
-- En este caso no está usando el índice
SELECT * FROM PROFESOR.CURSOS WHERE PRECIO_PARA_PARTICULARES < 300;

La query 1 devuelve menos filas que la query 2.. pero no solo es eso!

Cualquiera de esas queries, necesita identificar las filas que cumplen la condición, pero también recuperar el resto de columnas de esas filas (porque el SELECT es *).

Si se usa el índice, Oracle tiene que:
- Recorrer el índice para localizar las filas que cumplen la condición. -> ROWIDs           (INDEX RANGE SCAN)
- Con esos ROWIDs, ir a la tabla para recuperar el resto de columnas de esas filas.         (TABLE ACCESS BY ROWID)

La pregunta que se hace Oracle es si el coste de hacer INDEX RANGE SCAN + TABLE ACCESS BY ROWID es menor que el coste de hacer un FULL TABLE SCAN.

Y no solo influye la selectividad (cantidad de filas devueltas), sino también la cantidad de bloques de datos de la tabla que hay que leer para recuperar esas filas.

Si la query recupera 100 filas, pero esas 100 filas están distribuidas en 100 bloques de datos diferentes, entonces el coste de hacer TABLE ACCESS BY ROWID es alto (hay que leer 100 bloques de datos).
Por contra, si esas 100 filas están concentradas en 2 bloques de datos, entonces el coste de hacer TABLE ACCESS BY ROWID es bajo (solo hay que leer 2 bloques de datos).

Este concepto se denomina CLUSTERING FACTOR del índice.
El CLUSTERING FACTOR es un valor que mide lo bien o mal que están ordenadas las filas de la tabla respecto al orden del índice.

Un CLUSTERING FACTOR bajo indica que las filas están bien ordenadas respecto al índice (las filas que cumplen la condición están concentradas en pocos bloques de datos). BAJO SIGNIFICA, que está cercano al número de bloques de datos de la tabla.
Un CLUSTERING FACTOR alto indica que las filas están mal ordenadas respecto al índice (las filas que cumplen la condición están distribuidas en muchos bloques de datos). ALTO SIGNIFICA, que está cercano al número de filas de la tabla.

En función de esto, ORACLE decide si usar o no el índice para según qué consultas.

Esto son datos generales.. puede ser que en casos concretos, el optimizador se equivoque al tomar decisiones basándose en estos datos generales.

Esto es solo un ejemplo de por qué el optimizador puede tomar decisiones erróneas.

```sql
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
```

## Hay muchos hints

Los hints son instrucciones que le damos al optimizador para indicarle cómo nos gustaría que ejecute una consulta concreta.
Al final, son sugerencias que le damos al optimizador para que tome ciertas decisiones.. pero el optimizador es libre de hacer caso o no.

Eses hints se escriben justo después del SELECT, entre /*+ y */.

```sql
SELECT /*+ INDEX(c CURSO_IDX_PRECIO) */ *
FROM PROFESOR.CURSOS c
WHERE c.PRECIO_PARA_PARTICULARES < 300;
```

A priori, estas queries las escribe desarrollo. Y yo tengo como DBA poco control sobre ellas.
O no tan poco control. Como DBA oracle me da una fórmula muy potente para "intervenir" en esas queries sin tocar el código fuente.
Para poder inyectarles hints en esas queries, sin necesidad de tocar las queries originales.

Eso es lo que llamamos SQL PATCHING.

Son queries que le pido a oracle que modifique "en vuelo" para añadirles hints.
Es un poco limitado, sobre todo porque solo puedo parchear queries escritas literalmente!
Un mínimo cambio en la query (que cambie el valor de un filtro o un espacio en blanco) hace que el parche no se aplique.

Son especialmente útiles para 2 escenarios:
- Queries muy problemáticas de cuadros de mando, informes generales de la app.... Que se lanzan con bastante frecuencia y que no cambian.
- Con PREPARED STATEMENTS... porque en ese caso el parche se aplica a todas las ejecuciones de la query preparada, con independencia de los valores que se usen en cada ejecución.

## Qué es eso de los prepared statements?

Cuando llega una query a oracle, oracle tiene que parsearla (analizarla sintácticamente) , lo primero para mirar que esté bien escrita.
Hay muchas tareas que Oracle realiza cuando llega una query, y el parseo es la primera de ellas.
- La BBDD recibe la query (TEXTO CUTRE en SQL)
- Lo primero es parsearna la query (analizarla sintácticamente) y ver que no hay fallos de sintaxis.
- Lo siguiente es generar un árbol de entendimiento de la query (qué tablas intervienen, qué columnas, qué filtros, funciones, joins...)
- Mirar (en el catálogo) si las tablas existen, si el usuario tiene permisos sobre ellas, si las columnas existen, que tipos de datos tienen, si las funciones que se han indicado pueden aplicarse a esos tipos de datos...
- Generar un plan de ejecución (qué índices usar, qué orden de joins, qué métodos de acceso a datos usar...)
- Optimizar ese plan de ejecución (mirar si hay estadísticas, cluster factor, histrogramas... para tomar las mejores decisiones posibles)

- Ahora es cuando se ejecuta el plan de ejecución.

La cosa es que hay un muntón de tareas... que habitualmente damos por hechas.

Especialmente en:
- Queries muy complejas
- Queries que se lanzan muchas veces (por ejemplo, en aplicaciones web, donde cada petición de un usuario puede lanzar la misma query con diferentes parámetros)

lo que hacemos es usar queries con parámetros (placeholders) en lugar de valores literales. Ejemplo:

```sql
SELECT * FROM CURSOS WHERE PRECIO_PARA_PARTICULARES < :PRECIO_MAXIMO; -- parámetro SQL
```
Al llegar la query, la primera vez, se hace todo ese proceso de parseo, análisis, generación y optimización del plan de ejecución.
Y el resultado se cachea en la SHARED POOL (área de memoria compartida entre todas las sesiones).

La proxima vez que llegue la misma query (con independencia de los valores de los parámetros), oracle no tendrá que volver a hacer todo ese proceso... sino que ya sabe que la query es válida y ya tiene un plan de ejecución cacheado en la SHARED POOL, que puede usar.

Al montar una app, los desarrolles DEBEN hacer uso de prepared statements siempre que sea posible.

Yo he de velar (como DBA) porque se haga esto.

En estas queries es muy fácil aplicar SQL PATCHES, porque la query es siempre la misma (solo cambian los valores de los parámetros).

## Tipos de hints que tenemos en Oracle

Hay un montón de ellos. Algunos de los más usados:

- INDEX(tabla índice):    Forzar el uso de un índice concreto en una tabla concreta.
                          Si necesitas aplicar un filtro, hacer un join ... intenta hacer uso de un índice concreto.
- NO_INDEX(tabla índice): Forzar a NO usar un índice concreto en una tabla concreta.
                          Si el optimizador decide usar un índice que no me gusta, puedo forzar a que no lo use.  
- FULL(tabla):            Forzar un FULL TABLE SCAN en una tabla concreta.
                          Si el optimizador decide usar un índice que no me gusta, puedo forzar a que haga un full scan de la tabla.
- LEADING(tablas):        Forzar el orden de las tablas en los joins.
                          No en todo join aplica el concepto de "orden de las tablas"... pero en algunos casos sí.
                          - MERGE JOIN: El orden de las tablas no es importante.
                          - NESTED LOOPS: El orden de las tablas es importante.
                          - HASH JOIN: El orden de las tablas es importante.
- USE_NL(tabla):          Forzar el uso de NESTED LOOPS en los joins de una tabla concreta.
- USE_HASH(tabla):        Forzar el uso de HASH JOIN en los joins de una tabla concreta.
- MERGE(tabla):           Forzar el uso de MERGE JOIN en los joins de una tabla concreta.
- PARALLEL(tabla, grado): Forzar el uso de ejecución paralela en una tabla concreta, con un grado de paralelismo concreto.
- NO_PARALLEL(tabla):     Forzar a NO usar ejecución paralela en una tabla concreta.
- FIRST_ROWS(n):          Cambia el plan de ejecución de forma que se priorice la entrega de las primeras n filas lo más rápido posible. Por ejemplo, si tengo paginación en una app web, y solo necesito las primeras 10 filas, este hint puede ayudar a que esas primeras filas se entreguen rápido.
                          De nuevo.. esto puede mejorar la experiencia de usuario en apps web por ejemplo.. pero es más caro a nivel de recursos en la máquina. Si la tengo apretada, a nivel global del sistema puede empeorar el rendimiento. Si tengo abundancia de recursos, puede mejorar la experiencia de usuario. Si no la tengo (la abundancia), puede empeorar el rendimiento global del sistema.
- ALL_ROWS:               Cambia el plan de ejecución de forma que se priorice la entrega de todas las filas lo más rápido posible. Es el comportamiento por defecto del optimizador.

## PARALLEL y NO_PARALLEL

Hay veces donde quiero que oracle use todo la potencia de cálculo de la máquina para hacer la operación lo más rápido posible. Tengo que aplicar un filtro que afecta a muchas filas, y quiero que oracle use varios procesos en paralelo para hacer el trabajo más rápido:

```sql
SELECT /*+ PARALLEL(cursos, 8) */ *
FROM PROFESOR.CURSOS
WHERE PRECIO_PARA_PARTICULARES < 500;
```

Esto puede sentido en:
- tablas muy grandes (millones de filas)
- operaciones que afectan a muchas filas (filtros poco selectivos, joins entre tablas grandes...)
- PERO... me sale caro a nivel de recursos.

Si estoy dedicando las CPUs a hacer esta consulta, esas CPUs no estarán disponibles para otras tareas.

Si pongo esto en una query, podré hacer que esa query vaya más rápida... PERO mientras se eejcuta esa no podré estar resolviendo otras consultas.
Y al final el rendimiento global del sistema no mejora, incluso empeora... el abrir tareas paralelas (hilos) tiene un coste en CPU y memoria. No sale gratis.

Solo debo usar esto si tengo claro que en ese momento hay abundancia de recursos en la máquina (CPUs y memoria libres) y que puedo permitirme el lujo de dedicar muchos recursos a esa consulta concreta.
- Cargas masivas de datos (ETL)
- Generación de vistas materializadas

## Cómo se configuran los SQL PATCHES?

```sql
BEGIN
  DBMS_SQLTUNE.CREATE_SQL_PATCH(
    sql_text   => 'SELECT * FROM PROFESOR.CURSOS WHERE PRECIO_PARA_PARTICULARES < :PRECIO_MAXIMO',
    hints      => 'INDEX(cursos CURSO_IDX_PRECIO)',
    fixed      => TRUE, -- Si es TRUE, el parche se aplica siempre que la query coincida literalmente.
    name       => 'PARCHE_USO_INDICE_CURSO_IDX_PRECIO',
    description=> 'Parche para forzar el uso del índice CURSO_IDX_PRECIO en la tabla CURSOS'
  );
END;
/

-- Hay una tabla donde se van guardando los parches:
DESC DBA_SQL_PATCHES;
SELECT name, description, sql_text, hints, status FROM DBA_SQL_PATCHES;

-- borrar un parche:
BEGIN
  DBMS_SQLTUNE.DROP_SQL_PATCH(
    name => 'PARCHE_USO_INDICE_CURSO_IDX_PRECIO'
  );
END;
/

```
---

En el curso, estamos viendo lo mejor que puedo hacer con mi BBDD. En un entorno de producción, lo hacemos? Rara vez.
Ésto me cuesta tiempo -> dinero.
Lo habitual es si voy apretado de rendimiento -> más hardware (más CPUs, más memoria) = Más barato que horas de DBA.
 ^^^
ESTA ES LA REALIDAD EN LA MAYORÍA DE EMPRESAS.

Es como ir a un sastre a medida o comprar ropa pret a porter.

Es buena la solución.. no.. pero ... es barata y rápida.

> ESTO SON LOS CLOUDS!

Cuando al AZURE la contrato una BBDD Orale, Cosmos DB,  ... me están vendiendo una BBDD pret a porter.
La instalan con configuración estándar, sin optimizaciones.
Si va lenta, más hardware. Allí no hay nadie mirando planes de ejecución ni optimizando índices ni nada.

FUERZA BRUTA!

La realidad también es que sale más barato a corto plazo. Y es más rápido de implementar.

---

Hay casos que ni aún así... y ahí si que entra el DBA a optimizar.
