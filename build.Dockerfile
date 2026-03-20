# syntax=docker/dockerfile:1
# =============================================================================
# ONNX Runtime — Jetson (JetPack 5.1.4 / L4T R35.4.1)
# =============================================================================
#
# Build (natively on the Jetson):
#
#   docker build --output type=local,dest=. -f build.Dockerfile .
#
# The first build compiles ONNX Runtime from source (~30-60 min on Jetson
# Xavier). Docker layer caching means subsequent rebuilds of the Rust app
# skip the ORT build entirely.
# =============================================================================

# ---------------------------------------------------------------------------
# Build ONNX Runtime C shared library from source
# ---------------------------------------------------------------------------
# l4t-jetpack provides CUDA 11.4, cuDNN 8.6, TensorRT 8.5.2 plus all
# development headers needed to compile ORT with GPU execution providers.
# ---------------------------------------------------------------------------
ARG L4T_VER=35.4.1
FROM nvcr.io/nvidia/l4t-jetpack:r${L4T_VER} AS ort-builder

ARG L4T_VER
ARG JP_VER=5.1.4
ARG ORT_VERSION=v1.18-jetpack-5.1
ARG ORT_BASE_COMMIT=9691af1a2a39e1e788e23a2a2b63e8a3df533e5e

# ORT build dependencies.
# GCC 10 is used — nvcc 11.4 is incompatible with GCC 11's libstdc++
# (std::function parameter-pack bugs). GCC 9 (system default) is
# rejected by ORT's MLAS ARM bfloat16/fp16 compiler-flag checks.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        git \
        python3 python3-pip python3-dev python3-numpy python3-wheel \
        software-properties-common \
    && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update \
    && apt-get install -y --no-install-recommends gcc-10 g++-10 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100 \
    && update-alternatives --install /usr/bin/cc  cc  /usr/bin/gcc-10 100 \
    && update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-10 100 \
    && pip3 install --no-cache-dir 'cmake>=3.26,<3.30' psutil

RUN --mount=type=cache,target=/ort-src \
    echo "Cloning ORT fork" && \
    find /ort-src -mindepth 1 -delete 2>/dev/null || true && \
    git clone --single-branch --branch ${ORT_VERSION} --recursive \
        https://github.com/thenadz/onnxruntime4jetpack /ort-src

WORKDIR /ort-src

# Build the C shared library with CUDA + TensorRT support.
# (TRT provider is built but not used by the Rust application — CUDA EP only.
#  Keeping --use_tensorrt preserves the Docker layer cache from prior builds.)
# --build_dir uses a cache mount so compiled objects survive across rebuilds.
#
# CMAKE_CXX_FLAGS / CMAKE_CUDA_STANDARD / CMAKE_CUDA_FLAGS are REQUIRED:
# ORT sets CMAKE_CXX_STANDARD=17 but it doesn't propagate to all targets.
# Forcing -std=c++17 via CMAKE_CXX_FLAGS applies it globally to host code.
# CMAKE_CUDA_STANDARD=17 does the same for .cu files compiled by nvcc.
#
# --diag-suppress=940: nvcc 11.4 promotes "missing return at end of non-void
# function" to a hard error, while newer nvcc treats it as a warning.  ORT
# v1.18.0 has several .cu files with code paths that trigger this (e.g.
# _IsInf for FP8 types, MaxPoolWithIndex lambda).  The code is correct —
# the "missing" returns are in unreachable branches — so suppressing 940 is
# safe and avoids file-by-file patching.
RUN --mount=type=cache,target=/ort-src \
    --mount=type=cache,target=/ort-build \
    # Define the build command once — used here and recorded in BUILD_INFO.json.
    BUILD_CMD="./build.sh --build_dir /ort-build --config Release --build_shared_lib --parallel --skip_tests --allow_running_as_root --use_cuda --cuda_home /usr/local/cuda --cudnn_home /usr/lib/aarch64-linux-gnu --use_tensorrt --tensorrt_home /usr/lib/aarch64-linux-gnu --cmake_extra_defines 'CMAKE_CXX_FLAGS=-std=c++17 -DDISABLE_FLOAT8_TYPES' CMAKE_CUDA_STANDARD=17 'CMAKE_CUDA_FLAGS=--diag-suppress=940 -DDISABLE_FLOAT8_TYPES' CMAKE_CUDA_ARCHITECTURES=72 onnxruntime_BUILD_UNIT_TESTS=OFF" && \
    printf '%s\n' "$BUILD_CMD" > /tmp/build_cmd.txt && \
    rm -f /ort-build/Release/CMakeCache.txt && \
    eval "$BUILD_CMD" \
    # Parallel build output is often verbose and convoluted - if we fail,
    # retry on 1 thread for clear failure diagnostics.
    || { echo "=== PARALLEL BUILD FAILED — retrying -j1 to surface error ===" ; \
         cmake --build /ort-build/Release --config Release -- -j1 2>&1 \
           | tail -200 ; \
         false ; } \
    && cp /ort-build/Release/libonnxruntime.so* /usr/local/lib/ \
    && cp /ort-build/Release/libonnxruntime_providers_shared.so /usr/local/lib/ \
    && cp /ort-build/Release/libonnxruntime_providers_cuda.so /usr/local/lib/ \
    && cp /ort-build/Release/libonnxruntime_providers_tensorrt.so /usr/local/lib/

# Verify OrtGetApiBase is a GLOBAL dynamic symbol.
RUN readelf -Ws /usr/local/lib/libonnxruntime.so | grep OrtGetApiBase

# ---------------------------------------------------------------------------
# Package: assemble release tarball
# ---------------------------------------------------------------------------
RUN --mount=type=cache,target=/ort-src \
    set -e && \
    STAGE=/tmp/tarball-staging && mkdir -p "$STAGE" && \
    \
    # ── shared libraries ── \
    cp /usr/local/lib/libonnxruntime*.so* "$STAGE/" && \
    \
    # ── LICENSE + ThirdPartyNotices.txt ── \
    cp /ort-src/LICENSE "$STAGE/LICENSE" && \
    cp /ort-src/ThirdPartyNotices.txt "$STAGE/ThirdPartyNotices.txt" && \
    \
    # ── Detect versions from the build environment ── \
    ORT_VER=$(cat /ort-src/VERSION_NUMBER) && \
    FORK_COMMIT=$(git -C /ort-src rev-parse HEAD) && \
    PATCH_SHAS=$(git -C /ort-src log --reverse --format='"%H"' | paste -sd, -) && \
    BUILD_CMD=$(cat /tmp/build_cmd.txt) && \
    CMAKE_VER=$(cmake --version | head -1 | awk '{print $3}') && \
    PYTHON_VER=$(python3 --version | awk '{print $2}') && \
    CUDA_VER=$(nvcc --version | grep -oP 'release \K[0-9.]+') && \
    CUDNN_VER=$(cat /usr/include/cudnn_version.h 2>/dev/null \
                | grep -oP 'CUDNN_MAJOR\s+\K\d+' | head -1 || echo "unknown") && \
    CUDNN_MINOR=$(cat /usr/include/cudnn_version.h 2>/dev/null \
                  | grep -oP 'CUDNN_MINOR\s+\K\d+' | head -1 || echo "0") && \
    CUDNN_PATCH=$(cat /usr/include/cudnn_version.h 2>/dev/null \
                  | grep -oP 'CUDNN_PATCHLEVEL\s+\K\d+' | head -1 || echo "0") && \
    TRT_VER=$(dpkg -l 2>/dev/null | grep -oP 'libnvinfer\d*\s+\K[0-9][0-9.]*' | head -1 || echo "unknown") && \
    TRT_SHORT=$(echo "$TRT_VER" | grep -oP '^\d+\.\d+\.\d+') && \
    GCC_VER=$(gcc --version | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1) && \
    GPP_VER=$(g++ --version | head -1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1) && \
    L4T_VER="R${L4T_VER}" && \
    ARCH=$(uname -m) && \
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ) && \
    \
    # ── Compose tarball name ── \
    TARBALL_NAME="onnxruntime-jetson-v${ORT_VER}-jp${JP_VER}-cuda${CUDA_VER}-trt${TRT_SHORT}-${ARCH}.tar.gz" && \
    echo "$TARBALL_NAME" > /tmp/tarball_name.txt && \
    \
    # ── BUILD_INFO.json ── \
    cat > "$STAGE/BUILD_INFO.json" <<ENDJSON
{
  "ort_version": "${ORT_VER}",
  "ort_commit": "${ORT_BASE_COMMIT}",
  "fork_repo": "https://github.com/thenadz/onnxruntime4jetpack",
  "fork_branch": "${ORT_VERSION}",
  "fork_commit": "${FORK_COMMIT}",
  "jetpack_version": "${JP_VER}",
  "l4t_version": "${L4T_VER}",
  "cuda_version": "${CUDA_VER}",
  "cudnn_version": "${CUDNN_VER}.${CUDNN_MINOR}.${CUDNN_PATCH}",
  "tensorrt_version": "${TRT_VER}",
  "arch": "${ARCH}",
  "compiler": {
    "gcc": "gcc-10 (${GCC_VER})",
    "gxx": "g++-10 (${GPP_VER})"
  },
  "cmake_version": "${CMAKE_VER}",
  "python_version": "${PYTHON_VER}",
  "build_command": "${BUILD_CMD}",
  "applied_patches": [${PATCH_SHAS}],
  "build_timestamp_utc": "${TIMESTAMP}"
}
ENDJSON

# Finalize tarball with checksums.
RUN set -e && \
    STAGE=/tmp/tarball-staging && \
    TARBALL_NAME=$(cat /tmp/tarball_name.txt) && \
    cd "$STAGE" && \
    sha256sum -- $(ls -1 | grep -v '^SHA256SUMS$') > SHA256SUMS && \
    tar czf "/tmp/${TARBALL_NAME}" -C "$STAGE" .

# ---------------------------------------------------------------------------
# Export stage — extract the tarball to the host
# ---------------------------------------------------------------------------
FROM scratch AS export
COPY --from=ort-builder /tmp/onnxruntime-jetson-*.tar.gz /
