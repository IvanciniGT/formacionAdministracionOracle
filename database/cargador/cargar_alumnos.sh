#!/usr/bin/env bash
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-.venv}"
SCRIPT="${SCRIPT:-carga.py}"

PROPS_FILE="${PROPS_FILE:-conexion.properties}"

# único parámetro: N máximo (alumno1..alumnoN)
N_ALUMNO_MAX="${N_ALUMNO_MAX:-${1:-}}"
if [[ -z "${N_ALUMNO_MAX}" ]]; then
  echo "Uso: ./cargar_alumnos.sh 7"
  echo "  o:  N_ALUMNO_MAX=7 ./cargar_alumnos.sh"
  exit 1
fi

if [[ ! -f "requirements.txt" ]]; then
  echo "ERROR: no existe requirements.txt"
  exit 1
fi

if [[ ! -f "$SCRIPT" ]]; then
  echo "ERROR: no existe el script Python: $SCRIPT"
  exit 1
fi

if [[ ! -f "$PROPS_FILE" ]]; then
  echo "ERROR: no existe el archivo: $PROPS_FILE"
  exit 1
fi

# venv una sola vez
if [[ ! -d "$VENV_DIR" ]]; then
  echo ">>> Creando venv en $VENV_DIR"
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo ">>> Instalando/actualizando deps"
python -m pip install --upgrade pip
pip install -r requirements.txt

echo ">>> Cargando DSN/otros desde $PROPS_FILE"
set -a
source <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$PROPS_FILE" | sed 's/\r$//')
set +a

# Sobrescribe la password para TODOS
export ORA_PASSWORD="curso"

for i in $(seq 1 "$N_ALUMNO_MAX"); do
  export ORA_USER="alumno${i}"

  echo
  echo "================================================================================"
  echo ">>> Ejecutando $SCRIPT como ORA_USER=$ORA_USER (DSN=$ORA_DSN)"
  echo "================================================================================"

  python "$SCRIPT"
done

echo
echo ">>> OK: ejecutado para alumno1..alumno${N_ALUMNO_MAX} (password=curso)"
