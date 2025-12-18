-- Como generamos esas estadisticas:
ALTER SESSION SET CONTAINER =ORCLPDB1;

-- Manual

BEGIN
  DBMS_STATS.GATHER_TABLE_STATS(
    ownname => 'PROFESOR',
    tabname => 'CURSOS',
    method_opt => 'FOR ALL COLUMNS SIZE AUTO', -- por defecto :
        -- Si la columna tiene poca cardinalidad (pocos valores distintos) genera historgrama con tantos buckets como valores distintos
        -- Si la columna tiene mucha cardinalidad (muchos valores distintos) no genera histograma
    --method_opt => 'FOR ALL COLUMNS SIZE AUTO FOR COLUMNS SIZE 100 PRECIO_PARA_PARTICULARES', -- ejemplo de combinación
    -- podemos usar la palabra REPEAT... eso regenera las estadísticas con la misma configuración que la vez anterior
    --method_opt => 'FOR ALL COLUMNS REPEAT',
    cascade => TRUE, -- También genera estadísticas de los índices
    estimate_percent => NULL -- Todas las filas (NULL es default).. Si quiero solo un % pongo el valor (10 = 10%)
  );
END;
/
-- Esto se usa solo después de una carga masiva de datos!

--- Formulas automatizadas
-- Caso que quiera recalcular estadísticas de forma automatica (Y SIEMPRE VOY A QUERERLO) hay 2 pasos:
-- 1º Establecer las preferencias de estadisticas para la tabla... y se hace para cada tabla.
--    De no hacerse, hay unos valores por defecto que se aplican.. que me podrán servir o no.
--    En general para las tablas grandes e importantes de mi sistema, es mejor establecerlas explícitamente.

BEGIN
  DBMS_STATS.SET_TABLE_PREFS(
    ownname => 'PROFESOR',
    tabname => 'CURSOS',
    pname => 'METHOD_OPT',
    pvalue => 'FOR ALL COLUMNS SIZE AUTO FOR COLUMNS SIZE 255 PRECIO_PARA_PARTICULARES'  -- Ejemplo de configuración personalizada
  );
END;
/
SELECT * FROM DBA_TAB_COL_STATISTICS WHERE TABLE_NAME = 'CURSOS' AND OWNER = 'PROFESOR';
-- Una vez hecho esto, puedo:

-- Con un trabajo (JOB) programado (Esto es más legacy)
BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'ESTADISTICAS_MATRICULAS_JOB',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                            DBMS_STATS.GATHER_TABLE_STATS(
                                ownname => ''PROFESOR'',
                                tabname => ''CURSOS'',
                                method_opt => ''FOR ALL COLUMNS SIZE REPEAT'',
                                cascade => TRUE -- También genera estadísticas de los índices
                            );
                        END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0; BYSECOND=0', -- Diariamente a las 2:00 AM
    enabled         => TRUE,
    comments        => 'Job para mantenimiento automático de estadísticas de la tabla CURSOS'
  );
END;
/
-- Desactivar temporalmente el job
BEGIN
    DBMS_SCHEDULER.DISABLE('ESTADISTICAS_MATRICULAS_JOB');
END;
/
-- Reactivarlo más adelante
BEGIN
    DBMS_SCHEDULER.ENABLE('ESTADISTICAS_MATRICULAS_JOB');
END;
/
-- Eliminar el job
BEGIN
    DBMS_SCHEDULER.DROP_JOB('ESTADISTICAS_MATRICULAS_JOB');
END;
/
-- Puedo consultar los jobs creados con:
 SELECT JOB_NAME, ENABLED, LAST_START_DATE, NEXT_RUN_DATE FROM USER_SCHEDULER_JOBS;

-- Ejecutar manualmente un job:
BEGIN
    DBMS_SCHEDULER.RUN_JOB('ESTADISTICAS_MATRICULAS_JOB');
END;
/
-- 

-- Automáticamente (AUTO STATS GATHERING) en la ventana de mantenimiento (Esta es la forma guay)
-- En lugar de jobs, hablamos de tareas automáticas (AUTOTASK)
SELECT * FROM DBA_AUTOTASK_CLIENT;
-- La tarea que nos interesa es 'auto optimizer stats collection'

-- Las tareas automáticas se ejecutan en la ventana de mantenimiento (maintenance window)
-- La podemos ver configurada en la tabla DBA_SCHEDULER_WINDOWS
SELECT * FROM DBA_SCHEDULER_WINDOWS ;

-- Para modificar una ventana de mantenimiento:
BEGIN
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name => 'MONDAY_WINDOW',
    attribute => 'REPEAT_INTERVAL',
    value => 'FREQ=DAILY;BYDAY=MON; BYHOUR=2; BYMINUTE=0; BYSECOND=0'  -- Cambiar a las 2:00 AM
  );
END;
/
-- Las ventanas de mantenimiento tienen una duración:
BEGIN 
  DBMS_SCHEDULER.SET_ATTRIBUTE(
    name => 'MONDAY_WINDOW',
    attribute => 'DURATION',
    value => INTERVAL '2' HOUR  -- Cambiar duración a 2 horas
  );
END;
/
-- En ese periodo de tiempo, se ejecutan las tareas automáticas (auto stats gathering entre ellas)
-- Las que de tiempo a ejecutarse. Si una tarea no da tiempo a ejecutarse, se deja para la siguiente ventana de mantenimiento.

-- Temporalmente puedo desactivar ventanas de mantenimiento:
BEGIN
    DBMS_SCHEDULER.DISABLE('MONDAY_WINDOW');
END;
/
-- Reactivarlo más adelante
BEGIN
    DBMS_SCHEDULER.ENABLE('MONDAY_WINDOW');
END;
/
-- Esto no implica que todas las estadísticas de todas las tablas se vayan a regenerar automáticamente en cada ventana de mantenimiento.
-- Aquí, la tarea de auto stats gathering, decide qué tablas necesitan actualización de estadísticas basándose en el porcentaje de cambios en los datos desde la última recopilación de estadísticas.
-- ^^^ ESTO ES LO GENIAL que no me dan los jobs.
-- Hay una preferencia que podemos establecer adicional en las estadísticas de la tabla: 
-- STALE_PERCENT= Porcentaje de filas modificadas (INSERT/UPDATE/DELETE) desde la última vez que se generaron estadísticas.
-- Si el porcentaje de filas modificadas supera este valor, la tarea automática considerará que las estadísticas están obsoletas 
-- y las regenerará en la siguiente ventana de mantenimiento (si da tiempo.. si no se deja para la siguiente)

BEGIN
  DBMS_STATS.SET_TABLE_PREFS(
    ownname => 'PROFESOR',
    tabname => 'CURSOS',
    pname => 'STALE_PERCENT',
    pvalue => '5'  -- Si más del 5% de las filas han cambiado, las estadísticas se consideran obsoletas
  );
END;
/
-- por defecto es 10%

SELECT * FROM DBA_TAB_STATISTICS WHERE TABLE_NAME = 'CURSOS' AND OWNER = 'PROFESOR';