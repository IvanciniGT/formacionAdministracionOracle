# Collate - Colaciones

Este concepto existe en todas las bases de datos relacionales.

Tiene que ver con cómo la BBDD (en nuestro caso Oracle) compara cadenas de texto.

De hecho el collate es el algoritmo que se usa para comparar cadenas de texto.

```sql

CREATE TABLE palabras (
    palabra VARCHAR2(100)
);

INSERT INTO palabras (palabra) VALUES ('Camión');
INSERT INTO palabras (palabra) VALUES ('Camion');
INSERT INTO palabras (palabra) VALUES ('camión');
INSERT INTO palabras (palabra) VALUES ('camion');
INSERT INTO palabras (palabra) VALUES ('CAMION');
INSERT INTO palabras (palabra) VALUES ('CAMIÓN');
INSERT INTO palabras (palabra) VALUES ('Navarra');
INSERT INTO palabras (palabra) VALUES ('navarra');
INSERT INTO palabras (palabra) VALUES ('Ñoño');
INSERT INTO palabras (palabra) VALUES ('noño');
INSERT INTO palabras (palabra) VALUES ('Opera');
INSERT INTO palabras (palabra) VALUES ('Ópera');
INSERT INTO palabras (palabra) VALUES ('ópera');
INSERT INTO palabras (palabra) VALUES ('opera');
INSERT INTO palabras (palabra) VALUES ('ÓPERA');
INSERT INTO palabras (palabra) VALUES ('OPERA');

COMMIT;

SELECT palabra FROM palabras ORDER BY palabra;
```

Problemas:
- Camión y camión ... aparecen juntas? O primero aparecerán todas las palabras que comiencen por letras mayúsculas y luego las que comiencen por minúsculas?
- Camión y camion ... aparecen juntas? O primero aparecerán todas las palabras sin tildes y luego las que tienen tilde?
- Donde se pone la Ñ? Después de la N mayúscula? Después de la n minúscula? Al final del todo, después de la Z?

Las comparaciones y ordenaciones van de la mano. Para ordenar las palabras, primero hay que compararlas.
Si Ópera, opera y ÓPERA see consideran iguales, aparecerán juntas en el orden. De lo contrario, aparecerán en posiciones diferentes.

De alguna forma, esto es lo que intentábamos resolver con la chapuzilla del UPPER() o LOWER().

```sql
    SELECT palabra FROM palabras ORDER BY UPPER(palabra);
    SELECT PALABRA FROM PALABRAS WHERE UPPER(PALABRA) = UPPER('ópera');
```

La BBDD tiene un collate por defecto, que es el que se usa si no se especifica otro.

Esa configuración se puede hacer en un fichero: $ORACLE_HOME/ocommon/admin/<NOMBRE_DE_TU_BBDD>/nls_instance_parameters.ora. 

También podemos establecerla a nivel de sesión:

```sql
    ALTER SESSION SET NLS_COMP=BINARY; -- Case Sensitive, Accent Sensitive
    ALTER SESSION SET NLS_SORT=BINARY_CI; -- Case Insensitive
    ALTER SESSION SET NLS_SORT=BINARY_AI; -- Accent Insensitive
    ALTER SESSION SET NLS_SORT=BINARY_CI_AI; -- Case Insensitive, Accent Insensitive    
    -- En este caso, Camión, camión, CAMION y camion se consideran iguales.
    -- Eso si, la ñ se colocará después de la z.
    -- Hay collates específicos para cada idioma también.
    -- Por ejemplo, para español:
    ALTER SESSION SET NLS_SORT=SPANISH_AI; -- Depende de la versión de Oracle se llamará SPANISH_AI o XSPANISH_AI
```

En general no queremos ni lo uno ni lo otro. Ni establecerlos a nivel de base de datos ni a nivel de sesión.
A nivel de BBDD siempre habrá uno... pero no deberíamos recaer en él, especialmente cuando realmente quiera tener control de las comparaciones y ordenaciones.

Hay 2 opciones adicionales al especificar collates:
1. Hacerlo a nivel de columna en la tabla.

```sql
    SELECT palabra FROM palabras ORDER BY palabra COLLATE BINARY_CI_AI;
```

Qué tal esta? Esa consulta si no hay un índice asociado a la columna palabra, tardará un montón en ejecutarse... con independencia del collate que usemos. Siempre hay un collate.

Aquí hay un problema. Si hay un índice, pero ese índice ha sido creado con un collate diferente al que usamos en la consulta, el índice no se podrá usar -> hay que ordenar bajo demanda -> Problema de rendimiento.

En general, a no ser que sea para muy pocos datos, no deberíamos jugar con collates a nivel de consulta.

2. Asociar un collate a nivel de columna en la tabla = GUAY!

```sql
    CREATE TABLE palabras2 (
        palabra VARCHAR2(100) COLLATE BINARY_CI_AI
    );

    -- Si posteriormente creamos un índice sobre esa columna, el índice se creará usando el collate asociado a la columna.
    CREATE INDEX idx_palabra ON palabras2(palabra);

    -- Cuando hagamos consultas sobre esa columna, el índice se podrá usar siempre, porque el collate de la columna y el del índice coinciden.
    SELECT palabra FROM palabras2 WHERE palabra = 'ópera';
```

Si tengo una tabla que ya existe, le puedo cambiar a la columna que quiera el collate:

```sql
    ALTER TABLE palabras MODIFY palabra VARCHAR2(100) COLLATE BINARY_CI_AI;
```

Eso si, si la columna ya tiene datos y ya tengo un índice sobre esa columna, tendré que regenerar el índice:

```sql
    DROP INDEX idx_palabra;
    CREATE INDEX idx_palabra ON palabras(palabra);
```

Depende dee la cantidad de datos, esto puede tardar más o menos... No es un disparate si la tabla no es gigante.

3. Puede establecerse un collate a nivel de tabla también, pero no es muy habitual.

```sql
    CREATE TABLE palabras3 (
        palabra VARCHAR2(100)
    ) DEFAULT COLLATION BINARY_CI_AI;
```

NOTA: 

No confundir el collate con el conjunto de caracteres (character set). 
> El conjunto de caracteres define qué caracteres pueden almacenarse en la base de datos y cómo se almacenan (codificación). 
> El collate define cómo se comparan y ordenan esos caracteres.

Juegos de caracteres habituales hoy en día: UTF-8
- Me permite guardar todos los caracteres que me pueda imaginar.
- Y los guarda de forma bastante eficiente en espacio.
  - Los caracteres de uso más habitual (letras latinas sin tildes, números, signos de puntuación) se guardan en 1 byte.
  - Los caracteres con tildes y ñ, ç, etc se guardan en 2 bytes.
  - Otros caracteres menos habituales (chinos, japoneses, cirílico, griegas, emojis, etc) se guardan en 4 bytes.

La configuración del juego de caracteres se hace a nivel de base de datos, no a nivel de tabla ni columna ni consulta.
Cambiar el juego de caracteres de una base de datos ya creada es un proceso complejo y costoso en tiempo... implica reescribir completamente la BBDD (que ya habíamos dicho que son los ficheros que almacenan los datos físicamente).

Tendríamos que crear una BBDD nueva, exportar los datos (con un backup lógico), crear la nueva BBDD con el juego de caracteres adecuado, e importar los datos (restore lógico).