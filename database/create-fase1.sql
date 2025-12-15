DROP TABLE EVALUACIONES PURGE;
DROP TABLE MATRICULAS PURGE;
DROP TABLE ALUMNOS_EMPRESAS PURGE;
DROP TABLE ALUMNOS PURGE;
DROP TABLE CONVOCATORIAS PURGE;
DROP TABLE ESTADOS_CONVOCATORIA PURGE;
DROP TABLE ESTADOS_MATRICULA PURGE;
DROP TABLE EMPRESAS_TELEFONOS PURGE;
DROP TABLE EMPRESAS PURGE;
DROP TABLE PROFESORES_CURSOS PURGE;
DROP TABLE PROFESORES PURGE;
DROP TABLE CURSOS PURGE;
DROP TABLE TIPOS_CURSOS PURGE;

------------------------------------------------------------------------------------------------
-- DNI_UTILS Package
------------------------------------------------------------------------------------------------
-- Paquete de utilidades para la validación y normalización de DNIs españoles.
--
-- Formato DNI: 1-8 dígitos + letra mayúscula (puntos y guiones opcionales)
--
-- Optimización de almacenamiento:
--   - VARCHAR2(9):         9 bytes (1 byte por carácter)
--   - NUMBER(8) + CHAR(1): 5 bytes (1 byte por cada 2 dígitos + 1 byte para letra)
--   Recomendación: Valorar optimización con grandes volúmenes (>10M registros)
------------------------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE dni_utils IS
    ------------------------------------------------------------------------------------------------
    -- VALIDAR_DNI
    -- Valida un DNI español y extrae sus componentes (número y letra)
    --
    -- Parámetros:
    --   dni        IN  VARCHAR2   DNI a validar
    --   valido     OUT BOOLEAN    TRUE si el DNI es válido
    --   numero     OUT NUMBER     Número del DNI (solo si es válido)
    --   letra      OUT CHAR       Letra del DNI (solo si es válido)
    -- Nota:
    --   Este procedimiento trabaja con el tipo de dato BOOLEAN, por lo que solo puede ser llamado
    --   desde PL/SQL (por ejemplo desde triggers o procedimientos almacenados).
    ------------------------------------------------------------------------------------------------
    PROCEDURE validar_dni (
        dni IN VARCHAR2,
        valido OUT BOOLEAN,
        numero OUT NUMBER,
        letra OUT CHAR
    );

    ------------------------------------------------------------------------------------------------
    -- ES_DNI_VALIDO
    -- Verifica si un DNI tiene formato y letra correctos
    --
    -- Parámetros:
    --   dni        IN  VARCHAR2   DNI a validar
    --
    -- Retorna:
    --   NUMBER     1 si es válido, 0 en caso contrario
    ------------------------------------------------------------------------------------------------
    FUNCTION es_dni_valido (
        dni IN VARCHAR2
    ) RETURN NUMBER;

    ------------------------------------------------------------------------------------------------
    -- NORMALIZAR_DNI
    -- Convierte un DNI a un formato estándar según parámetros especificados
    --
    -- Parámetros:
    --   dni                 IN VARCHAR2   DNI a normalizar
    --   rellenar_con_ceros  IN NUMBER     1=rellenar con ceros, 0=no rellenar (default: 1)
    --   separador           IN VARCHAR2   Separador número-letra: '-', ' ' o '' (default: '')
    --   letra_mayuscula     IN NUMBER     1=mayúscula, 0=minúscula (default: 1)
    --   puntos_en_numero    IN NUMBER     1=formato con puntos, 0=sin puntos (default: 0)
    --
    -- Retorna:
    --   VARCHAR2   DNI normalizado o NULL si no es válido
    ------------------------------------------------------------------------------------------------
    FUNCTION normalizar_dni (
        dni                 IN VARCHAR2,
        rellenar_con_ceros  IN NUMBER   DEFAULT 1,
        separador           IN VARCHAR2 DEFAULT '',
        letra_mayuscula     IN NUMBER   DEFAULT 1,
        puntos_en_numero    IN NUMBER   DEFAULT 0
    ) RETURN VARCHAR2;

END dni_utils;
/



------------------------------------------------------------------------------------------------
-- DNI_UTILS Package Body
------------------------------------------------------------------------------------------------
-- Implementación del paquete de utilidades para DNIs españoles
------------------------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY dni_utils IS

    ------------------------------------------------------------------------------------------------
    -- CONSTANTES PRIVADAS
    ------------------------------------------------------------------------------------------------
    letras_validas      CONSTANT VARCHAR2(23)  := 'TRWAGMYFPDXBNJZSQVHLCKE';
    patron_dni          CONSTANT VARCHAR2(100) := '^(([0-9]{1,8})|([0-9]{1,2}([.][0-9]{3}){2})|([0-9]{1,3}[.][0-9]{3}))[ -]?[A-Za-z]$';
    patron_no_numerico  CONSTANT VARCHAR2(100) := '[^0-9]';

    ------------------------------------------------------------------------------------------------
    -- VALIDAR_DNI
    -- Implementación del procedimiento de validación
    ------------------------------------------------------------------------------------------------
    PROCEDURE validar_dni (
        dni IN VARCHAR2,
        valido OUT BOOLEAN,
        numero OUT NUMBER,
        letra OUT CHAR
    )
    IS
        letra_correcta CHAR(1);
    BEGIN
        -- Inicializar valores por defecto
        valido := FALSE;
        numero := NULL;
        letra  := NULL;

        -- Validar entrada NULL
        IF dni IS NULL THEN
            RETURN;
        END IF;

        -- Validar formato mediante expresión regular
        IF NOT REGEXP_LIKE(dni, patron_dni) THEN
            RETURN;
        END IF;

        -- Extraer número (eliminando caracteres no numéricos)
        numero := TO_NUMBER(REGEXP_REPLACE(dni, patron_no_numerico, ''));

        -- Mirar si el número está en rango válido
        IF numero < 1 OR numero > 99999999 THEN
            RETURN;
        END IF;

        -- Extraer letra (último carácter en mayúsculas)
        letra := SUBSTR(dni, -1, 1);

        -- Calcular letra correcta según algoritmo DNI
        -- Índice: MOD(numero, 23) + 1 (SUBSTR inicia en 1)
        letra_correcta := SUBSTR(letras_validas, MOD(numero, 23) + 1, 1);

        -- Verificar correspondencia de la letra
        valido := (letra = letra_correcta);
    EXCEPTION
        WHEN OTHERS THEN
            -- En caso de error, marcar como inválido
            valido := FALSE;
            numero := NULL;
            letra  := NULL;
    END;

    ------------------------------------------------------------------------------------------------
    -- ES_DNI_VALIDO
    -- Wrapper de validar_dni para uso en SQL
    --
    -- Nota: SQL no soporta tipo BOOLEAN, por lo que devuelve NUMBER (1=válido, 0=inválido)
    ------------------------------------------------------------------------------------------------
    FUNCTION es_dni_valido (
        dni IN VARCHAR2
    ) RETURN NUMBER
    IS
        dni_valido BOOLEAN;
        dni_numero NUMBER(8);
        dni_letra  CHAR(1);
    BEGIN
        validar_dni(dni, dni_valido, dni_numero, dni_letra);
        
        -- Convertir BOOLEAN a NUMBER para compatibilidad SQL
        RETURN CASE 
                WHEN dni_valido THEN 1
                ELSE 0
            END;
    END;

    ------------------------------------------------------------------------------------------------
    -- NORMALIZAR_DNI
    -- Convierte DNI a formato estándar según parámetros
    --
    -- Ejemplo de uso:
    --   SELECT normalizar_dni('12345678Z', 1, '-', 1, 0) FROM DUAL;
    --   Resultado: 12345678-Z
    ------------------------------------------------------------------------------------------------
    FUNCTION normalizar_dni (
        dni                 IN VARCHAR2,
        rellenar_con_ceros  IN NUMBER   DEFAULT 1,
        separador           IN VARCHAR2 DEFAULT '',
        letra_mayuscula     IN NUMBER   DEFAULT 1,
        puntos_en_numero    IN NUMBER   DEFAULT 0
    ) RETURN VARCHAR2
    IS
        dni_valido         BOOLEAN;
        dni_numero         NUMBER(8);
        dni_letra          CHAR(1);
        letra_normalizada  CHAR(1);
        numero_normalizado VARCHAR2(11);
    BEGIN
        -- Validar DNI
        validar_dni(dni, dni_valido, dni_numero, dni_letra);
        IF NOT dni_valido THEN
            RETURN NULL;
        END IF;

        -- Normalizar número
        numero_normalizado := TO_CHAR(dni_numero);
        
        IF puntos_en_numero = 1 THEN
            -- Aplicar formato con separadores de miles
            -- Formato: 00G000G000 rellena con ceros, 99G999G999 sin relleno
            IF rellenar_con_ceros = 1 THEN
                numero_normalizado := TO_CHAR(dni_numero, '00G000G000');
            ELSE
                numero_normalizado := TO_CHAR(dni_numero, '99G999G999');
            END IF;
        ELSE 
            -- Sin puntos: rellenar con LPAD si se solicita
            IF rellenar_con_ceros = 1 THEN
                numero_normalizado := LPAD(numero_normalizado, 8, '0');
            END IF;
        END IF;

        -- Normalizar letra (mayúscula/minúscula)
        -- Uso de CASE como expresión (alternativa a IF/THEN/ELSE como statement)
        letra_normalizada := CASE 
                                WHEN letra_mayuscula = 1 THEN UPPER(dni_letra)
                                ELSE LOWER(dni_letra)
                            END;

        -- Ensamblar resultado
        RETURN numero_normalizado || separador || letra_normalizada;
    END;
END dni_utils;
/




CREATE TABLE Tipos_Cursos (
    ID                          NUMBER          GENERATED BY DEFAULT AS IDENTITY,
    CODIGO                      VARCHAR2(50)    NOT NULL,
    NOMBRE                      VARCHAR2(100)   NOT NULL,
    DESCRIPCION                 VARCHAR2(4000),
    CONSTRAINT PK_Tipos_Cursos PRIMARY      KEY (ID),
    CONSTRAINT UQ_Tipos_Cursos_Codigo       UNIQUE (CODIGO) -- Identificador público del tipo de curso
);



CREATE TABLE Cursos (
 -- NOMBRE                      TIPO            SI ADMITE NULO
    ID                          NUMBER          GENERATED BY DEFAULT AS IDENTITY,
    CODIGO                      VARCHAR2(50)    NOT NULL,
    NOMBRE                      VARCHAR2(100)   COLLATE XSPANISH_AI NOT NULL , -- sin preocuparnos de mayúsculas/minúsculas ni acentos, ya que eso son cosas que se usan en comparaciones y en nuestro no las habrá. Las búsquedas van por Oracle Text
    DURACION                    NUMBER,
    TIPO                        NUMBER,
    PRECIO_PARA_EMPRESAS        NUMBER,
    PRECIO_PARA_PARTICULARES    NUMBER,
    TEMARIO                     VARCHAR2(4000),
    OBJETIVOS                   VARCHAR2(1000),
    REQUISITOS                  VARCHAR2(1000),
    ORIENTADO_A                 VARCHAR2(1000),

 -- CONSTRAINS
    -- Primary Key. Siempre tenemos uno
    CONSTRAINT PK_Cursos PRIMARY                KEY (ID),
    -- Unique: Es nuestro ID PUBLICO
    CONSTRAINT UQ_Cursos_Codigo                 UNIQUE (CODIGO),
                                                -- Este campo, por tener ser una clave única en automático tiene un índice asociado
                                                -- Búsquedas del tipo WHERE CODIGO = 'valor' serán muy rápidas
                                                -- Búsquedas del tipo WHERE CODIGO LIKE 'valor%' serán muy rápidas
    -- Foreign Key hacia Tipos_Cursos
    CONSTRAINT FK_Cursos_Tipo FOREIGN           KEY (TIPO) REFERENCES Tipos_Cursos(ID),
    -- Restricciones al valor de los campos
                                                -- AQUI PONEMOS UNA EXPRESION QUE DEVUELVA UN BOOLEANO
                                                -- Si devuelve TRUE, se acepta el valor
                                                -- Si devuelve FALSE, se rechaza el valor
    CONSTRAINT CHK_Cursos_Duracion              CHECK (DURACION IS NULL OR DURACION > 0),
    CONSTRAINT CHK_Cursos_Precio_Empresas       CHECK (PRECIO_PARA_EMPRESAS IS NULL OR PRECIO_PARA_EMPRESAS >= 0),
    CONSTRAINT CHK_Cursos_Precio_Particulares   CHECK (PRECIO_PARA_PARTICULARES IS NULL OR PRECIO_PARA_PARTICULARES >= 0),
    CONSTRAINT CHK_Cursos_Codigo_Mayusculas     CHECK (CODIGO = UPPER(CODIGO) AND REGEXP_LIKE(CODIGO, '^[A-Z0-9_-]+$'))
) PCTFREE 15; -- Valor por defecto

-- Trigger para asegurar que el campo CODIGO siempre se almacena en mayúsculas
CREATE OR REPLACE TRIGGER TRG_Cursos_Codigo_Mayusculas
BEFORE INSERT OR UPDATE ON Cursos
FOR EACH ROW
BEGIN
    -- Solo transformamos el valor si no es NULL
    -- De esta forma evitamos que el trigger falle al intentar transformar un NULL
    -- Si es nulo, lo dejamos como está, es decir NULL
    -- Y ya la restricción NOT NULL definida en la tabla se encargará de rechazarlo si es necesario dando un mensaje adecuado al usuario

    -- En el caso de un UPDATE, si el valor no cambia, el valor :NEW.CODIGO se queda como está, no lo tocamos... y sigue funcionando bien.
    IF :NEW.CODIGO IS NOT NULL THEN 
        :NEW.CODIGO := UPPER(:NEW.CODIGO);
    END IF;
END;
/
-- Nota: El trigger se define con una barra (/) al final para indicar a SQL*Plus que ejecute el bloque PL/SQL.

-- TODO: Crear un índice invertido full text con Oracle Text para el campo NOMBRE



CREATE TABLE Profesores (
    ID                          NUMBER          GENERATED BY DEFAULT AS IDENTITY,
    NOMBRE                      VARCHAR2(50)    COLLATE XSPANISH_AI NOT NULL,
    APELLIDOS                   VARCHAR2(150)   COLLATE XSPANISH_AI NOT NULL,
    DNI                         VARCHAR2(9)     NOT NULL,

 -- CONSTRAINS
    -- Primary Key. Siempre tenemos uno
    CONSTRAINT PK_Profesores PRIMARY             KEY (ID),
    -- Unique: Es nuestro ID PUBLICO
    CONSTRAINT UQ_Profesores_DNI                 UNIQUE (DNI)
    -- Restricciones al DNI aplicadas mediante un TRIGGER
) PCTFREE 3;

CREATE OR REPLACE TRIGGER TRG_Profesores_DNI_Validar_Normalizar
BEFORE INSERT OR UPDATE ON Profesores
FOR EACH ROW
DECLARE
    dni_valido      BOOLEAN;
    dni_numero      NUMBER(8);
    dni_letra       CHAR(1);
BEGIN
    -- Si el DNI Es null, no hacemos nada, y que el propio NOT NULL de la tabla se encargue de rechazarlo
    IF :NEW.DNI IS NULL THEN
        RETURN;
    END IF;
    -- Validar el formato del DNI
    dni_utils.validar_dni(:NEW.DNI, dni_valido, dni_numero, dni_letra);
    IF NOT dni_valido THEN
        RAISE_APPLICATION_ERROR(-20001, 'DNI inválido: ' || :NEW.DNI); -- Este mensaje le saldrá al usuario si el DNI no es válido
    ELSE
        -- Si es válido, normalizar el valor del DNI
        :NEW.DNI := TO_CHAR(dni_numero) || dni_letra; -- Número sin ceros a la izquierda + letra en mayúsculas, sin puntos ni separadores
    END IF;
END;
/

CREATE TABLE Profesores_Cursos (
    PROFESOR_ID    NUMBER      NOT NULL,
    CURSO_ID       NUMBER      NOT NULL,

 -- CONSTRAINS
    CONSTRAINT PK_Profesores_Cursos PRIMARY KEY (CURSO_ID, PROFESOR_ID),
    CONSTRAINT FK_Profesores_Cursos_Profesor FOREIGN KEY (PROFESOR_ID) REFERENCES Profesores(ID),
    CONSTRAINT FK_Profesores_Cursos_Curso FOREIGN KEY (CURSO_ID) REFERENCES Cursos(ID)
) PCTFREE 0;

CREATE TABLE Empresas (
    ID              NUMBER          GENERATED BY DEFAULT AS IDENTITY,
    NOMBRE          VARCHAR2(100)   COLLATE XSPANISH_AI NOT NULL,
    CIF             VARCHAR2(20)    NOT NULL, 
    DIRECCION       VARCHAR2(2000),
    EMAIL           VARCHAR2(100), 

 -- CONSTRAINS
    CONSTRAINT PK_Empresas PRIMARY  KEY (ID),
    CONSTRAINT UQ_Empresas_CIF      UNIQUE (CIF)
);


CREATE TABLE Empresas_Telefonos (
    EMPRESA_ID     NUMBER       NOT NULL,
    TELEFONO       VARCHAR2(20) NOT NULL, 

 -- CONSTRAINS
    CONSTRAINT PK_Empresas_Telefonos PRIMARY KEY (EMPRESA_ID, TELEFONO),
    CONSTRAINT FK_Empresas_Telefonos_Empresa FOREIGN KEY (EMPRESA_ID) REFERENCES Empresas(ID) ON DELETE CASCADE
) PCTFREE 0;


CREATE TABLE Estados_Convocatoria (
    ID          NUMBER          GENERATED BY DEFAULT AS IDENTITY,
    CODIGO      VARCHAR2(20)    NOT NULL,
    NOMBRE      VARCHAR2(100)   NOT NULL,

 -- CONSTRAINS
    CONSTRAINT PK_Estados_Convocatoria PRIMARY KEY (ID),
    CONSTRAINT UQ_Estados_Convocatoria_Codigo UNIQUE (CODIGO),
    CONSTRAINT CHK_Estados_Convocatoria_Codigo_Mayusculas CHECK (REGEXP_LIKE(CODIGO, '^[A-Z0-9_-]+$'))
);


CREATE TABLE Convocatorias (
    ID             NUMBER          GENERATED BY DEFAULT AS IDENTITY,
    CODIGO         RAW(16)         DEFAULT SYS_GUID() NOT NULL,
    CURSO_ID       NUMBER          NOT NULL,
    FECHA_INICIO   DATE            NOT NULL,
    FECHA_FIN      DATE            NOT NULL,
    ESTADO_ID      NUMBER          NOT NULL,

 -- CONSTRAINS
    CONSTRAINT PK_Convocatorias PRIMARY         KEY (ID),
    CONSTRAINT UQ_Convocatorias_Codigo          UNIQUE (CODIGO),
    CONSTRAINT FK_Convocatorias_Curso FOREIGN   KEY (CURSO_ID)      REFERENCES Cursos(ID),
    CONSTRAINT FK_Convocatorias_Estado FOREIGN  KEY (ESTADO_ID)     REFERENCES Estados_Convocatoria(ID),
    CONSTRAINT CHK_Convocatorias_Fechas         CHECK (FECHA_FIN >= FECHA_INICIO)
) PCTFREE 0;

CREATE TABLE Alumnos (
    ID              NUMBER          GENERATED BY DEFAULT AS IDENTITY,
    NOMBRE          VARCHAR2(50)    COLLATE XSPANISH_AI NOT NULL,
    APELLIDOS       VARCHAR2(150)   COLLATE XSPANISH_AI NOT NULL,
    DNI             VARCHAR2(9)     NOT NULL,
    EMAIL           VARCHAR2(100)   NOT NULL,

 -- CONSTRAINS
    CONSTRAINT PK_Alumnos PRIMARY            KEY (ID),
    CONSTRAINT UQ_Alumnos_DNI                UNIQUE (DNI),
    CONSTRAINT UQ_Alumnos_EMAIL              UNIQUE (EMAIL)
    -- Restricciones al DNI aplicadas mediante un TRIGGER (el mismo que para Profesores)
    -- Restricciones al EMAIL aplicadas mediante un TRIGGER (similar al del DNI, pero con regex para emails)
) PCTFREE 5;


CREATE OR REPLACE TRIGGER TRG_Alumnos_DNI_Validar_Normalizar
BEFORE INSERT OR UPDATE ON Alumnos
FOR EACH ROW
DECLARE
    dni_valido      BOOLEAN;
    dni_numero      NUMBER(8);
    dni_letra       CHAR(1);
BEGIN
    -- Si el DNI Es null, no hacemos nada, y que el propio NOT NULL de la tabla se encargue de rechazarlo
    IF :NEW.DNI IS NULL THEN
        RETURN;
    END IF;
    -- Validar el formato del DNI
    dni_utils.validar_dni(:NEW.DNI, dni_valido, dni_numero, dni_letra);
    IF NOT dni_valido THEN
        RAISE_APPLICATION_ERROR(-20001, 'DNI inválido: ' || :NEW.DNI); -- Este mensaje le saldrá al usuario si el DNI no es válido
    ELSE
        -- Si es válido, normalizar el valor del DNI
        :NEW.DNI := TO_CHAR(dni_numero) || dni_letra; -- Número sin ceros a la izquierda + letra en mayúsculas, sin puntos ni separadores
    END IF;
END;
/

CREATE TABLE Alumnos_Empresas (
    ALUMNO_ID      NUMBER      NOT NULL,
    EMPRESA_ID     NUMBER      NOT NULL,

 -- CONSTRAINS
    CONSTRAINT PK_Alumnos_Empresas PRIMARY KEY (ALUMNO_ID, EMPRESA_ID),
    CONSTRAINT FK_Alumnos_Empresas_Alumno FOREIGN KEY (ALUMNO_ID) REFERENCES Alumnos(ID),
    CONSTRAINT FK_Alumnos_Empresas_Empresa FOREIGN KEY (EMPRESA_ID) REFERENCES Empresas(ID)
);

CREATE TABLE Estados_Matricula (
    ID          NUMBER          GENERATED BY DEFAULT AS IDENTITY,
    CODIGO      VARCHAR2(20)    NOT NULL,
    NOMBRE      VARCHAR2(100)   NOT NULL,

 -- CONSTRAINS
    CONSTRAINT PK_Estados_Matricula PRIMARY KEY (ID),
    CONSTRAINT UQ_Estados_Matricula_Codigo UNIQUE (CODIGO),
    CONSTRAINT CHK_Estados_Matricula_Codigo_Mayusculas CHECK (REGEXP_LIKE(CODIGO, '^[A-Z0-9_-]+$'))
);

-- Alumno_ID, Empresa_ID, Convocatoria_ID, Estado_ID, Fecha_Matricula, Precio, Descuento, Precio_Final
CREATE TABLE Matriculas (
    ID               NUMBER      GENERATED BY DEFAULT AS IDENTITY,
    ALUMNO_ID        NUMBER      NOT NULL,
    EMPRESA_ID       NUMBER,
    CONVOCATORIA_ID  NUMBER      NOT NULL,
    ESTADO_ID        NUMBER      NOT NULL,
    FECHA_MATRICULA  DATE        NOT NULL,
    PRECIO           NUMBER(10,2) NOT NULL,
    DESCUENTO        NUMBER(5,2)  NOT NULL,
    PRECIO_FINAL     NUMBER(10,2) NOT NULL,

 -- CONSTRAINS
    -- Primary Key compuesta por los 3 campos
    CONSTRAINT PK_Matriculas PRIMARY KEY (ID), -- Ahora haremos algún comentario
    CONSTRAINT UNIQUE_Matriculas UNIQUE (ALUMNO_ID, EMPRESA_ID, CONVOCATORIA_ID), -- Ahora haremos algún comentario
    -- Foreign Keys
    -- Convocatoria
    CONSTRAINT FK_Matriculas_Convocatoria FOREIGN KEY (CONVOCATORIA_ID) REFERENCES Convocatorias(ID),
    -- Alumnos
    CONSTRAINT FK_Matriculas_Alumno FOREIGN KEY (ALUMNO_ID) REFERENCES Alumnos(ID),
    -- Empresas
    -- CONSTRAINT FK_Matriculas_Empresa FOREIGN KEY (EMPRESA_ID) REFERENCES Empresas(ID),
    -- Error: No puedo meter cualquier empresa. Solamente empresas para las que el alumno esté asociado/registrado en Alumnos_Empresas
    -- ESTA ES LA OPCIÓN BUENA:
    CONSTRAINT FK_Matriculas_Empresa FOREIGN KEY (ALUMNO_ID, EMPRESA_ID) 
        REFERENCES Alumnos_Empresas(ALUMNO_ID, EMPRESA_ID),
    -- El tratamiento que hace la BBDD cuando un campo FK es NULL es no aplicar la restricción
    -- Estado
    CONSTRAINT FK_Matriculas_Estado FOREIGN KEY (ESTADO_ID) REFERENCES Estados_Matricula(ID),
    -- CONTRAINS SOBRE LOS RANGOS DE LOS DATOS:
    CONSTRAINT CHK_Matriculas_Precio_Positive CHECK (PRECIO >= 0),
    CONSTRAINT CHK_Matriculas_Descuento_Range CHECK (DESCUENTO >= 0 AND DESCUENTO <= 100),
    CONSTRAINT CHK_Matriculas_Precio_Final_Positive CHECK (PRECIO_FINAL >= 0)
) PCTFREE 5;


CREATE INDEX IX_Matriculas_Convocatoria_Alumno ON Matriculas(CONVOCATORIA_ID, ALUMNO_ID);

CREATE TABLE Evaluaciones (
    MATRICULA_ID     NUMBER      NOT NULL,
    FECHA_EVALUACION DATE        NOT NULL,
    NOTA             NUMBER(5,2) NOT NULL,
    OBSERVACIONES    VARCHAR2(2000),

 -- CONSTRAINS
    CONSTRAINT PK_Evaluaciones PRIMARY KEY (MATRICULA_ID),
    CONSTRAINT FK_Evaluaciones_Matricula FOREIGN KEY (MATRICULA_ID) REFERENCES Matriculas(ID),
    CONSTRAINT CHK_Evaluaciones_Nota_Range CHECK (NOTA >= 0 AND NOTA <= 10)
);
