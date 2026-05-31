# Docker Buildx Bake --set Gotchas (Institutional Memory)

**Date added**: 2026-06-01  
**Trigger**: Incorrect tag override syntax in `scripts/build-and-push.sh` during Sprint 1 scaffolding.

## The Specific Mistake

When using `docker buildx bake --set` to override the `tags` list on a target, the author used HCL-style indexed array syntax:

```bash
--set "regular.tags[0]=myimage:foo"
--set "regular.tags[1]=myimage:bar"
```

**This is wrong for the bake CLI override language.**

## The Correct Pattern

```bash
--set "regular.tags=myimage:foo-cuda12.8"      # First = replaces the entire list
--set "regular.tags+=myimage:foo"              # Subsequent += appends
```

Or in the script:

```bash
SET_TAGS+=("regular.tags=$PERSONAL_REPO:$FINAL_TAG-cuda12.8")
SET_TAGS+=("regular.tags+=$PERSONAL_REPO:$FINAL_TAG")
```

## Root Cause (Why the Hallucination Happened)

- The author was deeply familiar with the `docker-bake.hcl` file, where `tags` is defined as a proper HCL list:
  ```hcl
  tags = [
    "runpod/comfyui:${TAG}-cuda12.8",
    "runpod/comfyui:cuda12.8",
  ]
  ```
- They mentally mapped the `--set` override syntax to HCL array indexing (`tags[0]=`, `tags[1]=`).
- The `docker buildx bake --set` flag uses its own small DSL (documented in `docker buildx bake --help` under "Override" and in the Buildx docs). It does **not** support `[index]` notation for list replacement. Instead it uses `=` to set/replace the whole value and `+=` to append to lists.
- Classic context bleed between the declarative HCL definition and the CLI override mechanism.

## Rule Going Forward (Any Docker / RunPod Image Work)

Whenever touching anything related to:
- `docker buildx bake`
- `docker-bake.hcl`
- Custom tag injection / personal namespace rewriting
- Any script that calls `--set` on bake targets

**Apply these checks**:
1. Never use `[0]`, `[1]`, etc. in `--set` arguments for lists.
2. First assignment for a list key must use plain `key=value` (replaces).
3. Additional values must use `key+=value` (appends).
4. Test the resulting command by printing it before execution (`echo "Executing: ${BAKE_CMD[*]}"` already does this — keep it).
5. When in doubt, run `docker buildx bake --help | grep -A 30 "Override"` or consult the current Buildx documentation.

This file exists so the same context bleed error is never repeated in this repository or any future RunPod / ComfyUI Docker work.

## Related Files

- `scripts/build-and-push.sh` — contains the corrected implementation + explanatory comments.
- `docker-bake.hcl` — correct HCL (not affected).
- `TODO.md` — has a cross-reference to this document.
