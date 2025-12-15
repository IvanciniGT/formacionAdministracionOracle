# Collates a nivel de tabla / columna

Solo están disponibles si tenemos actiavda la opción MAX_STRING_SIZE=EXTENDED. 
Esa opción, lo primero quee permite es usar VARCHAR2 de más de 4000 bytes (hasta 32767 bytes).
Pero también permite usar collates a nivel de tabla o columna.

En muchas instalaciones, por defecto el MAX_STRING_SIZE está a STANDARD, que limita a 4000 bytes los VARCHAR2 y además no se pueden usar collates a nivel de tabla o columna.

---

# Ejecución del scrips de creación de tablas

1. Cambiamos los Collates al nombre adecuado según versión de Oracle: XSPANISH_AI
2. Ejecutamos la creación de tablas y triggers
   Hemos saltado:
   - Que la tabla Cursos se cree en un tablespace con bloques de 32KB (A falta de un DBWR que escriba en bloques de 32KB, no sirve de nada crear tablas con bloques de 32KB) 
   - Creación de índices fulltext (A falta de activar Oracle Text)
   - Los procedimientos y triggers de la tabla empresas_telefonos
3. Nos faltaron también los views y los materialized views

---

# Siguientes pasos:

1. Cargar datos de prueba
   1. TAREA 1
      1. Probar consultas 
      2. Mirar los planes de ejecución
   2. TAREA 2
      1. Análisis del uso de los ficheros de la bbdd: 
         - Tablespaces, ficheros, segmentos, extents, bloques 
         - Export de un bloque a dicso para verlo por dentro.