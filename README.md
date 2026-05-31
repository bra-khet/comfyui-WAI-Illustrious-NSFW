# comfyui-WAI-Illustrious-NSFW

**Personal, minimal-bloat, live ComfyUI pod template** optimized for WAI-Illustrious-SDXL (Civitai's popular anime/NSFW SDXL model) + curated LoRAs + the exact custom nodes needed for character consistency, anatomy/NSFW work, and video workflows.

> **Full ownership.** Forked from the official `runpod-workers/comfyui-base`. We preserve every strength of that base (first-boot copy to `/workspace/runpod-slim/ComfyUI`, pre-installed ComfyUI-Manager + KJNodes, clean `start.sh`, FileBrowser/Jupyter/SSH extras, `/workspace` persistent volume, port 8188) while keeping the Docker image lean.

All heavy assets (WAI-Illustrious checkpoint, your LoRAs, outputs, workflows, and additional custom nodes) live on your persistent network volume — never baked into the image.

---

## Quick Links

- **[SETUP.md](SETUP.md)** — Complete step-by-step guide (fork → local build from WSL → push to your Docker Hub → RunPod template → volume layout → updates).
- [TODO.md](TODO.md) — Living sprint plan + exact custom nodes captured from your 2026-05-31 production snapshot (for future integration sprints).
- [docs/context.md](docs/context.md) — Technical deep dive into the upstream base (still 100% relevant).

---

## What You Get on First Boot (from the solid official base)

- ComfyUI + ComfyUI-Manager + ComfyUI-KJNodes + Civicomfy + ComfyUI-RunpodDirect already present and ready.
- Full Python environment (PyTorch cu128/cu130) baked at image build time.
- One-time copy of the clean base to your persistent volume.
- FileBrowser (8080), JupyterLab (8888), SSH (22), and ComfyUI (8188).
- `comfyui_args.txt` for custom launch flags.
- Optional env-var driven Civitai checkpoint downloads on start (`CIVITAI_API_KEY` + `COMFY_INITIAL_MODELS`).

Everything else (your real models, LoRAs, extra nodes from the snapshot, workflows) goes on the network volume and survives pod restarts and image upgrades.

---

## Pre-installed Nodes (Why This Starting Point Is Already Strong)

- **ComfyUI-Manager**: The key to long-term ownership — install or update any additional nodes live from the UI.
- **ComfyUI-KJNodes** (kijai): Outstanding utility node pack for SDXL/Illustrious batching, latents, video helpers, and model operations. One of the highest-value foundations you can have.

The other two (Civicomfy, RunpodDirect) are convenient RunPod/Civitai integrations.

In upcoming sprints we will surgically add only the high-signal nodes from your real 2026-05-31 snapshot (Impact-Pack + subpack, IPAdapter Plus, ControlNet Aux, rgthree-comfy, Inpaint-CropAndStitch, WanVideoWrapper, etc.). Nothing will be added until it is explicitly planned and reviewed.

---

## Local Build Workflow (WSL Ubuntu on Windows laptop)

```bash
# From WSL terminal
docker login

# Build locally for testing (no push)
./scripts/build-and-push.sh --target dev

# Build + push a dated personal release
./scripts/build-and-push.sh --push --tag 2026-06-01
```

See `SETUP.md` for the full recommended tag scheme, how to personalize `docker-bake.hcl` for your Docker Hub username, and exact RunPod template settings.

---

## GPU Guidance (WAI-Illustrious SDXL + LoRAs + Video)

- Comfortable interactive + batch work: **24 GB+ VRAM** (RTX 4090, A5000, A6000, L40, etc.).
- Tight but usable: 16 GB cards with `--force-fp16` + small batches.
- Luxury video/decode + large batches: 40–48 GB+.

---

## Update & Maintenance Philosophy

- Small, surgical, well-documented changes only.
- Every Sprint ends with a clear summary and a suggested `git commit`.
- The image stays lean. Heavy data and your personal node set live on the volume.
- You control the versioning and the release cadence.

---

## Source & Attribution

- Upstream foundation (do not replace): https://github.com/runpod-workers/comfyui-base
- This personal fork exists so you own the exact environment you use daily for WAI-Illustrious work.

---

**Sprint 1 complete — base analyzed and scaffolded. Ready for targeted Dockerfile / start.sh edits in Sprint 2.**
