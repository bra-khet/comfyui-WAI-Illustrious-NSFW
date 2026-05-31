# Personal WAI-Illustrious Live Pod Template — Setup Guide

**Purpose**: A clean, minimal-bloat, personally owned and versioned Docker image + RunPod template for running ComfyUI live (heavy interactive batch work in the real web UI) with the WAI-Illustrious-SDXL model family, a small curated set of LoRAs, and the custom nodes you actually use for character consistency, anatomy/NSFW refinement, and video workflows.

**Foundation**: This is a personal fork of the official `runpod-workers/comfyui-base` (https://github.com/runpod-workers/comfyui-base). We deliberately preserve every strength of that base instead of starting from worker-comfyui or community forks.

**Why fork instead of using someone else's template?**
- Full ownership and reproducibility.
- No surprise changes from upstream community templates.
- You control exactly what gets baked vs. lives on your persistent network volume.
- Easy to maintain long-term from your laptop.

---

## Core Architecture You Must Understand (runpod-slim first-boot)

The official base uses a brilliant, battle-tested pattern:

1. **Build time (multi-stage)**: A "builder" stage downloads a pinned ComfyUI release + a small number of high-value custom nodes as tarballs, initializes minimal git repos (so Manager can still track them), aggregates all `requirements.txt`, generates a hash-verified lockfile, and installs everything (including PyTorch) into the system Python.

2. **The baked artifact** (`/opt/comfyui-baked`) is a complete, ready-to-run ComfyUI tree.

3. **Runtime container** is lean (Ubuntu 24.04 + CUDA + the baked Python site-packages + the baked ComfyUI).

4. **First boot on a fresh volume** (the magic):
   - `start.sh` detects that `/workspace/runpod-slim/ComfyUI` does not exist (or the venv is missing).
   - It does a simple `cp -r /opt/comfyui-baked /workspace/runpod-slim/ComfyUI`.
   - It creates a Python venv with `--system-site-packages` so the pre-installed torch/numpy/etc. from the image are visible without duplication or huge venv copies.
   - ComfyUI-Manager + KJNodes (and any other nodes we add in future sprints) are already there.

5. **Subsequent boots / restarts / redeploys with the same volume**:
   - The ComfyUI directory already exists on the persistent volume → no copy happens.
   - The existing venv is simply activated.
   - All your models, LoRAs, outputs, workflows, and any custom nodes you installed later via Manager survive perfectly.

**Critical implication for image updates**:
Once a volume has been used once, future versions of your Docker image will **not** overwrite the ComfyUI directory on the volume. This is intentional and safe. If you later bake additional nodes, you will either:
- Tell users to delete `/workspace/runpod-slim/ComfyUI` on the volume (after backing up), or
- We may add a controlled "refresh" mechanism in a future sprint.

This is the single most important behavior to internalize.

---

## Recommended Persistent Volume Layout

Mount your RunPod network volume at `/workspace` (the default the base expects).

After first boot you will have:

```
/workspace/
├── runpod-slim/
│   ├── ComfyUI/                 # The live ComfyUI (copied on first boot, then yours forever)
│   │   ├── models/
│   │   │   ├── checkpoints/     # ← Put WAI-Illustrious here (and any other SDXL models)
│   │   │   ├── loras/           # ← Your curated LoRAs (character, anatomy, style, NSFW, etc.)
│   │   │   ├── vae/
│   │   │   ├── embeddings/
│   │   │   ├── controlnet/
│   │   │   ├── clip/
│   │   │   └── ...
│   │   ├── custom_nodes/        # Baked nodes + anything you add later via Manager
│   │   ├── output/              # All generated images & videos live here (persistent)
│   │   ├── input/
│   │   ├── user/default/workflows/   # Save your favorite .json workflows here
│   │   └── .venv-cu128/         # The per-volume virtualenv (do not delete lightly)
│   │
│   ├── comfyui_args.txt         # Your custom launch flags (see below)
│   └── filebrowser.db
│
├── models/                      # OPTIONAL top-level alternative (advanced)
│   └── ...                      # You can point ComfyUI at this via extra_model_paths.yaml
└── workflows/                   # OPTIONAL: keep master copies of workflows outside ComfyUI tree
```

**Recommendation for Sprint 1/2**: Use the paths **inside** `/workspace/runpod-slim/ComfyUI/models/...`. This is the simplest and matches what ComfyUI expects out of the box. We can add `extra_model_paths.yaml` support in a later sprint if you prefer a flatter `/workspace/models` structure.

---

## Prerequisites (your laptop)

- Windows laptop with WSL2 + Ubuntu distro installed and updated.
- Docker Desktop (or Docker Engine in WSL) with Buildx enabled (`docker buildx version`).
- A Docker Hub account (free) — you will push your personal image here.
- RunPod account with a Network Volume (at least 100–200 GB recommended for Illustrious + video models + outputs).
- Git.

### First-Time Docker Image Build Checklist (Critical if you've never done this before)

Because you mentioned this is your first Docker image, do these steps **in order** before running any build:

1. **Create the repository on Docker Hub**
   - Go to https://hub.docker.com/repositories
   - Click "Create repository"
   - Name: `comfyui-wai-illustrious`
   - Visibility: Private (recommended while you iterate) or Public
   - Leave the other settings default. Click Create.

2. **Create a Docker Hub Personal Access Token (you cannot use your normal password for `docker login`)**
   - Go to https://hub.docker.com/settings/security
   - Click "New Access Token"
   - Name: `comfyui-wai-illustrious-laptop`
   - Permissions: **Read & Write** (this is required to push images)
   - Click Generate
   - **Copy the token immediately** — you will only see it once. Save it somewhere safe (password manager).

3. **Confirm Docker Desktop is using WSL2 backend**
   - Open Docker Desktop → Settings → General
   - Make sure "Use the WSL 2 based engine" is checked.
   - Go to Settings → Resources → WSL Integration
   - Ensure your Ubuntu distro is toggled on.
   - Restart Docker Desktop if you changed anything.

4. **Open the real Ubuntu terminal (not PowerShell)**
   - Search for "Ubuntu" in the Start Menu and launch it.
   - This is where all build commands should run.

5. **First `docker login` (do this once)**
   In the Ubuntu terminal:
   ```bash
   docker login -u brakhet
   ```
   When it asks for password, **paste the Personal Access Token** you just created (it will not echo).

---

## Step-by-Step: From Fork to Running Pod

### 1. Fork & Clone (one time)

You already did this — your local directory is the fork.

In the future, to get upstream improvements from the official base while keeping your personal custom nodes:

```bash
# In WSL
cd ~/claude-code/runpod/comfyui-WAI-Illustrious-NSFW
git remote add upstream https://github.com/runpod-workers/comfyui-base.git
git fetch upstream
# Then carefully merge or cherry-pick only what you want
```

### 2. Personalize the image name (one time)

`docker-bake.hcl` now contains a `PERSONAL_REPO` variable near the top (default: `brakhet/comfyui-wai-illustrious`).

This is the single source of truth for your personal image name. All targets (`regular`, `dev`, `cuda13`, etc.) automatically use it.

If you ever want to change the namespace, edit only this one variable:

```hcl
variable "PERSONAL_REPO" {
  default = "yourname/comfyui-wai-illustrious"
}
```

Direct `docker buildx bake` commands (and the helper script) will now produce the correct personal tags automatically.

### 3. Local build & push (the repeatable workflow)

Use the helper created in Sprint 1:

```bash
# From WSL Ubuntu terminal (recommended)
cd /path/to/comfyui-WAI-Illustrious-NSFW

# 1. Login once per session
docker login

# 2. Build the dev image locally (no push) — great for testing
./scripts/build-and-push.sh --target dev

# 3. Build + push a dated personal tag (recommended for personal templates)
./scripts/build-and-push.sh --push --tag 2026-06-01

# 4. Or push the "latest personal" tags
./scripts/build-and-push.sh --push --tag latest
```

See the script header for all options. It uses `docker buildx bake` under the hood and respects the pins in `docker-bake.hcl`.

> **Important**: Before editing any bake-related tagging logic in the future, read [docs/docker-buildx-bake-gotchas.md](docs/docker-buildx-bake-gotchas.md). A previous version of the helper had incorrect `--set` array syntax for tags due to HCL vs. CLI override DSL confusion. The gotchas file exists to prevent recurrence.

**Tag convention suggestion** (customize as you like):
- Date-based for personal use: `2026-06-01-cuda12.8`
- Or lightweight semver: `v1.0.0-cuda12.8`
- Always also push a floating `cuda12.8` and `latest` tag for convenience.

### 4. Create the RunPod Template (one time, then update as needed)

1. Go to RunPod → Templates → New Template.
2. **Container Image**: `brakhet/comfyui-wai-illustrious:2026-06-01-cuda12.8` (or whatever you pushed).
3. **Container Disk**: 20–30 GB is usually plenty (the real data lives on the network volume).
4. **Volume Mount**:
   - Volume: select your persistent network volume.
   - Container Path: `/workspace`
5. **Ports**:
   - 8188 (ComfyUI) → HTTP
   - 8080 (FileBrowser)
   - 8888 (Jupyter)
   - 22 (SSH) — optional but very useful
6. **Env Vars** (recommended):
   - `JUPYTER_PASSWORD` = something strong (or leave blank for no token — your choice)
   - `PUBLIC_KEY` = your SSH public key (for passwordless root login)
7. **GPU**:
   - For comfortable WAI-Illustrious SDXL + LoRAs + high-res + some video: **24 GB+ VRAM** (4090, A6000, L40, A5000, etc.).
   - 12–16 GB cards can work with `--lowvram` or `--force-fp16` in `comfyui_args.txt` but batch work will be painful.
   - 48 GB+ (A6000 Ada, H100, etc.) = luxurious batch + video decode.

Save the template.

### 5. Deploy a Pod from the Template

- Select your template.
- Attach the same network volume you configured.
- Deploy.
- Wait for "First time setup: Copying baked ComfyUI to workspace..." in the logs.
- When you see `[ComfyUI-Manager] All startup tasks have been completed.` you are ready.

Access:
- ComfyUI: `https://<pod-id>-8188.proxy.runpod.net`
- FileBrowser: `https://<pod-id>-8080.proxy.runpod.net` (admin / adminadmin12 — change this immediately in a real deployment)
- Jupyter: `https://<pod-id>-8888.proxy.runpod.net`
- SSH: `ssh root@<pod-ip> -p 22` (or the proxy port)

---

## First Boot Experience (Sprint 2 improvement)

On the very first time your volume is used with this image, after ComfyUI is copied you will now see a clear block in the logs telling you exactly where to place:

- WAI-Illustrious checkpoint (`.../models/checkpoints/`)
- Your LoRAs (`.../models/loras/`)
- Other assets

This uses the nested layout inside `/workspace/runpod-slim/ComfyUI/models/...` that you prefer. The message only appears during the initial copy.

## Optional: API Keys + Auto-Download Models via Environment Variables (new)

You can set these in your RunPod **Template** (or at pod creation time) exactly like other popular ComfyUI templates:

- `CIVITAI_API_KEY` — Your Civitai API key (create at https://civitai.com/user/account). This also makes the pre-baked Civicomfy node automatically authenticated for manual downloads inside the UI.
- `HF_TOKEN` — Optional, for gated Hugging Face models (future-proofing).
- `COMFY_INITIAL_MODELS` — Comma-separated list of **Civitai model version IDs** (the numeric part after `/models/` or from the download button). Example: `123456,789012`

**Behavior**:
- Leave `COMFY_INITIAL_MODELS` blank or unset → nothing is downloaded (the default, zero surprise behavior).
- Provide the key + IDs → on every pod start the container will download any missing checkpoints from that list into `/workspace/runpod-slim/ComfyUI/models/checkpoints/`.
- Fully idempotent (won't re-download on every restart).
- Best-effort: a single bad ID or temporary rate limit will not break the pod; it just logs and continues.
- Works on both brand-new volumes and existing ones.

This gives you the "declarative model list in the template" experience you asked for while keeping the image itself lean.

Example in the RunPod template UI:
```
CIVITAI_API_KEY = your_real_key_here
COMFY_INITIAL_MODELS = 1234567,987654
```

The same keys are also exported into the SSH/Jupyter environment so CLI tools and nodes see them.

## Custom ComfyUI Arguments

Edit `/workspace/runpod-slim/comfyui_args.txt` (one flag per line, `#` for comments).

Example for WAI-Illustrious workflows:

```
--preview-method auto
--max-batch-size 4
--force-fp16
# --lowvram          # uncomment only on < 16 GB cards
```

The file is created empty on first boot. Changes take effect on next container start.

---

## Adding More Custom Nodes Later (The Manager Way)

Because ComfyUI-Manager is pre-installed and the git remotes are already configured on the baked nodes, you can:

1. In the ComfyUI web UI → Manager tab → Install Missing Custom Nodes or Install via Git URL.
2. Install whatever you want (Impact-Pack, IPAdapter, rgthree, WanVideoWrapper, etc.).
3. They land in `/workspace/runpod-slim/ComfyUI/custom_nodes/YourNode` (persistent on the volume).
4. Their Python dependencies are installed into the volume's `.venv-cu128` by the migration logic in `start.sh` the next time the pod boots with a new image that doesn't yet know about the new node.

This is the intended "live" workflow. Only nodes you want **guaranteed present on every fresh volume** (or that have very heavy native dependencies) should be baked into future versions of the image.

---

## Updating Your Personal Image Later

1. Pull latest changes from upstream base (if any) into your fork (carefully).
2. Make your targeted edits (new baked nodes, etc.).
3. Bump a date or version tag.
4. `./scripts/build-and-push.sh --push --tag 2026-06-15`
5. In RunPod, edit your Template → change the Container Image to the new tag.
6. Redeploy pods from the template (or terminate + start new from template).

Existing volumes keep all user data. See "Critical implication for image updates" above if you need to pick up newly baked nodes.

---

## Pre-installed Nodes in the Current Base (and Why They Are Excellent)

The official base already gives us (pinned + baked):

- **ComfyUI-Manager** (ltdrdata) — The single most important node. Live installation and updates of everything else.
- **ComfyUI-KJNodes** (kijai) — Extremely high value for SDXL/Illustrious work: better latent tools, image batching, video helpers, model merging utilities, etc. One of the best "foundation" nodes you can have.
- **Civicomfy** — Civitai integration conveniences.
- **ComfyUI-RunpodDirect** — RunPod-specific helpers.

**For WAI-Illustrious + NSFW/character + video, this is already a very strong starting point.** We will only add the minimal high-signal nodes from your 2026-05-31 snapshot in future sprints (Impact-Pack + subpack, IPAdapter Plus, ControlNet Aux, rgthree-comfy, Inpaint-CropAndStitch, WanVideoWrapper, etc.).

---

## GPU / VRAM Guidance (WAI-Illustrious SDXL)

- **Minimum for pleasant live use**: 16 GB (with `--force-fp16` + low batch).
- **Recommended**: 24 GB (RTX 4090, A5000, etc.) — comfortable 1024–1536 batches, good high-res fix, some video.
- **Luxury**: 40–48 GB+ — large batches, heavy video workflows (Wan 2.1 14B etc.), multiple simultaneous queues.
- Always keep an eye on the VRAM widget in the UI. Use `--preview-method auto` or `none` when doing very large batches.

---

## File Locations Reference

| Purpose                        | Path on Volume                                      |
|--------------------------------|-----------------------------------------------------|
| ComfyUI install (persistent)   | `/workspace/runpod-slim/ComfyUI`                    |
| Custom launch args             | `/workspace/runpod-slim/comfyui_args.txt`           |
| Checkpoints / models           | `/workspace/runpod-slim/ComfyUI/models/checkpoints` |
| LoRAs                          | `/workspace/runpod-slim/ComfyUI/models/loras`       |
| Outputs (images + video)       | `/workspace/runpod-slim/ComfyUI/output`             |
| Workflows                      | `/workspace/runpod-slim/ComfyUI/user/default/workflows` |
| Added custom nodes             | `/workspace/runpod-slim/ComfyUI/custom_nodes`       |
| FileBrowser root               | `/workspace`                                        |
| Jupyter root                   | `/workspace`                                        |

---

## Next Steps After Sprint 1

See `TODO.md` for the exact captured snapshot nodes and the planned sprint sequence.

Sprint 2 will focus on confirming real RunPod volume behavior and any minimal start.sh/Dockerfile tweaks needed for the personal experience before we do the (larger) snapshot node integration pass.

---

**Maintained by**: You (the owner of this fork).  
**Upstream**: https://github.com/runpod-workers/comfyui-base (monitor but merge surgically).  
**Questions / changes**: Work in small, reviewable sprints.
