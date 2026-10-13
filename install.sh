#!/usr/bin/env bash
# SYNCHROFRAME M/07 — per-user installer, no sudo required.
set -euo pipefail
umask 077

APP_DIR="$HOME/.local/share/synchroframe"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
RC_DIR="${ZDOTDIR:-$HOME}"
RC="$RC_DIR/.zshrc"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/synchroframe"
BEGIN='# >>> SYNCHROFRAME M07 (managed by install.sh) >>>'
END='# <<< SYNCHROFRAME M07 (managed by install.sh) <<<'

fail() { printf 'Ошибка: %s\n' "$*" >&2; exit 1; }
[[ -n "${HOME:-}" && "$HOME" == /* ]] || fail 'HOME должен быть абсолютным путём.'
[[ "$SOURCE_DIR" == "$APP_DIR" ]] || fail "Сначала разместите репозиторий в $APP_DIR. Текущий каталог: $SOURCE_DIR"
command -v zsh >/dev/null 2>&1 || fail 'Не установлен zsh.'
[[ -f "$APP_DIR/theme/mecha.zsh" ]] || fail 'Нет theme/mecha.zsh.'
zsh -n "$APP_DIR/theme/mecha.zsh" || fail 'Ошибка синтаксиса в theme/mecha.zsh; .zshrc не изменён.'
[[ ! -L "$RC" ]] || fail "$RC — символьная ссылка. Настройте подключение вручную или используйте обычный .zshrc."
[[ ! -e "$RC" || -f "$RC" ]] || fail "$RC существует, но не является обычным файлом."
[[ -d "$RC_DIR" ]] || fail "Не найден каталог Zsh $RC_DIR (при необходимости передайте ZDOTDIR)."

if [[ -f "$RC" ]] && { grep -Fqx "$BEGIN" "$RC" || grep -Fqx "$END" "$RC"; }; then
  if grep -Fqx "$BEGIN" "$RC" && grep -Fqx "$END" "$RC" && [[ -f "$STATE_DIR/zshrc.after-install" ]]; then
    printf 'SYNCHROFRAME уже подключён в %s.\n' "$RC"
    exit 0
  fi
  fail 'Найден неполный или неуправляемый блок SYNCHROFRAME в .zshrc. Нужна ручная проверка.'
fi
[[ ! -e "$STATE_DIR/zshrc.after-install" ]] || fail "Найдены данные предыдущей установки в $STATE_DIR. Сначала проверьте состояние."

mkdir -p -- "$STATE_DIR"
chmod 700 -- "$STATE_DIR"
if [[ -f "$RC" ]]; then
  cp -p -- "$RC" "$STATE_DIR/zshrc.before-install"
  printf 'yes\n' > "$STATE_DIR/zshrc.existed"
else
  printf 'no\n' > "$STATE_DIR/zshrc.existed"
  : > "$RC"
  chmod 600 -- "$RC"
fi
printf '%s\n' "$RC" > "$STATE_DIR/zshrc.path"
cat >> "$RC" <<'ZSHRC'

# >>> SYNCHROFRAME M07 (managed by install.sh) >>>
if [[ -r "$HOME/.local/share/synchroframe/theme/mecha.zsh" ]]; then
  MECHA_AUTOSTART=1
  MECHA_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/synchroframe"
  MECHA_ENGINE_PATH="$HOME/.local/share/synchroframe/theme/mecha.zsh"
  source "$MECHA_ENGINE_PATH"
fi
# <<< SYNCHROFRAME M07 (managed by install.sh) <<<
ZSHRC
cp -p -- "$RC" "$STATE_DIR/zshrc.after-install"
printf 'Установлено в %s\n' "$RC"
printf 'Резервная копия: %s\n' "$STATE_DIR/zshrc.before-install"
printf 'Откройте новый сеанс Zsh. Управление: mecha help\n'
if [[ -f "$RC" ]] && grep -Fq '/usr/local/share/mecha-synchroframe/mecha.zsh' "$RC"; then
  printf 'ВНИМАНИЕ: .zshrc также содержит старое системное подключение MECHA.\n' >&2
  printf 'Оно может загружаться раньше нового; удалите только старую строку source после проверки.\n' >&2
fi
