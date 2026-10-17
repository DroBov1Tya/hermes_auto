#!/usr/bin/env bash
set -Eeuo pipefail

# Interactive bootstrap for a Hermes security-assessment profile.
# When piped from curl, fetch this repository into a temporary directory so
# SOUL.md and the user-provided skills are available to the installer.

[[ $# -eq 0 ]] || { printf 'This installer uses an interactive menu; do not pass flags.\n' >&2; exit 2; }

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

cleanup() { [[ -z "$TEMP_ROOT" ]] || rm -rf -- "$TEMP_ROOT"; }
trap cleanup EXIT
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
run() { printf '+'; printf ' %q' "$@"; printf '\n'; "$@"; }
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else die "Install sha256sum or shasum to verify the PentaCore archive"; fi
}

# curl | bash leaves stdin attached to the curl pipe. Read answers from the
# terminal, but keep stdout on its original stream so the menu stays visible.
if [[ ! -t 0 || ! -t 1 ]]; then
  if [[ -r /dev/tty && -w /dev/tty ]]; then
    exec </dev/tty
  else
    die "Interactive terminal required. Start this command from a terminal."
  fi
fi

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SOURCE_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
else
  need git
  TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-setup.XXXXXX")"
  SOURCE_ROOT="$TEMP_ROOT/source"
  run git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$SOURCE_ROOT"
fi

ask_yes_no() {
  local prompt="$1" default="$2" answer suffix
  [[ "$default" == yes ]] && suffix='[Y/n]' || suffix='[y/N]'
  while true; do
    printf '%s %s ' "$prompt" "$suffix"
    IFS= read -r answer
    answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "$answer" ]]; then [[ "$default" == yes ]]; return; fi
    case "$answer" in y|yes|д|да) return 0 ;; n|no|н|нет) return 1 ;; *) printf 'Enter y or n.\n' ;; esac
  done
}

select_item() {
  local key="$1" prompt="$2" default="$3" value
  if ask_yes_no "$prompt" "$default"; then value=yes; else value=no; fi
  printf -v "SELECTED_$key" '%s' "$value"
}

printf '\nHermes security profile installer\nProfile name [%s]: ' "$PROFILE"
IFS= read -r profile_answer
if [[ -n "$profile_answer" ]]; then PROFILE="$profile_answer"; fi
[[ "$PROFILE" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$ ]] || die "Profile name must be 1-32 ASCII letters, digits, '_' or '-'."

printf '\nChoose the components to install. Press Enter to accept the suggested choice.\n\n'
select_item pentacore 'Add PentaCore memory MCP and its bundled skill?' yes
select_item kali 'Add kali-mcp, its MCP server and kali-workbench skill?' yes
select_item playwright 'Add Microsoft Playwright MCP?' no
select_item strix 'Add Strix vulnerability playbooks (29) and LLM application skill?' yes
select_item mcp_review 'Add OWASP MCP server source-review skill?' yes
select_item report_writing 'Add bug-bounty report-writing skill?' yes
select_item custom_skills 'Add the supplied workflow/management skills?' yes
select_item soul 'Install the supplied SOUL.md in this profile?' yes

need hermes
need git
[[ "$SELECTED_kali" != yes ]] || { need uv; need docker; }
[[ "$SELECTED_playwright" != yes ]] || need npx
if [[ "$SELECTED_pentacore" == yes ]]; then
  need curl; need jq; need tar
  command -v sha256sum >/dev/null 2>&1 || need shasum
fi

HOME_DIR="${HOME:?HOME is not set}"
HERMES_HOME_DIR="${HERMES_HOME:-$HOME_DIR/.hermes}"
PROFILE_DIR="$HERMES_HOME_DIR/profiles/$PROFILE"
DATA_DIR="$HOME_DIR/.local/share/hermes-pentest"
BIN_DIR="$HOME_DIR/.local/opt/hermes-pentest"
mkdir -p "$DATA_DIR" "$BIN_DIR"

if [[ ! -d "$PROFILE_DIR" ]]; then
  run hermes profile create "$PROFILE"
else
  printf 'Keeping existing Hermes profile at %s.\n' "$PROFILE_DIR"
fi
[[ ! -L "$PROFILE_DIR/skills" ]] || die "Refusing to use a symlink as the profile skills directory"
mkdir -p "$PROFILE_DIR/skills"

install_skill_file() {
  local source="$1" target_name="$2" target
  target="$PROFILE_DIR/skills/$target_name"
  [[ -f "$source" && ! -L "$source" ]] || die "Skill source missing or not a regular file: $source"
  [[ ! -L "$PROFILE_DIR/skills" ]] || die "Refusing to install skills through a symlink: $PROFILE_DIR/skills"
  [[ ! -L "$target" ]] || die "Refusing to install through a skill symlink: $target"
  if [[ -e "$target" ]]; then printf 'Keeping existing skill: %s\n' "$target_name"; return; fi
  mkdir -p "$target"
  cp -- "$source" "$target/SKILL.md"
}

install_skill_from_git() {
  local repo="$1" revision="$2" path="$3" name="$4"
  [[ -n "$TEMP_ROOT" ]] || { TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-setup.XXXXXX")"; trap cleanup EXIT; }
  local work="$TEMP_ROOT/source-git-${name}"
  mkdir -p "$work"
  run git -C "$work" init -q
  run git -C "$work" remote add origin "$repo"
  run git -C "$work" fetch --quiet --depth=1 origin "$revision"
  local actual
  actual="$(git -C "$work" rev-parse FETCH_HEAD)"
  [[ "$actual" == "$revision" ]] || die "Fetched unexpected revision for $name: $actual"
  git -C "$work" show "$revision:$path" > "$work/SKILL.md" || die "Skill file not found: $repo@$revision:$path"
  install_skill_file "$work/SKILL.md" "$name"
}

add_mcp() {
  local name="$1" command="$2"; shift 2
  if hermes -p "$PROFILE" mcp list 2>/dev/null | grep -Fq -- "$name"; then
    printf 'MCP server already configured: %s\n' "$name"; return
  fi
  if (($#)); then run hermes -p "$PROFILE" mcp add "$name" --command "$command" --args "$@"
  else run hermes -p "$PROFILE" mcp add "$name" --command "$command"; fi
}

if [[ "$SELECTED_soul" == yes ]]; then
  [[ ! -L "$PROFILE_DIR/SOUL.md" ]] || die "Refusing to overwrite a SOUL.md symlink"
  if [[ ! -e "$PROFILE_DIR/SOUL.md" ]]; then cp -- "$SOURCE_ROOT/SOUL.md" "$PROFILE_DIR/SOUL.md"; else printf 'Keeping existing SOUL.md.\n'; fi
fi

if [[ "$SELECTED_custom_skills" == yes ]]; then
  for skill in "$SOURCE_ROOT"/skills/*; do
    [[ -d "$skill" && ! -L "$skill" ]] || continue
    target="$PROFILE_DIR/skills/$(basename "$skill")"
    if [[ -e "$target" ]]; then printf 'Keeping existing skill: %s\n' "$(basename "$skill")"; else cp -R -- "$skill" "$target"; fi
  done
fi

if [[ "$SELECTED_pentacore" == yes ]]; then
  machine="$(uname -m)"; system="$(uname -s)"
  case "$machine" in arm64|aarch64) arch=aarch64 ;; x86_64|amd64) arch=x86_64 ;; *) die "Unsupported architecture: $machine" ;; esac
  case "$system/$arch" in Darwin/aarch64) suffix=aarch64-apple-darwin ;; Linux/aarch64|Linux/x86_64) suffix="$arch-unknown-linux-gnu" ;; *) die "No PentaCore release for $system/$arch" ;; esac
  release="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$PENTACORE_API?per_page=100" | jq -cer '[.[] | select(.draft == false)][0]')"
  version="$(jq -er '.tag_name | ltrimstr("v")' <<<"$release")"
  archive="pentacore-$version-$suffix.tar.gz"
  asset_url="$(jq -er --arg name "$archive" '[.assets[] | select(.name == $name) | .browser_download_url][0]' <<<"$release")"
  sums_url="$(jq -er '[.assets[] | select(.name == "SHA256SUMS") | .browser_download_url][0]' <<<"$release")"
  [[ -n "$asset_url" && -n "$sums_url" ]] || die "PentaCore release $version does not contain the expected archive and SHA256SUMS."
  [[ -n "$TEMP_ROOT" ]] || { TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/hermes-setup.XXXXXX")"; trap cleanup EXIT; }
  archive_path="$TEMP_ROOT/$archive"; sums_path="$TEMP_ROOT/SHA256SUMS"
  curl -fL --retry 3 "$asset_url" -o "$archive_path"
  curl -fL --retry 3 "$sums_url" -o "$sums_path"
  expected_hash="$(awk -v file="$archive" '$2 == file || $2 == ("*" file) {print $1; exit}' "$sums_path")"
  [[ "$expected_hash" =~ ^[a-fA-F0-9]{64}$ ]] || die "No valid SHA-256 entry for $archive"
  actual_hash="$(sha256_file "$archive_path")"
  actual_hash="$(printf '%s' "$actual_hash" | tr '[:upper:]' '[:lower:]')"
  expected_hash="$(printf '%s' "$expected_hash" | tr '[:upper:]' '[:lower:]')"
  [[ "$actual_hash" == "$expected_hash" ]] || die "PentaCore archive SHA-256 mismatch"
  binary_member="$(tar -tzf "$archive_path" | awk '($0 == "pentacore" || $0 ~ /\/pentacore$/) && $0 !~ /(^|\/)\.\.(\/|$)/ {print; exit}')"
  [[ -n "$binary_member" ]] || die "PentaCore archive does not contain its executable"
  tar -tvzf "$archive_path" | awk -v path="$binary_member" 'substr($0, 1, 1) == "-" && $NF == path {found=1} END {exit !found}' || die "PentaCore executable is not a regular archive file"
  tmp_binary="$BIN_DIR/.pentacore.$$"
  tar -xOzf "$archive_path" "$binary_member" > "$tmp_binary"
  chmod 755 "$tmp_binary"; mv -f -- "$tmp_binary" "$BIN_DIR/pentacore"
  skill_paths="$(tar -tzf "$archive_path" | awk '/(^|\/)skills\/pentacore-memory\/.*\.md$/ && $0 !~ /(^|\/)\.\.(\/|$)/')"
  while IFS= read -r member; do
    [[ -n "$member" ]] || continue
    relative="${member#*skills/pentacore-memory/}"
    [[ "$relative" != "$member" && "$relative" != /* && "$relative" != *'..'* ]] || die "Unsafe skill member in PentaCore archive"
    parent_relative="$(dirname "$relative")"
    skills_dir="$PROFILE_DIR/skills"
    [[ ! -L "$skills_dir" ]] || die "Refusing to write through a skills directory symlink"
    current_dir="$skills_dir/pentacore-memory"
    [[ ! -L "$current_dir" ]] || die "Refusing to write through a PentaCore skill path symlink"
    [[ ! -e "$current_dir" || -d "$current_dir" ]] || die "PentaCore skill path is not a directory"
    mkdir -p "$current_dir"
    if [[ "$parent_relative" != . ]]; then
      IFS=/ read -r -a path_parts <<< "$parent_relative"
      for path_part in "${path_parts[@]}"; do
        [[ -n "$path_part" && "$path_part" != . && "$path_part" != .. ]] || die "Unsafe path in PentaCore skill archive"
        current_dir="$current_dir/$path_part"
        [[ ! -L "$current_dir" ]] || die "Refusing to write through a PentaCore skill path symlink: $current_dir"
        [[ ! -e "$current_dir" || -d "$current_dir" ]] || die "PentaCore skill path component is not a directory: $current_dir"
        mkdir -p "$current_dir"
      done
    fi
    destination="$current_dir/$(basename "$relative")"
    [[ ! -L "$destination" ]] || die "Refusing to write through a PentaCore skill file symlink: $destination"
    [[ -e "$destination" ]] && continue
    mkdir -p "$(dirname "$destination")"
    tar -xOzf "$archive_path" "$member" > "$destination"
  done <<< "$skill_paths"
  add_mcp pentacore "$BIN_DIR/pentacore"
  env_file="$PROFILE_DIR/.env"
  [[ ! -L "$env_file" ]] || die "Refusing to write through an .env symlink"
  if [[ ! -e "$env_file" ]]; then printf 'PENTACORE_PROJECT=hermes-pentest\n' > "$env_file"; chmod 600 "$env_file"; fi
  printf 'Installed PentaCore %s.\n' "$version"
fi

if [[ "$SELECTED_kali" == yes ]]; then
  KALI_DIR="$DATA_DIR/kali-mcp"
  [[ ! -L "$KALI_DIR" ]] || die "Refusing to use a symlink as kali-mcp checkout: $KALI_DIR"
  if [[ -e "$KALI_DIR" ]]; then
    [[ -d "$KALI_DIR/.git" ]] || die "Existing kali-mcp path is not a Git checkout: $KALI_DIR"
    [[ "$(git -C "$KALI_DIR" rev-parse HEAD)" == "$KALI_REVISION" ]] || die "Existing kali-mcp checkout is not at the pinned revision: $KALI_DIR"
    [[ -z "$(git -C "$KALI_DIR" status --porcelain --untracked-files=all)" ]] || die "Existing kali-mcp checkout has local changes: $KALI_DIR"
    printf 'Using existing pinned kali-mcp checkout: %s\n' "$KALI_DIR"
  else
    mkdir -p "$KALI_DIR"
    run git -C "$KALI_DIR" init -q
    run git -C "$KALI_DIR" remote add origin "$KALI_REPO"
    run git -C "$KALI_DIR" fetch --depth=1 origin "$KALI_REVISION"
    run git -C "$KALI_DIR" checkout --detach FETCH_HEAD
    [[ "$(git -C "$KALI_DIR" rev-parse HEAD)" == "$KALI_REVISION" ]] || die "Fetched unexpected kali-mcp revision"
  fi
  run uv sync --locked --project "$KALI_DIR/mcp"
  [[ -e "$KALI_DIR/.env" ]] || { cp -- "$KALI_DIR/.env.example" "$KALI_DIR/.env"; chmod 600 "$KALI_DIR/.env"; }
  install_skill_file "$KALI_DIR/skill/kali-workbench.md" kali-workbench
  add_mcp kali-shell uv run --directory "$KALI_DIR/mcp" python -u server.py
  printf 'kali-mcp installed. Configure %s/.env before starting Docker.\n' "$KALI_DIR"
fi

if [[ "$SELECTED_strix" == yes ]]; then
  STRIX_DIR="$DATA_DIR/strix"
  if [[ ! -e "$STRIX_DIR" ]]; then
    mkdir -p "$STRIX_DIR"
    run git -C "$STRIX_DIR" init -q
    run git -C "$STRIX_DIR" remote add origin "$STRIX_REPO"
    run git -C "$STRIX_DIR" fetch --depth=1 origin "$STRIX_REVISION"
    run git -C "$STRIX_DIR" checkout --detach FETCH_HEAD
  fi
  [[ "$(git -C "$STRIX_DIR" rev-parse HEAD)" == "$STRIX_REVISION" ]] || die "Existing Strix source is not at the pinned revision: $STRIX_DIR"
  while IFS= read -r path; do
    [[ "$path" == *.md ]] || continue
    case "$path" in strix/skills/vulnerabilities/*|strix/skills/technologies/llm_applications.md) ;; *) die "Unexpected Strix skill path: $path" ;; esac
    name="$(git -C "$STRIX_DIR" show "$STRIX_REVISION:$path" | sed -n 's/^name:[[:space:]]*\([a-z0-9][a-z0-9_-]*\)[[:space:]]*$/\1/p' | head -n1)"
    [[ -n "$name" ]] || die "Strix skill has no valid Hermes name: $path"
    [[ ! -L "$PROFILE_DIR/skills/strix" ]] || die "Refusing to write through a Strix skills symlink"
    dest="$PROFILE_DIR/skills/strix/$name"
    if [[ -e "$dest" ]]; then printf 'Keeping existing skill: strix/%s\n' "$name"; continue; fi
    mkdir -p "$dest"
    git -C "$STRIX_DIR" show "$STRIX_REVISION:$path" > "$dest/SKILL.md"
  done < <(git -C "$STRIX_DIR" ls-tree -r --name-only "$STRIX_REVISION" -- strix/skills/vulnerabilities strix/skills/technologies/llm_applications.md)
  printf 'Installed Strix skills from %s.\n' "$STRIX_REVISION"
fi

if [[ "$SELECTED_mcp_review" == yes ]]; then
  install_skill_from_git "$OWASP_REPO" "$OWASP_REVISION" plugins/ai-security-skills/skills/mcp-server-review/SKILL.md mcp-server-review
fi
if [[ "$SELECTED_report_writing" == yes ]]; then
  install_skill_from_git "$PUBLIC_SKILLS_REPO" "$PUBLIC_SKILLS_REVISION" bug-bounty/bug-bounty-report-writing/SKILL.md bug-bounty-report-writing
fi

if [[ "$SELECTED_playwright" == yes ]]; then
  add_mcp playwright npx -y @playwright/mcp@latest --isolated
  printf 'Playwright MCP registered. Configure authorized target boundaries before browser use.\n'
fi

printf '\nSetup complete. Hermes profile: %s\n' "$PROFILE"
printf 'Review installed MCP servers with: hermes -p %q mcp list\n' "$PROFILE"
printf 'Docker services are not started by this installer.\n'
