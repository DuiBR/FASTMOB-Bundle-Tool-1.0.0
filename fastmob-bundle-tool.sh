#!/usr/bin/env bash
# FASTMOB Bundle Tool
# Instalador + menu interativo para análise e edição de React Native bundles.
# Suporte principal: Hermes HBC 40-99 via hermes-decomp.
# Versão: 1.0.0

set -uo pipefail

APP_NAME="FASTMOB Bundle Tool"
APP_VERSION="1.0.0"
HERMES_REPO="https://github.com/SymbioticSec/hermes-decomp.git"
HERMES_TAG="${HERMES_TAG:-v0.2.1}"

FM_HOME="${FASTMOB_HOME:-$HOME/.fastmob-bundle-tool}"
DIR_ORIGINAL="$FM_HOME/original"
DIR_CURRENT="$FM_HOME/current"
DIR_OUTPUT="$FM_HOME/output"
DIR_ANALYSIS="$FM_HOME/analysis"
DIR_BACKUPS="$FM_HOME/backups"
DIR_TOOLS="$FM_HOME/tools"
DIR_LOGS="$FM_HOME/logs"
CURRENT_BUNDLE="$DIR_CURRENT/index.android.bundle"
ORIGINAL_BUNDLE="$DIR_ORIGINAL/index.android.bundle"
ACTION_LOG="$DIR_LOGS/actions.log"

C_RESET=$'\033[0m'
C_RED=$'\033[31m'
C_GREEN=$'\033[32m'
C_YELLOW=$'\033[33m'
C_BLUE=$'\033[34m'
C_CYAN=$'\033[36m'
C_BOLD=$'\033[1m'

say() { printf "%s\n" "$*"; }
ok() { printf "%s[OK]%s %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%s[AVISO]%s %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
err() { printf "%s[ERRO]%s %s\n" "$C_RED" "$C_RESET" "$*" >&2; }
info() { printf "%s[INFO]%s %s\n" "$C_CYAN" "$C_RESET" "$*"; }
die() { err "$*"; exit 1; }

pause_menu() {
  printf "\nPressione ENTER para continuar..."
  read -r _ || true
}

log_action() {
  mkdir -p "$DIR_LOGS"
  printf '%s | %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$ACTION_LOG"
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    return 126
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

sha256_value() {
  local f="$1"
  if have sha256sum; then
    sha256sum "$f" | awk '{print $1}'
  elif have shasum; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    python3 - "$f" <<'PY'
import hashlib,sys
h=hashlib.sha256()
with open(sys.argv[1],'rb') as f:
    for chunk in iter(lambda:f.read(1024*1024), b''):
        h.update(chunk)
print(h.hexdigest())
PY
  fi
}

mkdir_layout() {
  mkdir -p "$DIR_ORIGINAL" "$DIR_CURRENT" "$DIR_OUTPUT" "$DIR_ANALYSIS" \
           "$DIR_BACKUPS" "$DIR_TOOLS" "$DIR_LOGS"
}

detect_platform() {
  OS_FAMILY="unknown"
  OS_ID="unknown"
  OS_NAME="$(uname -s 2>/dev/null || echo unknown)"
  ARCH="$(uname -m 2>/dev/null || echo unknown)"

  if [ -n "${TERMUX_VERSION:-}" ] || [[ "${PREFIX:-}" == *"com.termux"* ]]; then
    OS_FAMILY="termux"
    OS_ID="termux"
    return
  fi

  case "$OS_NAME" in
    Darwin)
      OS_FAMILY="macos"
      OS_ID="macos"
      return
      ;;
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-linux}"
        local likes="${ID_LIKE:-}"
        case "${ID:-}" in
          debian|ubuntu|linuxmint|pop|kali|raspbian) OS_FAMILY="apt" ;;
          fedora|rhel|centos|rocky|almalinux|ol) OS_FAMILY="dnf" ;;
          arch|manjaro|endeavouros) OS_FAMILY="pacman" ;;
          alpine) OS_FAMILY="apk" ;;
          opensuse*|sles) OS_FAMILY="zypper" ;;
          *)
            if [[ "$likes" == *debian* ]]; then OS_FAMILY="apt"
            elif [[ "$likes" == *fedora* ]] || [[ "$likes" == *rhel* ]]; then OS_FAMILY="dnf"
            elif [[ "$likes" == *arch* ]]; then OS_FAMILY="pacman"
            elif [[ "$likes" == *suse* ]]; then OS_FAMILY="zypper"
            fi
            ;;
        esac
      fi
      ;;
  esac
}

install_packages() {
  detect_platform
  info "Sistema detectado: $OS_ID / $OS_NAME / $ARCH"

  case "$OS_FAMILY" in
    apt)
      run_root apt-get update || die "Não foi possível executar apt-get update."
      run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential pkg-config libssl-dev ca-certificates curl git \
        python3 file binutils tmux tar gzip unzip nano || \
        die "Falha ao instalar dependências via APT."
      ;;
    dnf)
      local pm="dnf"
      have dnf || pm="yum"
      run_root "$pm" install -y \
        gcc gcc-c++ make pkgconf-pkg-config openssl-devel ca-certificates \
        curl git python3 file binutils tmux tar gzip unzip nano || \
        die "Falha ao instalar dependências via $pm."
      ;;
    pacman)
      run_root pacman -Sy --needed --noconfirm \
        base-devel pkgconf openssl ca-certificates curl git python file \
        binutils tmux tar gzip unzip nano || \
        die "Falha ao instalar dependências via pacman."
      ;;
    apk)
      run_root apk add --no-cache \
        build-base pkgconf openssl-dev ca-certificates curl git python3 \
        file binutils tmux tar gzip unzip nano || \
        die "Falha ao instalar dependências via apk."
      ;;
    zypper)
      run_root zypper --non-interactive install \
        gcc gcc-c++ make pkg-config libopenssl-devel ca-certificates \
        curl git python3 file binutils tmux tar gzip unzip nano || \
        die "Falha ao instalar dependências via zypper."
      ;;
    termux)
      pkg update -y || die "Falha em pkg update."
      pkg install -y clang make pkg-config openssl ca-certificates curl git \
        python file binutils tmux tar gzip unzip nano rust || \
        die "Falha ao instalar dependências no Termux."
      ;;
    macos)
      have brew || die "Homebrew não encontrado. Instale o Homebrew antes de continuar."
      brew install pkg-config openssl git python rust tmux coreutils || true
      ;;
    *)
      die "Distribuição não suportada automaticamente. Instale manualmente: git curl python3 file binutils build tools Rust/Cargo."
      ;;
  esac
}

memory_mb() {
  if [ -r /proc/meminfo ]; then
    awk '/MemTotal:/ {printf "%d\n", $2/1024}' /proc/meminfo
  else
    echo 4096
  fi
}

swap_mb() {
  if [ -r /proc/meminfo ]; then
    awk '/SwapTotal:/ {printf "%d\n", $2/1024}' /proc/meminfo
  else
    echo 0
  fi
}

ensure_swap_if_needed() {
  [ "${FASTMOB_NO_SWAP:-0}" = "1" ] && return 0
  [ "$(uname -s 2>/dev/null)" = "Linux" ] || return 0
  [ "$OS_FAMILY" != "termux" ] || return 0

  local mem swap
  mem="$(memory_mb)"
  swap="$(swap_mb)"
  if [ "$mem" -ge 1536 ] || [ "$swap" -ge 2048 ]; then
    return 0
  fi

  warn "Pouca RAM detectada (${mem} MiB) e apenas ${swap} MiB de swap."
  info "O instalador tentará criar/ativar 4 GiB de swap para evitar travamento durante o Cargo."

  if ! run_root true >/dev/null 2>&1; then
    warn "Sem root/sudo. Não foi possível criar swap. A compilação usará apenas 1 job."
    return 0
  fi

  local avail_kb
  avail_kb="$(df -Pk / | awk 'NR==2 {print $4}')"
  if [ "${avail_kb:-0}" -lt 5242880 ]; then
    warn "Menos de 5 GiB livres em /. Swap automática não será criada."
    return 0
  fi

  if [ -f /swapfile ]; then
    if ! swapon --show=NAME 2>/dev/null | grep -qx '/swapfile'; then
      run_root swapon /swapfile 2>/dev/null || true
    fi
  else
    if have fallocate; then
      run_root fallocate -l 4G /swapfile || return 0
    else
      run_root dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress || return 0
    fi
    run_root chmod 600 /swapfile
    run_root mkswap /swapfile >/dev/null
    run_root swapon /swapfile
  fi

  if ! grep -qE '^/swapfile[[:space:]]' /etc/fstab 2>/dev/null; then
    printf '/swapfile none swap sw 0 0\n' | run_root tee -a /etc/fstab >/dev/null || true
  fi
  ok "Swap disponível: $(swap_mb) MiB."
}

ensure_rust() {
  if have cargo && have rustc; then
    return 0
  fi

  if [ "$OS_FAMILY" = "termux" ]; then
    pkg install -y rust || die "Não foi possível instalar Rust no Termux."
  elif [ "$OS_FAMILY" = "macos" ] && have brew; then
    brew install rust || die "Não foi possível instalar Rust pelo Homebrew."
  else
    info "Instalando Rust/Cargo via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
      sh -s -- -y --profile minimal || die "Falha ao instalar Rust."
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  fi

  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
  have cargo || die "Cargo continua indisponível após a instalação."
  have rustc || die "rustc continua indisponível após a instalação."
}

hermes_ok() {
  have hermes-decomp || return 1
  hermes-decomp versions 2>/dev/null | grep -Eq '(^|[^0-9])96([^0-9]|$)'
}

install_hermes_decomp() {
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

  if hermes_ok; then
    ok "hermes-decomp já está instalado e reconhece HBC 96."
    return 0
  fi

  ensure_rust
  ensure_swap_if_needed

  local src="$DIR_TOOLS/hermes-decomp-src"
  info "Preparando hermes-decomp $HERMES_TAG..."

  if [ -d "$src/.git" ]; then
    git -C "$src" fetch --tags --force
    git -C "$src" checkout -f "$HERMES_TAG"
    git -C "$src" clean -fd
  else
    rm -rf "$src"
    git clone --branch "$HERMES_TAG" --depth 1 "$HERMES_REPO" "$src" || \
      die "Falha ao clonar hermes-decomp."
  fi

  local jobs="${CARGO_BUILD_JOBS:-}"
  if [ -z "$jobs" ]; then
    local mem cpu
    mem="$(memory_mb)"
    cpu="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    if [ "$mem" -lt 2048 ]; then jobs=1
    elif [ "$cpu" -gt 2 ]; then jobs=2
    else jobs="$cpu"
    fi
  fi

  info "Compilando hermes-decomp com cargo --release -j $jobs."
  (
    cd "$src" || exit 1
    cargo build --release -j "$jobs"
  ) || die "Falha ao compilar hermes-decomp."

  local built="$src/target/release/hermes-decomp"
  [ -x "$built" ] || die "Binário hermes-decomp não foi gerado."

  if run_root true >/dev/null 2>&1; then
    run_root install -m 0755 "$built" /usr/local/bin/hermes-decomp
  else
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$built" "$HOME/.local/bin/hermes-decomp"
  fi

  hash -r 2>/dev/null || true
  export PATH="$HOME/.local/bin:$PATH"
  hermes_ok || die "hermes-decomp instalado, mas a verificação final falhou."
  ok "hermes-decomp instalado com sucesso."
}

install_self_command() {
  local self
  self="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
  [ -f "$self" ] || return 0

  if run_root true >/dev/null 2>&1; then
    run_root install -m 0755 "$self" /usr/local/bin/fastmob-bundle 2>/dev/null || true
  else
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$self" "$HOME/.local/bin/fastmob-bundle" 2>/dev/null || true
  fi
}

bootstrap() {
  mkdir_layout
  detect_platform
  export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

  local missing=0
  for cmd in git curl python3 file strings cc make pkg-config; do
    have "$cmd" || missing=1
  done

  if [ "$missing" -eq 1 ]; then
    install_packages
  fi

  ensure_rust
  install_hermes_decomp
  install_self_command
  touch "$FM_HOME/.bootstrap-ok"
}

expand_path() {
  local p="$1"
  if [[ "$p" == "~/"* ]]; then
    p="$HOME/${p#\~/}"
  elif [ "$p" = "~" ]; then
    p="$HOME"
  fi
  printf '%s' "$p"
}

bundle_required() {
  if [ ! -f "$CURRENT_BUNDLE" ]; then
    warn "Nenhum bundle selecionado."
    import_bundle
  fi
  [ -f "$CURRENT_BUNDLE" ] || return 1
}

detect_bundle() {
  local f="${1:-$CURRENT_BUNDLE}"
  python3 - "$f" <<'PY'
import sys, struct
p=sys.argv[1]
d=open(p,'rb').read(65536)
if len(d)>=12:
    magic, ver=struct.unpack_from("<QI", d, 0)
    if magic == 0x1F1903C103BC1FC6:
        print(f"hermes|{ver}")
        raise SystemExit
try:
    t=d.decode("utf-8")
    printable=sum(ch.isprintable() or ch in "\r\n\t" for ch in t)
    ratio=printable/max(len(t),1)
    hints=("__d(", "require(", "function", "var ", "const ", "let ")
    if ratio > 0.90 and any(h in t for h in hints):
        print("javascript|")
    else:
        print("unknown|")
except UnicodeDecodeError:
    print("unknown|")
PY
}

bundle_type() {
  detect_bundle "$CURRENT_BUNDLE" | cut -d'|' -f1
}

bundle_version() {
  detect_bundle "$CURRENT_BUNDLE" | cut -d'|' -f2
}

backup_current() {
  [ -f "$CURRENT_BUNDLE" ] || return 1
  local ts out
  ts="$(date '+%Y%m%d-%H%M%S')"
  out="$DIR_BACKUPS/index.android.bundle.$ts"
  cp -p "$CURRENT_BUNDLE" "$out"
  printf '%s\n' "$out"
}

validate_bundle_file() {
  local f="$1"
  [ -f "$f" ] || return 1
  local detected typ
  detected="$(detect_bundle "$f")"
  typ="${detected%%|*}"

  case "$typ" in
    hermes)
      hermes-decomp info "$f" >/dev/null 2>&1 || return 1
      ;;
    javascript)
      if have node; then
        node --check "$f" >/dev/null 2>&1 || return 1
      else
        python3 - "$f" <<'PY' >/dev/null
import sys
open(sys.argv[1],'r',encoding='utf-8').read()
PY
      fi
      ;;
    *)
      return 1
      ;;
  esac
  return 0
}

import_bundle() {
  printf "\n%sSelecionar index.android.bundle%s\n" "$C_BOLD" "$C_RESET"
  local p
  read -r -p "Caminho do arquivo: " p
  p="$(expand_path "$p")"
  [ -f "$p" ] || { err "Arquivo não encontrado: $p"; return 1; }

  mkdir_layout
  cp -p "$p" "$ORIGINAL_BUNDLE"
  cp -p "$p" "$CURRENT_BUNDLE"
  printf '%s\n' "$p" > "$FM_HOME/source-path.txt"

  local det typ ver
  det="$(detect_bundle "$CURRENT_BUNDLE")"
  typ="${det%%|*}"
  ver="${det#*|}"

  if [ "$typ" = "unknown" ]; then
    warn "Formato não reconhecido automaticamente."
  elif [ "$typ" = "hermes" ]; then
    ok "Hermes HBC detectado. Versão: $ver"
    if ! hermes-decomp info "$CURRENT_BUNDLE" >/dev/null; then
      err "hermes-decomp não conseguiu validar o arquivo."
      return 1
    fi
  else
    ok "Bundle JavaScript textual detectado."
  fi

  log_action "IMPORT | source=$p | type=$typ | version=$ver | sha256=$(sha256_value "$CURRENT_BUNDLE")"
  bundle_info
}

bundle_info() {
  bundle_required || return
  local det typ ver
  det="$(detect_bundle "$CURRENT_BUNDLE")"
  typ="${det%%|*}"
  ver="${det#*|}"

  printf "\n%s=== INFORMAÇÕES DO BUNDLE ===%s\n" "$C_BOLD" "$C_RESET"
  say "Arquivo atual : $CURRENT_BUNDLE"
  say "Tipo          : $typ"
  [ -n "$ver" ] && say "HBC           : $ver"
  say "Tamanho       : $(du -h "$CURRENT_BUNDLE" | awk '{print $1}')"
  say "SHA-256       : $(sha256_value "$CURRENT_BUNDLE")"

  if [ "$typ" = "hermes" ]; then
    printf "\n"
    hermes-decomp info "$CURRENT_BUNDLE" || true
  else
    file "$CURRENT_BUNDLE" || true
  fi
}

dump_strings_to() {
  local input="$1" output="$2"
  local det typ
  det="$(detect_bundle "$input")"
  typ="${det%%|*}"
  if [ "$typ" = "hermes" ]; then
    hermes-decomp dump "$input" --kind strings > "$output"
  else
    strings -a "$input" > "$output"
  fi
}

refresh_strings() {
  bundle_required || return 1
  local out="$DIR_ANALYSIS/strings-current.txt"
  info "Extraindo strings..."
  dump_strings_to "$CURRENT_BUNDLE" "$out" || { err "Falha ao extrair strings."; return 1; }
  ok "Strings salvas em: $out"
}

list_urls() {
  bundle_required || return
  refresh_strings || return
  local src="$DIR_ANALYSIS/strings-current.txt"
  local out="$DIR_ANALYSIS/urls-current.txt"
  python3 - "$src" "$out" <<'PY'
import re,sys
src,out=sys.argv[1:3]
text=open(src,'r',encoding='utf-8',errors='replace').read()
urls=[]
for m in re.finditer(r'https?://[^\s"\'<>\\\x00]+', text):
    u=m.group(0).rstrip('),;]}')
    if u not in urls:
        urls.append(u)
with open(out,'w',encoding='utf-8') as f:
    for u in urls:
        f.write(u+"\n")
print("\n".join(urls))
PY
  say
  ok "Lista salva em: $out"
}

search_value() {
  bundle_required || return
  local q
  read -r -p "Texto/URL/valor para pesquisar: " q
  [ -n "$q" ] || return
  refresh_strings >/dev/null || return
  printf "\n%sResultados:%s\n" "$C_BOLD" "$C_RESET"
  grep -Fin -- "$q" "$DIR_ANALYSIS/strings-current.txt" | head -100 || warn "Nenhum resultado na tabela de strings."
  printf "\nOcorrências binárias exatas: "
  python3 - "$CURRENT_BUNDLE" "$q" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
q=sys.argv[2].encode()
print(d.count(q))
PY
}

xref_value() {
  bundle_required || return
  [ "$(bundle_type)" = "hermes" ] || { warn "XREF está disponível apenas para Hermes HBC."; return; }
  local q
  read -r -p "String ou termo para XREF: " q
  [ -n "$q" ] || return
  hermes-decomp xref "$CURRENT_BUNDLE" --query "$q" || true
}

byte_len() {
  python3 - "$1" <<'PY'
import sys
print(len(sys.argv[1].encode("utf-8")))
PY
}

raw_count() {
  python3 - "$1" "$2" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
print(d.count(sys.argv[2].encode("utf-8")))
PY
}

safe_raw_same_length_patch() {
  local old="$1" new="$2" tmp="$3"
  local oldlen newlen count
  oldlen="$(byte_len "$old")"
  newlen="$(byte_len "$new")"
  [ "$oldlen" -eq "$newlen" ] || return 20
  count="$(raw_count "$CURRENT_BUNDLE" "$old")"
  [ "$count" -eq 1 ] || return 21

  local before="$DIR_ANALYSIS/.strings-before.$$"
  local after="$DIR_ANALYSIS/.strings-after.$$"
  dump_strings_to "$CURRENT_BUNDLE" "$before" || return 22

  cp -p "$CURRENT_BUNDLE" "$tmp"
  python3 - "$tmp" "$old" "$new" <<'PY'
import sys,hashlib,struct
p,old,new=sys.argv[1],sys.argv[2].encode(),sys.argv[3].encode()
if len(old)!=len(new):
    raise SystemExit(20)
d=bytearray(open(p,'rb').read())
if d.count(old)!=1:
    raise SystemExit(21)
pos=d.find(old)
d[pos:pos+len(old)]=new

# HBC armazena SHA-1 no footer (20 bytes). Recalcula apenas se for Hermes.
if len(d)>=12:
    magic=struct.unpack_from("<Q",d,0)[0]
    if magic==0x1F1903C103BC1FC6 and len(d)>=20:
        d[-20:]=hashlib.sha1(d[:-20]).digest()

open(p,'wb').write(d)
print(pos)
PY
  local rc=$?
  [ "$rc" -eq 0 ] || { rm -f "$tmp" "$before"; return "$rc"; }

  validate_bundle_file "$tmp" || { rm -f "$tmp" "$before"; return 23; }
  dump_strings_to "$tmp" "$after" || { rm -f "$tmp" "$before"; return 24; }

  # Segurança para packed strings: só aceita se o dump mostrar uma única
  # entrada removida e uma única entrada adicionada.
  local changed
  changed="$(diff -U0 "$before" "$after" 2>/dev/null | \
    grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | wc -l | tr -d ' ')"

  if [ "$changed" -gt 2 ]; then
    warn "Patch binário afetaria $changed linhas da tabela de strings. Operação cancelada para evitar corromper strings sobrepostas."
    rm -f "$tmp" "$before" "$after"
    return 25
  fi

  rm -f "$before" "$after"
  return 0
}

commit_tmp_patch() {
  local tmp="$1" desc="$2"
  validate_bundle_file "$tmp" || { err "O arquivo modificado não passou na validação."; rm -f "$tmp"; return 1; }
  local bak
  bak="$(backup_current)"
  mv -f "$tmp" "$CURRENT_BUNDLE"
  ok "Alteração aplicada."
  say "Backup anterior: $bak"
  say "SHA-256 novo : $(sha256_value "$CURRENT_BUNDLE")"
  log_action "PATCH | $desc | backup=$bak | sha256=$(sha256_value "$CURRENT_BUNDLE")"
}

replace_hbc_string() {
  local old="$1" new="$2" kind="$3"
  local tmp="$DIR_CURRENT/.patched.$$"
  local errorfile="$DIR_ANALYSIS/.patch-error.$$"
  rm -f "$tmp" "$errorfile"

  info "Tentando patch pela tabela Hermes..."
  if hermes-decomp patch-string "$CURRENT_BUNDLE" --old "$old" --new "$new" -o "$tmp" 2>"$errorfile"; then
    commit_tmp_patch "$tmp" "$kind: $old -> $new"
    rm -f "$errorfile"
    return
  fi

  local first_error
  first_error="$(cat "$errorfile" 2>/dev/null || true)"
  rm -f "$tmp"

  # Caso comum: o usuário digitou sem a "/" final, mas a entrada real possui "/".
  if printf '%s' "$first_error" | grep -qi "string not found"; then
    if [[ "$old" != */ ]] && [ "$(raw_count "$CURRENT_BUNDLE" "${old}/")" -eq 1 ]; then
      local old2="${old}/"
      local new2="$new"
      [[ "$new2" == */ ]] || new2="${new2}/"
      info "Entrada provável encontrada com '/' final. Tentando automaticamente:"
      say "  antiga: $old2"
      say "  nova  : $new2"
      if hermes-decomp patch-string "$CURRENT_BUNDLE" --old "$old2" --new "$new2" -o "$tmp" 2>"$errorfile"; then
        commit_tmp_patch "$tmp" "$kind: $old2 -> $new2"
        rm -f "$errorfile"
        return
      fi
      old="$old2"
      new="$new2"
    fi
  fi

  local oldlen newlen
  oldlen="$(byte_len "$old")"
  newlen="$(byte_len "$new")"

  if [ "$oldlen" -eq "$newlen" ]; then
    warn "hermes-decomp recusou o patch. Tentando fallback binário seguro de mesmo tamanho."
    if safe_raw_same_length_patch "$old" "$new" "$tmp"; then
      commit_tmp_patch "$tmp" "$kind (fallback seguro): $old -> $new"
      rm -f "$errorfile"
      return
    fi
  fi

  err "Não foi possível aplicar a alteração automaticamente."
  say
  say "Motivo retornado pelo hermes-decomp:"
  cat "$errorfile" 2>/dev/null || true
  say
  if [ "$oldlen" -ne "$newlen" ]; then
    warn "Antigo: $oldlen bytes | Novo: $newlen bytes."
    warn "Em HBC 96 ou menor, mudanças de tamanho funcionam quando a string NÃO é packed/overlapping."
    warn "Strings packed com tamanho diferente são recusadas para evitar corrupção."
  fi
  warn "Use a pesquisa de strings/XREF para confirmar a entrada ou escolha uma substituição compatível."
  rm -f "$tmp" "$errorfile"
}

replace_js_string() {
  local old="$1" new="$2" kind="$3"
  local tmp="$DIR_CURRENT/.patched.$$"
  python3 - "$CURRENT_BUNDLE" "$tmp" "$old" "$new" <<'PY'
import sys
src,dst,old,new=sys.argv[1:5]
data=open(src,'rb').read()
a=old.encode(); b=new.encode()
count=data.count(a)
if count == 0:
    print("NOT_FOUND")
    raise SystemExit(10)
open(dst,'wb').write(data.replace(a,b))
print(count)
PY
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    err "Texto não encontrado no bundle."
    rm -f "$tmp"
    return
  fi
  commit_tmp_patch "$tmp" "$kind: $old -> $new"
}

replace_value_menu() {
  local kind="$1"
  bundle_required || return

  local old new
  printf "\n%sAlterar %s%s\n" "$C_BOLD" "$kind" "$C_RESET"
  read -r -p "Valor/link antigo: " old
  [ -n "$old" ] || { warn "Valor antigo vazio."; return; }
  read -r -p "Valor/link novo: " new
  [ -n "$new" ] || { warn "Valor novo vazio."; return; }

  if [ "$kind" = "URL" ]; then
    if [[ ! "$new" =~ ^https?:// ]]; then
      warn "A nova URL não começa com http:// ou https://."
      read -r -p "Continuar mesmo assim? [s/N]: " ans
      [[ "${ans,,}" = "s" ]] || return
    fi
  fi

  say
  say "Antigo: $old ($(byte_len "$old") bytes)"
  say "Novo  : $new ($(byte_len "$new") bytes)"
  say "Ocorrências binárias do antigo: $(raw_count "$CURRENT_BUNDLE" "$old")"

  local typ
  typ="$(bundle_type)"
  case "$typ" in
    hermes) replace_hbc_string "$old" "$new" "$kind" ;;
    javascript) replace_js_string "$old" "$new" "$kind" ;;
    *) err "Formato não reconhecido para edição automática." ;;
  esac
}

replace_string_by_id() {
  bundle_required || return
  [ "$(bundle_type)" = "hermes" ] || { warn "Opção disponível apenas para HBC."; return; }

  local id new tmp="$DIR_CURRENT/.patched.$$"
  read -r -p "String ID: " id
  [[ "$id" =~ ^[0-9]+$ ]] || { err "ID inválido."; return; }
  read -r -p "Novo conteúdo: " new
  [ -n "$new" ] || return

  if hermes-decomp patch-string "$CURRENT_BUNDLE" --id "$id" --new "$new" -o "$tmp"; then
    commit_tmp_patch "$tmp" "String ID $id -> $new"
  else
    rm -f "$tmp"
    err "hermes-decomp recusou a alteração por ID."
  fi
}

decompile_full() {
  bundle_required || return
  [ "$(bundle_type)" = "hermes" ] || { warn "Somente Hermes HBC."; return; }
  local out="$DIR_ANALYSIS/decompiled-$(date '+%Y%m%d-%H%M%S').js"
  warn "A decompilação completa pode consumir CPU/RAM e levar vários minutos."
  info "Saída: $out"
  if hermes-decomp decompile "$CURRENT_BUNDLE" -o "$out"; then
    ok "Decompilação concluída."
  else
    err "Falha na decompilação."
  fi
}

decompile_function() {
  bundle_required || return
  [ "$(bundle_type)" = "hermes" ] || { warn "Somente Hermes HBC."; return; }
  local id
  read -r -p "Function ID: " id
  [[ "$id" =~ ^[0-9]+$ ]] || { err "ID inválido."; return; }
  local out="$DIR_ANALYSIS/function-${id}.js"
  hermes-decomp decompile "$CURRENT_BUNDLE" --function "$id" > "$out" && {
    ok "Salvo em $out"
    sed -n '1,160p' "$out"
  }
}

disasm_function() {
  bundle_required || return
  [ "$(bundle_type)" = "hermes" ] || { warn "Somente Hermes HBC."; return; }
  local id
  read -r -p "Function ID: " id
  [[ "$id" =~ ^[0-9]+$ ]] || { err "ID inválido."; return; }
  local out="$DIR_ANALYSIS/function-${id}.disasm.txt"
  hermes-decomp disasm "$CURRENT_BUNDLE" --function "$id" --info --show-offsets --output "$out" && {
    ok "Salvo em $out"
    sed -n '1,180p' "$out"
  }
}

edit_function_hasm() {
  bundle_required || return
  [ "$(bundle_type)" = "hermes" ] || { warn "Somente Hermes HBC."; return; }

  local id
  read -r -p "Function ID: " id
  [[ "$id" =~ ^[0-9]+$ ]] || { err "ID inválido."; return; }

  info "Verificando round-trip da função..."
  hermes-decomp asm-check "$CURRENT_BUNDLE" --function "$id" || {
    err "asm-check falhou. A edição foi cancelada."
    return
  }

  local hasm="$DIR_ANALYSIS/function-${id}.hasm"
  hermes-decomp emit-hasm "$CURRENT_BUNDLE" --function "$id" -o "$hasm" || {
    err "Falha ao exportar HASM."
    return
  }
  cp -p "$hasm" "${hasm}.original"

  local editor="${EDITOR:-nano}"
  have "$editor" || editor="vi"
  info "Abrindo $hasm com $editor."
  "$editor" "$hasm"

  read -r -p "Aplicar a função editada ao bundle? [s/N]: " ans
  [[ "${ans,,}" = "s" ]] || { warn "Alteração cancelada. HASM permanece em $hasm"; return; }

  local tmp="$DIR_CURRENT/.patched.$$"
  if hermes-decomp patch-function "$CURRENT_BUNDLE" --function "$id" --hasm "$hasm" -o "$tmp"; then
    commit_tmp_patch "$tmp" "patch-function ID=$id"
  else
    rm -f "$tmp"
    err "Falha ao aplicar HASM."
  fi
}

validate_current() {
  bundle_required || return
  if validate_bundle_file "$CURRENT_BUNDLE"; then
    ok "Bundle atual passou na validação."
    bundle_info
  else
    err "Bundle atual NÃO passou na validação."
  fi
}

compare_original() {
  bundle_required || return
  [ -f "$ORIGINAL_BUNDLE" ] || { warn "Original não encontrado."; return; }
  say "Original: $(sha256_value "$ORIGINAL_BUNDLE")"
  say "Atual   : $(sha256_value "$CURRENT_BUNDLE")"
  if cmp -s "$ORIGINAL_BUNDLE" "$CURRENT_BUNDLE"; then
    ok "Nenhuma diferença."
    return
  fi
  if [ "$(bundle_type)" = "hermes" ]; then
    hermes-decomp bin-diff "$ORIGINAL_BUNDLE" "$CURRENT_BUNDLE" || true
  else
    warn "Arquivos são diferentes."
  fi
}

restore_last_backup() {
  local last
  last="$(ls -1t "$DIR_BACKUPS"/index.android.bundle.* 2>/dev/null | head -1 || true)"
  [ -n "$last" ] || { warn "Nenhum backup encontrado."; return; }
  cp -p "$last" "$CURRENT_BUNDLE"
  ok "Restaurado: $last"
  log_action "RESTORE | $last"
}

restore_original() {
  [ -f "$ORIGINAL_BUNDLE" ] || { warn "Original não encontrado."; return; }
  [ -f "$CURRENT_BUNDLE" ] && backup_current >/dev/null || true
  cp -p "$ORIGINAL_BUNDLE" "$CURRENT_BUNDLE"
  ok "Bundle original restaurado."
  log_action "RESTORE ORIGINAL"
}

export_final() {
  bundle_required || return
  validate_bundle_file "$CURRENT_BUNDLE" || {
    err "Exportação bloqueada: o bundle atual não passou na validação."
    return
  }

  local default="$DIR_OUTPUT/index.android.bundle"
  local dest
  read -r -p "Destino [$default]: " dest
  dest="${dest:-$default}"
  dest="$(expand_path "$dest")"

  if [ -d "$dest" ]; then
    dest="${dest%/}/index.android.bundle"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -p "$CURRENT_BUNDLE" "$dest"
  ok "Exportado: $dest"
  say "SHA-256: $(sha256_value "$dest")"
  log_action "EXPORT | $dest"
}

show_history() {
  if [ -f "$ACTION_LOG" ]; then
    tail -100 "$ACTION_LOG"
  else
    warn "Ainda não há histórico."
  fi
}

system_status() {
  detect_platform
  printf "\n%s=== AMBIENTE ===%s\n" "$C_BOLD" "$C_RESET"
  say "Sistema       : $OS_ID ($OS_NAME)"
  say "Arquitetura   : $ARCH"
  say "RAM           : $(memory_mb) MiB"
  say "Swap          : $(swap_mb) MiB"
  say "Rust          : $(rustc --version 2>/dev/null || echo não instalado)"
  say "Cargo         : $(cargo --version 2>/dev/null || echo não instalado)"
  say "hermes-decomp : $(hermes-decomp --help 2>/dev/null | head -1 || echo não instalado)"
  say "Workspace     : $FM_HOME"
}

menu_header() {
  clear 2>/dev/null || true
  printf "%s%s\n" "$C_BOLD" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  FASTMOB BUNDLE TOOL %s\n" "$APP_VERSION"
  printf "  React Native / Hermes HBC\n"
  printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$C_RESET"
  if [ -f "$CURRENT_BUNDLE" ]; then
    local det
    det="$(detect_bundle "$CURRENT_BUNDLE")"
    printf "Bundle: %s | %s\n\n" "$CURRENT_BUNDLE" "$det"
  else
    printf "Bundle: nenhum selecionado\n\n"
  fi
}

main_menu() {
  while true; do
    menu_header
    cat <<'MENU'
[1]  Selecionar/importar index.android.bundle
[2]  Analisar bundle / identificar HBC
[3]  Listar URLs encontradas
[4]  Alterar URL/link
[5]  Alterar texto/string
[6]  Alterar valor armazenado como string
[7]  Alterar string pelo ID Hermes
[8]  Pesquisar texto/URL/string
[9]  Localizar referências (XREF)

[10] Decompilar bundle completo
[11] Decompilar uma função
[12] Disassembly de uma função
[13] Editar função via HASM (avançado)

[14] Validar bundle atual
[15] Comparar atual com original
[16] Restaurar último backup
[17] Restaurar bundle original
[18] Exportar index.android.bundle final
[19] Histórico de alterações
[20] Status do sistema/ferramentas

[0]  Sair
MENU
    printf "\n"
    read -r -p "Escolha: " choice
    case "$choice" in
      1) import_bundle; pause_menu ;;
      2) bundle_info; pause_menu ;;
      3) list_urls; pause_menu ;;
      4) replace_value_menu "URL"; pause_menu ;;
      5) replace_value_menu "TEXTO"; pause_menu ;;
      6) replace_value_menu "VALOR"; pause_menu ;;
      7) replace_string_by_id; pause_menu ;;
      8) search_value; pause_menu ;;
      9) xref_value; pause_menu ;;
      10) decompile_full; pause_menu ;;
      11) decompile_function; pause_menu ;;
      12) disasm_function; pause_menu ;;
      13) edit_function_hasm; pause_menu ;;
      14) validate_current; pause_menu ;;
      15) compare_original; pause_menu ;;
      16) restore_last_backup; pause_menu ;;
      17) restore_original; pause_menu ;;
      18) export_final; pause_menu ;;
      19) show_history; pause_menu ;;
      20) system_status; pause_menu ;;
      0) say "Saindo."; exit 0 ;;
      *) warn "Opção inválida."; sleep 1 ;;
    esac
  done
}

usage() {
  cat <<EOF
$APP_NAME $APP_VERSION

Uso:
  $0                 instala/verifica dependências e abre o menu
  $0 --install       apenas instala/verifica as dependências
  $0 --bundle FILE   importa FILE e abre o menu
  $0 --status        mostra o ambiente
  $0 --help          mostra esta ajuda

Variáveis opcionais:
  FASTMOB_HOME=/pasta       workspace (padrão: ~/.fastmob-bundle-tool)
  FASTMOB_NO_SWAP=1         não criar swap automaticamente
  CARGO_BUILD_JOBS=1        limita jobs da compilação Rust
  HERMES_TAG=v0.2.1         versão do hermes-decomp a compilar
EOF
}

main() {
  mkdir_layout
  case "${1:-}" in
    --help|-h)
      usage
      exit 0
      ;;
    --install)
      bootstrap
      ok "Instalação concluída. Comando: fastmob-bundle"
      exit 0
      ;;
    --status)
      system_status
      exit 0
      ;;
    --bundle)
      bootstrap
      [ -n "${2:-}" ] || die "Informe o caminho após --bundle."
      local p
      p="$(expand_path "$2")"
      [ -f "$p" ] || die "Arquivo não encontrado: $p"
      cp -p "$p" "$ORIGINAL_BUNDLE"
      cp -p "$p" "$CURRENT_BUNDLE"
      log_action "IMPORT CLI | source=$p"
      main_menu
      ;;
    *)
      bootstrap
      main_menu
      ;;
  esac
}

main "$@"
