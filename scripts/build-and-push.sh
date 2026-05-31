#!/usr/bin/env bash
# ============================================================================
# build-and-push.sh — Personal WAI-Illustrious ComfyUI image build helper
# ============================================================================
# Sprint 1 scaffolding artifact.
#
# !!! INSTITUTIONAL MEMORY — READ BEFORE EDITING TAG LOGIC !!!
# See docs/docker-buildx-bake-gotchas.md
#
# The docker buildx bake --set override syntax for lists is:
#   target.tags=foo      (first = replaces the entire list)
#   target.tags+=bar     (subsequent += appends)
#
# NEVER use target.tags[0]= or target.tags[1]= style.
# That was a hallucination caused by mental bleed from docker-bake.hcl HCL syntax.
# The error was fixed 2026-06-01 with Jem's help after the first successful dev build.
# ============================================================================

#
# Purpose:
#   Provide a simple, safe, repeatable way to build and push *your personal*
#   fork of the runpod-workers/comfyui-base image from a laptop (WSL Ubuntu
#   recommended).
#
# Why this script exists:
#   - The original repo is designed for the official runpod/ namespace + CI.
#   - For a personal fork you want your own Docker Hub repo (e.g. robin/comfyui-wai-illustrious)
#     and easy date-based or semver tags without editing HCL every time.
#   - Keeps the heavy lifting in docker-bake.hcl (single source of truth for pins).
#
# Usage (from WSL Ubuntu terminal):
#   ./scripts/build-and-push.sh --help
#   docker login
#   ./scripts/build-and-push.sh --target dev                    # local only, for testing
#   ./scripts/build-and-push.sh --push --tag 2026-06-01         # dated personal release
#   ./scripts/build-and-push.sh --push --tag latest             # floating latest
#   ./scripts/build-and-push.sh --push --tag v1.0.0-cu128       # semver style
#
# The script will automatically append the CUDA suffix (-cuda12.8 or -cuda13.0)
# unless you pass --no-cuda-suffix (advanced).
#
# It respects TAG, TORCH_VERSION etc. overrides via environment variables
# exactly like the upstream docker-bake.hcl expects.
#
# After a successful push, update your RunPod template with the new tag.
#
# Design notes (per project principles):
#   - No changes to the actual Dockerfile or start.sh in Sprint 1.
#   - Minimal magic. The real pins and targets live in docker-bake.hcl.
#   - Safe defaults (never push unless --push is given).
#   - Clear output so you always know exactly what will be tagged.
# ============================================================================

set -euo pipefail

# --- Defaults (override via env or flags) ---
DEFAULT_PERSONAL_REPO="brakhet/comfyui-wai-illustrious"
PERSONAL_REPO="${PERSONAL_REPO:-$DEFAULT_PERSONAL_REPO}"
TARGET="regular"
PUSH=false
TAG=""
NO_CUDA_SUFFIX=false
EXTRA_BAKE_ARGS=()

# --- Helper output ---
usage() {
  cat <<'EOF'
Personal WAI-Illustrious ComfyUI build helper (Sprint 1)

Usage:
  ./scripts/build-and-push.sh [options]

Options:
  --target <name>     Bake target: dev, regular, cuda13, devpush, etc. (default: regular)
  --push              Actually push to Docker Hub (default: build only)
  --tag <value>       Tag suffix (e.g. 2026-06-01, latest, v1.0.0). CUDA suffix added automatically.
  --no-cuda-suffix    Do not append -cuda12.8 / -cuda13.0 (advanced — only if you customized HCL)
  --repo <name>       Override Docker Hub repo (e.g. brakhet/comfyui-wai-illustrious)
  --help              Show this help

Environment variables (advanced):
  PERSONAL_REPO       Same as --repo
  TAG                 Same as --tag (overridden by --tag flag)
  Any variable from docker-bake.hcl can be overridden (COMFYUI_VERSION, etc.)

Examples:
  # Local test build (no push, loads into local Docker)
  ./scripts/build-and-push.sh --target dev

  # Build + push a dated personal image (recommended)
  ./scripts/build-and-push.sh --push --tag 2026-06-01 --repo brakhet/comfyui-wai-illustrious

  # Push floating 'latest' for the personal image
  ./scripts/build-and-push.sh --push --tag latest

After pushing, update your RunPod template container image field with the new tag.
EOF
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"; shift 2 ;;
    --push)
      PUSH=true; shift ;;
    --tag)
      TAG="$2"; shift 2 ;;
    --no-cuda-suffix)
      NO_CUDA_SUFFIX=true; shift ;;
    --repo)
      PERSONAL_REPO="$2"; shift 2 ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      EXTRA_BAKE_ARGS+=("$1"); shift ;;
  esac
done

if [[ -z "$TAG" && -n "${TAG:-}" ]]; then
  TAG="${TAG}"
fi

echo "======================================================================"
echo "  Personal WAI-Illustrious ComfyUI — Local Build Helper (Sprint 1)"
echo "======================================================================"
echo "Target:          $TARGET"
echo "Personal repo:   $PERSONAL_REPO"
echo "Tag (raw):       ${TAG:-<not set — will use docker-bake.hcl default>}"
echo "Push:            $PUSH"
echo "No CUDA suffix:  $NO_CUDA_SUFFIX"
echo ""

# --- Sanity checks ---
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found in PATH" >&2
  exit 1
fi

if ! docker buildx version >/dev/null 2>&1; then
  echo "ERROR: docker buildx is required. Enable it in Docker Desktop or install buildx." >&2
  exit 1
fi

if [[ "$PUSH" == true ]]; then
  if ! docker info 2>/dev/null | grep -q "Username:"; then
    echo "WARNING: You are asking to push, but 'docker login' may not have been run in this session."
    echo "         The build will fail at push time if you are not logged in."
    echo ""
  fi
fi

# --- Construct the bake command ---
BAKE_CMD=(docker buildx bake -f docker-bake.hcl)

# We always want to set the PERSONAL_REPO via an override if the HCL supports it.
# For Sprint 1 we do NOT modify docker-bake.hcl yet. Instead we post-process the
# tags using --set on the chosen target. This is the least invasive approach.

# Determine final tag list
if [[ -n "$TAG" ]]; then
  if [[ "$NO_CUDA_SUFFIX" == true ]]; then
    FINAL_TAG="$TAG"
  else
    # We let the bake file decide cuda suffix via its own targets, then we override
    # the actual published name. For simplicity in Sprint 1 we build the regular
    # target and then explicitly set tags with our personal repo + provided tag.
    FINAL_TAG="$TAG"
  fi
else
  FINAL_TAG=""
fi

# For the dev target we usually want local docker output only.
if [[ "$TARGET" == "dev" ]]; then
  PUSH=false
  echo "Note: 'dev' target forces local Docker output (no push) regardless of --push flag."
fi

# --- Build the actual set expressions for personal naming ---
# The upstream HCL defines targets that already emit runpod/comfyui tags.
# We use --set to completely replace the tags for the selected target with our personal ones.
# This keeps the pin variables and logic 100% in docker-bake.hcl.

SET_TAGS=()
if [[ "$TARGET" == "dev" ]]; then
    # dev target is special — it uses output type docker and a simple tag
    SET_TAGS+=("dev.tags=$PERSONAL_REPO:dev")
elif [[ "$TARGET" == "regular" || "$TARGET" == "common" ]]; then
    if [[ -n "$FINAL_TAG" ]]; then
        # The first assignment (=) clears defaults; the second (+=) appends to the array
        SET_TAGS+=("regular.tags=$PERSONAL_REPO:$FINAL_TAG-cuda12.8")
        SET_TAGS+=("regular.tags+=$PERSONAL_REPO:$FINAL_TAG")
    else
        SET_TAGS+=("regular.tags=$PERSONAL_REPO:slim-cuda12.8")
        SET_TAGS+=("regular.tags+=$PERSONAL_REPO:slim")
    fi
elif [[ "$TARGET" == "cuda13" ]]; then
    if [[ -n "$FINAL_TAG" ]]; then
        SET_TAGS+=("cuda13.tags=$PERSONAL_REPO:$FINAL_TAG-cuda13.0")
        SET_TAGS+=("cuda13.tags+=$PERSONAL_REPO:$FINAL_TAG")
    else
        SET_TAGS+=("cuda13.tags=$PERSONAL_REPO:slim-cuda13.0")
        SET_TAGS+=("cuda13.tags+=$PERSONAL_REPO:cuda13.0")
    fi
else
    # Fallback for devpush / other custom targets — user is expected to know what they are doing
    echo "Note: Using target '$TARGET' with minimal tag mangling. You may want to pass explicit tags via bake args."
    if [[ -n "$FINAL_TAG" ]]; then
        SET_TAGS+=("$TARGET.tags=$PERSONAL_REPO:$FINAL_TAG")
    fi
fi
for st in "${SET_TAGS[@]}"; do
  BAKE_CMD+=(--set "$st")
done

if [[ "$PUSH" == true ]]; then
  BAKE_CMD+=(--push)
else
  # For non-push regular builds we still want a usable local image for most targets.
  # The 'dev' target already sets output=type=docker.
  # For regular we can add a load for convenience on local builds.
  if [[ "$TARGET" != "dev" ]]; then
    BAKE_CMD+=(--load)
  fi
fi

# Pass through any extra raw args the user gave us
BAKE_CMD+=("${EXTRA_BAKE_ARGS[@]}")

# Final command
BAKE_CMD+=("$TARGET")

echo "Executing:"
echo "  ${BAKE_CMD[*]}"
echo ""
echo "======================================================================"

# Run it
"${BAKE_CMD[@]}"

echo ""
echo "======================================================================"
echo "Build finished."
if [[ "$PUSH" == true ]]; then
  echo "Image(s) pushed. Example tag you can use in RunPod template:"
  if [[ -n "$FINAL_TAG" ]]; then
    echo "   $PERSONAL_REPO:$FINAL_TAG-cuda12.8   (or the -cuda13.0 variant)"
  else
    echo "   $PERSONAL_REPO:slim-cuda12.8"
  fi
  echo ""
  echo "Next step: Edit your RunPod Template → Container Image → paste the tag above."
else
  echo "Local image built (or loaded). Inspect with:"
  echo "   docker images | grep $PERSONAL_REPO"
fi
echo "======================================================================"
