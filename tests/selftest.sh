#!/usr/bin/env bash
# Integration tests for installer/uninstaller in isolated HOME. The zsh shim
# simulates the executable gate where Zsh is unavailable in a build container.
set -euo pipefail
PROJECT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT/bin"
cat > "$TMP_ROOT/bin/zsh" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == -n && -s "$2" ]] || exit 9
MOCK
chmod +x "$TMP_ROOT/bin/zsh"
export PATH="$TMP_ROOT/bin:$PATH"

case_dir() {
  export HOME="$TMP_ROOT/$1"
  unset ZDOTDIR XDG_STATE_HOME XDG_CONFIG_HOME || true
  mkdir -p -- "$HOME/.local/share"
  cp -a -- "$PROJECT" "$HOME/.local/share/synchroframe"
}
check() { [[ "$1" ]] || { echo "FAILED: $2" >&2; exit 1; }; }

case_dir original
printf 'PROMPT=old\n# untouched\n' > "$HOME/.zshrc"
cp -- "$HOME/.zshrc" "$TMP_ROOT/original-zshrc"
bash "$HOME/.local/share/synchroframe/install.sh" >/dev/null
bash "$HOME/.local/share/synchroframe/install.sh" | grep -q 'уже подключён'
bash "$HOME/.local/share/synchroframe/uninstall.sh" >/dev/null
cmp -s -- "$HOME/.zshrc" "$TMP_ROOT/original-zshrc"
echo 'PASS original config exact restore'

case_dir modified
printf 'PROMPT=old\n' > "$HOME/.zshrc"
bash "$HOME/.local/share/synchroframe/install.sh" >/dev/null
printf 'export ADDED=1\n' >> "$HOME/.zshrc"
bash "$HOME/.local/share/synchroframe/uninstall.sh" >/dev/null
grep -q '^PROMPT=old$' "$HOME/.zshrc"
grep -q '^export ADDED=1$' "$HOME/.zshrc"
! grep -q 'managed by install.sh' "$HOME/.zshrc"
echo 'PASS modified config selective removal'

case_dir missing
bash "$HOME/.local/share/synchroframe/install.sh" >/dev/null
bash "$HOME/.local/share/synchroframe/uninstall.sh" >/dev/null
[[ ! -e "$HOME/.zshrc" ]]
echo 'PASS initial missing config removal'

case_dir symlink
printf 'unchanged\n' > "$HOME/target"
ln -s "$HOME/target" "$HOME/.zshrc"
if bash "$HOME/.local/share/synchroframe/install.sh" >"$TMP_ROOT/symlink-log" 2>&1; then
  echo 'FAIL: installer accepted symlink' >&2; exit 1
fi
[[ $(cat "$HOME/target") == unchanged ]]
echo 'PASS symlink protection'

case_dir gitpurge
printf 'PROMPT=old\n' > "$HOME/.zshrc"
git -C "$HOME/.local/share/synchroframe" init -q
git -C "$HOME/.local/share/synchroframe" add .
git -C "$HOME/.local/share/synchroframe" -c user.name=Test -c user.email=test@example.invalid commit -qm init
bash "$HOME/.local/share/synchroframe/install.sh" >/dev/null
bash "$HOME/.local/share/synchroframe/uninstall.sh" --purge >/dev/null
[[ ! -e "$HOME/.local/share/synchroframe" ]]
echo 'PASS clean git checkout purge'

case_dir dirtypurge
printf 'PROMPT=old\n' > "$HOME/.zshrc"
git -C "$HOME/.local/share/synchroframe" init -q
git -C "$HOME/.local/share/synchroframe" add .
git -C "$HOME/.local/share/synchroframe" -c user.name=Test -c user.email=test@example.invalid commit -qm init
bash "$HOME/.local/share/synchroframe/install.sh" >/dev/null
printf 'local\n' >> "$HOME/.local/share/synchroframe/README.md"
bash "$HOME/.local/share/synchroframe/uninstall.sh" --purge >/dev/null 2>&1
[[ -d "$HOME/.local/share/synchroframe" ]]
echo 'PASS dirty git checkout preserved'
