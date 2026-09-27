#!/bin/sh
# Env-driven llama-server launcher for HF Inference Endpoints.
# The model repo is mounted read-only at /repository by the platform.
set -eu

: "${MODEL_PATH:=/repository/Ternary-Bonsai-2-27B-PQ2_0.gguf}"
: "${MMPROJ_PATH:=}"
: "${NGL:=${NGL_DEFAULT:-0}}"
: "${CTX_SIZE:=32768}"
: "${PORT:=80}"
: "${TEMP:=1.0}"
: "${TOP_P:=0.95}"
: "${TOP_K:=20}"
: "${MIN_P:=0.05}"
: "${CACHE_TYPE_K:=}"
: "${CACHE_TYPE_V:=}"
: "${FA:=on}"

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: model file not found: $MODEL_PATH" >&2
    echo "Files present in /repository:" >&2
    ls -lh /repository >&2 || true
    exit 1
fi

set -- -m "$MODEL_PATH" \
    --host 0.0.0.0 --port "$PORT" \
    -ngl "$NGL" -fa "$FA" -c "$CTX_SIZE" \
    --jinja \
    --temp "$TEMP" --top-p "$TOP_P" --top-k "$TOP_K" --min-p "$MIN_P"

if [ -n "$CACHE_TYPE_K" ]; then
    set -- "$@" --cache-type-k "$CACHE_TYPE_K"
fi
if [ -n "$CACHE_TYPE_V" ]; then
    set -- "$@" --cache-type-v "$CACHE_TYPE_V"
fi

if [ -n "$MMPROJ_PATH" ]; then
    if [ ! -f "$MMPROJ_PATH" ]; then
        echo "ERROR: mmproj file not found: $MMPROJ_PATH" >&2
        exit 1
    fi
    set -- "$@" --mmproj "$MMPROJ_PATH"
fi

exec /opt/llama/llama-server "$@"
