
DROP TABLE palabras PURGE;
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

-- Ver el collate de la base de datos
SELECT * FROM NLS_DATABASE_PARAMETERS WHERE PARAMETER = 'NLS_COMP'; -- binary
SELECT * FROM NLS_DATABASE_PARAMETERS WHERE PARAMETER = 'NLS_SORT'; -- BINARY

-- Ver el collate de la sesión
SELECT * FROM NLS_SESSION_PARAMETERS WHERE PARAMETER = 'NLS_COMP'; -- binary
SELECT * FROM NLS_SESSION_PARAMETERS WHERE PARAMETER = 'NLS_SORT'; -- Spanish
-- Por el idioma que tenemos configurado en el vscode

-- Para cambiarlo a nivel de sesión
ALTER SESSION SET NLS_COMP = BINARY;
ALTER SESSION SET NLS_SORT = BINARY_CI;

SELECT palabra FROM palabras ORDER BY palabra;

SELECT palabra FROM palabras WHERE palabra = 'Camion';
-- Nos saca 1 fila

ALTER SESSION SET NLS_COMP = LINGUISTIC;
ALTER SESSION SET NLS_SORT = XSPANISH_AI;
SELECT palabra FROM palabras WHERE palabra = 'Camion';

-- Ver las colaciones installadas
SELECT * FROM v$NLS_VALID_VALUES ;
-- En este caso, en la instalación que tenemos no vienen instaladas colaciones de comparación insensibles a mayúsculas/minúsculas

-- Podría cambiar la colación a nivel de consulta
SELECT palabra FROM palabras ORDER BY palabra ;
SELECT palabra FROM palabras ORDER BY palabra COLLATE BINARY;


-- Modificamos la tabla palabras para que la columna palabra tenga la colación SPANISH

ALTER TABLE palabras MODIFY palabra VARCHAR2(100) COLLATE XSPANISH_AI;

CREATE INDEX ix_palabras_ai
ON palabras (palabra);

SELECT * FROM palabras WHERE palabra = 'Camion';

