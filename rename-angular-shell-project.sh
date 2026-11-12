#!/bin/bash
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Uso: ./rename-angular-shell-project.sh <novo-nome> <caminho-do-repositorio>"
  exit 1
fi

NEW_NAME="$1"
TARGET_PATH="$2"
CURRENT_NAME="vyracare-app-shell"
CURRENT_NAME_UNDERSCORE="vyracare_app_shell"
NEW_NAME_UNDERSCORE=$(echo "$NEW_NAME" | tr '-' '_')

cd "$TARGET_PATH"

python <<PY
from pathlib import Path

current_name = "${CURRENT_NAME}"
current_name_underscore = "${CURRENT_NAME_UNDERSCORE}"
new_name = "${NEW_NAME}"
new_name_underscore = "${NEW_NAME_UNDERSCORE}"

skip_dirs = {".git", "node_modules", "dist", "coverage", ".angular"}
text_extensions = {
    ".ts", ".tsx", ".js", ".mjs", ".cjs", ".json", ".scss", ".css",
    ".html", ".md", ".txt", ".yml", ".yaml", ".sh", ".conf", ".env"
}

for path in Path(".").rglob("*"):
    if any(part in skip_dirs for part in path.parts):
        continue
    if not path.is_file():
        continue
    if path.suffix and path.suffix.lower() not in text_extensions:
        continue

    content = path.read_text(encoding="utf-8")
    updated = content.replace(current_name, new_name).replace(
        current_name_underscore, new_name_underscore
    )
    if updated != content:
        path.write_text(updated, encoding="utf-8")
PY

echo "Shell Angular renomeado com sucesso para ${NEW_NAME}"
