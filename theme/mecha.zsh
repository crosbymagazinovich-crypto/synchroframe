# MECHA / SYNCHROFRAME — Zsh prompt overlay for NOCTIS + NLINE.
# shellcheck shell=zsh
[[ -n ${ZSH_VERSION:-} && -o interactive ]] || return 0
[[ -n ${__MECHA_LOADED:-} ]] && return 0
typeset -g __MECHA_LOADED=1

# Color palette. All visible control codes are Zsh prompt escapes.
typeset -gr __M_HOT='%F{#FF455F}' __M_SAFE='%F{#58E6A1}' __M_ICE='%F{#76D5E6}'
typeset -gr __M_TEXT='%F{#E5EDF7}' __M_DIM='%F{#8495AB}'
typeset -gr __M_OK='%F{#9BD8BD}' __M_WARN='%F{#FFB18F}'
typeset -gr __M_RESET='%f%b'

autoload -Uz add-zsh-hook
zmodload zsh/datetime 2>/dev/null || true

__mecha_safe() {
  # Treat git/venv strings as untrusted data even with PROMPT_SUBST enabled.
  local m_text="$1"
  m_text=${m_text//$'\033'/}
  m_text=${m_text//$'\007'/}
  m_text=${m_text//$'\r'/ }
  m_text=${m_text//$'\n'/ }
  m_text=${m_text//$'\t'/ }
  m_text=${m_text//\\/／}
  m_text=${m_text//\$/＄}
  m_text=${m_text//\`/＇}
  m_text=${m_text//\%/%%}
  REPLY="${m_text[1,25]}"
}

__mecha_git() {
  REPLY=''
  (( $+commands[git] )) || return 0
  local m_ref='' m_mark=''
  m_ref=$(command git symbolic-ref -q --short HEAD 2>/dev/null) || \
    m_ref=$(command git rev-parse --short HEAD 2>/dev/null) || return 0
  __mecha_safe "$m_ref"
  m_ref=$REPLY
  if [[ ${MECHA_GIT_DIRTY:-1} == 1 ]]; then
    # Only tracked-file changes are checked; no untracked-file directory walk.
    if ! command git diff --no-ext-diff --quiet --ignore-submodules -- 2>/dev/null || \
       ! command git diff --no-ext-diff --cached --quiet --ignore-submodules -- 2>/dev/null; then
      m_mark='*'
    fi
  fi
  REPLY="${m_ref}${m_mark}"
}

__mecha_clock_now() {
  if (( ${+parameters[EPOCHSECONDS]} )); then
    REPLY=$EPOCHSECONDS
  else
    REPLY=$SECONDS
  fi
}

__mecha_title() {
  [[ ${MECHA_TITLE:-0} == 1 && -t 1 && -n ${KONSOLE_VERSION:-}${KONSOLE_DBUS_SERVICE:-} ]] || return 0
  # Constant title, no terminal escape injection from user data.
  printf '\033]0;M07 // %s\007' "$1"
}

__mecha_preexec() {
  __mecha_clock_now
  typeset -g __MECHA_START="$REPLY"
  __mecha_title 'RUNNING'
}

__mecha_precmd() {
  local m_rc=$? m_cols=${COLUMNS:-80} m_elapsed=0
  local m_nl=$'\n' m_clock='' m_git='' m_py='' m_fault=''
  local m_dir='' m_host='' m_context='' m_state='' m_mode='' m_sign=''
  local m_safe_root='' m_hint='' m_prompt='' m_left='' m_hot=$__M_SAFE m_cursor_hex='#58E6A1'
  __mecha_clock_now
  if [[ -n ${__MECHA_START:-} ]]; then
    (( m_elapsed = REPLY - __MECHA_START ))
    (( m_elapsed < 0 )) && m_elapsed=0
    __MECHA_START=''
  fi
  if (( m_rc == 0 )); then
    m_state="${__M_OK}● ONLINE${__M_RESET}"
    m_sign='↯'
    __mecha_title 'READY'
  else
    m_state="${__M_WARN}▲ FAULT ${m_rc}${__M_RESET}"
    m_fault=" ${__M_WARN}✕${m_rc}${__M_RESET}"
    m_sign='×'
    __mecha_title 'FAULT'
  fi

  # Prompt expansions %n/%m/%~ are delegated to Zsh; paths are not eval'ed.
  m_host="${__M_DIM}%n@%m${__M_RESET}"
  if (( EUID == 0 )); then
    m_hot=$__M_HOT
    m_cursor_hex='#FF455F'
    m_host="${m_hot}ROOT@%m${__M_RESET}"
    if (( m_rc == 0 )); then
      m_state="${m_hot}⚠ OVERRIDE${__M_RESET}"
    else
      m_state="${m_hot}⚠ ROOT${__M_RESET} ${__M_WARN}▲ FAULT ${m_rc}${__M_RESET}"
    fi
    m_context="${m_hot}ROOT${__M_RESET} "
    m_sign='⚠'
  elif [[ -n ${SSH_CONNECTION:-}${SSH_TTY:-} ]]; then
    m_host="${__M_ICE}SSH:${__M_RESET}${__M_DIM}%n@%m${__M_RESET}"
    m_context="${__M_ICE}SSH${__M_RESET} "
  fi
  # Konsole cursor follows effective user (OSC 12). The default palette is unchanged.
  # Refresh on EVERY prompt: exiting a nested root shell must restore green.
  if [[ -t 1 && ${MECHA_CURSOR_SYNC:-1} == 1 && $TERM != dumb ]]; then
    printf '\033]12;%s\007' "$m_cursor_hex"
  fi
  if (( m_cols >= 110 )); then
    m_dir='%37<…<%~%<<'
  elif (( m_cols >= 78 )); then
    m_dir='%26<…<%~%<<'
  elif (( m_cols >= 52 )); then
    m_dir='%20<…<%~%<<'
  else
    m_dir='%12<…<%~%<<'
  fi

  if (( m_cols >= 58 )); then
    __mecha_git
    [[ -n $REPLY ]] && m_git=" ${__M_DIM}⌁${__M_RESET}${__M_ICE}${REPLY}${__M_RESET}"
  fi
  if [[ -n ${VIRTUAL_ENV:-} ]] && (( m_cols >= 114 )); then
    __mecha_safe "${VIRTUAL_ENV:t}"
    m_py=" ${__M_DIM}◇${__M_RESET}${__M_ICE}py:${REPLY}${__M_RESET}"
  fi
  if (( m_elapsed >= 2 )); then
    m_hint="${__M_DIM} · ${m_elapsed}s${__M_RESET}"
  fi
  m_clock="${__M_DIM}%D{%H:%M}${__M_RESET}${m_hint}"

  m_mode=${MECHA_LAYOUT:-hud}
  if [[ $m_mode == slim ]] || (( m_cols < 50 )); then
    # Single-line for short panes and opt-in high density mode.
    PROMPT="${m_hot}M07${__M_RESET} ${m_context}${__M_TEXT}${m_dir}${__M_RESET}${m_git}${m_fault} ${m_hot}${m_sign}›${__M_RESET} "
    if (( m_cols >= 92 )); then RPROMPT="$m_clock"; else RPROMPT=''; fi
  elif (( m_cols < 78 )); then
    # Two lines; no large header when horizontal space is limited.
    PROMPT="${m_hot}▰ M07${__M_RESET} ${m_context}${__M_ICE}CORE${__M_RESET} ${__M_TEXT}${m_dir}${__M_RESET}${m_git}${m_fault}${m_nl}${m_hot}${m_sign} EXEC ›${__M_RESET} "
    RPROMPT=''
  else
    # Cinematic cockpit / original three-level M-07 rebuilt from scratch.
    PROMPT="${m_hot}%B▰ M/07%b${__M_RESET}  ${__M_DIM}▰▰▱ SYNCHROFRAME${__M_RESET}  ${m_host}  ${m_state}${m_nl}${__M_ICE}◇ CORE${__M_RESET}  ${__M_TEXT}${m_dir}${__M_RESET}${m_git}${m_py}${m_fault}${m_nl}${m_hot}${m_sign} DRIVE ›${__M_RESET} "
    RPROMPT="$m_clock"
  fi
  return 0
}

__mecha_enable() {
  [[ -n ${__MECHA_ENABLED:-} ]] && return 0
  typeset -g __MECHA_OLD_PROMPT="$PROMPT" __MECHA_OLD_RPROMPT="$RPROMPT"
  # Existing REDLINE and NOCTIS hooks must not both render a prompt.
  if [[ -n ${__NLINE_ENABLED:-} ]] && (( $+functions[__nline_disable] )); then
    typeset -g __MECHA_RESUME_NLINE=1
    __nline_disable
  fi
  if (( ${precmd_functions[(I)__noctis_zsh_precmd]:-0} > 0 )); then
    add-zsh-hook -d precmd __noctis_zsh_precmd
    typeset -g __MECHA_RESUME_NOCTIS=1
  fi
  if (( ${preexec_functions[(I)__noctis_zsh_preexec]:-0} > 0 )); then
    add-zsh-hook -d preexec __noctis_zsh_preexec
    typeset -g __MECHA_RESUME_NOCTIS_EXEC=1
  fi
  add-zsh-hook precmd __mecha_precmd
  add-zsh-hook preexec __mecha_preexec
  typeset -g __MECHA_ENABLED=1
  setopt prompt_percent
}

__mecha_disable() {
  [[ -n ${__MECHA_ENABLED:-} ]] || return 0
  add-zsh-hook -d precmd __mecha_precmd
  add-zsh-hook -d preexec __mecha_preexec
  if [[ -n ${__MECHA_RESUME_NOCTIS:-} ]]; then
    add-zsh-hook precmd __noctis_zsh_precmd
    unset __MECHA_RESUME_NOCTIS
  fi
  if [[ -n ${__MECHA_RESUME_NOCTIS_EXEC:-} ]]; then
    add-zsh-hook preexec __noctis_zsh_preexec
    unset __MECHA_RESUME_NOCTIS_EXEC
  fi
  if [[ -n ${__MECHA_RESUME_NLINE:-} ]] && (( $+functions[__nline_enable] )); then
    __nline_enable
    unset __MECHA_RESUME_NLINE
  else
    PROMPT="$__MECHA_OLD_PROMPT"
    RPROMPT="$__MECHA_OLD_RPROMPT"
  fi
  # Restore the profile-defined cursor color on MECHA off (OSC 112).
  if [[ -t 1 && ${MECHA_CURSOR_SYNC:-1} == 1 && $TERM != dumb ]]; then
    printf '\033]112\007'
  fi
  unset __MECHA_ENABLED
}

__mecha_apply_palette() {
  if [[ -z ${KONSOLE_VERSION:-}${KONSOLE_DBUS_SERVICE:-} ]]; then
    print -r -- 'Palette is available only inside Konsole; prompt colors work anywhere.'
    return 0
  fi
  if (( $+commands[konsoleprofile] )); then
    command konsoleprofile 'ColorScheme=MECHA-Synchroframe'
  else
    print -u2 -- 'konsoleprofile not found; select MECHA-Synchroframe in Konsole profile settings.'
    return 1
  fi
}

mecha() {
  local m_cfg="${MECHA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/noctis-mecha}/layout"
  case "${1:-status}" in
    use)
      case "${2:-}" in
        hud|slim)
          typeset -g MECHA_LAYOUT="$2"
          command mkdir -p -- "${m_cfg:h}" || return 1
          print -r -- "$MECHA_LAYOUT" >| "$m_cfg" || return 1
          __mecha_enable
          print -r -- "MECHA / ${MECHA_LAYOUT:u} active · mecha palette (optional)"
          ;;
        *) print -u2 -- 'Usage: mecha use hud|slim'; return 2;;
      esac
      ;;
    on)
      typeset -g MECHA_LAYOUT=${MECHA_LAYOUT:-hud}
      command mkdir -p -- "${m_cfg:h}" || return 1
      print -r -- "$MECHA_LAYOUT" >| "$m_cfg" || return 1
      __mecha_enable
      ;;
    off)
      __mecha_disable
      command mkdir -p -- "${m_cfg:h}" || return 1
      print -r -- off >| "$m_cfg"
      print -r -- 'MECHA off; previous prompt restored for this shell.'
      ;;
    palette) __mecha_apply_palette;;
    title)
      case "${2:-}" in
        on|off)
          typeset -g MECHA_TITLE=$([[ "$2" == on ]] && print -r -- 1 || print -r -- 0)
          print -r -- "Title telemetry: $2 (current shell)"
          ;;
        *) print -u2 -- 'Usage: mecha title on|off'; return 2;;
      esac
      ;;
    git)
      case "${2:-}" in
        dirty|clean)
          typeset -g MECHA_GIT_DIRTY=$([[ "$2" == dirty ]] && print -r -- 1 || print -r -- 0)
          print -r -- "Tracked-file dirty check: $2 (current shell)"
          ;;
        *) print -u2 -- 'Usage: mecha git dirty|clean'; return 2;;
      esac
      ;;
    doctor)
      local m_root="${XDG_DATA_HOME:-$HOME/.local/share}"
      local m_engine="${MECHA_ENGINE_PATH:-$m_root/synchroframe/theme/mecha.zsh}"
      print -r -- 'MECHA / SYNCHROFRAME diagnostics'
      [[ -r "$m_engine" ]] && print -r -- '  OK prompt engine' || print -u2 -- "  MISSING prompt engine ($m_engine)"
      [[ -r "$m_root/konsole/MECHA-Synchroframe.colorscheme" ]] && print -r -- '  OK Konsole palette (optional)' || print -r -- '  Konsole palette not installed (optional)'
      [[ -r "$m_root/konsole/MECHA-ASCEND.profile" ]] && print -r -- '  OK Konsole profile (optional)' || print -r -- '  Konsole profile not installed (optional)'
      print -r -- "  Zsh: ${ZSH_VERSION:-unknown} · prompt enabled=${__MECHA_ENABLED:-0} · width=${COLUMNS:-unknown}"
      print -r -- "  NOCTIS_PROFILE=${NOCTIS_PROFILE:-unset} · MECHA_ACTIVE=${MECHA_ACTIVE:-unset}"
      ;;
    status)
      print -r -- "MECHA layout=${MECHA_LAYOUT:-hud} enabled=${__MECHA_ENABLED:-0} git_dirty=${MECHA_GIT_DIRTY:-1} title=${MECHA_TITLE:-0}"
      ;;
    help)
      print -r -- 'mecha use hud|slim · mecha palette · mecha git dirty|clean · mecha title on|off · mecha off · mecha doctor'
      ;;
    *) print -u2 -- 'Usage: mecha help'; return 2;;
  esac
}

# Trust only exact tokens loaded from disk.
typeset m_cfg="${MECHA_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/noctis-mecha}/layout"
typeset m_saved='hud'
if [[ -r $m_cfg ]]; then
  IFS= read -r m_saved < "$m_cfg"
fi
case "$m_saved" in
  hud|slim) typeset -g MECHA_LAYOUT="$m_saved" ;;
  off) typeset -g MECHA_LAYOUT=hud ;;
  *) m_saved=hud; typeset -g MECHA_LAYOUT=hud ;;
esac
# Standalone installer sets MECHA_AUTOSTART=1. Existing NOCTIS/MECHA
# activation modes continue to work, and persisted `mecha off` is respected.
if [[ $m_saved != off ]] && \
   [[ ${MECHA_AUTOSTART:-0} == 1 || ${NOCTIS_PROFILE:-0} == 1 || ${NOCTIS_FORCE:-0} == 1 || ${MECHA_ACTIVE:-0} == 1 || ${KONSOLE_PROFILE_NAME:-} == NOCTIS-* || ${KONSOLE_PROFILE_NAME:-} == MECHA-* ]]; then
  __mecha_enable
fi
unset m_cfg m_saved
