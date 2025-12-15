import os
import sys
import random
import datetime as dt

import oracledb
from faker import Faker

# -----------------------------------------------------------------------------
# ENV + conexión
# -----------------------------------------------------------------------------
def env(name: str, default: str | None = None) -> str:
    v = os.getenv(name, default)
    if v is None or v == "":
        print(f"Falta variable de entorno: {name}")
        sys.exit(1)
    return v

ORA_USER = env("ORA_USER")
ORA_PASSWORD = env("ORA_PASSWORD")
ORA_DSN = env("ORA_DSN")

# opcional: thick mode con Instant Client
ORA_THICK = os.getenv("ORA_THICK", "0")
if ORA_THICK == "1":
    lib_dir = env("ORACLE_CLIENT_LIB_DIR")
    oracledb.init_oracle_client(lib_dir=lib_dir)

# -----------------------------------------------------------------------------
# Volúmenes objetivo (incremental: si hay menos, añade hasta llegar)
# -----------------------------------------------------------------------------
NUM_TIPOS_CURSOS = 6
NUM_CURSOS = 2000
NUM_PROFESORES = 800
NUM_EMPRESAS = 4000
NUM_ALUMNOS = 30000
NUM_CONVOCATORIAS = 20000
NUM_MATRICULAS = 120000

PCT_MATRICULAS_EMPRESA = 0.35
PCT_EVALUADAS = 0.70
BATCH_SIZE = 1000

fake = Faker("es_ES")

# -----------------------------------------------------------------------------
# Conexión
# -----------------------------------------------------------------------------
try:
    conn = oracledb.connect(user=ORA_USER, password=ORA_PASSWORD, dsn=ORA_DSN)
    conn.autocommit = False
    cur = conn.cursor()
    print("Conexión a la base de datos exitosa")
except Exception as e:
    print(f"Error al conectar: {e}")
    sys.exit(1)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
def table_count(table_name: str) -> int:
    cur.execute(f"SELECT COUNT(*) FROM {table_name}")
    return int(cur.fetchone()[0])

def fetch_ids(sql: str, params=None) -> list[int]:
    cur.execute(sql, params or {})
    return [r[0] for r in cur.fetchall()]

def execute_many(sql: str, rows: list[tuple]):
    if not rows:
        return 0
    try:
        cur.executemany(sql, rows)
        return cur.rowcount if cur.rowcount is not None else 0
    except Exception as e:
        print(f"Error ejecutando batch: {e}")
        conn.rollback()
        raise

def commit(msg: str):
    conn.commit()
    print(msg)

def unique_code(prefix: str, used: set[str], length: int = 8) -> str:
    while True:
        tail = "".join(random.choice("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") for _ in range(length))
        code = f"{prefix}_{tail}"
        if code not in used:
            used.add(code)
            return code

def dni_valido() -> str:
    letras = "TRWAGMYFPDXBNJZSQVHLCKE"
    num = random.randint(1, 99999999)
    letra = letras[num % 23]
    return f"{num:08d}{letra}"

def run_step_target(table: str, target: int, fn, *args, **kwargs):
    current = table_count(table)
    if current >= target:
        print(f"{table}: {current}/{target} (OK) -> salto {fn.__name__}()")
        return
    missing = target - current
    print(f"{table}: {current}/{target} -> insertando +{missing} ({fn.__name__})")
    fn(missing, *args, **kwargs)

# -----------------------------------------------------------------------------
# Estados (idempotentes, MERGE)
# -----------------------------------------------------------------------------
def ensure_estados_convocatoria():
    sql = """
    MERGE INTO Estados_Convocatoria t
    USING (SELECT :1 CODIGO, :2 NOMBRE FROM dual) s
    ON (t.CODIGO = s.CODIGO)
    WHEN NOT MATCHED THEN
      INSERT (CODIGO, NOMBRE) VALUES (s.CODIGO, s.NOMBRE)
    """
    data = [
        ("ABIERTA", "Abierta"),
        ("CERRADA", "Cerrada"),
        ("IMPARTIENDOSE", "Impartiéndose"),
        ("CANCELADA", "Cancelada"),
        ("FINALIZADA", "Finalizada"),
    ]
    for row in data:
        cur.execute(sql, row)
    commit("Estados_Convocatoria cargados/verificados.")

def ensure_estados_matricula():
    sql = """
    MERGE INTO Estados_Matricula t
    USING (SELECT :1 CODIGO, :2 NOMBRE FROM dual) s
    ON (t.CODIGO = s.CODIGO)
    WHEN NOT MATCHED THEN
      INSERT (CODIGO, NOMBRE) VALUES (s.CODIGO, s.NOMBRE)
    """
    data = [
        ("RESERVADA", "Reservada"),
        ("PENDIENTE", "Pendiente"),
        ("CONFIRMADA", "Confirmada"),
        ("PAGADA", "Pagada"),
        ("CANCELADA", "Cancelada"),
        ("DEVUELTA", "Devuelta"),
    ]
    for row in data:
        cur.execute(sql, row)
    commit("Estados_Matricula cargados/verificados.")

# -----------------------------------------------------------------------------
# Inserts
# -----------------------------------------------------------------------------
def insert_tipos_cursos(_n_ignored: int | None = None):
    data = [
        ("PRESENCIAL", "Presencial", "Formación en aula."),
        ("ONLINE", "Online", "Formación en remoto."),
        ("HIBRIDO", "Híbrido", "Parte presencial y parte online."),
        ("INCOMPANY", "In-company", "En las instalaciones del cliente."),
        ("TALLER", "Taller", "Formato práctico intensivo."),
        ("BOOTCAMP", "Bootcamp", "Programa intensivo."),
    ]
    sql = """
    MERGE INTO Tipos_Cursos t
    USING (SELECT :1 CODIGO, :2 NOMBRE, :3 DESCRIPCION FROM dual) s
    ON (t.CODIGO = s.CODIGO)
    WHEN NOT MATCHED THEN
      INSERT (CODIGO, NOMBRE, DESCRIPCION) VALUES (s.CODIGO, s.NOMBRE, s.DESCRIPCION)
    """
    for row in data[:NUM_TIPOS_CURSOS]:
        cur.execute(sql, row)
    commit("Tipos_Cursos cargados/verificados.")

def insert_cursos(n: int):
    tipo_ids = fetch_ids("SELECT id FROM Tipos_Cursos ORDER BY id")

    cur.execute("SELECT CODIGO FROM Cursos")
    used_codes = {r[0] for r in cur.fetchall()}

    rows = []
    for _ in range(n):
        codigo = unique_code("CUR", used_codes, 10)
        nombre = fake.sentence(nb_words=5).rstrip(".")
        duracion = random.choice([8, 12, 16, 20, 24, 30, 40, 60])
        tipo = random.choice(tipo_ids)

        p_emp = round(random.uniform(300, 2500), 2)
        p_part = round(p_emp * random.uniform(0.6, 0.9), 2)

        temario = "\n".join(fake.sentences(nb=random.randint(5, 12)))
        objetivos = " ".join(fake.sentences(nb=3))
        requisitos = " ".join(fake.sentences(nb=2))
        orientado = " ".join(fake.sentences(nb=2))

        rows.append((codigo, nombre, duracion, tipo, p_emp, p_part, temario, objetivos, requisitos, orientado))

        if len(rows) >= BATCH_SIZE:
            execute_many("""
                INSERT INTO Cursos
                (CODIGO, NOMBRE, DURACION, TIPO, PRECIO_PARA_EMPRESAS, PRECIO_PARA_PARTICULARES,
                 TEMARIO, OBJETIVOS, REQUISITOS, ORIENTADO_A)
                VALUES (:1,:2,:3,:4,:5,:6,:7,:8,:9,:10)
            """, rows)
            conn.commit()
            rows.clear()

    execute_many("""
        INSERT INTO Cursos
        (CODIGO, NOMBRE, DURACION, TIPO, PRECIO_PARA_EMPRESAS, PRECIO_PARA_PARTICULARES,
         TEMARIO, OBJETIVOS, REQUISITOS, ORIENTADO_A)
        VALUES (:1,:2,:3,:4,:5,:6,:7,:8,:9,:10)
    """, rows)
    commit(f"+{n} cursos insertados.")

def insert_profesores(n: int):
    cur.execute("SELECT DNI FROM Profesores")
    used_dni = {r[0] for r in cur.fetchall()}

    rows = []
    for _ in range(n):
        nombre = fake.first_name()
        apellidos = f"{fake.last_name()} {fake.last_name()}"

        dni = dni_valido()
        while dni in used_dni:
            dni = dni_valido()
        used_dni.add(dni)

        rows.append((nombre, apellidos, dni))

        if len(rows) >= BATCH_SIZE:
            execute_many("INSERT INTO Profesores (NOMBRE, APELLIDOS, DNI) VALUES (:1,:2,:3)", rows)
            conn.commit()
            rows.clear()

    execute_many("INSERT INTO Profesores (NOMBRE, APELLIDOS, DNI) VALUES (:1,:2,:3)", rows)
    commit(f"+{n} profesores insertados.")

def insert_empresas(n: int):
    cur.execute("SELECT CIF FROM Empresas")
    used_cif = {r[0] for r in cur.fetchall()}

    rows = []
    for _ in range(n):
        nombre = fake.company()
        cif = fake.bothify(text="?#?######?").upper()
        cif = "".join(ch if ch != "?" else random.choice("ABCDEFGHJNPQRSUVW") for ch in cif)
        while cif in used_cif:
            cif = fake.bothify(text="?#?######?").upper()
            cif = "".join(ch if ch != "?" else random.choice("ABCDEFGHJNPQRSUVW") for ch in cif)
        used_cif.add(cif)

        direccion = fake.address().replace("\n", ", ")
        email = fake.company_email()
        rows.append((nombre, cif, direccion, email))

        if len(rows) >= BATCH_SIZE:
            execute_many("INSERT INTO Empresas (NOMBRE, CIF, DIRECCION, EMAIL) VALUES (:1,:2,:3,:4)", rows)
            conn.commit()
            rows.clear()

    execute_many("INSERT INTO Empresas (NOMBRE, CIF, DIRECCION, EMAIL) VALUES (:1,:2,:3,:4)", rows)
    commit(f"+{n} empresas insertadas.")

def insert_alumnos(n: int):
    cur.execute("SELECT DNI FROM Alumnos")
    used_dni = {r[0] for r in cur.fetchall()}
    cur.execute("SELECT EMAIL FROM Alumnos")
    used_email = {r[0] for r in cur.fetchall()}

    rows = []
    for _ in range(n):
        nombre = fake.first_name()
        apellidos = f"{fake.last_name()} {fake.last_name()}"

        dni = dni_valido()
        while dni in used_dni:
            dni = dni_valido()
        used_dni.add(dni)

        email = fake.email()
        while email in used_email:
            email = fake.email()
        used_email.add(email)

        rows.append((nombre, apellidos, dni, email))

        if len(rows) >= BATCH_SIZE:
            execute_many("INSERT INTO Alumnos (NOMBRE, APELLIDOS, DNI, EMAIL) VALUES (:1,:2,:3,:4)", rows)
            conn.commit()
            rows.clear()

    execute_many("INSERT INTO Alumnos (NOMBRE, APELLIDOS, DNI, EMAIL) VALUES (:1,:2,:3,:4)", rows)
    commit(f"+{n} alumnos insertados.")

def insert_convocatorias(n: int):
    curso_ids = fetch_ids("SELECT id FROM Cursos")
    estado_ids = fetch_ids("SELECT id FROM Estados_Convocatoria")
    if not estado_ids:
        raise RuntimeError("Estados_Convocatoria está vacío. Ejecuta ensure_estados_convocatoria().")

    rows = []
    for _ in range(n):
        curso_id = random.choice(curso_ids)
        estado_id = random.choice(estado_ids)

        inicio = fake.date_between(start_date="-365d", end_date="+60d")
        fin = inicio + dt.timedelta(days=random.randint(1, 10))

        rows.append((curso_id, inicio, fin, estado_id))

        if len(rows) >= BATCH_SIZE:
            execute_many("""
                INSERT INTO Convocatorias (CURSO_ID, FECHA_INICIO, FECHA_FIN, ESTADO_ID)
                VALUES (:1,:2,:3,:4)
            """, rows)
            conn.commit()
            rows.clear()

    execute_many("""
        INSERT INTO Convocatorias (CURSO_ID, FECHA_INICIO, FECHA_FIN, ESTADO_ID)
        VALUES (:1,:2,:3,:4)
    """, rows)
    commit(f"+{n} convocatorias insertadas.")

# -----------------------------------------------------------------------------
# FIX CLAVE: Matriculas incremental sin violar UNIQUE_MATRICULAS
# -----------------------------------------------------------------------------
def insert_matriculas(n: int):
    alumno_ids = fetch_ids("SELECT id FROM Alumnos")
    convocatoria_ids = fetch_ids("SELECT id FROM Convocatorias")
    estado_ids = fetch_ids("SELECT id FROM Estados_Matricula")
    if not estado_ids:
        raise RuntimeError("Estados_Matricula está vacío. Ejecuta ensure_estados_matricula().")

    # alumno -> empresas asociadas (para cumplir FK compuesta)
    cur.execute("SELECT alumno_id, empresa_id FROM Alumnos_Empresas")
    ae = {}
    for a_id, e_id in cur.fetchall():
        ae.setdefault(a_id, []).append(e_id)

    # Semilla de combinaciones ya existentes (solo si hay “pocas”, para no petar RAM si crece)
    existing = set()
    existing_count = table_count("Matriculas")
    if existing_count and existing_count <= 300000:
        cur.execute("SELECT ALUMNO_ID, EMPRESA_ID, CONVOCATORIA_ID FROM Matriculas")
        for a_id, e_id, c_id in cur.fetchall():
            existing.add((int(a_id), None if e_id is None else int(e_id), int(c_id)))

    sql = """
    INSERT /*+ IGNORE_ROW_ON_DUPKEY_INDEX(MATRICULAS UNIQUE_MATRICULAS) */
    INTO Matriculas
      (ALUMNO_ID, EMPRESA_ID, CONVOCATORIA_ID, ESTADO_ID, FECHA_MATRICULA, PRECIO, DESCUENTO, PRECIO_FINAL)
    VALUES
      (:1,:2,:3,:4,:5,:6,:7,:8)
    """

    start_count = table_count("Matriculas")
    target_count = start_count + n

    # para evitar duplicados dentro de esta ejecución
    in_run = set()

    while True:
        current = table_count("Matriculas")
        remaining = target_count - current
        if remaining <= 0:
            break

        batch_goal = min(BATCH_SIZE, remaining)

        rows = []
        attempts = 0
        # generamos un poco “de más” por si descartamos duplicados
        while len(rows) < batch_goal and attempts < batch_goal * 20:
            attempts += 1

            alumno_id = random.choice(alumno_ids)
            convocatoria_id = random.choice(convocatoria_ids)
            estado_id = random.choice(estado_ids)

            empresa_id = None
            if random.random() < PCT_MATRICULAS_EMPRESA and alumno_id in ae:
                empresa_id = random.choice(ae[alumno_id])

            key = (alumno_id, empresa_id, convocatoria_id)

            # OJO: si empresa_id es None, el UNIQUE no te va a saltar normalmente,
            # pero aun así evitamos repetir para no meter basura.
            if key in in_run or key in existing:
                continue

            fecha_mat = fake.date_between(start_date="-365d", end_date="today")
            precio = round(random.uniform(100, 2500), 2)
            descuento = round(random.uniform(0, 30), 2) if empresa_id is not None else round(random.uniform(0, 10), 2)
            precio_final = round(precio * (1 - descuento / 100), 2)

            rows.append((alumno_id, empresa_id, convocatoria_id, estado_id, fecha_mat, precio, descuento, precio_final))
            in_run.add(key)

        if not rows:
            # Si por cualquier motivo no conseguimos generar, salimos para evitar bucle infinito
            print("WARN: no se pudieron generar filas nuevas para Matriculas (espacio de combinaciones agotado?)")
            break

        execute_many(sql, rows)
        conn.commit()

        # opcional: si tenemos existing en RAM, lo vamos ampliando para acelerar descartes
        if existing_count <= 300000:
            for r in rows:
                existing.add((r[0], r[1], r[2]))

        print(f"MATRICULAS: {table_count('Matriculas')}/{target_count}")

    end_count = table_count("Matriculas")
    commit(f"+{end_count - start_count} matriculas insertadas.")

# -----------------------------------------------------------------------------
# Evaluaciones incremental (solo para matrículas sin evaluación)
# -----------------------------------------------------------------------------
def insert_evaluaciones_incremental(pct: float):
    cur.execute("""
        SELECT m.id
        FROM Matriculas m
        LEFT JOIN Evaluaciones e ON e.matricula_id = m.id
        WHERE e.matricula_id IS NULL
    """)
    pendientes = [r[0] for r in cur.fetchall()]
    if not pendientes:
        print("EVALUACIONES: no hay matrículas pendientes -> OK")
        return

    random.shuffle(pendientes)
    n = int(len(pendientes) * pct)
    if n <= 0:
        print(f"EVALUACIONES: pct={pct} -> n=0 -> salto")
        return
    pendientes = pendientes[:n]

    rows = []
    for mid in pendientes:
        fecha = fake.date_between(start_date="-180d", end_date="today")
        nota = round(random.uniform(0, 10), 2)
        obs = fake.text(max_nb_chars=400).replace("\n", " ")
        rows.append((mid, fecha, nota, obs))

        if len(rows) >= BATCH_SIZE:
            execute_many("""
                INSERT INTO Evaluaciones (MATRICULA_ID, FECHA_EVALUACION, NOTA, OBSERVACIONES)
                VALUES (:1,:2,:3,:4)
            """, rows)
            conn.commit()
            rows.clear()

    execute_many("""
        INSERT INTO Evaluaciones (MATRICULA_ID, FECHA_EVALUACION, NOTA, OBSERVACIONES)
        VALUES (:1,:2,:3,:4)
    """, rows)
    commit(f"Evaluaciones añadidas: {n}")

# -----------------------------------------------------------------------------
# Main (incremental sin tocar existentes)
# -----------------------------------------------------------------------------
try:
    ensure_estados_convocatoria()
    ensure_estados_matricula()

    insert_tipos_cursos()

    run_step_target("CURSOS", NUM_CURSOS, insert_cursos)
    run_step_target("PROFESORES", NUM_PROFESORES, insert_profesores)
    run_step_target("EMPRESAS", NUM_EMPRESAS, insert_empresas)
    run_step_target("ALUMNOS", NUM_ALUMNOS, insert_alumnos)
    run_step_target("CONVOCATORIAS", NUM_CONVOCATORIAS, insert_convocatorias)
    run_step_target("MATRICULAS", NUM_MATRICULAS, insert_matriculas)

    insert_evaluaciones_incremental(PCT_EVALUADAS)

finally:
    try:
        cur.close()
        conn.close()
    except Exception:
        pass
