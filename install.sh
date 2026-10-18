#!/usr/bin/env bash
set -Eeuo pipefail

# Interactive bootstrap for a Hermes security-assessment profile.
# When piped from curl, fetch this repository into a temporary directory so
# SOUL.md and the user-provided skills are available to the installer.

[[ $# -eq 0 ]] || { printf 'This installer uses an interactive menu and does not accept flags.\n' >&2; exit 2; }

REPO_URL="https://github.com/DroBov1Tya/hermes_auto.git"
REPO_REF="main"
PENTACORE_API="https://api.github.com/repos/DroBov1Tya/PentaCore/releases"
KALI_REPO="https://github.com/DroBov1Tya/kali-mcp.git"
KALI_REVISION="167cff30facde70e143cb6d76861f46065dbdb0b"
STRIX_REPO="https://github.com/usestrix/strix.git"
STRIX_REVISION="972f5097c2bfaf8f1dd8b55744ab8861f0d6b6e5"
OWASP_REPO="https://github.com/OWASP/secure-agent-playbook.git"
OWASP_REVISION="65d4efd2cd0b081d52101e9708792b944e4ddebb"
PUBLIC_SKILLS_REPO="https://github.com/securityskills/skills.git"
PUBLIC_SKILLS_REVISION="b2b6b5200ee91a249816df209a0b89ff01ae450a"

PROFILE="pentest"
TEMP_ROOT=""
SOURCE_ROOT=""
SKILLS_ADDED=0
SKILLS_KEPT=0

cleanup() {
  [[ -z "$TEMP_ROOT" ]] || rm -rf "$TEMP_ROOT"
  [[ -z "${skill_tmp:-}" ]] || rm -f "$skill_tmp"
  [[ -z "${soul_tmp:-}" ]] || rm -f "$soul_tmp"
  [[ -z "${tmp_binary:-}" ]] || rm -f "$tmp_binary"
}
trap cleanup EXIT
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'; C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'
else
  C_RESET=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""
fi
CURRENT_STEP='startup'
on_error() {
  local line="$1" status="$2"
  trap - ERR
  printf '%s❌ Error during "%s" (line %s, exit code %s).%s\n' "$C_RED" "$CURRENT_STEP" "$line" "$status" "$C_RESET" >&2
  printf 'See the message above and retry. Files already written will remain in place.\n' >&2
  exit "$status"
}
trap 'on_error "$LINENO" "$?"' ERR
info() { printf '%sℹ️  %s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
step() { CURRENT_STEP="$*"; printf '\n%s🔹 %s%s\n' "$C_CYAN" "$*" "$C_RESET"; }
success() { printf '%s✅ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warning() { printf '%s⚠️  %s%s\n' "$C_YELLOW" "$*" "$C_RESET"; }
die() { printf '%s❌ Error: %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
run() {
  printf '%s▶%s' "$C_CYAN" "$C_RESET"; printf ' %q' "$@"; printf '\n'
  # Interactive Hermes commands need a terminal even when this script came from curl | bash.
  if [[ "${1:-}" == hermes ]]; then "$@" </dev/tty; else "$@"; fi
}
ask_yes_no() {
  local prompt="$1" default="$2" answer suffix
  [[ "$default" == yes ]] && suffix='[Y/n]' || suffix='[y/N]'
  while true; do
    printf '%s %s ' "$prompt" "$suffix"
    IFS= read -r answer </dev/tty || die "Could not read a response from the terminal."
    answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "$answer" ]]; then [[ "$default" == yes ]]; return; fi
    case "$answer" in y|yes) return 0 ;; n|no) return 1 ;; *) printf 'Enter y or n.\n' ;; esac
  done
}
install_git_if_missing() {
  command -v git >/dev/null 2>&1 && return
  warning 'Git is required to download the installer source.'
  if command -v brew >/dev/null 2>&1; then
    ask_yes_no 'Install Git with Homebrew?' yes || die 'Install Git, then run this installer again.'
    run brew install git
  elif command -v apt-get >/dev/null 2>&1; then
    ask_yes_no 'Install Git with apt?' yes || die 'Install Git, then run this installer again.'
    if [[ "$(id -u)" -eq 0 ]]; then run apt-get update; run apt-get install -y git
    elif command -v sudo >/dev/null 2>&1; then run sudo apt-get update; run sudo apt-get install -y git
    else die 'Installing packages with apt requires root or sudo.'; fi
  else
    die 'Git was not found. Install it with your OS package manager, then retry.'
  fi
  need git
}
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else die "Install sha256sum or shasum to verify the PentaCore archive."; fi
}

# Keep Bash's stdin attached to the script when invoked through curl | bash.
# Individual read calls below use /dev/tty so they cannot replace the script
# stream or accidentally make Bash wait for more shell code from the user.
[[ -r /dev/tty && -w /dev/tty ]] || die "An interactive terminal is required. Run this command from a terminal window."

step 'Preparing installer source'
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
else
  install_git_if_missing
  TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-setup.XXXXXX")"
  SOURCE_ROOT="$TEMP_ROOT/source"
  info 'Downloading installer files from GitHub. This usually takes a few seconds.'
  run git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=30 clone --progress --depth 1 --branch "$REPO_REF" "$REPO_URL" "$SOURCE_ROOT"
fi

select_item() {
  local key="$1" prompt="$2" default="$3" value icon
  MENU_INDEX=$((MENU_INDEX + 1))
  printf '\n%s%02d/%02d%s ' "$C_BOLD" "$MENU_INDEX" "$MENU_TOTAL" "$C_RESET"
  if ask_yes_no "$prompt" "$default"; then value=yes; else value=no; fi
  printf -v "SELECTED_$key" '%s' "$value"
  if [[ "$value" == yes ]]; then icon='✓'; else icon='–'; fi
  printf '   %s %s\n' "$icon" "$prompt"
  SELECTION_SUMMARY+=("   $icon $prompt")
}

skip_item() {
  local key="$1" prompt="$2"
  MENU_INDEX=$((MENU_INDEX + 1))
  printf '\n%s%02d/%02d%s ' "$C_BOLD" "$MENU_INDEX" "$MENU_TOTAL" "$C_RESET"
  printf '   ⏭️  %s\n' "$prompt"
  printf -v "SELECTED_$key" '%s' no
  SELECTION_SUMMARY+=("   ⏭️  $prompt")
}

printf '\n%s🛠️  Hermes Pentest Setup%s\n' "$C_BOLD" "$C_RESET"
printf '────────────────────────────────────────\n'
printf 'Create a dedicated Hermes profile and add the selected MCP servers and skills.\n'
printf 'This installer does not scan targets or start Docker services.\n\n'
printf '👤 Profile name [%s]: ' "$PROFILE"
IFS= read -r profile_answer </dev/tty || die "Could not read the profile name from the terminal."
if [[ -n "$profile_answer" ]]; then PROFILE="$profile_answer"; fi
[[ "$PROFILE" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$ ]] || die "Profile name must be 1–32 characters: ASCII letters, digits, '_' or '-'."
HOME_DIR="${HOME:?HOME is not set}"
HERMES_HOME_DIR="${HERMES_HOME:-$HOME_DIR/.hermes}"
PROFILE_DIR="$HERMES_HOME_DIR/profiles/$PROFILE"

MENU_INDEX=0
MENU_TOTAL=8
SELECTION_SUMMARY=()
printf '\n%s📦 Components%s\n' "$C_BOLD" "$C_RESET"
info 'Choose y/n; press Enter to accept the option in brackets.'
select_item pentacore 'PentaCore memory MCP and bundled skill' yes
select_item kali 'kali-mcp: MCP server and kali-workbench skill' yes
select_item playwright 'Microsoft Playwright MCP' no
select_item strix 'Strix: 29 vulnerability playbooks and LLM skill' yes
select_item mcp_review 'OWASP MCP review skill' yes
select_item report_writing 'Bug bounty report-writing skill' yes
select_item custom_skills 'Supplied workflow and management skills' yes
if [[ -L "$PROFILE_DIR/SOUL.md" ]]; then
  skip_item soul 'SOUL.md is a symlink; it will be left unchanged'
elif [[ -e "$PROFILE_DIR/SOUL.md" && ! -f "$PROFILE_DIR/SOUL.md" ]]; then
  skip_item soul 'SOUL.md is a special file; it will be left unchanged'
elif [[ -f "$PROFILE_DIR/SOUL.md" ]]; then
  if cmp -s "$SOURCE_ROOT/SOUL.md" "$PROFILE_DIR/SOUL.md"; then
    select_item soul 'SOUL.md already matches the supplied file' yes
  else
    select_item soul 'Replace existing SOUL.md (a backup will be created)' no
  fi
else
  select_item soul 'Add the supplied SOUL.md to this profile' yes
fi

step 'Review your selections'
printf '👤 Profile: %s\n' "$PROFILE"
printf '%s\n' "${SELECTION_SUMMARY[@]}"
if ! ask_yes_no 'Continue and apply these changes?' yes; then
  info 'Installation cancelled before profile changes were made.'
  exit 0
fi
success 'Selections confirmed.'

step 'Checking dependencies for selected components'

missing=()
for command_name in hermes git curl sqlite3; do command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name"); done
[[ "$SELECTED_kali" != yes ]] || { command -v uv >/dev/null 2>&1 || missing+=(uv); command -v docker >/dev/null 2>&1 || missing+=(docker); }
[[ "$SELECTED_playwright" != yes ]] || { command -v npx >/dev/null 2>&1 || missing+=(npx); }
if [[ "$SELECTED_pentacore" == yes ]]; then
  for command_name in jq tar; do command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name"); done
  command -v sha256sum >/dev/null 2>&1 || { command -v shasum >/dev/null 2>&1 || missing+=(sha256); }
fi

if ((${#missing[@]})); then
  warning "Missing dependencies: ${missing[*]}"
  installable=()
  brew_cask_docker=no
  if command -v brew >/dev/null 2>&1; then
    for command_name in "${missing[@]}"; do
      case "$command_name" in
        hermes) ;;
        git|jq|sqlite3|uv|curl) installable+=("$command_name") ;;
        tar) installable+=("gnu-tar") ;;
        npx) installable+=(node) ;;
        docker) brew_cask_docker=yes ;;
        sha256) ;;
      esac
    done
    if ((${#installable[@]})); then
      info "Homebrew can install: ${installable[*]}"
      if ask_yes_no 'Install these dependencies now?' yes; then run brew install "${installable[@]}"; fi
    fi
    if [[ "$brew_cask_docker" == yes ]]; then
      info 'Docker Desktop will be installed; start it manually afterward.'
      if ask_yes_no 'Install Docker Desktop now?' yes; then run brew install --cask docker; fi
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    for command_name in "${missing[@]}"; do
      case "$command_name" in
        git|jq|sqlite3|curl|tar) installable+=("$command_name") ;;
        npx) installable+=(nodejs npm) ;;
        docker) installable+=(docker.io) ;;
        sha256) ;;
        hermes|uv) ;;
      esac
    done
    if ((${#installable[@]})); then
      info "apt can install: ${installable[*]}"
      if ask_yes_no 'Install these dependencies now?' yes; then
        if [[ "$(id -u)" -eq 0 ]]; then run apt-get update; run apt-get install -y "${installable[@]}"
        elif command -v sudo >/dev/null 2>&1; then run sudo apt-get update; run sudo apt-get install -y "${installable[@]}"
    else die 'Installing packages with apt requires root or sudo.'; fi
      fi
    fi
  else
    warning 'No supported package manager was found. Install dependencies with your OS package manager.'
  fi

  if [[ " ${missing[*]} " == *' hermes '* ]] && ! command -v hermes >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1; then
      if ask_yes_no 'Install Hermes Agent with its official installer?' yes; then
        run bash -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash'
        export PATH="$HOME/.local/bin:$HOME/.hermes/bin:$PATH"
      fi
    fi
  fi
  if [[ " ${missing[*]} " == *' uv '* ]] && ! command -v uv >/dev/null 2>&1; then
    if ask_yes_no 'Install uv with Astral’s official installer?' yes; then
      run bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
      export PATH="$HOME/.local/bin:$PATH"
    fi
  fi
  if [[ " ${missing[*]} " == *' sha256 '* ]] && ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    warning 'Install a SHA-256 utility (sha256sum or shasum) to verify PentaCore.'
  fi
else
  success 'All selected component dependencies are available.'
fi

need hermes
need git
need curl
need sqlite3
[[ "$SELECTED_kali" != yes ]] || { need uv; need docker; }
[[ "$SELECTED_playwright" != yes ]] || need npx
if [[ "$SELECTED_pentacore" == yes ]]; then need jq; need tar; command -v sha256sum >/dev/null 2>&1 || need shasum; fi

HOME_DIR="${HOME:?HOME is not set}"
DATA_DIR="$HOME_DIR/.local/share/hermes-pentest"
BIN_DIR="$HOME_DIR/.local/opt/hermes-pentest"
mkdir -p "$DATA_DIR" "$BIN_DIR"

if [[ ! -d "$PROFILE_DIR" ]]; then
  step "Creating Hermes profile: $PROFILE"
  run hermes profile create "$PROFILE"
else
  info "Using existing profile: $PROFILE_DIR"
fi
[[ ! -L "$PROFILE_DIR/skills" ]] || die "The profile skills directory is a symlink; refusing to write through it."
mkdir -p "$PROFILE_DIR/skills"

install_skill_file() {
  local source="$1" target_name="$2" target skill_file
  target="$PROFILE_DIR/skills/$target_name"
  skill_file="$target/SKILL.md"
  [[ -f "$source" && ! -L "$source" ]] || die "Skill source is missing or is not a regular file: $source"
  [[ ! -L "$PROFILE_DIR/skills" ]] || die "The profile skills directory is a symlink: $PROFILE_DIR/skills"
  [[ ! -L "$target" ]] || die "Skill path is a symlink: $target"
  [[ ! -L "$skill_file" ]] || die "SKILL.md is a symlink: $skill_file"
  [[ ! -e "$skill_file" || -f "$skill_file" ]] || die "SKILL.md path is not a regular file: $skill_file"
  if [[ -s "$skill_file" ]]; then SKILLS_KEPT=$((SKILLS_KEPT + 1)); info "Skill already installed: $target_name"; return; fi
  [[ ! -e "$target" || -d "$target" ]] || die "Skill path is not a directory: $target"
  mkdir -p "$target"
  skill_tmp="$(mktemp "$target/.SKILL.md.new.XXXXXX")"
  cp "$source" "$skill_tmp"
  mv -f "$skill_tmp" "$skill_file"
  SKILLS_ADDED=$((SKILLS_ADDED + 1))
  success "Installed skill: $target_name"
}

install_skill_from_git() {
  local repo="$1" revision="$2" path="$3" name="$4"
  [[ -n "$TEMP_ROOT" ]] || { TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-setup.XXXXXX")"; trap cleanup EXIT; }
  local work="$TEMP_ROOT/source-git-${name}"
  mkdir -p "$work"
  info "Fetching $name from $repo ($revision)."
  run git -C "$work" init -q
  run git -C "$work" remote add origin "$repo"
  run git -C "$work" fetch --quiet --depth=1 origin "$revision"
  local actual
  actual="$(git -C "$work" rev-parse FETCH_HEAD)"
  [[ "$actual" == "$revision" ]] || die "GitHub returned an unexpected $name revision: $actual"
  git -C "$work" show "$revision:$path" > "$work/SKILL.md" || die "Skill file not found in $repo@$revision: $path"
  install_skill_file "$work/SKILL.md" "$name"
}

add_mcp() {
  local name="$1" command="$2"; shift 2
  local servers
  servers="$(hermes -p "$PROFILE" mcp list)" || die "Could not inspect the profile MCP configuration."
  if printf '%s\n' "$servers" | awk -v wanted="$name" '$1 == wanted {found=1} END {exit !found}'; then
    info "MCP server is already registered: $name"; return
  fi
  if (($#)); then run hermes -p "$PROFILE" mcp add "$name" --command "$command" --args "$@"
  else run hermes -p "$PROFILE" mcp add "$name" --command "$command"; fi
}

if [[ "$SELECTED_soul" == yes ]]; then
  step 'Installing SOUL.md'
  [[ ! -L "$PROFILE_DIR/SOUL.md" ]] || die "The profile SOUL.md is a symlink; refusing to overwrite it."
  if [[ -f "$PROFILE_DIR/SOUL.md" ]] && cmp -s "$SOURCE_ROOT/SOUL.md" "$PROFILE_DIR/SOUL.md"; then
    info 'SOUL.md already matches the supplied file.'
  elif [[ -e "$PROFILE_DIR/SOUL.md" ]]; then
    soul_backup="$PROFILE_DIR/SOUL.md.backup.$(date +%Y%m%d-%H%M%S)-$$"
    cp -p "$PROFILE_DIR/SOUL.md" "$soul_backup"
    soul_tmp="$(mktemp "$PROFILE_DIR/.SOUL.md.new.XXXXXX")"
    cp "$SOURCE_ROOT/SOUL.md" "$soul_tmp"
    mv -f "$soul_tmp" "$PROFILE_DIR/SOUL.md"
    success "SOUL.md replaced; the previous version is backed up at $soul_backup"
  else
    soul_tmp="$(mktemp "$PROFILE_DIR/.SOUL.md.new.XXXXXX")"
    cp "$SOURCE_ROOT/SOUL.md" "$soul_tmp"
    mv -f "$soul_tmp" "$PROFILE_DIR/SOUL.md"
    success 'SOUL.md installed.'
  fi
fi

if [[ "$SELECTED_custom_skills" == yes ]]; then
  step 'Installing supplied workflow and management skills'
  for skill in "$SOURCE_ROOT"/skills/*; do
    [[ -d "$skill" && ! -L "$skill" ]] || continue
    target="$PROFILE_DIR/skills/$(basename "$skill")"
    [[ ! -L "$target" ]] || die "The supplied skill path is a symlink: $target"
    if [[ -e "$target" ]]; then
      [[ -d "$target" ]] || die "The supplied skill path is not a directory: $target"
      [[ ! -L "$target/SKILL.md" ]] || die "SKILL.md is a symlink: $target/SKILL.md"
      nested_link="$(find "$target" -type l -print -quit)" || die "Could not inspect symlinks in: $target"
      [[ -z "$nested_link" ]] || die "An incomplete skill directory contains a symlink; resolve it manually: $nested_link"
      if [[ -s "$target/SKILL.md" ]]; then
        SKILLS_KEPT=$((SKILLS_KEPT + 1)); info "Skill already exists: $(basename "$skill")"
      else
        cp -Rn "$skill/." "$target/"
        if [[ -f "$skill/SKILL.md" ]]; then
          skill_tmp="$(mktemp "$target/.SKILL.md.new.XXXXXX")"
          cp "$skill/SKILL.md" "$skill_tmp"
          mv -f "$skill_tmp" "$target/SKILL.md"
        fi
        [[ -f "$target/SKILL.md" ]] || die "Could not restore SKILL.md: $target"
        SKILLS_ADDED=$((SKILLS_ADDED + 1)); success "Repaired incomplete skill: $(basename "$skill")"
      fi
    else
      cp -R "$skill" "$target"
      SKILLS_ADDED=$((SKILLS_ADDED + 1)); success "Installed skill: $(basename "$skill")"
    fi
  done
fi

if [[ "$SELECTED_pentacore" == yes ]]; then
  step 'Downloading and configuring PentaCore'
  machine="$(uname -m)"; system="$(uname -s)"
  case "$machine" in arm64|aarch64) arch=aarch64 ;; x86_64|amd64) arch=x86_64 ;; *) die "PentaCore does not support architecture $machine." ;; esac
  case "$system/$arch" in Darwin/aarch64) suffix=aarch64-apple-darwin ;; Linux/aarch64|Linux/x86_64) suffix="$arch-unknown-linux-gnu" ;; *) die "No PentaCore build is available for $system/$arch." ;; esac
  info "Finding a compatible release for $system/$arch."
  release="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$PENTACORE_API?per_page=100" | jq -cer '[.[] | select(.draft == false)][0]')"
  version="$(jq -er '.tag_name | ltrimstr("v")' <<<"$release")"
  archive="pentacore-$version-$suffix.tar.gz"
  asset_url="$(jq -er --arg name "$archive" '[.assets[] | select(.name == $name) | .browser_download_url][0]' <<<"$release")"
  sums_url="$(jq -er '[.assets[] | select(.name == "SHA256SUMS") | .browser_download_url][0]' <<<"$release")"
  [[ -n "$asset_url" && -n "$sums_url" ]] || die "PentaCore release $version is missing the expected archive or SHA256SUMS."
  info "Downloading PentaCore $version and its checksum file."
  [[ -n "$TEMP_ROOT" ]] || { TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-setup.XXXXXX")"; trap cleanup EXIT; }
  archive_path="$TEMP_ROOT/$archive"; sums_path="$TEMP_ROOT/SHA256SUMS"
  curl -fL --retry 3 "$asset_url" -o "$archive_path"
  curl -fL --retry 3 "$sums_url" -o "$sums_path"
  expected_hash="$(awk -v file="$archive" '$2 == file || $2 == ("*" file) {print $1; exit}' "$sums_path")"
  [[ "$expected_hash" =~ ^[a-fA-F0-9]{64}$ ]] || die "No valid SHA-256 entry found for $archive."
  actual_hash="$(sha256_file "$archive_path")"
  actual_hash="$(printf '%s' "$actual_hash" | tr '[:upper:]' '[:lower:]')"
  expected_hash="$(printf '%s' "$expected_hash" | tr '[:upper:]' '[:lower:]')"
  [[ "$actual_hash" == "$expected_hash" ]] || die "PentaCore archive SHA-256 verification failed."
  # Consume the full tar listing: an early awk exit can SIGPIPE tar under pipefail.
  binary_member="$(tar -tzf "$archive_path" | awk '($0 == "pentacore" || $0 ~ /\/pentacore$/) && $0 !~ /(^|\/)\.\.(\/|$)/ && !found {print; found=1}')"
  [[ -n "$binary_member" ]] || die "No PentaCore executable was found in the archive."
  tar -tvzf "$archive_path" | awk -v path="$binary_member" 'substr($0, 1, 1) == "-" && $NF == path {found=1} END {exit !found}' || die "The PentaCore executable in the archive is not a regular file."
  tmp_binary="$(mktemp "$BIN_DIR/.pentacore.XXXXXX")"
  tar -xOzf "$archive_path" "$binary_member" > "$tmp_binary"
  chmod 755 "$tmp_binary"; mv -f "$tmp_binary" "$BIN_DIR/pentacore"
  skill_paths="$(tar -tzf "$archive_path" | awk '/(^|\/)skills\/pentacore-memory\/.*\.md$/ && $0 !~ /(^|\/)\.\.(\/|$)/')"
  while IFS= read -r member; do
    [[ -n "$member" ]] || continue
    relative="${member#*skills/pentacore-memory/}"
    [[ "$relative" != "$member" && "$relative" != /* && "$relative" != *'..'* ]] || die "Unsafe skill path found in the PentaCore archive."
    parent_relative="$(dirname "$relative")"
    skills_dir="$PROFILE_DIR/skills"
    [[ ! -L "$skills_dir" ]] || die "The skills directory is a symlink; refusing to write through it."
    current_dir="$skills_dir/pentacore-memory"
    [[ ! -L "$current_dir" ]] || die "PentaCore skill path is a symlink: $current_dir"
    [[ ! -e "$current_dir" || -d "$current_dir" ]] || die "PentaCore skill path is not a directory: $current_dir"
    mkdir -p "$current_dir"
    if [[ "$parent_relative" != . ]]; then
      IFS=/ read -r -a path_parts <<< "$parent_relative"
      for path_part in "${path_parts[@]}"; do
        [[ -n "$path_part" && "$path_part" != . && "$path_part" != .. ]] || die "Unsafe path component found in the PentaCore archive."
        current_dir="$current_dir/$path_part"
        [[ ! -L "$current_dir" ]] || die "PentaCore skill path is a symlink: $current_dir"
        [[ ! -e "$current_dir" || -d "$current_dir" ]] || die "PentaCore skill path component is not a directory: $current_dir"
        mkdir -p "$current_dir"
      done
    fi
    destination="$current_dir/$(basename "$relative")"
    [[ ! -L "$destination" ]] || die "PentaCore skill file is a symlink: $destination"
    if [[ -e "$destination" ]]; then
      [[ -f "$destination" && ! -L "$destination" ]] || die "PentaCore skill path is not a regular file: $destination"
      if [[ -s "$destination" ]]; then
        if [[ "$(basename "$destination")" == SKILL.md ]]; then SKILLS_KEPT=$((SKILLS_KEPT + 1)); fi
        continue
      fi
      warning "Restoring empty skill file from the archive: $destination"
      skill_tmp="$(mktemp "${destination}.new.XXXXXX")"
      tar -xOzf "$archive_path" "$member" > "$skill_tmp"
      mv -f "$skill_tmp" "$destination"
      if [[ "$(basename "$destination")" == SKILL.md ]]; then SKILLS_ADDED=$((SKILLS_ADDED + 1)); fi
      continue
    fi
    mkdir -p "$(dirname "$destination")"
    skill_tmp="$(mktemp "${destination}.new.XXXXXX")"
    tar -xOzf "$archive_path" "$member" > "$skill_tmp"
    mv -f "$skill_tmp" "$destination"
    if [[ "$(basename "$destination")" == SKILL.md ]]; then SKILLS_ADDED=$((SKILLS_ADDED + 1)); fi
  done <<< "$skill_paths"
  add_mcp pentacore "$BIN_DIR/pentacore"
  env_file="$PROFILE_DIR/.env"
  [[ ! -L "$env_file" ]] || die "The profile .env file is a symlink: $env_file"
  if [[ ! -e "$env_file" ]]; then printf 'PENTACORE_PROJECT=hermes-pentest\n' > "$env_file"; chmod 600 "$env_file"; fi
  success "PentaCore $version installed, SHA-256 verified, and MCP registered."
fi

if [[ "$SELECTED_kali" == yes ]]; then
  step 'Installing kali-mcp and the kali-workbench skill'
  KALI_DIR="$DATA_DIR/kali-mcp"
  [[ ! -L "$KALI_DIR" ]] || die "The kali-mcp directory is a symlink: $KALI_DIR"
  if [[ -e "$KALI_DIR" ]]; then
    [[ -d "$KALI_DIR/.git" ]] || die "The kali-mcp directory exists but is not a Git checkout: $KALI_DIR"
    [[ -z "$(git -C "$KALI_DIR" status --porcelain --untracked-files=all)" ]] || die "The kali-mcp checkout has local changes; they were preserved: $KALI_DIR"
    [[ "$(git -C "$KALI_DIR" config --get remote.origin.url || true)" == "$KALI_REPO" ]] || die "The kali-mcp checkout has an unexpected origin: $KALI_DIR"
    kali_head="$(git -C "$KALI_DIR" rev-parse --verify HEAD 2>/dev/null || true)"
    [[ -z "$kali_head" || "$kali_head" == "$KALI_REVISION" ]] || die "The kali-mcp checkout is not at the pinned revision: $KALI_DIR"
    info "Resuming kali-mcp checkout: $KALI_DIR"
  else
    mkdir -p "$KALI_DIR"
    run git -C "$KALI_DIR" init -q
    run git -C "$KALI_DIR" remote add origin "$KALI_REPO"
  fi
  run git -C "$KALI_DIR" fetch --depth=1 origin "$KALI_REVISION"
  run git -C "$KALI_DIR" checkout --detach FETCH_HEAD
  [[ "$(git -C "$KALI_DIR" rev-parse HEAD)" == "$KALI_REVISION" ]] || die "GitHub returned an unexpected kali-mcp revision."
  run uv sync --locked --project "$KALI_DIR/mcp"
  if [[ ! -e "$KALI_DIR/.env" ]]; then cp "$KALI_DIR/.env.example" "$KALI_DIR/.env"; chmod 600 "$KALI_DIR/.env"; fi
  install_skill_file "$KALI_DIR/skill/kali-workbench.md" kali-workbench
  add_mcp kali-shell uv run --directory "$KALI_DIR/mcp" python -u server.py
  success "kali-mcp and kali-workbench skill installed. Configure $KALI_DIR/.env before starting Docker."
fi

if [[ "$SELECTED_strix" == yes ]]; then
  step 'Installing Strix vulnerability playbooks'
  STRIX_DIR="$DATA_DIR/strix"
  if [[ ! -e "$STRIX_DIR" ]]; then
    mkdir -p "$STRIX_DIR"
    run git -C "$STRIX_DIR" init -q
    run git -C "$STRIX_DIR" remote add origin "$STRIX_REPO"
  else
    [[ -d "$STRIX_DIR/.git" ]] || die "The Strix directory exists but is not a Git checkout: $STRIX_DIR"
    [[ -z "$(git -C "$STRIX_DIR" status --porcelain --untracked-files=all)" ]] || die "The Strix checkout has local changes; they were preserved: $STRIX_DIR"
    [[ "$(git -C "$STRIX_DIR" config --get remote.origin.url || true)" == "$STRIX_REPO" ]] || die "The Strix checkout has an unexpected origin: $STRIX_DIR"
    strix_head="$(git -C "$STRIX_DIR" rev-parse --verify HEAD 2>/dev/null || true)"
    [[ -z "$strix_head" || "$strix_head" == "$STRIX_REVISION" ]] || die "The Strix source is not at the pinned revision: $STRIX_DIR"
  fi
  run git -C "$STRIX_DIR" fetch --depth=1 origin "$STRIX_REVISION"
  run git -C "$STRIX_DIR" checkout --detach FETCH_HEAD
  [[ "$(git -C "$STRIX_DIR" rev-parse HEAD)" == "$STRIX_REVISION" ]] || die "The Strix source is not at the pinned revision: $STRIX_DIR"
  info 'Reading the Strix skill list and adding skills to the profile.'
  strix_paths="$(git -C "$STRIX_DIR" ls-tree -r --name-only "$STRIX_REVISION" -- strix/skills/vulnerabilities strix/skills/technologies/llm_applications.md)" || die 'Could not read the Strix skill list.'
  strix_total="$(printf '%s\n' "$strix_paths" | awk 'NF {n++} END {print n+0}')"
  strix_index=0
  while IFS= read -r path; do
    [[ "$path" == *.md ]] || continue
    strix_index=$((strix_index + 1))
    if ((strix_index == 1 || strix_index % 5 == 0 || strix_index == strix_total)); then
      info "Processing Strix skills: $strix_index of $strix_total."
    fi
    case "$path" in strix/skills/vulnerabilities/*|strix/skills/technologies/llm_applications.md) ;; *) die "Unexpected Strix skill path: $path" ;; esac
    name="$(git -C "$STRIX_DIR" show "$STRIX_REVISION:$path" | sed -n 's/^name:[[:space:]]*\([a-z0-9][a-z0-9_-]*\)[[:space:]]*$/\1/p' | awk 'NR == 1 {first=$0} END {print first}')"
    [[ -n "$name" ]] || die "Could not determine a valid Hermes name for Strix skill: $path"
    [[ ! -L "$PROFILE_DIR/skills/strix" ]] || die "The Strix skills directory is a symlink: $PROFILE_DIR/skills/strix"
    dest="$PROFILE_DIR/skills/strix/$name"
    [[ ! -L "$dest" ]] || die "The Strix skill path is a symlink: $dest"
    if [[ -e "$dest/SKILL.md" ]]; then
      [[ -f "$dest/SKILL.md" && ! -L "$dest/SKILL.md" ]] || die "Strix SKILL.md is not a regular file: $dest/SKILL.md"
      if [[ ! -s "$dest/SKILL.md" ]]; then
        skill_tmp="$(mktemp "$dest/.SKILL.md.new.XXXXXX")"
        git -C "$STRIX_DIR" show "$STRIX_REVISION:$path" > "$skill_tmp"
        mv -f "$skill_tmp" "$dest/SKILL.md"
        SKILLS_ADDED=$((SKILLS_ADDED + 1))
        success "Repaired incomplete Strix skill: $name"
        continue
      fi
      SKILLS_KEPT=$((SKILLS_KEPT + 1)); info "Strix skill already exists: $name"; continue
    fi
    mkdir -p "$dest"
    skill_tmp="$(mktemp "$dest/.SKILL.md.new.XXXXXX")"
    git -C "$STRIX_DIR" show "$STRIX_REVISION:$path" > "$skill_tmp"
    mv -f "$skill_tmp" "$dest/SKILL.md"
    SKILLS_ADDED=$((SKILLS_ADDED + 1))
  done <<< "$strix_paths"
  success "Strix skills installed from revision $STRIX_REVISION."
fi

if [[ "$SELECTED_mcp_review" == yes ]]; then
  step 'Installing OWASP MCP review skill'
  install_skill_from_git "$OWASP_REPO" "$OWASP_REVISION" plugins/ai-security-skills/skills/mcp-server-review/SKILL.md mcp-server-review
  success 'OWASP MCP review skill installed.'
fi
if [[ "$SELECTED_report_writing" == yes ]]; then
  step 'Installing bug bounty report-writing skill'
  install_skill_from_git "$PUBLIC_SKILLS_REPO" "$PUBLIC_SKILLS_REVISION" bug-bounty/bug-bounty-report-writing/SKILL.md bug-bounty-report-writing
  success 'Bug bounty report-writing skill installed.'
fi

if [[ "$SELECTED_playwright" == yes ]]; then
  step 'Registering Microsoft Playwright MCP'
  add_mcp playwright npx -y @playwright/mcp@latest --isolated
  success 'Playwright MCP registered. Configure browser scope before use.'
fi

# Enable the useful built-in CLI toolsets in the selected profile. Hermes
# applies these changes to new sessions; an already-running TUI may need /reset.
step 'Enabling Hermes CLI toolsets: web, browser, todo'
run hermes -p "$PROFILE" tools enable web browser todo --platform cli
success 'CLI toolsets enabled.'

skill_file_count="$(find "$PROFILE_DIR/skills" -type f -name SKILL.md | wc -l | tr -d '[:space:]')"
printf '\n%s📚 Skills in profile (%s)%s\n' "$C_BOLD" "$skill_file_count" "$C_RESET"
printf '   %s\n' "$PROFILE_DIR/skills"
printf '   ➕ Added: %s | ↪ Already present: %s\n' "$SKILLS_ADDED" "$SKILLS_KEPT"
find "$PROFILE_DIR/skills" -type f -name SKILL.md -print | sort
printf '\n%s🔎 Checking the skills visible to Hermes%s\n' "$C_BOLD" "$C_RESET"
run hermes -p "$PROFILE" skills list

printf '\n%s✅ Installation complete%s\n' "$C_GREEN" "$C_RESET"
printf '👤 Profile: %s\n' "$PROFILE"
printf '🔌 MCP:     hermes -p %q mcp list\n' "$PROFILE"
printf '🧰 Tools:   hermes -p %q tools list --platform cli\n' "$PROFILE"
printf '🔄 Start a new Hermes session or run /reset in the current TUI.\n'
printf '\n%s🧠 Next step: configure your AI provider%s\n' "$C_BOLD" "$C_RESET"
printf '   hermes -p %q setup\n' "$PROFILE"
if [[ "$SELECTED_kali" == yes ]]; then
  printf '🐳 Kali: configure %s/.env, then start Docker Compose manually.\n' "$DATA_DIR/kali-mcp"
else
  printf '🐳 Docker containers were not started by the installer.\n'
fi
