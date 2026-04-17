#!/usr/bin/env bash
# Open Unity Editor across OS; optional -buildTarget (Android / iOS).
# Standalone install or Unity Hub (--unity-version).

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: open-unity.sh [options] [--] [extra Unity args...]

Options:
  -a, --android          Set build target to Android (-buildTarget Android)
  -i, --ios              Set build target to iOS (-buildTarget iOS)
  -p, --project PATH     Pass -projectPath PATH
      --hub              Resolve editor under Unity Hub (needs --unity-version)
      --unity-version V  Hub Editor version folder, e.g. 2022.3.10f1 (prefix match ok)
  -h, --help             Show this help

Environment:
  UNITY_EDITOR           Full path to Unity executable (skips auto-detect)
  UNITY_USE_HUB=1        Same as --hub when set
  UNITY_HUB_EDITOR_ROOT  Override Hub "Editor" directory (parent of version dirs)

Examples:
  ./open-unity.sh
  ./open-unity.sh -a
  ./open-unity.sh -i -p ~/MyGame
  ./open-unity.sh --hub --unity-version 2022.3.10f1 -a
EOF
}

is_wsl() {
  [[ -f /proc/version ]] && grep -qi microsoft /proc/version
}

# Args: base directory (Unix path), wanted version string
# Prints: matching version directory name (one line) or empty
pick_hub_version_dir() {
  local base="$1"
  local want="$2"
  [[ -d "$base" ]] || return 1
  local exact
  exact=$(find "$base" -mindepth 1 -maxdepth 1 -type d -name "$want" 2>/dev/null | head -1)
  if [[ -n "$exact" ]]; then
    basename "$exact"
    return 0
  fi
  # Prefix match: prefer longest matching directory name
  local best="" best_len=0
  local d name
  while IFS= read -r -d '' d; do
    name=$(basename "$d")
    if [[ "$name" == "$want"* ]]; then
      local n=${#name}
      if (( n > best_len )); then
        best_len=$n
        best=$name
      fi
    fi
  done < <(find "$base" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  [[ -n "$best" ]] && printf '%s\n' "$best"
}

hub_editor_root_default() {
  if [[ -n "${UNITY_HUB_EDITOR_ROOT:-}" ]]; then
    printf '%s\n' "$UNITY_HUB_EDITOR_ROOT"
    return 0
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if [[ -d "$HOME/Applications/Unity/Hub/Editor" ]]; then
      printf '%s\n' "$HOME/Applications/Unity/Hub/Editor"
    elif [[ -d "/Applications/Unity/Hub/Editor" ]]; then
      printf '%s\n' "/Applications/Unity/Hub/Editor"
    fi
    return 0
  fi
  if is_wsl; then
    printf '%s\n' "/mnt/c/Program Files/Unity/Hub/Editor"
    return 0
  fi
  if [[ "$(uname -s)" == "Linux" ]]; then
    printf '%s\n' "$HOME/Unity/Hub/Editor"
  fi
}

resolve_standalone_unity() {
  if [[ -n "${UNITY_EDITOR:-}" ]]; then
    printf '%s\n' "$UNITY_EDITOR"
    return 0
  fi
  local p
  case "$(uname -s)" in
    Darwin)
      p="/Applications/Unity/Unity.app/Contents/MacOS/Unity"
      ;;
    Linux)
      if is_wsl; then
        p="/mnt/c/Program Files/Unity/Editor/Unity.exe"
      elif command -v unity-editor >/dev/null 2>&1; then
        command -v unity-editor
        return 0
      else
        p="/usr/bin/unity-editor"
      fi
      ;;
    *)
      echo "open-unity.sh: unsupported OS: $(uname -s)" >&2
      return 1
      ;;
  esac
  printf '%s\n' "$p"
}

resolve_hub_unity() {
  local version="$1"
  local root
  root=$(hub_editor_root_default) || true
  [[ -n "${root:-}" ]] || {
    echo "open-unity.sh: could not find Unity Hub Editor directory; set UNITY_HUB_EDITOR_ROOT" >&2
    return 1
  }
  [[ -d "$root" ]] || {
    echo "open-unity.sh: Hub Editor root not found: $root" >&2
    return 1
  }
  local vdir
  vdir=$(pick_hub_version_dir "$root" "$version") || true
  [[ -n "${vdir:-}" ]] || {
    echo "open-unity.sh: no Hub install matches version: $version (under $root)" >&2
    return 1
  }

  case "$(uname -s)" in
    Darwin)
      printf '%s\n' "$root/$vdir/Unity.app/Contents/MacOS/Unity"
      ;;
    Linux)
      if is_wsl; then
        printf '%s\n' "$root/$vdir/Editor/Unity.exe"
      else
        # Typical Linux Hub layout mirrors Windows (Editor/Unity) or distro packages vary
        if [[ -x "$root/$vdir/Editor/Unity" ]]; then
          printf '%s\n' "$root/$vdir/Editor/Unity"
        elif [[ -x "$root/$vdir/Editor/Unity.sh" ]]; then
          printf '%s\n' "$root/$vdir/Editor/Unity.sh"
        else
          printf '%s\n' "$root/$vdir/Editor/Unity"
        fi
      fi
      ;;
    *)
      echo "open-unity.sh: unsupported OS for Hub resolve: $(uname -s)" >&2
      return 1
      ;;
  esac
}

BUILD_TARGET=""
PROJECT_PATH=""
UNITY_VERSION=""
USE_HUB=false
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -a | --android)
      BUILD_TARGET="Android"
      shift
      ;;
    -i | --ios)
      BUILD_TARGET="iOS"
      shift
      ;;
    -p | --project)
      PROJECT_PATH="${2:-}"
      if [[ -z "$PROJECT_PATH" ]]; then
        echo "open-unity.sh: $1 requires a path" >&2
        exit 1
      fi
      shift 2
      ;;
    --hub)
      USE_HUB=true
      shift
      ;;
    --unity-version)
      UNITY_VERSION="${2:-}"
      if [[ -z "$UNITY_VERSION" ]]; then
        echo "open-unity.sh: --unity-version requires a value" >&2
        exit 1
      fi
      USE_HUB=true
      shift 2
      ;;
    --)
      shift
      EXTRA+=("$@")
      break
      ;;
    *)
      EXTRA+=("$1")
      shift
      ;;
  esac
done

if [[ -n "${UNITY_USE_HUB:-}" && "$UNITY_USE_HUB" != "0" ]]; then
  USE_HUB=true
fi

unity_bin=""
if [[ -n "${UNITY_EDITOR:-}" ]]; then
  unity_bin="$UNITY_EDITOR"
elif $USE_HUB; then
  [[ -n "$UNITY_VERSION" ]] || {
    echo "open-unity.sh: --hub / UNITY_USE_HUB requires --unity-version <ver> (or set UNITY_EDITOR)" >&2
    exit 1
  }
  unity_bin=$(resolve_hub_unity "$UNITY_VERSION")
else
  unity_bin=$(resolve_standalone_unity)
fi

[[ -n "$unity_bin" ]] || exit 1
if [[ ! -e "$unity_bin" ]]; then
  echo "open-unity.sh: Unity executable not found: $unity_bin" >&2
  exit 1
fi

cmd=( "$unity_bin" )
if [[ -n "$PROJECT_PATH" ]]; then
  cmd+=( -projectPath "$PROJECT_PATH" )
fi
if [[ -n "$BUILD_TARGET" ]]; then
  cmd+=( -buildTarget "$BUILD_TARGET" )
fi
cmd+=( "${EXTRA[@]}" )

exec "${cmd[@]}"
