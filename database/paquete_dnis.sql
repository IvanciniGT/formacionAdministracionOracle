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

