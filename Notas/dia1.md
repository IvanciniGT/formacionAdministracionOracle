# BBDD

- Persistencia de la información (datos)
- Consultar la información previamente almacenada

Esos datos al final los guardamos a HDD (en cualquiera de sus formas) en ficheros.

## Cómo gestiona el SO los ficheros (lo relativo a su acceso)

Los SO ofrecen 2 formas de acceder a archivos:
- Acceso secuencial
  - Leo el archivo desde el principio hasta el final.
  - Escribo el archivo desde el principio hasta el final, o agrego datos al final (logs).
- Acceso aleatorio
  - Leo de un archivo solo la parte que me interesa.
  - Escribo en un archivo solo la parte que me interesa.
Notas: 
- Cuando tengo archivos grandes, de los que solo quiero ir leyendo o escribiendo partes concretas, el acceso aleatorio es mucho más eficiente.
- Es mucho más complejo de implementar un sistema de acceso aleatorio que uno de acceso secuencial.

Al final, en un fichero (HDD) lo que vamos guardando son bytes.
Oye.. pero hay archivos también de texto plano (txt, csv, json, xml, etc). Esto es un apaño para que los humanos podamos leerlos y entenderlos. Al final, esos archivos de texto plano también son bytes en el HDD.

> En los ejemplo que yo a poner, trabajaré con caracteres, pero entendiendo que lo que se guarda en el HDD son bytes.

Cualquier archivos de esos de texto, de los que estamos acostumbrados, normalmente lo gestionamos de forma secuencial (lo leemos o escribimos de principio a fin). Esto es lo que hace WORD (xml), Excel (csv, xlsx), navegadores web (html, json, xml, etc), VSCode (txt, json, xml, etc), etc.

Cuando son pequeños no hay problema. Y es bien fácil. El SO se encarga de anotar dónde empieza y dónde acaba el archivo en el HDD. Es una operación que al desarrollar software delego al SO. Simplemente le pido:
- Abre el archivo y dame todo su contenido (lectura secuencial).
- Abre el archivo y escribe todo este contenido (escritura secuencial).
- Agrega este contenido al final del archivo (escritura secuencial).

Para poder implementar un acceso aleatorio sobre un fichero, la estructura de ese fichero debe permitirme conocer a priori dónde empieza y acaba cada parte del fichero que me interesa. 

> Ejemplos:

```xml
<!-- Este archivo aquí lo vemos como texto.. pero a nivel de HDD son bytes -->
<personas>
  <persona id="1">
    <nombre>Juan</nombre>
    <edad>30</edad>
  </persona>
  <persona id="2">
    <nombre>Ana</nombre>
    <edad>25</edad>
  </persona>
</personas>
```
- Quiero recuperar el nombre de la persona con id=2.
  De qué byte a qué byte está el nombre de la persona con id=2? Byte 121 - Byte 123 incluido.
  Hay forma de saber eso a priori? Imposible.
- Quiero modificar el nombre del persona con id=1, ponerle "Carlos" en lugar de "Juan".
  La primera dificultad sería saber dónde empieza y acaba el nombre de la persona con id=1 (Byte 43 - Byte 47 incluido)... lo cual ya hemos dicho que es misión imposible.
  Pero el problema es más gordo aún. "Carlos" tiene 6 caracteres, "Juan" tiene 4 caracteres. Si quiero escribir "Carlos" en el mismo sitio donde estaba "Juan", voy a pisar los bytes que estaban ocupados por "</" y voy a corromper el archivo.

      <nombre>Juan</nombre>
      <nombre>Carlosnombre>
                  **

  Los archivos no son elásticos. No puedo hacer crecer o menguar partes del archivo.
  Imaginad en pale... hago una lista de cosas... y si ahora quiero insertar una cosa en medio de la lista... tendría que mover todo lo que hay detrás para hacer hueco a la nueva cosa. Otra opción es poner ahí en medio (*1).. y luego al final del archivo pongo otra vez el *1 y la cosa nueva. Cuando quiera leerlo... se me complica la cosa... no es tan directo como leer secuencialmente. Los ojos (al leerlo en papel como humano) tienen que saltar de una posición a otra del papel... Incluso puede ser que ese *1 esté en otra página de mi cuaderno.. y entonces ya hasta pasar páginas con la mano.. sin perder la página original donde estaba antes y vi lo de *1.

```txt
1|Juan|30
2|Ana|25
```

Ese archivo tiene exactamente el mismo problema que el XML. No puedo saber a priori dónde empieza y acaba cada campo (nombre, edad) de cada persona (id). Y si quiero modificar un campo, puede que el nuevo valor tenga más o menos caracteres que el valor original, con lo que corro el riesgo de corromper el archivo.

Si tengo un sistema donde necesite hacer frecuentes lecturas y escrituras sobre partes concretas de un archivo, el acceso secuencial no me vale. Necesito otra forma: Acceso aleatorio.

Pero esa forma de trabajar no sale gratis. Tien un coste importante... de hecho varios (o mejor dicho un sobrecoste con respecto al acceso secuencial), pero debido a varios motivos:

    ```txt
    1Juan30
    2Ana 25
    ```

El ID sé que es el primer byte de cada línea... y ocupa 1 byte.
El nombre sé que empieza en el byte 2 de cada linea... y ocupa 4 bytes (aunque no use los 4 bytes completos, si pongo "Ana" dejo un espacio en blanco al final).
La edad sé que empieza en el byte 6 de cada línea... y ocupa 2 bytes.

Si quiero la edad de la persona con id=2, sé que tengo que ir a la segunda fila (si es que los registros están ordenados por id) y leer los bytes 6 y 7. Cómo además sé a priori que una fila ocupa 7 bytes (1+4+2), Y entre fila y fila hay otro byte de salto de línea, puedo calcular la posición exacta A PRIORI en el archivo donde está la edad de la persona con id=2:
    Salto una fila, con su salto de línea (7+1 bytes)
    De la segunda fila salto el id (1 byte) y el nombre (4 bytes)
    Total = 7+1+1+4 = 13 bytes
    La edad de la persona con id=2 está en los bytes 14 y 15 del archivo.

    No necesito leerlo a priori. Sin lewerlo, sé (puedo calcular) dónde está la región del archivo que me interesa.

    Consigo eso, a costa de:
     1. Tener un algoritmo que me permita calcular esas posiciones a priori -> Sobrecoste de desarrollo.
                                                                            -> Los campos deben tener un tamaño fijo (o máximo) -> Sobrecoste de almacenamiento (puedo estar desperdiciando espacio en blanco).
     2. Limito totalmente la cantidad de valores que puede tener cada campo -> Sobrecoste de usabilidad.

        En nuestro caso, cuántos ids puedo tener? Del 0 al 9 (1 byte).
        La edad máxima que puedo tener es 99 (2 bytes).
        El nombre máximo que puedo tener es 4 caracteres (4 bytes).
    
        Si quiero que el nombre potencialmente tenga 10 caracteres, ya no puedo usar 4 bytes, necesito 10 bytes -> Sobrecoste de almacenamiento.

            ```txt
            1Juan      30
            2Ana       25
            ```
        Tengo mucho espacio perdido... y además, sigo con una limitación funcional en el nombre (10 caracteres máximo).

        Una cosa es lo que ocurre en RAM.. y otra en HDD... En RAM los datos ocupan lo que necesitan.. en HDD, si quiero acceso aleatorio, tengo que reservar espacio fijo para cada campo... 
---

# BBDD Relaciones

## Logs

Las BBDD relaciones usan logs para distintas funciones:
- Log típico: Ir registrando las operaciones que se hacen en la BBDD, si hay incidentes. Tenemos niveles de log: debug, info, warning, error, critical.
- Transaccionales (Y esto va de serie ne cualquier BBDD relacional de producción: PostgreSQL, Oracle, MySQL, SQL Server, etc): Cada vez que se hace una operación que genere una actualización en los datos (INSERT, UPDATE, DELETE), se registra en un log transaccional. Si hay un fallo, se puede recuperar la BBDD hasta el último estado consistente conocido. Depende de la BBDD se les llama de una forma u otra (WAL en PostgreSQL, Redo Log en Oracle, Archive Log en SQL Server, etc).

---

# Oracle Database

## Cómo gestiona Oracle los archivos de datos

En Oracle (y en muchas otras BBDD relacionales) hay 2 conceptos:
- Estructura lógica: Cómo organizo yo los datos 
- Estructura física: Cómo los almacena el SO en el HDD

### Estructura lógica

    - Tablespace: Agrupación de tablas, índices...  ~ Conjunto de datafiles.
    - Tablas, Índices:   Contienen datos (filas/columnas)  ~ Conjunto de segmentos.
    - Segmento:   ~ Conjunto de extents.

### Estructura física
    - Datafile:   Fichero físico en el HDD que contiene datos de un tablespace.
                  Se divide en extents.
    - Extent:     Conjunto de bloques de datos contiguos.
    - Bloque de datos: Secuencia de bytes que se guardan en HDD (por defecto 8KB en Oracle, pero eso lo puede cambiar el DBA).

### Estructura de un archivo de datos (datafile)

    archivoDatos1.dbf

    |   extent1          |    extent2         |   extent3          |     extent4        |...
    | Blq1 | Blq2 | Blq3 | Blq1 | Blq2 | Blq3 | Blq1 | Blq2 | Blq3 | Blq1 | Blq2 | Blq3 |...
    |------segmento 1-------------------------|---segmento2-----------------------------|...

 La tabla tablaA está compuesta por los segmentos 1 y 3.
 El índice índiceA está compuesto por el segmento 2.

 Quizás, el segmento 3 (de la tablaA) esté en otro archivo de datos (archivoDatos2.dbf).

 Tablespace1:              Usa como datafiles:
    - TablaA                      - archivoDatos1.dbf
    - ÍndiceA                     - archivoDatos2.dbf

 TablaA usa para almacenar sus datos los segmentos 1 y 3.
    - Segmento 1 está en el archivoDatos1.dbf y tiene los extents 1 y 2.
    - Segmento 3 está en el archivoDatos2.dbf y tiene los extents 1, 2, 3, 4, 5... hasta el 50.
 ÍndiceA usa para almacenar sus datos el segmento 2. 
    - Segmento 2 está en el archivoDatos1.dbf y tiene los extents 3 y 4.

En los bloques al final es donde guardo los datos reales (filas de la tabla, nodos del índice, etc).

Cuando creo una tabla, un índice, etc... Oracle asigna espacio en los datafiles para guardar los datos de esos objetos lógicos (tablas, índices, etc). Ese espacio se asigna en forma de extents (conjuntos de bloques contiguos).

Al crear la tablaB, Oracle le asigna 2 extents (de 3 bloques cada uno) en el archivo de datos archivoDatos1.dbf.
Y de entrada tendríamos 6 bloques (2x3x8Kb = 48KB) para guardar los datos de la tablaB. Que se reservan en el archivo (HDD). Inicialmente están vacíos (sin datos).... pero ya ocupan espacio en el HDD.

En esos bloques es donde se van guardando las filas de la tablaB, hasta que llenemos esos 2 extents. En ese momento Oracle asignará más extents (más bloques) para seguir guardando datos de la tablaB. Y de repente le reserva otros 2 extents (de 3 bloques cada uno) en el archivo de datos archivoDatos2.dbf. Que de nuevo inicialmente estarán vacíos (sin datos).... pero ya ocupan espacio en el HDD.

Este es el primer nivel de almacenamiento físico de Oracle (datafiles, extents, bloques de datos).

Ahora nos toca conocer cómo se organizan los datos dentro de esos bloques de datos.

### Bloque de datos

Un bloque es la mínima unidad de almacenamiento que Oracle lee o escribe en el HDD.
En un bloque se guardarán datos de una tabla o de un índice.. u otros.
Puede ser que haya modificado solo un campo mínimo de una fila de una tabla que está en un bloque... y que en ese bloque tenga 200 filas... Oracle escribirá el bloque completo en el HDD (aunque solo haya modificado un campo de una fila).

#### Cómo es un bloque por dentro?

Tiene 2 partes:
- Header:
  - Información básica del bloque: 
    - Tipo de bloque (tabla, índice, etc).
    - Identificador del segmento al que pertenece (tabla, índice, etc).
    - Información de control de concurrencia (SCN, undo, etc).
      - Si estoy modificando una fila, la fila se bloquea hasta que termine la transacción.
        Esa información, de que una fila está bloqueada, se guarda en el header del bloque.
        Hay una cantidad limitada de espacio en el header para guardar información de concurrencia.
        Puede ocurrir, si tengo muchos registros en un bloue que muchos usuarios (4) estén tratando de modificar filas distintas del mismo bloque... y que no quepa toda la información de concurrencia en el header del bloque. Y se bloqueen transacciones enteras esperando a que haya espacio en el header del bloque para guardar su información de concurrencia.
- Row Directory: Índice interno del bloque que indica dónde empieza cada fila dentro del bloque (más en concreto cuánto espacio ocupa cada fila).
- Área de datos: Donde se guardan las filas de la tabla o los nodos del índice. Además, cada fila o nodo tiene su propio header con información de control (si el registro está repartido en varios bloques de datos, si está activo o no).
  Un registro si se borra no se elimina físicamente del bloque, simplemente se marca como borrado en su header.Y el espacio sigue ocupado hasta que se haga un proceso de compactación (reorganización) del bloque - Tarea típica de administración de BBDD.

   ------ BLOQUE 234 --------------------
   Header: 
    Hola, soly un bloque de la tabla EMPLEADOS y aún me queda 50% de espacio libre.
    Row Directory:
        Fila 1: ocupa 24 bytes
        Fila 2: ocupa 28 bytes
        Fila 3: ocupa 30 bytes
    Data:
        | 1 | Ana | 2000 |
        | 2 | Juan | 2500 |
        | 3 | Pedro | 3000 |


    Hay un porcentaje de espacio libre del tamaño total del bloque que se reserva para modificaciones futuras (updates) de los registros que ya están en el bloque.

    > Ejemplo: Un bloque de 8KB (8192 bytes)
    
        - header de 200 bytes 
        - row directory de 100 bytes
        - me quedan 7892 bytes para datos
         - De esos un % se reserva para modificaciones futuras (updates) de los registros que ya están en el bloque.
           En oracle se configura con un parámetro llamado PCTFREE (ese parámetro se puede configurar a nivel de tabla, índice, etc). 
         - Imaginamos que tenemos un PCTFREE del 20%
           - 20% de 7892 bytes = 1578 bytes reservados para modificaciones futuras (updates)
           - 80% de 7892 bytes = 6314 bytes para nuevos registros (inserts)
         -  Si cada registro ocupa de media 100 bytes, en ese bloque podré meter:
           - 63 registros nuevos (6314/100)
           - Y luego podré modificar esos registros (updates) hasta ocupar los 1578 bytes reservados para modificaciones futuras.

En Oracle, igual que en otras muchas BBDD, para los textos (que son de las cosas más complejas a la hora de almacenar datos) usamos mucho un tipo de datos llamado VARCHAR2 (NOTA: hoy en día es exactamente igual que VARCHAR en ORACLE. Varchar es un sinónimo de VARCHAR2, aunque Oracle avisa que en el futuro podrían diferenciarse: SIEMPRE usar VARCHAR2 en Oracle). Eso son textos de ancho variable. Eso de variable.. a priori podría dificultar el cálculo de posiciones a priori (acceso aleatorio). Para ello, Oracle no rellena con espacios en blanco el resto del campo (como hacíamos en los ejemplos anteriores), sino que guarda el tamaño real de la fila en el row directory del bloque. Así puede saber a priori dónde empieza cada fila dentro del bloque. 

Esto evita tener que tener espacio reservado a nivel de cada campo.

Qué pasa cuando hay una actualización? Para eso tenemos ese espacio reservado en el bloque (PCTFREE). Si la actualización hace que la fila ocupe más espacio, Oracle puede mover la fila dentro del bloque (si hay espacio libre suficiente en el bloque) y actualizar el row directory del bloque para reflejar la nueva posición y tamaño de la fila.

La idea es que la fila no tenga que moverse a otro bloque. Eso sería malo. 

Más adelante hablaremos de los índices. 
Pero os adelanto que la UBICACION que oracle guarda para un registro dentro de un índice es el bloque de datos en el que está la fila de la tabla.
Si tengo que mover una fila de un bloque a otro, tendría que actualizar TODOS los índices que apunten a esa fila (porque la ubicación habría cambiado). Eso es muy costoso. Por eso Oracle intenta evitar mover filas entre bloques.

Una vez lleno el pctfree, si hay una actualización que hace que una fila ocupe más espacio del que tiene asignado, Oracle no podrá mover la fila dentro del bloque (porque no hay espacio libre suficiente en el bloque). En ese caso, Oracle moverá la fila a otro bloque (donde haya espacio libre suficiente) y marcará la fila original como borrada (en su header). Y actualizará el row directory del bloque original para reflejar que esa fila ya no está ahí. Y necesitará actualizar TODOS los índices que apunten a esa fila (porque la ubicación habría cambiado).

Este es otro motivo por el que habitualmente necesitamos ejecutar operaciones de mantenimiento en las tablas (reorganización, reindexado, etc) para optimizar el almacenamiento y acceso a los datos.
Por ejemplo, de vez en cuando hay que recompactar los bloques de datos para eliminar los registros marcados como borrados y liberar espacio. O directamente reorganizar toda la tabla (volcarla a otro sitio y volver a crearla) para que las filas estén lo más juntas posible y evitar fragmentación y generar nuevo pctfree en los bloques, de forma que nuevas modificaciones de filas no tengan que mover filas entre bloques.

> Ejemplos:

>> Ejemplo 1: Tengo una tabla con información de 

                                                     EstadoMatriculacion             Tipos de cursos
                                                          ^                                ^
         Empresas < Empleados x Empresa > Personas < Matriculaciones >  Convocatorias > Cursos
                          |                               v     |                          v
                          +-------------------------------+    Evaluaciones           Profesores

   - Tabla Evaluaciones:
    | MATRICULA_ID | FECHA_EVALUACION | NOTA | OBSERVACIONES |
        Number          Date        Number(5,2)     Varchar2(2000)

    Esa tabla tiene una relación con la tabla Matriculaciones (MATRICULA_ID) 1-1.
    Eso significa, que por cada fila de Matriculaciones tengo 1 fila en Evaluaciones.
    Pregunta que hice la semana pasada: Si tengo una relación 1-1, por qué no simplemente añadir los campos de Evaluaciones a la tabla Matriculaciones? Porque los campos que tengo en Evaluaciones son campos que pueden cambiar con frecuencia (FECHA, NOTA, OBSERVACIONES)y además, sus tamaños pueden cambiar considerablemente.
    Al empezar un curso, que evaluación hay? a priori ninguna. Así que esos campos estarán a NULL.
    Incluso una vez introducidos, qué campo puede cambiar de tamaño a lo loco? 50 --> 1000 caracteres en OBSERVACIONES. Y me puede destrozar el rendimiento... agotando rápidamente el pctfree de los bloques de Matriculaciones, si lo tuviera allí.

    Decisión:
     1. Evaluaciones en tabla aparte.
     2. PCTFREE alto en Evaluaciones (por los cambios de tamaño en OBSERVACIONES): 20-25%
     3. Mantenimiento frecuente en Evaluaciones (reorganización, etc).

   - Tabla Personas:
    | ID_Persona | Nombre | Apellidos | Email | Teléfono | DNI |

    Qué PCTFree? El tamaño de esos campos es variable (VARCHAR2). Ahora... van a cambiar con frecuencia?
    - El nombre, apellidos, dni va a cambiar con muy poca frecuencia.
    - El Telefono puede cambiar con más frecuencia? Podría... pero no con mucha frecuencia...
      Ahora bien.. incluso cambiando... Su tamaño cambiaría? NO
    - El email? En nuestro caso, esl un Identificador único del usuario en la plataforma. Puede cambiar... pero no tanto... y su tamaño no va a cambiar mucho. 40 caracteres -> 50 caracteres.

     PCTFREE: 5%    

   - Tabla Matriculaciones:
    | ID_Matriculacion | ID_Persona | ID_Empresa | ID_Convocatoria | Fecha_Matriculacion | Estado_Matriculación |
        Number            Number        Number         Number            Date                Number
    
    Pregunta: Qué PCTFREE le pongo a la tabla Matriculaciones? 0%
    Por qué un 0%? Aunque cambie algún dato (que de cambiar sería el Estado_Matriculacion), no va a crecer el tamaño de la fila. Siempre va a ocupar lo mismo. Así que no necesito reservar espacio para modificaciones futuras (updates). 
    Solo habría un dato en esa tabla que pudiera cambiar de tamaño: ID_Empresa
    He apuntado a una persona sin empresa (NULL) y luego le asigno una empresa (un número). En ese caso la fila crecería en tamaño.
       La pregunta que me haría en este momento es: Con qué frecuencia voy a hacer eso? Si es algo muy poco frecuente, puedo asumir el coste de mover la fila a otro bloque (y actualizar los índices) cuando eso ocurra. Y poner un PCTFREE del 0%... y no tengo desperdicio de espacio en los bloques.


Por qué quiero optimizar el almacenamiento de los bloques? Qué quiero conseguir? Dicho de otra forma, por qué querría yo poder bajar el pctfree a 0?
 - Optimizar espacio de almacenamiento... que es MUY CARO para las BBDD.
 - Optimizar el uso de RAM.

Las BBDD tienden a cachear esos bloques de datos en RAM, para acelerar el acceso a los datos.
Lo ideal, que pudiera tener TODOS los bloques de datos en RAM, y solo tener que ir a HDD para actualizar datos (escrituras). Pero que todas las consultas se resuelvan en RAM. Eso mejoraría el rendimiento de la BBDD.

Hay un indicador clave en las BBDD que es el "Cache Hit Ratio". El % de éxito que tengo al ir a buscar un dato en RAM (cache) y no tener que ir a HDD. En una BBDD, lo ideal es tener un Cache Hit Ratio del 90% o superior.

Lo que se guarda en la cache de la BBDD son bloques de datos completos.
Si tengo mucho espacio desperdiciado en los bloques (por tener un pctfree alto), estoy desperdiciando espacio en RAM (cache de la BBDD) . En cache (RAM) teendré mucho espacio sin datos... pero ocupando RAM... Y eso implica que puedo tener menos bloques en RAM (cache de la BBDD) y por tanto el Cache Hit Ratio baja.

Si tengo los bloque más compactos (con más datos, por tener un pctfree bajo), podré tener más bloques en RAM (cache de la BBDD) y el Cache Hit Ratio subirá, y eso redunda en un mejor rendimiento de la BBDD.

---

Conclusión: Las BBDD relacionales en general y Oracle en particular, requieren de mantenimiento periódico para optimizar el almacenamiento y acceso a los datos. Y ese mantenimiento no será igual para cada tabla. Cada tabla necesita tener sus propias tareas de mantenimiento, en función de su estructura y uso.

Por eso es importante:
- ENTENDER la estructura lógica y física de mi BBDD.
- CONOCER los patrones de uso de cada tabla (qué datos cambian con frecuencia, qué datos crecen en tamaño, etc).
- Hacer un DISEÑO adecuado de la BBDD.
- Para PROPONER/ESTABLECER UN PLAN DE MANTENIMIENTO adecuado a cada tabla.

Entendiendo bien estas cosas, somos capaces de optimizar el rendimiento y coste de nuestra BBDD al máximo.

Eso sí... requiere tiempo y esfuerzo... pero a la larga merece la pena???

El "merece la pena"... es complejo.

De hecho, la tendencia actual en el mundo IT en general es a qué no merece la pena.

JAVA. Qué tal gestiona JAVA la memoria RAM? Como el puto culo!

```java
String texto = "Hola"; // Asigno la variable texto al valor "Hola"
texto = "adios";       // Asigno la variable texto al valor "adios"
                       // Esta linea ha guardado "adios" en RAM... la pregunta es si se ha guardado donde estaba "Hola" o en otro sitio. Y la respuesta es que en otro sitio.
                       // Lo que tengo es fé de que en un momento dado, entrará un proceso en segundo plano que existe en la JVM (Java Virtual Machine) que se llama Garbage Collector (GC) que liberará el espacio en RAM que ocupaba "Hola" porque ya no hay ninguna variable que apunte a ese valor.
```

Y esto es complejo.. el concepto de variable cambia de lenguaje a lenguaje.
Si ese código lo escribo en C:

```c
char texto[10];        // Reservo espacio para 10 caracteres
strcpy(texto, "Hola"); // Copio "Hola" en la variable texto
strcpy(texto, "adios");// Copio "adios" en la variable texto
```

En C una variable es como un cajoncito en la RAM, donde pongo cosas o del que saco cosas.
En cambio, en JAVA una variable es una referencia a un dato que tengo en la RAM.... tiene más que ver con el concepto de puntero en C/C++.
En C, lo único que tengo en memoria RAM en cualquier momento del tiempo es una secuencia de caracteres (texto).
En cambi, en JAVA, despu´çes de ejecutar `texto = "adios";`, en memoria RAM tengo 2 textos: "Hola" y "adios".
Pero esto implica una cosa... El mismo programa (ese en concreto), hecho en JAVA o en C, tendrá requerimientos de RAM muy distintos. En concreto en JAVA necesitaré el doble de RAM que en C (por lo menos).

Y lo curioso es que eso mismo ocurre en Python y en JS... que con Java son los 3 lenguajes más usados hoy en día.
EEs decir, los 3 lenguajes más usados hoy en día gestionan la memoria RAM como el puto culo.

Por qué hacemos eso? Y no mejor creamos software en C/C++ que gestiona la memoria RAM de forma eficiente?
Programar en Java, JS o Python es más sencillo y rápido que en C/C++.
- Necesito menos horas de programador con menos nivel de programación para hacer el mismo software.

Y al final, desde el punto de vista de la empresa, la cuenta es:
- 200 horas de programador "barato" (50€/hora) en Java = 10.000€
- 250 horas de programador "caro" (80€/hora) en C++ = 20.000€
- Diferencia: 10.000€ a favor de Java.

Cuánto cuesta una pastilla de RAM para el servidor? 1000€

Está claro... lo hago en java y me ahorro 9.000€.

A costa de mayor gasto de electricidad... más gasto para el planeta en producción de chips, extracción de silicio...
Y todas esas cosas que a nadie le importan. Menos pasta para los trabajadores.

---

Este mismo concepto es el que se aplica a los CLOUDs.

Hoy en día es posible contratar una BBDD (Oracle, postgres, mariadb) totalmente gestionadas por el proveedor CLOUD (AWS, Azure, GCP, Oracle Cloud, etc).
Eso si... se gestionan en automático... con scripts de mnto fijos... sin personalización.

Va a ir la BBDD igual de fina que si la gestionara un DBA experto? Ni de coña.
Pongo en la balanza:
- Coste de tener un DBA experto en plantilla (60.000€/año)
- Coste de contratar 2 servidores adicionales en el CLOUD (2.000€/mes = 24.000€/año) para compensar la ineficiencia de la BBDD gestionada automáticamente sin personalización.

Resultado: Ahorro de 36.000€/año. AL CLOUD.
Que tengo un experto que ya no tengo... que contamina más el tener más máquinas producidas y con gasto de electricidad... A la empresa le da igual.

---

## Consulta de datos en BBDD Relacionales y en particular en Oracle

Para acceder los datos de una tabla, a priiori, cualquier gestor de BBDD relacional (Oracle, PostgreSQL, MySQL, SQL Server, etc) tiene que hacer un lectura completa de todos los bloques de datos que tienen información de la tabla para devolverlos. Esto implica, que podría ser que el gestor de BBDD leyera el doble de bytes de los que realmente necesita para devolver el resultado de la consulta (debido a cabeceras, pctfree, datos que siguen guardados en bloques pero que no están activos, etc). Y ESO SIN CONTAR con que yo solo quiera un subconjunto de las filas o columnas de la tabla (query restrictiva a nivel de columnas o filas -WHERE-)

Esa operación se denomina "Full Table Scan" (FTS).

| Personas |
| ID_Persona | Nombre | Apellidos | Email                | Teléfono  | DNI       |
| 1          | Ana    | Pérez     | ejemplo1@empresa.com | 123456789 | 12345678A |
| 2          | Juan   | Gómez     | ejemplo2@empresa.com | 987654321 | 87654321B |
| 3          | Pedro  | López     | ejemplo3@empresa.com | 456123789 | 56781234C |
| 4          | María  | Pérez     | ejemplo4@empresa.com | 321654987 | 43218765D |
| 5          | Pedro  | Gómez     | ejemplo5@empresa.com | 654987321 | 98765432E |

Si quiero sacar TODOS los datos de la tabla Personas, el motor de BBDD tendrá que leer TODOS los bloques de datos que contienen filas de la tabla Personas .... de ellos, deberá devolver solamente las filas activas (no borradas).
Esa operación es la que hemos dicho que es un Full Table Scan (FTS).
Y esa operación, el tiempo que requiere, es directamente proporcional al número de registros que tenga la tabla.
Dicho de otra forma: 
 - Un FST es un algoritmo O(n) (donde el tiempo crece linealmente con el número de registros n).

Claro... en la mayor parte de los casos, no quiero TODOS los datos de la tabla. Quiero un subconjunto de ellos. Para eso aplicaremos filtros (WHERE). La pregunta es cómo hace el motor de BBDD para aplicar esos filtros?

    SELECT * FROM Personas WHERE Apellidos = 'Pérez';

Para resolver una query como esa, el motor de BBDD haría lo mismo que para recuperar todos los datos de la tabla (FTS), es decir, lee todos los bloques de datos que contienen filas de la tabla Personas. Y de ellos, todos los registros activos (no borrados) que contengan. Eso si, irá recopilando solamente los registros que cumplan el filtro (Apellidos = 'Pérez'). Pero esa condición (filtro) ha de ser aplicada sobre cada registro que se lee.
Es decir, a priori, este tipo de consulta también atiende a un algoritmo O(n) (donde el tiempo crece linealmente con el número de registros n). A más registros en la tabla, más tiempo tardará en devolver el resultado.

Por desgracia, las BBDD tienden a crecer con el tiempo. Y por ende, el rendimiento de las consultas tenderá a empeorar con el tiempo.

Qué podemos hacer aquí?
La idea es.,.. si quiero recuperar solamente los regsitros que cumplan una condición concreta (Apellidos = 'Pérez'), no necesitar leer todos los bloques de datos de la tabla Personas y todos sus registros. Ahí es donde quiero ahorrar.

Para ello, las BBDD relacionales usan los índices.

Los índices son copias ordenadas de los datos, conteniendo adicionalmente información acerca de la ubicación física de los registros en los bloques de datos de la tabla original.
Cuando tengo datos ordenados, podemos aplicar algoritmos de búsqueda mucho más eficientes que el FTS (O(n)), principalmente algoritmos de búsqueda binaria y variantes, que son O(log n) (donde el tiempo crece logarítmicamente con el número de registros n)... y esto es bastante poco (el crecimiento).

Una búsqueda binaria es una técnica que llevamos aplciando desde que tenemos 7/8 años- 10 años. Cada vez que buscamos una palabra en un diccionario, estamos aplicando una búsqueda binaria. Yo no recorro el diccionario entero, palabra por palabra, hasta encontrar la que busco. 

Simplemente abro el diccionario por la mitad, veo si la palabra que busco está antes o después de la palabra en la que he abierto el diccionario. Y así voy descartando la mitad del diccionario en cada paso, hasta que encuentro la palabra que busco.

Para 1 millón de datos, necesito hacer log(2(1.000.000)) = 20 operaciones para encontrar el dato que busco.
Si en lugar de hacer una búsdqueda binaria, hago un FTS (O(n)), necesitaría hacer 1.000.000 de operaciones para encontrar el/los datos que busco.

Es más, si quiero buscar la palabra "almendro" en un diccionario, abro el diccionario por la mitad? Lo abro por el principio.

Si abriera por la mitad:
1000000 / 2 = 500000 / 2 = 250000 / 2 = 125000 / 2 = 62500 / 2 = 31250 / 2 = 15625 / 2 = 7812 / 2 = 3906 / 2 = 1953 / 2 = 976 / 2 = 488 / 2 = 244 / 2 = 122 / 2 = 61 / 2 = 30 / 2 = 15 / 2 = 7 / 2 = 3 / 2 = 1  ---> 20 operaciones 

Si optimizo el primer corte: 10000 / 2 = 5000 / 2 = 2500 / 2 = 1250 / 2 = 625 / 2 = 312 / 2 = 156 / 2 = 78 / 2 = 39 / 2 = 19 / 2 = 9 / 2 = 4 / 2 = 2 / 2 = 1 ---> 14 operaciones

Esa optimización la puedo hacer gracias a que conozco la distribución de datos que tengo. En el caso de un diccionario, sé que las palabras empiezan por letras de la A a la Z. Y conozco más o menos qué % de palabras empiezan por cada letra... o al menos de qué letras hay más palabras. De la A hay muchas palabras que de la Z.

Las BBDD también hacen esto. Son capaces de optimizar esos cortes iniciales (2/3 primeros cortes) para reducir el número de operaciones necesarias para encontrar los datos que busco. Para ello generan estadísticas de la distribución de los datos en las tablas e índices.

Esas estadísticas, en muchos casos son objeto de operaciones de mantenimiento en la BBDD (recolección de estadísticas) para que estén actualizadas y permitan al optimizador de consultas de la BBDD generar planes de ejecución óptimos para las consultas.



                                                     EstadoMatriculacion             Tipos de cursos
                                                          ^                                ^
         Empresas < Empleados x Empresa > Personas < Matriculaciones >  Convocatorias > Cursos
                          |                               v     |                          v
                          +-------------------------------+    Evaluaciones           Profesores

    > Ejemplos:
    - Tabla Personas:
       | ID_Persona | Nombre | Apellidos | Email | Teléfono | DNI |
       En un momento dado del tiempo, tengo 200.000 personas en la tabla Personas. y calculo sus estadísticas...
       Eso implica que tengo que leer todos los bloques de datos que contienen filas de la tabla Personas (FTS) y analizar todos los registros activos (no borrados) que contengan para calcular la distribución de los datos en la tabla Personas.

       Al año, paso de 200k a 1M de personas en la tabla Personas.
       Pregunta... Es importante regenerar estadísticas de la tabla Personas? Depende... de la columna:
       - DNI: Va a cambiar el % de DNIs que empiezan por 1 o por 3 con el tiempo? POCO
       - NOMBRE: Va a cambiar el % de nombres que empiezan por A o por Z con el tiempo? POCO
       - ID: Van a cambiar? MUCHISIMO.
         La primera vez que calculamos las estadísticas, tenemos 200k personas. El ID va del 1 al 200.000.
         Al año, tenemos 1M de personas. El ID va del 1 al 1.000.000.
         Todos los % van a cambiar.

CONCLUSION, las estadísticas hay que irlas regenerando... pero a diferente ritmo en función de cada columna concreta de nuestras tablas.
- Hay columnas que requieren poco mantenimiento en lo referente a regeneración de estadísticas: Nombre, Apellidos, DNI, Email, Teléfono.
- Hay columnas que requieren mucho mantenimiento en lo referente a regeneración de estadísticas: Todos los identificadores, fechas

---

En cualquier caso, esto de las estadísticas, solamente me ayuda a optimizar los primeros cortes de la búsqueda binaria. Pero para poder aplicar la búsqueda binaria, necesito tener los datos ordenados.
Y a las compoutadoras se les da como el culo ordenar datos.... es de las peores cosas que se les puedo pedir.
Un algoritmo bueno para ordenar datos es de orden O(n log n) (donde el tiempo crece como n log n con el número de registros n).

Es decir, que para 100.000 registros, necesito hacer 100.000 x log(2(100.000)) = 100.000 x 16 = 1.600.000 operaciones para ordenar los datos.
Pero para 1M de registros, necesito hacer 1.000.000 x log(2(1.000.000)) = 1.000.000 x 20 = 20.000.000 operaciones para ordenar los datos.

En cualquier caso, son muchas más operaciones que las necesarias para hacer un FTS (100.000 o 1.000.000 de operaciones respectivamente).

Si no tengo los datos preordenados, la BBDD NUNCA decidirá ordenar los datos para responder a una consulta aplicando un algoritmo de búsqueda binaria. Siempre hará un FULL SCAN.... son menos operaciones als que tiene que hacer.

SOLAMENTE la BBDD decidirá aplicar un algoritmo de búsqueda binaria si tiene los datos preordenados. Y la diferencia de rendimiento es abismal.
- Sobre 1.000.000:
  - FTS: 1.000.000 operaciones
  - Búsqueda binaria: 20 operaciones
  - Búsqueda binaria con buenas estadísticas: 14 operaciones

La ordenación de datos, en un problema. Ya que a priori, por cuantós campos independientes puedo tener ordenados un conjunto de datos? Por 1 solo campo. Esto no es solución. Querré hacer búsquedas posiblemente por distintos campos.

La única opción que tengo es hacer una COPIA ORDENADA de los datos por cada campo que quiera tener ordenado.
Eso es un ÍNDICE.

    | Personas |
    | ID_Persona | Nombre | Apellidos | Email                | Teléfono  | DNI       |
    | 1          | Ana    | Pérez     | ejemplo1@empresa.com | 123456789 | 12345678A |
    | 2          | Juan   | Gómez     | ejemplo2@empresa.com | 987654321 | 87654321B |
    | 3          | Pedro  | López     | ejemplo3@empresa.com | 456123789 | 56781234C |
    | 4          | María  | Pérez     | ejemplo4@empresa.com | 321654987 | 43218765D |
    | 5          | Pedro  | Gómez     | ejemplo5@empresa.com | 654987321 | 98765432E |

    INDICE por APELLIDOS:
        Dato ordenado   | Ubicación (ID_Persona)
        Gómez           | 2, 5
        López           | 3
        Pérez           | 1, 4
    
    INDICE por NOMBRE:
        Dato ordenado   | Ubicación (ID_Persona)
        Ana             | 1
        Juan            | 2
        María           | 4
        Pedro           | 3, 5
    
    INDICE por DNI:
        Dato ordenado  | Ubicación (ID_Persona)
        12345678A      | 1
        43218765D      | 4
        56781234C      | 3
        87654321B      | 2
        98765432E      | 5

    De hecho, Oracle los datos originales (tabla) los mete ordenados por tiempo... momento en el que se insertan.
    Los nuevos se van insertando al final.

    Eso si... aquí hay un problema.
    LLEGA UN DATO NUEVO:
    | 6          | Alberto | Sánchez   | ejemplo6@miempresa.com | 789123456 | 34567891F |

    En la tabla Personas, ese nuevo dato se añade al final (orden por tiempo).
    Pero en los índices, ese nuevo dato debe insertarse en la posición correcta para mantener el orden.
        
        INDICE por NOMBRE:
            Dato ordenado   | Ubicación (ID_Persona)
            Ana             | 1
            Juan            | 2
            María           | 4
            Pedro           | 3, 5
        En este caso, Alberto habría que meterlo al principio del índice, antes del dato Ana....
        Y la pregunta es, hay hueco en el fichero, para escribirlo ahí? NO .. al menos a priori
        Las BBDD, al crear índices, reservan mucho espacio en blanco entre los datos para futuras inserciones.
        De forma que cuando llegue el dato Alberto, haya espacio para insertarlo ahí sin tener que mover el resto de datos. 
        Es decir, que si los datos de una columna ocupan 100Kbs, el índice podría ocupar 150Kbs... para tener espacio libre para futuras inserciones.

        Si una tabla ocupa 100Kbs... y le creo muchos índices... y en esos índices tengo muchos espacios en blanco... puedo llegar a tener índices que ocupen varios MBs... para una tabla de 100Kbs.

        Hay que tener mucho cuidado al crear índices... porque cada índice que creo, implica un sobrecoste de almacenamiento y rendimiento (inserciones, actualizaciones, borrados) de datos y de mantenimiento (reorganización de índices, recolección de estadísticas, etc).
---

El proceso de regeneración/generación de estadísticas consiste en leer todos los datos de la tabla para aprender la distribución de los datos en la tabla (mínimos, máximos, medias, percentiles, etc).

Por ejemplo. En el diccionario sabemos que hay:
A - 6-7%
B
C
D
E - 6-7%
F
G
H
I
J
K
L
M
N
O
P
Q - 0,2%
R
S
T
U
V
W - 0,05%
X - 0,10%
Y
Z - 0,35%

En total 26 letras.... 1/26 = 3,85% de las palabras empiezan por cada letra (si la distribución fuera uniforme).
Eso lo puedo calcular... leyendo todas las palabras del diccionario (FTS) y contando cuántas empiezan por cada letra.

Si de repente cambian mucho las palabras, puede ser que tenga sentido rehacer ese trabajo. Recalcular las estadísticas, volviendo a leer todas las palabras del diccionario (FTS) y contando cuántas empiezan por cada letra.

En este caso, estamos calculando la distribución de los datos para una variable de tipo texto.
En el caso de una variable de tipo NUMERO la cosa cambia:

> Ejemplo: EDAD. Si tengo 1M de personas

Me leo todos los datos de la tabla (FTS) y veo que las edades van de 18 a 100 años.
    Mínimo:  18
    Máximo: 100
    Mediana: 40 -> La mitad de las personas tienen menos de 40 años, en nuestro caso 500.000 personas.
                -> La otra mitad tienen más de 40 años, en nuestro caso 500.000 personas.
    Percentil 10: 22 -> El 10% de las personas tienen menos de 22 años, en nuestro caso 100.000 personas.
    Percentil 20: 30 -> El 20% de las personas tienen menos de 30 años, en nuestro caso 200.000 personas.
    Percentil 30: 35 -> El 30% de las personas tienen menos de 35 años, en nuestro caso 300.000 personas.
    Percentil 40: 38 -> El 40% de las personas tienen menos de 38 años, en nuestro caso 400.000 personas.
    Percentil 50: 40 -> El 50% de las personas tienen menos de 40 años, en nuestro caso 500.000 personas.
    Percentil 60: 45 -> El 60% de las personas tienen menos de 45 años, en nuestro caso 600.000 personas.
    Percentil 70: 50 -> El 70% de las personas tienen menos de 50 años, en nuestro caso 700.000 personas.
    Percentil 80: 60 -> El 80% de las personas tienen menos de 60 años, en nuestro caso 800.000 personas.   
    Percentil 90: 75 -> El 90% de las personas tienen menos de 75 años, en nuestro caso 900.000 personas.

    Quiero la gente que tiene 43 años... Mirando los percentiles:
    - Puedo saltar a las primeras 500.000 personas (la mitad) porque tienen menos de 40 años.
    - Puedo obviar a las últimas 400.000 personas porque tienen más de 45 años.
    - Me quedan 100.000 personas (de la 500.001 a la 600.000) que tienen entre 40 y 45 años.
    - Ahí están las que a mi me interesan (43 años).
  
  En este caso, hemos calculado 10 percentiles (del 10 al 90) para la variable EDAD.
  Podría calcular 99 percentiles (del 1 al 99) para tener una distribución más fina de los datos.
  Y atinar con precisión del 1% a la hora de descartar datos que no me interesan.