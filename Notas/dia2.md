
# Oracle

## Repaso del día anterior

- Acceso aleatorio a ficheros vs acceso secuencial
  Oracle usa ambos tipos de acceso
  - Datafiles: acceso aleatorio
  - Redo logs: acceso secuencial
- Estructura de almacenamiento interno de Oracle
  - Tablespaces
  - Datafiles
  - Segments
  - Extents
  - Blocks:
    - Cabecera del bloque
    - Directorio de filas
    - Filas de datos

    |----------------Datafile ---------------------------------------------------------------------------|
    |-extent1-------|-extent2-------|-extent3----------|-extent4-----------|-extent5-----------|-extent6-|
    |-1-|-2-|-3-|-4-|-5-|-6-|-7-|-8-|-9-|-10-|-11-|-12-|-13-|-14-|-15-|-16-|-17-|-18-|-19-|-20-|-21-|-22-|- Bloques
    ................                .......................................                                 SegmentoA
                    ................                                                                        SegmentoB
                                                                           ...............................  SegmentoC


- PCTFREE: espacio reservado en un bloque para futuras actualizaciones
  El problema es que si una fila cambia a un tamaño mayor y no cabe en el bloque, se produce un "row chaining" o "row migration" 
- Indices -> Nos permiten aplicar búsquedas binarias
  Inicialmente para encontrardatos es necesatio aplicar lo que llamamos "full table scan":
    O(n) = Si hay 1M de filas, serán necesarias 1M de operaciones
  Una búsqueda binaria reduce el número de operaciones a O(log n):
    O(log n) = Si hay 1M de filas, serán necesarias aprox. 20 operaciones
  Esas búsquedas se pueden beneficiar de estadísticas.
  Tanto las estadísticas, como las tablas y los índices, van a requerir de mantenimiento.
- Mantenimientos requeridos:
  - Al meter nuevos datos, puede ser que cambie la distribución de los datos, por lo que las estadísticas pueden quedar obsoletas.
  - Puede ser que los bloques donde se guarda información de los índices se queden sin espacio libre, por lo que habrá que hacer un reindexado. Además, cuando se borran datos, los índices pueden quedar con información sucia, ocupando espacio (al borrar un dato, no se borra de inmediato del índice, sino que se marca como borrado, pero sigue ocupando espacio).
  - Con las tablas hay el mismo efecto: al borrar datos, los bloques pueden quedar con espacio libre que no se puede reutilizar (fragmentación). En las modificaciones de datos, puede ser que las filas crezcan y no quepan en el bloque, por lo que se produce "row chaining" o "row migration". También es necesario de vez en cuando reescribir las tablas para eliminar fragmentación y recuperar espacio.
    En este sentido ayudarán las tablas particionadas. Por ejemplo, si los datos van cambiando por fechas, cuando se cierre una fecha, puedo reorganizar los datos de esa partición y evitar tener que volver a hacerlo en el futuro.... ya no cambiarán. Y esto favorece el mantenimiento. 

---

# Más sobre índices

Hay distintos tipos de índices en Oracle. Hay BBDD qe tienen más tipos de índices, que en Oracle no existen:
- Índices B-tree (el más común)
- Índices bitmap (útiles en columnas con pocos valores distintos)
- Índices compuestos (índices sobre varias columnas)
- Índices basados en funciones (índices que usan una función sobre la columna)
- Índices de texto completo (para búsquedas de texto) - Oracle Text

## Índices B-tree

En los índices, da igual el tipo de índice, lo que guardamos siempre es un valor y su ubicación o ubicaciones (una referencia a la fila (ROWID)).

Ese ROWID no es el ID Primario que yo pongo a la fila, es una propio de Oracle. Ese ROWID indica cuál es la ubicación real física de la fila dentro de los archivos de la BBDD:
    - Datafile
    - Número de bloque dentro del datafile
    - Offset dentro del bloque

El que haya que mover una fila de un bloque a otro es delicado, porque si se mueve, el ROWID cambia.Realmente Oracle, al mover una fila no cambia el ROWID, lo que hace es en el sitio antiguo poner un puntero a la nueva ubicación. 
Al recuperar el dato, Oracle va a ir a buscarlo a su ubicación antigua y al llegar verá que allí no está, sino que hay un puntero a la nueva ubicación. Esto hace que las consultas sean más lentas, por lo que es importante evitar el "row migration".

En los índices BTree lo que tenemos es una estructura jerárquica de nodos: Esos nodos van guardando valores y referencias a otros nodos o a filas (ROWID). Navegando por esos nodos, podemos encontrar rápidamente el valor que buscamos.

    | Tabla Cursos                                                                  |           |
    |-------------------------------------------------------------------------------|-----------|
    | ID_CURSO (PK) | NOMBRE_CURSO   | DURACION | PRECIO | DESCRIPCION  | TIPO      | ROWID     |
    |-------------------------------------------------------------------------------|-----------|
    | 1              | Oracle Básico | 30       | 500    | Curso ...   | Presencial | AAABBBCCC |
    | 2              | Java Avanzado | 45       | 700    | Curso ...   | Online     | AAABBBCCD |
    | 3              | Python Data   | 40       | 600    | Curso ...   | Presencial | AAABBBCCE |
    | 4              | SQL Intermedio| 35       | 550    | Curso ...   | Online     | AAABBBCCF |
    | 5              | C# Fundaments | 25       | 450    | Curso ...   | Presencial | AAABBBCCG |
    | 6              | JavaScript ES6| 30       | 480    | Curso ...   | Online     | AAABBBCCH |
    | 7              | HTML5 & CSS3  | 20       | 550    | Curso ...   | Presencial | AAABBBCCI |
    |-------------------------------------------------------------------------------| ----------|

Imaginad que queremos hacer búsquedas que devuelvan pocos datos sobre la tabla Cursos, filtrando por precio.

    SELECT * FROM Cursos WHERE PRECIO = 600;

A priori, Oracle debe ir fila a fila mirando si esa fila tiene PRECIO = 600 -> Full Table Scan = O(n) = tantas operaciones como filas haya en la tabla.

Un índice aquí podría ayudar. En este caso un índice de tipo B-tree sobre la columna PRECIO.

    CREATE INDEX idx_precio ON Cursos(PRECIO);

Como es ese índice B-tree?
      
              500 <- Nodo Raíz
            /     \
         480       600
        /         /   \
      450        550  700

Asociado a nodo (valor en ese índice) tenemos las filas (ROWID) que tienen ese valor.

    450 -> AAABBBCCG
    480 -> AAABBBCCH
    500 -> AAABBBCCC
    550 -> AAABBBCCF , AAABBBCCI
    600 -> AAABBBCCE
    700 -> AAABBBCCD

Al hacer una consulta con filtro por PRECIO, Oracle puede usar el índice para localizar rápidamente el valor 600 y obtener su ROWID asociado. Con ese ROWID ya puede ir directamente a la tabla y recuperar la fila completa.

> Pregunta: Tengo en la tabla cursos 10k filas (100 bloques). Hago la siguiente consulta con filtro por PRECIO, y el resultado son 1k filas (85 bloques):

    > SELECT ID FROM Cursos WHERE PRECIO = 600;

    ¿Se usa ahí el índice? Posiblemente no.
     - El índice le aporta solo información acerca de en que UBICACIÓN están las filas que cumplen el filtro.
     - Pero luego se tiene que ir a esas ubicaciones (bloques) a recuperar el ID de cada fila.
     - Posiblemente el optimizador de consultas decida que es mejor hacer un full table scan, leyendo los 100 bloques de la tabla, en lugar de usar el índice y luego tener que leer 85 bloques de la tabla.

    > SELECT FECHA_INICIO FROM CONVOCATORIAS JOIN CURSOS ON CONVOCATORIAS.CURSO_ID = CURSOS.ID_CURSO WHERE CURSOS.PRECIO = 600;

    ¿Se usa ahí el índice? Posiblemente si se use el índice.
     - El índice le aporta información acerca de la UBICACIÓN están las filas que cumplen el filtro.
     - Necesita información ADICIONAL de la tabla CURSOS Oracle para resolver esta Query? NO
     - Si tengo la columna CURSO_ID en CONVOCATORIAS indexada, puedo usar el índice para localizar rápidamente las filas en CONVOCATORIAS que cumplen el filtro, y recuperar directamente la columna FECHA_INICIO sin tener que ir a la tabla CURSOS.

     Nota.... hablaremos más adelante de las distintas formas que tiene Oracle de resolver JOINS:
     - Nested Loops
     - Hash Join
     - Sort Merge Join

Y si huvieramos creado el índice: 

    CREATE INDEX idx_precio_nombre ON Cursos(PRECIO, ID);  # Esto es un tipo de índice especial: índice compuesto

En este caso el índice ya contiene la información adicional que necesito (ID), además de la información de ubicación (ROWID), y del precio:

    450 -> (AAABBBCCG, 5)
    480 -> (AAABBBCCH, 6)
    500 -> (AAABBBCCC, 1)
    550 -> (AAABBBCCF, 4) , (AAABBBCCI, 7)
    600 -> (AAABBBCCE, 3)
    700 -> (AAABBBCCD, 2)

Eso permite quee una query del tipo:

    SELECT ID FROM Cursos WHERE PRECIO = 600;

Se pueda resolver solo con el índice, sin tener que ir a la tabla Cursos. En este caso ni se lo piensa! -> INDICE!

Los índices se crean para acelerar las consultas CONCRETAS que se hacen frecuentemente en la BBDD.
El día 1 que pongo una BBDD en producción No tendre npi de que consultas se van a hacer frecuentemente, podré tener mis espectativas, pero no lo sabré con seguridad. Por eso, al principio, no suelo crear índices.

Voy monitorizando la BBDD, y viendo que consultas se hacen frecuentemente, y cuáles de esas consultas son lentas. A partir de ahí, decido crear índices para acelerar esas consultas.

Lo contrario es una cagada! El crear el día 1 decenas o cientos de índices que no sé si realmente se van a usar, solo va a penalizar las operaciones de escritura (INSERT, UPDATE, DELETE), y el espacio en disco.
Si tengo mucha experiencia, habrá algunos índices que pueda intuir que serán útiles, pero no muchos.
Y además, eso me exige tener bastante conocimiento funcional de la aplicación que va a usar la BBDD, para adelantarme a las consultas que se van a hacer = COMPLEJO!

No quiero mejorar tampoco TODA consulta. Quiero mejorar las consultas que son críticas para el negocio, las que más se usan, las que más tiempo consumen. Para mejorarlas tengo que penalizar las escrituras, y tengo que gastar pasta en espacio en disco. Tomo decisiones de cuando compensa y cuando no.

Los índices BTREE pueden usarse para acelerar consultas con filtros de igualdad (=) y de rango (>, <, BETWEEN, LIKE 'abc%').

## Índices basados en funciones

    | Tabla ALUMNOS                                               |           |
    |-------------------------------------------------------------|-----------|
    | ID  (PK)       | NOMBRE        | APELLIDOS | DNI            | ROWID     |
    |-------------------------------------------------------------|-----------|
    | 1              | Juan          | Pérez     | 12345678A      | AAABBBCCC |
    | 2              | María         | Gómez     | 87654321B      | AAABBBCCD |
    | 3              | Luis          | Rodríguez | 11223344C      | AAABBBCCE |
    | 4              | Ana           | López     | 44332211d      | AAABBBCCF |
    | 5              | Carmen        | Sánchez   | 55667788E      | AAABBBCCG |
    | 6              | Pedro         | Fernández | 99887766f      | AAABBBCCH |
    | 7              | Laura         | Martínez  | 66778899G      | AAABBBCCI |
    |-------------------------------------------------------------| ----------|

    CREATE INDEX idx_dni ON ALUMNOS(DNI);

    Si hago la consulta:

    SELECT * FROM ALUMNOS WHERE DNI = '12345678A';

    Tengo 10k alumnos dados de alta. Pero hay muy pocos alumnos con el mismo DNI (1).
    En este caso, Oracle claramente preferiría usar el índice para recuperar la ubicación de la fila que cumple el filtro, y luego acceder al bloque pertinente de la tabla para recuperar la fila completa.

    Se usa el índice en este caso? SI

    SELECT * FROM ALUMNOS WHERE UPPER(DNI) = UPPER('12345678a');

    Se usa el índice ahí? NO
    - El índice ha sido creado sobre la columna DNI, pero no tiene el UPPER(DNI).
    - Ese dato UPPER(DNI) no está en el índice, ese dato habrá que calcularlo en cada query sobre cada fila.

    En un caso como este me intersa un índice basado en función:

    CREATE INDEX idx_upper_dni ON ALUMNOS(UPPER(DNI));

    Los índices guardan una copia del dato... pero también pueden guardar una copia transformada del dato (índices basados en funciones)... con independencia del dato que haya en la tabla.

    Puedo tener el dato como sea en la tabla (mayúsculas, minúsculas), y en el índice guardo una copia transformada del dato (todo en mayúsculas).

    En este caso, la consulta:

    SELECT * FROM ALUMNOS WHERE UPPER(DNI) = UPPER('12345678a');

    Si se usaría el índice, porque el índice ya tiene el dato UPPER(DNI) pre-calculado.
    Y lo que jode no es el el UPPER('12345678a'), eso se hace una vez... es un valor fijo.
    Lo que jode es el UPPER(DNI), que habría que calcular para cada fila. O lo tengo en el índice, o no se puede usar el índice.

    En un caso como este, realmente habría una mejor opción... YA LA TRABAJAMOS EN EL CURSO DE PLSQL. Crear un trigger BEFORE INSERT OR UPDATE que se encargue de guardar el DNI siempre en mayúsculas en la tabla. Beneficios:
    - Así no necesito un índice basado en función, y puedo usar un índice normal sobre la columna DNI.
    - Tengo los datos normalizados en la tabla (todos en mayúsculas).

    Puedo usar cualquier función en un índice basado en función. Por ejemplo:
    - puedo crear un índice basado en la función que extraiga el dominio de un email
    - puedo guardar si un número es par o impar
    - incluso funciones personalizadas que yo cree

    El concepto es, creo el índice con el dato exactamente como lo voy a usar en las consultas, para que el índice tenga oportunidad de ser usado. Eso no garatiza que se use el índice (eso lo decide el planificador de consultas), pero al menos le doy la oportunidad.

## Índices de tipo Bitmap

Están pensados para columnas con pocos valores distintos (poca cardinalidad). Por ejemplo, una columna que indique el género (M/F), o una columna que indique si un producto está en stock (SI/NO). No tienen por qué ser solo dos valores, pueden ser más, pero pocos.

En este caso, en lugar de guardar en el índice el valor y su ROWID asociado, lo que se guarda es un mapa de bits (bitmap) por cada valor posible en la columna.

Mapa de bits? Es una secuencia de bits (0s y 1s), donde cada bit representa un valor en la tabla. Si el bit está a 1, significa que la fila correspondiente tiene ese valor; si está a 0, no lo tiene.

Por ejemplo, en nuestro caso de la tabla Cursos, si creamos un índice bitmap sobre la columna TIPO:

    CREATE BITMAP INDEX idx_tipo ON Cursos(TIPO);

Tendremos dos mapas de bits, uno para "Presencial" y otro para "Online":
    Presencial: 1 0 1 0 1 0 1  (filas 1,3,5,7 son presenciales)
    Online:     0 1 0 1 0 1 0  (filas 2,4,6 son online)

En este índice se guarda el resultado del filtro aplicado sobre cada fila de la tabla. Ya está pre-calculado.

Van muy rápido para consultas que combinan varios filtros con AND y OR, porque pueden combinar los mapas de bits rápidamente usando operaciones bit a bit (AND, OR). Pero:
- Los operadores para los que funcionan bien son los de igualdad (=) y los lógicos (AND, OR).
- La actualización de índices bitmap es costosa, por lo que no son adecuados para tablas con muchas actualizaciones.
  - Por ejemplo, si estamos montando un data warehouse, donde las tablas se cargan de golpe y luego no se actualizan, los índices bitmap pueden ser una buena opción.

## Oracle Text - Índices de texto completo

    | Tabla Cursos                                           |
    |--------------------------------------------------------|
    | ID_CURSO (PK) | NOMBRE_CURSO                           |
    |--------------------------------------------------------|
    | 1              | Curso de Oracle Básico                |
    | 2              | Introducción a las BBDD Relacionales  |
    | 3              | Python Data Science                   |
    | 4              | Trabajando con SQL                    |
    | 5              | Fundamentos del lenguaje C#           |
    | 6              | Javascript ES6 para el desarrollo web |
    | 7              | Creación de páginas web con HTML5     |
    |--------------------------------------------------------|

    Quiero poder buscar cursos por NOMBRE.

    RARO Es que un usuario me vaya a escribir el nombre completo del curso para buscarlo. Y además con exactitud (mayúsculas, minúsculas, tildes, etc).

    INDICE: CREATE INDEX idx_nombre ON Cursos(NOMBRE_CURSO);

    Serviría el índice para: SI
        
        SELECT * FROM Cursos WHERE NOMBRE_CURSO = 'Python Data Science';

    Serviría el índice para: SI
        
        SELECT * FROM Cursos WHERE NOMBRE_CURSO LIKE 'Python%';

    Serviría el índice para: NO
        
        SELECT * FROM Cursos WHERE NOMBRE_CURSO LIKE '%Python%';

    Serviría el índice para: NO
        
        SELECT * FROM Cursos WHERE UPPER(NOMBRE_CURSO) LIKE UPPER('%python%');


    | 1              | Curso de Oracle Básico con SQL        |
    | 2              | Introducción a las BBDD Relacionales  |
    | 3              | Python Data Science                   |
    | 4              | SQL Avanzado para Oracle              |
    | 5              | SQL Avanzado para Postgres            |
    | 6              | Fundamentos del lenguaje C#           |
    | 7              | Javascript ES6 para el desarrollo web |
    | 8              | Creación de páginas web HTML5         |

    BUSQUEDA: "sql oracle" 
      Ese texto LITERALMENTE no está en ningún curso.
      Ni siquiera variaciones en mayúsculas/minúsculas.

    PERO la realidad es que ante una query como esa, que querríamos nosotros devolver?
       SQL Avanzado para Oracle
       Curso de Oracle Básico con SQL

En un caso como este, ninguno de los índices vistos hasta ahora me sirve.
Lo que necesito es un índice de TEXTO COMPLETO (Full Text Index).

Es otro tipo muy diferente de índice, que crea un índice invertido (inverted index).
ElasticSearch, Lucene, Solr, Oracle Text, etc usan índices invertidos.

Cómo funcionan? Lo que hacen es un preprocesamiento enorme de los textos, para generar el índice. Ese procesamiento va por fases:
- Tokenización: Dividen el texto en palabras (tokens), eliminando puntuación y caracteres especiales: ()-.,;.
- Normalización: Convertir todas las palabras a minúsculas, eliminar tildes
- Filtrado: Stop words: eliminar palabras comunes que no aportan significado (el, la, de, y, para, con)
- Stemming/Lematización: Reducir las palabras a su raíz o forma base (correr, corriendo, corrí -> corr)
  - Quitar conjugaciones de verbos, plurales, modificadores de género.

Una vez hecho eso, creamos el índice:

    ORIGEN 

    | 1 | Curso de Oracle Básico con SQL        |
    | 2 | Introducción a las BBDD Relacionales  |
    | 3 | Python Data Science                   |
    | 4 | SQL Avanzado para Oracle              |
    | 5 | SQL Avanzado para Postgres            |
    | 6 | Fundamentos del lenguaje C#           |
    | 7 | Javascript ES6 para el desarrollo web |
    | 8 | Creación de páginas web HTML5         |

    PASO 1: Tokenización y Normalización

    | ID | TOKENS                                   |
    |----|------------------------------------------|
    | 1  | curso, de, oracle, basico, con, sql      |
    | 2  | introduccion, a, las, bbdd, relacionales |
    | 3  | python, data, science                    |
    | 4  | sql, avanzado, para, oracle              |
    | 5  | sql, avanzado, para, postgres            |
    | 6  | fundamentos, del, lenguaje, c#           |
    | 7  | javascript, es6, para, el, desarrollo, web |
    | 8  | creación, de, páginas, web, html5        |

    PASO 2: Filtrado (stop words)
    | ID | TOKENS                                   |
    |----|------------------------------------------|
    | 1  | curso, *, oracle, basico, *, sql         |
    | 2  | introduccion, *, *, bbdd, relacionales   |
    | 3  | python, data, science                    |
    | 4  | sql, avanzado, *, oracle                 |
    | 5  | sql, avanzado, *, postgres               |
    | 6  | fundamentos, *, lenguaje, c#             |
    | 7  | javascript, es6, *, *, desarrollo, web   |
    | 8  | creación, *, páginas, web, html5         |

    PASO 3: Stemming/Lematización
    | ID | TOKENS                                   |
    |----|------------------------------------------|
    | 1  | curs, *, oracl, basic, *, sql           |
    | 2  | introduccion, *, *, bbdd, relacional    |
    | 3  | python, data, scienc                    |
    | 4  | sql, avanz, *, oracl                    |
    | 5  | sql, avanz, *, postgr                   |
    | 6  | fundament, *, lenguaj, c#               |
    | 7  | javascript, es6, *, *, desarroll, web    |
    | 8  | creacion, *, pagin, web, html5          |

    PASO 4: Generamos el índice invertido

    | TOKEN       | IDS CURSOS               |
    |-------------|--------------------------|
    | avanz       | 4(2), 5(2)               |
    | basic       | 1(4)                     |
    | bbdd        | 2(4)                     |
    | c#          | 6(4)                     |
    | curs        | 1(1)                     |
    | creacion    | 8(1)                     |
    | data        | 3(2)                     |
    | desarroll   | 7(5)                     |
    | es6         | 7(2)                     |
    | fundament   | 6(1)                     |
    | html5       | 8(4)                     |
    | introduccion| 2(1)                     |
    | lenguaj     | 6(3)                     |
    | oracl       | 1(3), 4(3)               |
    | pagin       | 8(2)                     |
    | postgr      | 5(4)                     |
    | python      | 3(1)                     |
    | relacional  | 2(5)                     |
    | scienc      | 3(3)                     |
    | sql         | 1(6), 4(1), 5(1)         |
    | web         | 7(6), 8(3)               |  

Realmente, lo que se guarda como ubicación no es el ID del curso, sino el ROWID de la fila en la tabla Cursos.
Si que se guarda información de la posición del token dentro del texto (entre paréntesis), para poder hacer búsquedas más avanzadas (frases, proximidad, etc).

Como podeéis imaginar, esto depende TOTALMENTE del idioma (stop words, stemming, etc). Oracle Text soporta muchos idiomas.

Hay herramientas que soportan características MUY avanzadas (por ejemplo, palabras que fonéticamente son similares, suenan igual... aunque se escriban diferente). También hay herramientas que soportan un grado enorme de personalización en el flujo de procesamiento del texto.

Eso es lo que hacen los indexadores de texto completo (Full Text Indexers): ElasticSearch, Solr, Lucene.

En general, las BBDD no ofrecen mucha funcionalidad avanzada de texto completo.
Otras BBDD relacionales tienen algunas cositas o mecanismos alternativos.
Por ejemplo en postgres usamos mucho el concepto de trigramas (secuencias de 3 letras) para hacer búsquedas aproximadas.

    Postgres: TRIGRAMAS de "Curso de Oracle Básico con SQL":
    - "cur", "urs", "rso", "so ", "o d", " de", "de ", "e o", " or", "ora", "rac", "acl", "cle", "le ", "e b", " ba", "Bas", "asi", "sic", "ico", "co ", "o c", " co", "con", "on ", "n S", " SQ", "SQL"
  

Oracle está a medio camino con la herramienta Oracle Text, es potente... pero no llega a la potencia de ElasticSearch o Solr. Dentro de eso, es de las herramientas más potentes que existen en el mundo de las BBDD relacionales.

Si quiero realmente funcionaldiad muy avanzadas de búsqueda de texto, lo mejor es usar ElasticSearch o Solr como motor de búsqueda externo, y no usar la funcionalidad de texto completo que pueda tener la BBDD relacional.

Pero para muchos casos sencillos, Oracle Text es más que suficiente.

El caso de nuestros títulos de cursos es un caso sencillo, donde Oracle Text puede funcionar perfectamente.

Lo que haríamos es definir un índice de texto completo sobre la columna NOMBRE_CURSO:

    CREATE INDEX idx_texto_nombre ON Cursos(NOMBRE_CURSO) INDEXTYPE IS CTXSYS.CONTEXT;

Para poder hacer eso, necesitamos tener instalado el componente Oracle Text en la BBDD... y activado.

Y luego, en las queries usamos la función CONTAINS para hacer búsquedas de texto completo:

    SELECT * FROM Cursos WHERE CONTAINS(NOMBRE_CURSO, 'sql oracle', 1) > 0;

    CONTAINS(NOMBRE_CURSO, 'sql oracle', 1)
      - El 1 es un label que le doy a esa búsqueda, para luego poder recuperar la puntuación (score) de cada fila.
      - Esa puntuación indica lo relevante que es esa fila para la búsqueda realizada.
      - Esa puntuación se puede recuperar con la función SCORE(1) (el 1 es el label que le di a la búsqueda).

Oracle text ofrece bastante funcionalidad avanzada.

Cuando se hace una búsqueda, lo que ocurre es que sobre el término de búsqueda se aplica el mismo procesamiento que se hizo al crear el índice (tokenización, normalización, filtrado, stemming), y luego se busca en el índice invertido.

    SQL para orácle  ->  sql, *, oracl

Esos términos resultantes se buscan en el índice invertido, y se combinan los resultados para obtener las filas que cumplen la búsqueda.

El rendimiento de esto en las búsquedas es excepcional. Aunque penaliza algo en las escrituras (INSERT, UPDATE, DELETE), porque el índice de texto completo es complejo y grande, y hay que mantenerlo actualizado.

Este tipo de índices de hecho se generan de forma asíncrona, fuera de la transacción que modifica los datos.

Yo hago insert.
La fila se mete en la tabla.
Se ejecutan triggers antes o después, si los hubiera.
Se actualizan índices "normales" (B-tree, bitmap, etc).
Y Se marca la transacción como completa.
...
Tiempo después... en algún momento, se actualizará el índice de texto completo, de forma asíncrona.

Puede haber un desfase de décimas de segundo a casi minutos, dependiendo de la carga de la BBDD y del tamaño del texto que se esté indexando.

Puede ocurrir que un usuario meta un dato, justo después quiera buscarlo y aún lo no aparezca en los resultados de búsqueda, porque el índice de texto completo aún no se ha actualizado.

Oracle decide cuando tiene una menor carga de trabajo y en esos momentos es cuando actualiza los índices de texto completo... cuando tiene un hueco... pero son tareas de prioridad baja.

NUNCA DEBERIAMOS TENER BUSQUEDAS DE TIPO LIKE '%TEXTO%' EN CAMPOS DE TEXTO. 
Y como siempre, la palabra NUNCA no puede usarse en informática... puede haber casos.
Si tengo una tabla con 200 entradas, y hago una búsqueda puntual con LIKE '%TEXTO%', no pasará nada.

Pero casos muy concretos.

Busca en el título de los expedientes... OLVIDATE ---> usa Oracle Text.

---

Para completar el tema de almacenamiento...

Oracle no guarda solamente en la BBDD los datafiles. Hay más ficheros asociados a la BBDD.
Pero antes de explicaros esto, os explico otra cosa:
- Diferencia entre BBDD e instancia de Oracle

Por BBDD entendemos los ficheros físicos que componen la BBDD (datafiles, y otros ficheros adicionales).
Por instancia de Oracle entendemos el conjunto de procesos y memoria que gestionan el acceso a la BBDD.

LA BBDD EXISTE SIEMPRE.
La instancia solo existe cuando Oracle está arrancado.

Ficheros = BBDD
Programas en ejecución = Instancia

La instancia me permite acceder a la BBDD.

---

En la BBDD No tenemos solo datafiles. Hay más ficheros asociados a la BBDD:
- Datafiles: donde se guardan los datos de las tablas, índices, etc.
- Redo log files
- Archive log files (si la BBDD está en modo ARCHIVELOG)
- Control files
- ...

## Control Files

Son archivos pequeños (normalmente unos pocos MB) que guardan información crítica sobre la BBDD.
Si estos archivos es complejo iniciar la instancia de Oracle.
En ellos se guarda:
- Estructura lógica de la BBDD (tablespaces, datafiles, etc)
- Configuración de la BBDD
- Información para recuperación de la BBDD (puntos de recuperación, etc)
- Información sobre los redo log files

No mareamos mucho con los control files, pero es importante saber que existen y para qué sirven.
Si tuviera que hacer un backup completo de la BBDD, tendría que incluir los control files.

## Redo Log Files

Y para explicar los redo log files, primero os explico qué es el "redo".
Y antes de hablar del redo, vamos a hablar MUY BREVEMENTE (más adelante lo haremos con más detalle) de las operaciones de backup y recuperación en Oracle.

### Introducción a backup y recuperación en Oracle

En Oracle, este tema de backup y recuperación es una locura.
Cuando digo locura, me refiero a que tiene una potencia enorme, aunque es complejo.
Tenemos muchísimas utilidades para tratar de minimizar la pérdida de datos y el tiempo de recuperación ante fallos.
Dicho esto... es muy complejo recuperar datos de una BBDD si no hemos establecido unos procedimientos claros de backup y recuperación.

Cuando hacemos backups de una BBDD (Oracle o no) hay ciertos mecanismos estandar, que normalmente tenemos disponibles en casi toda BBDD. Hay 3 factores que analizamos por separado:
- Tipo de backup:
  - Completo:               copia toda la BBDD
  - Incremental:            copia solo los datos que han cambiado desde el último backup (completo o incremental)
  - Transaccional (o de logs): vamos guardando información (operaciones) que nos permita recuperar la BBDD hasta un punto en el tiempo concreto (por ejemplo, hasta justo antes de que un usuario borrara datos por error), posterior a al último backup completo o incremental.
- Modo de backup:
  - Online (o caliente):     la instancia está en funcionamiento y los usuarios pueden seguir trabajando mientras se hace el backup
  - Offline (o frío):        la instancia está parada o al menos no está presente para los usuarios mientras se hace el backup
- Físico o lógico:
  - Físico:                  copia los ficheros físicos que componen la BBDD (datafiles, control files, redo log files, etc)
  - Lógico:                  copia los datos de las tablas e índices, pero no los ficheros físicos.

Cada una de ellas tiene sus ventajas e inconvenientes... por ejemplo:
- Un backup online me permite no interrumpir el servicio a los usuarios, pero es más complejo de hacer y puede ser que el backup no sea consistente si no se hace bien. Y además tarda más tiempo.
- Un backup físico es más rápido de hacer y restaurar, pero no puedo llevarlo a otra versión de Oracle diferente a la que se hizo el backup.
- Un backup lógico me permite llevar los datos a otra versión de Oracle diferente a la que se hizo el backup, pero es más lento de hacer y restaurar.

- Habitualmente hacemos backups completos cada X tiempo (por ejemplo, los domingos por la noche)
- Luego, vamos haciendo backups incrementales cada Y tiempo (por ejemplo, diarios)
- Y Además, puedo ir guardando información transaccional (de logs) para poder recuperar la BBDD hasta un punto en el tiempo concreto.

Oracle permite sin problemas un plan de backup como ese. Postgres NO. En postgres no existe el concepto de backup incremental.

La restauración de un sistema cuyo procedimiento de backup hubiera sido el descrito, sería:
- Restaurar el último backup completo
- Aplicar los backups incrementales posteriores al backup completo restaurado
- Aplicar la información transaccional (de logs) para recuperar la BBDD hasta el punto en el tiempo deseado.

Los backups completos y incrementales lo que hacen es copiar ficheros (físicos) o datos (lógicos).
Pero la información transaccional (de logs) es diferente. Lo que se hace es guardar información acerca de las operaciones que van haciendo sobre la BBDD (INSERT, UPDATE, DELETE, etc).

Esa información de los cambios que se van haciendo en la BBDD es el "redo".

Oracle usa ese redo para garantizar la durabilidad de las transacciones, y también para permitir la recuperación de la BBDD hasta un punto en el tiempo concreto, siempre y cuando haya yo decidido guardar esa información de redo (modo ARCHIVELOG).

Resumiendo. Para el funcionamiento normal de la BBDD, Oracle usa el "redo" para garantizar la durabilidad de las transacciones. Ese redo se guarda en los redo log files. Esos son archivos que oracle usa para guardar el redo de las transacciones que se van haciendo en la BBDD. Pero esos archivos son circulares... cuando se llenan, se sobreescriben.... de lo contario podrían crecer indefinidamente.

Si me interesa poder restaurar la BBDD hasta un punto en el tiempo concreto, posterior al último backup completo o incremental, necesito que Oracle guarde ese redo de forma permanente. En este caso activo el modo ARCHIVELOG de la BBDD.
En este modo, cuando un redo log file se llena, antes de sobreescribirlo, Oracle hace una copia de ese archivo a otro sitio (archivo de archive log), para que esa información no se pierda y pueda usarse para restaurar la BBDD hasta un punto en el tiempo concreto.

    DATAFILES: donde se guardan los datos de las tablas, índices, etc.
    REDO LOG FILES: donde se guarda el redo de las transacciones en curso.
                    estos archivos son circulares... cuando se llenan se sobreescriben.
    ARCHIVE LOG FILES: si la BBDD está en modo ARCHIVELOG, aquí se guardan copias de los redo log files llenos, para poder usarlos en la recuperación.
    CONTROL FILES: donde se guarda información crítica sobre la BBDD.

    Los REDO LOG y los ARCHIVE LOG se gestionan mediante acceso secuencial, no aleatorio como los DATAFILES.

    Esos logs no son parte o producto de la instancia de Oracle, son parte de la BBDD.

    La instancia de Oracle puede generar sus propios logs de actividad (alert log, trace files, etc), pero esos logs son independientes de la BBDD.

---

# Instancia de Oracle

Todo lo que hemos ido hablando ha sido más orientado a la BBDD (ficheros físicos, almacenamiento de datos, índices, etc).
Ahora vamos a hablar un poco de la instancia de Oracle... que son los programas en ejecución que permiten acceder a la BBDD.

Oracle no es un programa que se ejecuta de forma monolítica (un solo proceso).
Oracle es un conjunto de procesos que trabajan conjuntamente para gestionar el acceso a la BBDD.
Muchos procesos!

Esos procesos, que ahora después nombramos, van a usar la memoria RAM de la máquina para:
- Poner el propio código de los procesos
- Gardar datos temporales de trabajo
- Caché <-- Muy importante en Oracle

Las BBDD son expertas en tragarse TODA LA MEMORIA RAM disponible en la máquina... y más si le doy más.
Van a hacer uso intensivo de la memoria RAM para acelerar el acceso a los datos.
Es fundamental tener suficiente memoria RAM en la máquina donde esté la BBDD.

Hay 2 zonas diferentes de memoria RAM que usa Oracle:
- SGA (System Global Area): memoria compartida entre todos los procesos de la instancia de Oracle.
  Esta región.. esta parte de la memoria que usa Oracle es la grande! La que requiere de gigabytes de RAM.
- PGA (Program Global Area): memoria privada de cada proceso de Oracle.

Es decir, cada proceso tiene su propia zona de memoria privada (PGA), y luego todos los procesos comparten una zona común (SGA).

Aunque el PGA se configura con valores más bajos, como abrimos muchos procesos, el total de memoria usada por los PGA puede ser también considerable.

SGA hay una. PGA hay muchas (una por proceso). Y podemos acabar con ciens de procesos abiertos en una instancia de Oracle (que podemos ver con el comando "ps" en Linux).

Hay que dimensionar muy bien aquello.

### SGA (System Global Area)

Esta parte es la que hemos dicho que comparten todos los procesos de la instancia de Oracle.
Dentro de la SGA gestionamos (guardamos) varios tipos de información:
- Data Buffer Cache: caché de datos leídos desde los datafiles.
  Lo que guardamos ahí son bloques completos de datos (normalmente 8KB cada bloque). Bloques de los que hay dentro de los datafiles.
  Cuando un proceso necesita leer datos de la BBDD (ficheros), primero mira en esta caché si ese bloque ya está ahí.
  Si está, lo lee de la caché (rápido).
  Si no está, tiene que ir a disco a leer el bloque (lento), y luego lo guarda en la caché para que él u otros procesos puedan usarlo más adelante.
  No me interesa mucho que esto ocurra. Lo ideal sería que TODA la BBDD estuviera en esta caché.
  Me suele ser complicado, sobre todo si la BBDD es grande.
  Y ahí entra ese parámetro que puedo medir en Oracle llamado "cache hit ratio".
  - Cache Hit Ratio: porcentaje de veces que un bloque de datos que se necesita lo encuentro precargado en la cache.
    - Si el cache hit ratio es alto (por ejemplo, > 90%), significa que la caché está funcionando bien, y la mayoría de las lecturas se hacen desde la caché (rápido).
    - Si el cache hit ratio es bajo (por ejemplo, < 70%), significa que la caché no está funcionando bien, y muchas lecturas se hacen desde disco (lento).
    - Valores intermedios (70%-90%) los tengo que mirar con más detalle.
    Tendremos mucho control de esta cache. Podremos ver qué bloques están en la caché, incluso qué tablas o índices son los que más espacio ocupan en la caché... las que están dando un mal ratio de aciertos.
    Podré mirar porqué, como mejorarlo (índices, estadísticas, consultas, etc).
    > La compactación, el PCTFREE, etc afectan a la eficiencia de esta caché.
- Shared Pool: caché de objetos de la base de datos:
  - Sentencias SQL parseadas y listas para ejecutar. Cuando una query se recibe por la BBDD, realmente lo que se recibe es un TEXTO. Ese texto hay que procesarlo:
    1. Ver si la sintaxis es correcta 
    2. Entender qué es lo que se pide (análisis semántico)
    3. Verificar que los objetos (tablas, índices, columnas) a los que se hace referencia existen
    4. Generar un plan de ejecución óptimo para esa query
    Todo eso lleva rato hacerlo. 
    Cuando se recibe una query, Oracle mira en esta caché si ya tiene esa query procesada y lista para ejecutar. 
    Ésta región la podré configurar para que sea más o menos grande.
    Cuantas más queries mejor... eso si... la memoria que tengo es finita... si le doy más memoria a esta región, le estoy quitando memoria a otras regiones de la SGA -> menos memoria para caché de datos, por ejemplo.
  - Data Dictionary Cache: caché de metadatos de la BBDD (estructura de tablas, índices, usuarios, permisos, etc).
    Cuando un proceso necesita información acerca de la estructura de la BBDD, primero mira en esta caché.
    Si la información está ahí, la lee de la caché (rápido).
    Si no está, tiene que ir a disco a leer los controlfiles o datafiles del diccionario de datos (lento), y luego lo guarda en la caché para que él u otros procesos puedan usarlo más adelante. Esto normalmente se hace durante el arranque de la instancia de Oracle. Y ocupa poca memoria. En cualquier caso... ocupe mucho o poco no hay mucho margen de configuración.
- Redo Log Buffer
    Hemos dicho que Oracle usa el "redo" para garantizar la durabilidad de las transacciones.
    El "redo" es la información acerca de los cambios que se van haciendo en la BBDD (INSERT, UPDATE, DELETE, etc).
    Esos cambios no se guardan directamente en los redo log files (disco), porque eso sería lento... y haría que las transacciones fueran lentas.
    En lugar de eso, los cambios (redo) se van guardando primero en esta región de memoria (Redo Log Buffer).
    Luego, cada cierto tiempo (o cuando se llena el buffer), un proceso llamado LGWR (Log Writer) se encarga de volcar ese redo desde la memoria a los redo log files en disco. Necesitamos un espacio de memoria para ir guardando ese redo temporalmente antes de volcarlo a disco. Esta zona es pequeña, normalmente unos pocos MB.
    Tampoco queremos que sea muy grande, si no bajo cosas con bastante frecuencia el redo a disco, corro riesgo de perder redo en caso de fallo. Los "flush" de este buffer a disco los hace el proceso LGWR cada pocos segundos o incluso decimas de segundo.
- Otros componentes menores de la SGA:
  - Large Pool
  - Java Pool
  - Streams Pool
  Son zonas pequeñas y que salvo casos muy concretos no se suelen usar ni configurar.

### PGA (Program Global Area)

Cada proceso de Oracle tiene su propia zona de memoria privada (PGA).
Hay que tener en cuenta, que además de los procesos "permanentes" de Oracle (los que siempre están ahí cuando la instancia está arrancada), cada vez que un usuario se conecta a la BBDD, se abre un proceso adicional (proceso de servidor) para atender esa conexión. Esto hace que podamos llegar a tener cientos de procesos abiertos en una instancia de Oracle.

Cada uno de esos procesos necesita su propio espacio de memoria privado (PGA).
Que se guarda aquí:
- Información de sesión del usuario conectado
- Área de trabajo:
  - Ordenación de datos (sort area)
  - Hash joins
  - Agregaciones
  - ...

En general la PGA es mucho más pequeña que la SGA. Eso si, necesito el minimo de espacio como para que las operaciones que haga cada proceso puedan realizarse en memoria. Si no, Oracle tendrá que usar espacio en disco (temp files) para hacer esas operaciones, y eso es lento a rabiar. CUIDADO !

Tener en cuenta que para ordenar datos, necesito tener en memoria sufiente espacio como para dejar el conjunto entero de datos a ordenar. Y lo ideal es que tenga espacio para tener 2 veces ese conjunto de datos (uno para los datos originales, y otro para los datos ordenados).

Si tengo una consulta que devuelve 1 millón de filas, y necesito ordenarlas, necesito tener espacio en la PGA para guardar esas 1 millón de filas 2 veces... la original y la ordenada.

Vamos a necesitrar limitar el número de conexiones simultáneas a la BBDD, para no quedarnos sin memoria RAM en la máquina. Cada conexión consume memoria RAM (PGA).

A nivel de una app cliente, una conexión es un hilo de ejecución. Eso no consume memoria... desde el punto de vista de la app cliente.
Pero cuando ese hilo se conecta a la BBDD, se abre un proceso en la instancia de Oracle, y ese proceso consume memoria RAM (PGA).

En general lo que hacemos es:
- En el servidor de BBDD limitar el número máximo de conexiones simultáneas que puede haber a la BBDD.
- En la app cliente, usar un pool de conexiones, para no abrir y cerrar conexiones constantemente; y para poder atender a más usuarios sin abrir más conexiones simultáneas a la BBDD de las que ésta puede soportar.

Necesitamos sincronizar muy bien el número máximo de conexiones simultáneas que puede haber en la BBDD, con el número máximo de conexiones que puede abrir la app cliente desde su pool de conexiones.

Esos datos, en cualquier caso, de nuevo y por desgracia salen de monitorizar la BBDD en producción y de la app cliente en producción.

---

## Procesos de Oracle

Además de los procesos que se abren para atender las conexiones de los usuarios, hay una serie de procesos permanentes que siempre están ahí cuando la instancia de Oracle está arrancada.
Cada proceso tiene una función concreta.

- PMON: Process Monitor
  - Proceso padre de todos los procesos de Oracle.
  - Se encarga de arrancar y parar los demás procesos.
  - Se encarga de limpiar recursos de procesos que han fallado (conexiones, sesiones, etc).
- SMON: System Monitor
  - Se encarga de tareas de mantenimiento de la BBDD.
  - Recuperación automática de la BBDD tras un fallo.
  - Limpieza de segmentos temporales.
- DBWR: Database Writer
  - Los datos, cuando son modificados, se hacen en memoria (Data Buffer Cache).
  - Esos bloques de datos modificados en memoria se llaman "dirty blocks".
  - Y es necesario bajarlos a disco (datafiles) en algún momento.
  - El proceso DBWR se encarga de bajar esos "dirty blocks" a disco.
  - Puede haber varios procesos DBWR (DBW0, DBW1, etc) para paralelizar la escritura a disco (Más vale que tenga también varios discos físicos para que no generen cuello de botella entre ellos).
- LGWR: Log Writer
  - Se encarga de volcar el redo desde la memoria (Redo Log Buffer) a los redo log files en disco.
  - Esto se hace cada pocos segundos o incluso décimas de segundo.
- Archiver (ARCn)
  - Si la BBDD está en modo ARCHIVELOG, este proceso se encarga de copiar los redo log files llenos a los archive log files.
  - Puede haber varios procesos ARCn para paralelizar la copia a disco (Más vale que tenga también varios discos físicos para que no generen cuello de botella entre ellos).
- Algunos más:
  - CKPT: Checkpoint
  - RECO: Recoverer
  - AQn: Advanced Queuing
  - MMON: Manageability Monitor
  - MMAN: Manageability Monitor

Hay algunas configuraciones especiales de Oracle para cambiar ciertos comportamientos de estos procesos.
Es importante reconocer algunos de ellos por su nombre, para luego poder entender mejor los logs de Oracle (alert log, trace files, etc). O ficheros de configuración de Oracle.

En general no nos metemos con muchas configuraciones de estos procesos.
Aunque hay algunas cosas que podemos tocar:
- Número de procesos DBWR: para paralelizar la escritura a disco de los "dirty blocks".
- Número de procesos ARCn: para paralelizar la copia a disco de los redo log files llenos a los archive log files.

O configuraciones de memoria que afectan a estos procesos:
- Tamaño del Redo Log Buffer: afecta al proceso LGWR.
- Tamaño de la Data Buffer Cache: afecta al proceso DBWR.
---

# SORT / ORDENACIONES

Las ordenaciones son la peor cosa que hay en una BBDD.
Los mejores algoritmos de ordenación son O(n log n). Es decir...
Una búsqueda binaria (O(log n)) es una operación que    A MAS DATOS tarda MUY POCO MÁS en completarse.
Un full scan (O(n)) es una operación que                A MAS DATOS tarda MÁS en completarse.
Una ordenación (O(n log n)) es una operación que        A MAS DATOS tarda MUCHO MÁS en completarse.

Para evitar las ordenaciones, usamos índices, que son copias ordenadas de los datos.
Y mira que eso es un follón... y es caro (espacio en disco, tiempo en escrituras, complejidad en mantenimiento, etc).
Y aún así los creamos, apra evitar la ordenación en las consultas.

Lo cuál no significa que en muchas ocasiones Oracle neceite hacer ordenaciones (bien porque yo se las pido explícitamente , o bien porque el planificador de consultas decide que necesita hacerlo para añgunas operaciones adicionales).

Hay muchas operaciones en una BBDD que requieren ordenaciones... y que debo vigilarlas mucho:
- ORDER BY colA ASC/DESC
- DISTINCT (Es pernicioso... es malvado... no quiero ni verlo...)
            El comando está. Y tiene sus casos de uso... Y cuando hay que usarlo se usa.
            El problema es que suele hace un abuso innecesario de él.
            En muchas ocasiones el problema es de diseño de la BBDD o de las consultas. 
            El DISTINCT es muy cabrón! MUCHO, obliga a hacer un ORDER BY (por todas las columnas del SELECT) para luego eliminar duplicados.
- GROUP BY colA, colB: Hace ordenación de los datos por las columnas del GROUP BY para luego agrupar los datos.
- UNION: Es un UNION ALL sobre el que se aplica un DISTINCT para eliminar duplicados.
         El UNION ALL Es guay. concatena una tabla de resultados con otra tabla de resultados. Eso es muy rápido
- Algunos Joins... aunque nos suelen preocupar poco, ya que para ellos solemos usamos índices que evitan la ordenación.
  - JOINS que usan HASH JOIN: Necesitan ordenar los datos para luego hacer la unión.
  - JOINS que usan MERGE JOIN: Necesitan que los datos estén ordenados previamente para luego hacer la unión.

