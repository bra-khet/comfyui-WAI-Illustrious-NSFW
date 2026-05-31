# TODO — Personal WAI-Illustrious ComfyUI Live Pod Template

This file captures the living plan for the personal fork of runpod-workers/comfyui-base.

**Core Goal**: Minimal-bloat, highly reliable, user-owned Docker image + RunPod template for heavy live ComfyUI usage with WAI-Illustrious-SDXL (anime/NSFW/character consistency) + small curated LoRAs + video workflows. All persistent state lives on the network volume at `/workspace`.

**Guiding Principles** (never violate):
- Build only on the official runpod-workers/comfyui-base (preserve first-boot copy to `/workspace/runpod-slim/ComfyUI`, Manager + KJNodes pre-install, start.sh logic, FileBrowser/Jupyter/SSH extras, port 8188, etc.).
- Keep image lean: heavy models/LoRAs stay on volume, not baked.
- Live UI first: excellent experience for interactive batch work inside the real ComfyUI web interface.
- Surgical, well-documented, versioned changes with clear rationale.
- Long-term maintainability from a laptop (WSL2 Ubuntu).

---

## Sprint 1 — COMPLETE (this file created during scaffolding)

- [x] Full analysis of original repo structure and the critical runpod-slim first-boot mechanism.
- [x] Created `.dockerignore`.
- [x] Created high-quality personal `SETUP.md` + updated `README.md`.
- [x] Created lightweight local build helper script(s).
- [x] Captured user's 2026-05-31 snapshot data here for future work (no changes made to image yet).
- [x] Documented pre-installed nodes value and first-version minimalism.

**End of Sprint 1 statement**: "Sprint 1 complete — base analyzed and scaffolded. Ready for targeted Dockerfile / start.sh edits in Sprint 2."

---

## User's Current ComfyUI Snapshot (2026-05-31_14-48-25_snapshot.json)

**Source**: Taken from user's production personal ComfyUI setup. This is the authoritative list of what the user actually uses and wants preserved/reproduced in the personal pod template.

### Git-tracked custom nodes (5) — exact SHAs from snapshot for reproducibility

1. `https://github.com/AtlasCloudAI/atlascloud_comfyui` @ `4f820748305de812f35cb3d450c6a1962aab0687`
2. `https://github.com/civitai/civitai_comfy_nodes` @ `2a2ca4e05955ebbee32eaa269c2c20b4654e8910`
3. `https://github.com/ltdrdata/ComfyUI-Impact-Pack` @ `429d0159ad429e64d2b3916e6e7be9c22d025c3c`
4. `https://github.com/nobandegani/ComfyUI-InoNodes` @ `0a5288386fb0163b08770c6bb61c6522ec214e48`
5. `https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch` @ `c9393427b20e8f0d282d48b840e98189be3c5488`

### CNR (ComfyUI Node Registry) nodes with versions (14)

- civicomfy: 1.0.9 (already baked in base)
- ComfyUI-Copilot: 2.0.28
- comfyui-custom-scripts: 1.2.5
- comfyui-easy-use: 1.3.6
- comfyui-impact-subpack: 1.3.5
- comfyui-kjnodes: 1.4.0 (already baked)
- comfyui-node-organizer: 2.1.1
- ComfyUI-WanVideoWrapper: 1.4.7   ← Video workflow interest (Wan 2.1 etc.)
- comfyui_controlnet_aux: 1.1.5
- comfyui_essentials: 1.1.0
- comfyui_ipadapter_plus: 2.0.0
- rgthree-comfy: 1.0.2605082257
- was-ns: 3.0.1

### File-based custom nodes (1)

- `websocket_image_save.py` (filename only in snapshot; origin unknown — likely a small custom websocket save node or from a workflow pack)

### Heavy pip dependencies (selection of the most relevant / heavy ones from the 200+ listed)

These are mostly transitive from the above nodes. Key ones that benefit from baking:
- insightface==0.7.3 + onnxruntime-gpu==1.26.0 (Impact-Pack face analysis, IPAdapter)
- mediapipe==0.10.35
- opencv-python / contrib / headless
- rembg==2.0.75 + pillow-heif
- transformers, diffusers, accelerate, peft, timm (many nodes)
- ultralytics + ultralytics-thop (YOLO in some packs)
- git+https versions for cstr, ffmpy, img2texture, SAM-2 (facebookresearch/sam2), segment-anything
- polars, pyarrow ecosystem, etc.

**Future Sprint Decision Points (do not implement until agreed)**:
- Which of the 5 git + 12 new CNR nodes to pin + bake into the personal image vs. document "install via Manager after first deploy".
- Special handling for WanVideoWrapper (video models are very large; may want separate volume guidance).
- Impact-Pack + subpack + Inpaint-CropAndStitch + IPAdapter + controlnet_aux + rgthree are high-value for character consistency + anatomy/NSFW refinement with Illustrious.
- Whether to pre-populate any model lists or manager cache extensions.
- How to handle the single `websocket_image_save.py` (find source or recreate as a tiny custom node).

**Action**: In Sprint 2 or 3 we will do a surgical "add user snapshot nodes" pass (new ARGs in docker-bake.hcl, download blocks in Dockerfile, update fetch-hashes.sh, update docs).

---

## Sprint 2+ Roadmap (high level, will be refined each sprint)

**Sprint 2 — Targeted base preservation + first personal customizations**
- Confirm /workspace volume mount behavior on real RunPod (first boot copy, subsequent boots reuse venv + user data).
- Possibly light surgical edits to start.sh or Dockerfile only if needed to improve personal UX (e.g. better logging of volume layout on first boot).
- Introduce personal image naming + tag scheme in docker-bake.hcl (or via helper script only).
- Add initial documentation for WAI-Illustrious + recommended LoRA folder layout.

**Sprint 3 — Integrate snapshot custom nodes (the only major image changes)**
- Add the git nodes + CNR nodes from the 2026-05-31 snapshot using the existing pinned-tarball + git-init pattern.
- Decide bake vs. Manager-install for each (lean image wins unless heavy native deps).
- Update requirements aggregation and prebake-manager-cache if needed.
- Test local build + basic pod deploy (user provides output).

**Sprint 4 — Volume layout, model placement, and first-run experience**
- Finalize recommended directory structure under /workspace (checkpoints, loras, vae, embeddings, workflows, output, input).
- Possibly add a small `extra_model_paths.yaml` or symlinks / startup script help.
- Document exact steps to place WAI-Illustrious checkpoint + LoRAs on volume.
- Add any small quality-of-life (e.g. default workflows folder seeding?).

**Sprint 5 — Video workflow readiness (Wan + others)**
- Ensure WanVideoWrapper and related (if baked) have good volume paths for large video models.
- GPU/VRAM guidance for SDXL + video decode.
- Possibly light comfyui_args.txt suggestions for memory / attention.

**Later / Maintenance**
- Image update story (when to force-reseed ComfyUI dir on volume after a new base bake).
- Optional: personal prebake of a couple high-value LoRAs? (probably not — keep lean).
- CI? (user will decide; local laptop builds are primary).
- Security / secrets handling in personal template.

---

## Known Subtle Behaviors of the Base (documented for future edits)

1. **First-boot copy is one-way and non-destructive on subsequent boots**:
   - `if [ ! -d "$COMFYUI_DIR" ] || [ ! -d "$VENV_DIR" ]` then `cp -r /opt/comfyui-baked ...`
   - Once a pod has ever booted successfully, the ComfyUI dir on the volume is **never overwritten** by future image pulls.
   - Implication: Shipping a new baked node in a future image version will **not** appear for existing volumes. User must manually delete `/workspace/runpod-slim/ComfyUI` (after backup) or we add an opt-in refresh mechanism later.

2. **Baked nodes get git remotes + initial commit** so ComfyUI-Manager can still offer updates (user's choice, at their risk).

3. **Venv is per-volume**: `.venv-cu128` inside the copied ComfyUI. Migration logic only for the old `.venv` → cu128 rename.

4. **comfyui_args.txt** is the only supported way to pass extra CLI flags. One per line, `#` comments ignored.

5. **Heavy user data must live on /workspace** (models, added custom_nodes, outputs, workflows). The image itself should stay < ~15-18 GB.

---

## Local Development & Build Helpers (current state)

- See `scripts/build-and-push.sh` (created in Sprint 1).
- Run from WSL Ubuntu terminal for best Docker experience.
- See SETUP.md for exact usage and personal Docker Hub naming.

---

## Clarifying Questions (to be answered before Sprint 2 or 3)

1. What is your Docker Hub username / organization? (We will use `yourname/comfyui-wai-illustrious` or similar as the image prefix.)
2. Preferred volume mount path on RunPod? (Default in base is `/workspace` — do you ever want a different root?)
3. Any must-have ComfyUI launch flags right now (e.g. --lowvram, specific attention, max batch, preview method)?
4. Exact preferred subfolder layout under the volume for models vs. a top-level /workspace/models that ComfyUI discovers via extra_model_paths.yaml?
5. Do you want any default workflows or input images seeded on first boot of a fresh volume? (lightweight only)
6. Target GPU(s) for the primary template (A6000 48GB, 4090 24GB, H100, etc.)? This affects VRAM guidance text.
7. Any hard requirement to support CUDA 12.4 legacy pods, or can we stay on the current cu128/cu130 baseline?

Answer any of the above when convenient; we will not block Sprint 2 on them.

---

## Git Hygiene

After every meaningful Sprint completion, run:
```bash
git add -A
git commit -m "Sprint: <one-line description>"
```
(Per project Claude.md instructions.)

---

**Last updated**: During Sprint 1 scaffolding (2026-05-31 context).
**Next action**: User review of SETUP.md + helpers, then Sprint 2 kickoff.
