#!/usr/bin/env bash
set -euo pipefail
APP_DIR="$HOME/.local/share/synchroframe"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[[ "$SOURCE_DIR" == "$APP_DIR" ]] || { printf 'Запускайте из %s\n' "$APP_DIR" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { printf 'git не установлен\n' >&2; exit 1; }
[[ -d "$APP_DIR/.git" ]] || { printf 'Это не Git-клон. Для обновления загрузите новый архив вручную.\n' >&2; exit 1; }
[[ -z "$(git -C "$APP_DIR" status --porcelain)" ]] || { printf 'Есть несохранённые правки. Сначала commit/stash; обновление отменено.\n' >&2; exit 1; }
git -C "$APP_DIR" pull --ff-only
command -v zsh >/dev/null 2>&1 && zsh -n "$APP_DIR/theme/mecha.zsh"
printf 'Обновление завершено. Перезапустите Zsh.\n'
