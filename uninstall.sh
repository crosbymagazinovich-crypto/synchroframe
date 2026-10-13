#!/usr/bin/env bash
# SYNCHROFRAME M/07 — undo only changes created by install.sh.
set -euo pipefail
umask 077
PURGE=0
if [[ "${1:-}" == '--purge' && $# -eq 1 ]]; then
  PURGE=1
elif (( $# != 0 )); then
  printf 'Использование: bash uninstall.sh [--purge]\n' >&2
  exit 2
fi
APP_DIR="$HOME/.local/share/synchroframe"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/synchroframe"
BEGIN='# >>> SYNCHROFRAME M07 (managed by install.sh) >>>'
END='# <<< SYNCHROFRAME M07 (managed by install.sh) <<<'
fail() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
[[ "$SOURCE_DIR" == "$APP_DIR" ]] || fail "Удаление допускается только из $APP_DIR"
[[ -f "$STATE_DIR/zshrc.path" && -f "$STATE_DIR/zshrc.existed" ]] || fail 'Не найдена запись об установке. Ничего не удалено.'
IFS= read -r RC < "$STATE_DIR/zshrc.path"
[[ -n "$RC" && "$RC" == /* ]] || fail 'Некорректный путь .zshrc в записи об установке.'
[[ ! -L "$RC" ]] || fail "$RC стал символьной ссылкой; автоматическое удаление остановлено."
[[ ! -e "$RC" || -f "$RC" ]] || fail "$RC не обычный файл."
[[ -f "$RC" ]] || fail 'Исходный .zshrc не найден; автоматическое удаление остановлено.'

has_begin=0 has_end=0
if grep -Fqx "$BEGIN" "$RC"; then has_begin=1; fi
if grep -Fqx "$END" "$RC"; then has_end=1; fi
[[ "$has_begin" == "$has_end" ]] || fail 'В .zshrc найден только один маркер; автоматическое удаление остановлено.'

if [[ -f "$STATE_DIR/zshrc.after-install" ]] && cmp -s -- "$RC" "$STATE_DIR/zshrc.after-install"; then
  if [[ "$(cat "$STATE_DIR/zshrc.existed")" == 'no' ]]; then
    rm -f -- "$RC"
  else
    [[ -f "$STATE_DIR/zshrc.before-install" ]] || fail 'Отсутствует резервная копия; ничего не удалено.'
    cp -p -- "$STATE_DIR/zshrc.before-install" "$RC"
  fi
elif (( has_begin )); then
  # Preserve user changes since installation; remove ONLY a unique marked span.
  [[ "$(grep -Fxc "$BEGIN" "$RC")" == 1 && "$(grep -Fxc "$END" "$RC")" == 1 ]] || fail 'В .zshrc повторяются маркеры; ничего не удалено.'
  TMP="$(mktemp "${RC}.synchroframe.XXXXXXXX")"
  trap 'rm -f -- "$TMP"' EXIT
  awk -v begin="$BEGIN" -v end="$END" '
    $0 == begin { inside=1; next }
    $0 == end { inside=0; next }
    !inside { print }
  ' "$RC" > "$TMP"
  chmod --reference="$RC" "$TMP"
  mv -f -- "$TMP" "$RC"
  trap - EXIT
elif (( ! has_end )); then
  printf 'Блок уже удалён из .zshrc; пользовательские изменения сохранены.\n'
fi

printf 'Тема отключена. Откройте новый сеанс Zsh.\n'
printf 'Резервная копия .zshrc: %s\n' "$STATE_DIR/zshrc.before-install"
rm -f -- "$STATE_DIR/zshrc.after-install" "$STATE_DIR/zshrc.path" "$STATE_DIR/zshrc.existed"
if (( PURGE )); then
  # Never delete a checkout containing modifications, untracked, or ignored files.
  if [[ -d "$APP_DIR/.git" ]] && command -v git >/dev/null 2>&1 && \
     [[ -z "$(git -C "$APP_DIR" status --porcelain --untracked-files=all --ignored)" ]]; then
    cd -- "$HOME"
    rm -rf -- "$APP_DIR"
    printf 'Чистый Git-клон удалён: %s\n' "$APP_DIR"
  else
    printf 'Файлы оставлены: репозиторий не является чистым Git-клоном.\n' >&2
    printf 'Проверьте свои изменения и затем удалите вручную: %s\n' "$APP_DIR"
  fi
else
  printf 'Файлы проекта оставлены: %s (для чистого Git-клона доступен --purge).\n' "$APP_DIR"
fi
