# llama-prism-bonsai2

Docker images packaging the [PrismML fork of llama.cpp](https://github.com/PrismML-Eng/llama.cpp)
(pinned release `prism-b10743-adfffbe`, build 10743 / commit `adfffbe41`) for
[Hugging Face Inference Endpoints](https://huggingface.co/docs/inference-endpoints),
built to serve [Ternary Bonsai 2 27B](https://huggingface.co/prism-ml/Ternary-Bonsai-2-27B-gguf).

Stock llama.cpp cannot run the model's ternary packings (`PQ2_0` / `PTQ1_0`) —
it rejects them, or loads `Q2_0` silently and produces garbage. These images run
the fork's prebuilt binaries, which include the ternary hybrid-attention kernels.

## Images

| Image | Base | Notes |
|---|---|---|
| `ghcr.io/kantundpeterpan/llama-prism-bonsai2:prism-b10743-adfffbe` | `ubuntu:24.04` | CPU build (x64), ~50 MB |
| `ghcr.io/kantundpeterpan/llama-prism-bonsai2:prism-b10743-adfffbe-cuda12.8` | `nvidia/cuda:12.8.0-runtime-ubuntu24.04` | CUDA 12.8 build, all layers on GPU by default |

The model weights are **not** in the images. HF Inference Endpoints downloads the
selected model repo and mounts it read-only at `/repository`; the container only
needs the engine binaries.

> The ghcr.io package is set to **inherit visibility from this repo** (public).
> Keep the repo public, or set `image.custom` credentials on the endpoint, or HF
> cannot pull the image.

## Build

```sh
docker build --platform linux/amd64 -f Dockerfile        -t llama-prism-bonsai2:cpu  .
docker build --platform linux/amd64 -f Dockerfile.gpu    -t llama-prism-bonsai2:cuda .
```

The build downloads the pinned release tarball directly from
[github.com/PrismML-Eng/llama.cpp releases](https://github.com/PrismML-Eng/llama.cpp/releases/tag/prism-b10743-adfffbe)
(pin it by changing `ARG PRISM_TAG`), and fails if any shared library is unresolved
(`ldd` gate) or if `llama-server --version` does not run.

## Runtime configuration (env vars)

All knobs are environment variables with sensible defaults — no rebuild needed to
switch quant, context, sampling, or vision.

| Env | Default | Effect |
|---|---|---|
| `MODEL_PATH` | `/repository/Ternary-Bonsai-2-27B-PQ2_0.gguf` | `-m` model file |
| `MMPROJ_PATH` | *(unset)* | `--mmproj` vision projector (omit for text-only) |
| `NGL` | `0` (cpu image) / `99` (cuda image) | `-ngl` GPU layer offload |
| `CTX_SIZE` | `32768` | `-c` max context (up to 262144) |
| `PORT` | `80` | `--port` (HF expects 80) |
| `TEMP` / `TOP_P` / `TOP_K` / `MIN_P` | `1.0` / `0.95` / `20` / `0.05` | model-card sampling |
| `CACHE_TYPE_K` / `CACHE_TYPE_V` | *(unset = f16)* | KV cache dtype, e.g. `q4_0` (~3.5x smaller; needed for 256K ctx on a 16 GB T4) |
| `FA` | `on` | `-fa` flash attention |

Fixed flags: `--jinja` (native OpenAI-style tool calling), `--host 0.0.0.0`.

## Example: HF Inference Endpoint

```
repository: kantundpeterpan/Ternary-Bonsai-2-27B-gguf   (slim mirror: PQ2_0 + mmproj)
framework:  custom
image:      ghcr.io/kantundpeterpan/llama-prism-bonsai2:prism-b10743-adfffbe-cuda12.8
port:       80
health:     /health
compute:    aws eu-west-1, nvidia-t4 x1
env:
  MODEL_PATH:      /repository/Ternary-Bonsai-2-27B-PQ2_0.gguf
  MMPROJ_PATH:     /repository/Ternary-Bonsai-2-27B-mmproj-BF16.gguf
  CTX_SIZE:        262144
  CACHE_TYPE_K:    q4_0
  CACHE_TYPE_V:    q4_0
```

Serves OpenAI-compatible `/v1/chat/completions` (plus llama-server's
`/health`, `/tokenize`, ...). Measured on T4: ~17 tok/s decode.

## Update to a newer fork release

1. Change `ARG PRISM_TAG` in both Dockerfiles (and the matching tarball suffix for
   CUDA if the release renames its artifacts).
2. Rebuild, tag, and push under the new `prism-<tag>` tag.
3. Point the endpoint at the new tag (`update_endpoint` → `model.image.custom.url`).

## Upstream status

Bonsai 2 kernels are being upstreamed to mainline llama.cpp in parts (CPU/Metal
FWHT merged; CUDA/Vulkan in flight as of Sept 2026) — see
[PrismML-Eng/Bonsai-demo](https://github.com/PrismML-Eng/Bonsai-demo) "Upstream
Status". `PQ2_0`/`PTQ1_0` remain fork-specific packings either way. When full
support lands, stock `ghcr.io/ggml-org/llama.cpp` images can be used directly.
