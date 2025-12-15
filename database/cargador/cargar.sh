#!/usr/bin/env bash
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${VENV_DIR:-.venv}"
SCRIPT="${1:-carga.py}"
PROPS_FILE="${PROPS_FILE:-conexion.properties}"

if [[ ! -f "requirements.txt" ]]; then
  echo "ERROR: no existe requirements.txt en el directorio actual"
  exit 1
fi

if [[ ! -f "$SCRIPT" ]]; then
  echo "ERROR: no existe el script Python: $SCRIPT"
  exit 1
fi

if [[ ! -f "$PROPS_FILE" ]]; then
  echo "ERROR: no existe el archivo de propiedades: $PROPS_FILE"
  exit 1
fi

echo ">>> Creando venv en $VENV_DIR"
"$PYTHON_BIN" -m venv "$VENV_DIR"

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo ">>> Actualizando pip"
python -m pip install --upgrade pip

echo ">>> Instalando dependencias"
pip install -r requirements.txt

echo ">>> Cargando variables de entorno desde $PROPS_FILE"
set -a
# solo líneas KEY=VALUE, ignora comentarios y vacío, y quita CRLF si lo hubiera
source <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$PROPS_FILE" | sed 's/\r$//')
set +a

echo ">>> Ejecutando $SCRIPT"
python "$SCRIPT"

echo ">>> OK"
