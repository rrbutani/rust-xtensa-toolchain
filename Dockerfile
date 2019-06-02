# Dev environment container for Rust Xtensa devices.
# Has:
#   -


ARG BASE=ubuntu:18.04
ARG VERSION=0.1.0
ARG CLANG_VER=7
ARG RUST_INSTALL_DIR=/opt/rust
ARG ESP_TOOLCHAIN_INSTALL_DIR=/opt/esp-toolchain
ARG ESP_TOOLCHAIN_VER=1.22.0-80-g6c4433a-5.2.0
ARG ESP_IDF_INSTALL_DIR=/opt/esp-idf
ARG ESP_IDF_TAG=v3.2
ARG NINJA_TAG=v1.9.0
ARG LLVM_XTENSA_COMMIT_SHA=757e18f722dbdcd98b8479e25041b1eee1128ce9
ARG CLANG_XTENSA_COMMIT_SHA=248d9ce8765248d953c3e5ef4022fb350bbe6c51
ARG XTENSA_RUST_SHA=bba6c06d7eae6d9d9c3f48c68ab80ed0f2681859

# Builds the things!
FROM $BASE as build

RUN : \
 && apt-get update -y \
    -qq 2>/dev/null \
 && apt-get upgrade -y \
    -qq 2>/dev/null \
 && apt-get install -y \
        curl gnupg \
        git make \
        python3 \
        cmake \
        python2.7 \
        pkg-config libssl-dev \
    -qq 2>/dev/null \
 && update-alternatives \
    --install /usr/bin/python python $(which python3) 1

RUN : \
 && curl https://apt.llvm.org/llvm-snapshot.gpg.key \
    | apt-key add - \
 && . /etc/lsb-release \
 && echo \
        "deb http://apt.llvm.org/${DISTRIB_CODENAME:-disco}/ llvm-toolchain-${DISTRIB_CODENAME:-disco} main" \
    >> /etc/apt/sources.list.d/llvm.list \
 && echo \
        "deb-src http://apt.llvm.org/${DISTRIB_CODENAME:-disco}/ llvm-toolchain-${DISTRIB_CODENAME:-disco} main" \
    >> /etc/apt/sources.list.d/llvm.list

ARG CLANG_VER
RUN : \
 && apt-get update -y \
    -qq 2>/dev/null \
 && apt-get install -y \
        clang-${CLANG_VER} \
    -qq 2>/dev/null \
 && update-alternatives \
    --install /usr/bin/cc cc $(which clang-${CLANG_VER}) 99

WORKDIR /opt

ARG NINJA_TAG
RUN : \
 && git clone https://github.com/ninja-build/ninja.git \
 && cd ninja \
 && git checkout ${NINJA_TAG} \
 && CXX=clang++-${CLANG_VER} ./configure.py --bootstrap \
 && cp /opt/ninja/ninja /usr/bin/ninja

ARG LLVM_XTENSA_COMMIT_SHA
ARG CLANG_XTENSA_COMMIT_SHA
RUN : \
 && git clone https://github.com/espressif/llvm-xtensa.git \
    -b esp-develop \
    && cd llvm-xtensa \
    && git checkout ${LLVM_XTENSA_COMMIT_SHA} \
    && cd .. \
 && git clone https://github.com/espressif/clang-xtensa.git \
    -b esp-develop llvm-xtensa/tools/clang \
    && cd llvm-xtensa/tools/clang \
    && git checkout ${CLANG_XTENSA_COMMIT_SHA} \
    && cd ../../../ \
 && mkdir llvm_build \
 && cd llvm_build \
 && CXX=clang++-${CLANG_VER} CMAKE_CXX_COMPILER=clang++-${CLANG_VER} cmake ../llvm-xtensa \
    -DLLVM_TARGETS_TO_BUILD="Xtensa;X86" \
    -DCMAKE_BUILD_TYPE=Release \
    -G "Ninja" \
 && ninja

# Versions of git prior to 2.18.0 don't support the --progress flag with `git
# submodule` commands. Ubuntu 18.04 ships with git 2.17.1. To get around this,
# we'll modify x.py so that it doesn't try to pass --progress to submodule
# commands. If you're using a BASE that ships with git 2.18.0+ this isn't
# necessary but it doesn't hurt.
#
# This is, by the way, is issue #57080 which was fixed in #60379.
# (https://github.com/rust-lang/rust/issues/57080)
# Unforunately the rust-xtensa fork that we're using forked before this PR was
# merged so, we have to do a gross hack. This will hopefully change in the
# future!
ARG XTENSA_RUST_SHA
RUN : \
 && git clone https://github.com/MabezDev/rust-xtensa.git \
    -b xtensa-target \
 && cd rust-xtensa \
 && git checkout ${XTENSA_RUST_SHA}

    #--prefix="/opt/rust" \
ARG RUST_INSTALL_DIR
RUN : \
 && update-alternatives \
    --install /usr/bin/c++ c++ $(which clang++-${CLANG_VER}) 99 \
 && cd rust-xtensa \
 && sed -i 's/\"\-\-progress\",//g' src/bootstrap/bootstrap.py \
 && ./configure \
    --llvm-root="/opt/llvm_build" \
    --enable-extended \
    --tools="cargo,rustfmt,src" \
    --datadir="${RUST_INSTALL_DIR}/data" \
    --sysconfdir="${RUST_INSTALL_DIR}/sysconf" \
    --infodir="${RUST_INSTALL_DIR}/info" \
    --libdir="${RUST_INSTALL_DIR}/lib" \
    --mandir="${RUST_INSTALL_DIR}/man" \
    --docdir="${RUST_INSTALL_DIR}/doc" \
    --bindir="${RUST_INSTALL_DIR}/bin" \
    --localstatedir="${RUST_INSTALL_DIR}/localstate" \
 && ./x.py build \
 && ./x.py install

ARG ESP_TOOLCHAIN_INSTALL_DIR
ARG ESP_TOOLCHAIN_VER
RUN : \
 && mkdir -p "${ESP_TOOLCHAIN_INSTALL_DIR}" \
 && cd "${ESP_TOOLCHAIN_INSTALL_DIR}" \
 && curl https://dl.espressif.com/dl/xtensa-esp32-elf-linux64-${ESP_TOOLCHAIN_VER}.tar.gz \
    | tar -xzf -

ARG ESP_IDF_INSTALL_DIR
ARG ESP_IDF_TAG
RUN : \
  && git clone https://github.com/espressif/esp-idf.git \
    -b ${ESP_IDF_TAG} \
    --recursive \
    ${ESP_IDF_INSTALL_DIR}

FROM $BASE as dev

ARG BASE
ARG VERSION
ARG RUST_INSTALL_DIR
ARG LLVM_XTENSA_COMMIT_SHA
ARG CLANG_XTENSA_COMMIT_SHA
ARG XTENSA_RUST_SHA
ARG ESP_TOOLCHAIN_INSTALL_DIR
ARG ESP_TOOLCHAIN_VER
ARG ESP_IDF_INSTALL_DIR
ARG ESP_IDF_TAG

LABEL version=${VERSION}
LABEL props.base-image=${BASE}
LABEL props.rust-install-dir=${RUST_INSTALL_DIR}
LABEL props.llvm-xtensa-commit-sha=${LLVM_XTENSA_COMMIT_SHA}
LABEL props.clang-xtensa-commit-sha=${CLANG_XTENSA_COMMIT_SHA}
LABEL props.xtensa-rust-commit-sha=${XTENSA_RUST_SHA}
LABEL props.esp-toolchain-install-dir=${ESP_TOOLCHAIN_INSTALL_DIR}
LABEL props.esp-toolchain-version=${ESP_TOOLCHAIN_VER}
LABEL props.esp-idf-install-dir=${ESP_IDF_INSTALL_DIR}
LABEL props.esp-idf-tag=${ESP_IDF_TAG}

ENV VERSION=${VERSION}
ENV RUST_INSTALL_DIR=${RUST_INSTALL_DIR}

COPY --from=build "${RUST_INSTALL_DIR}" "${RUST_INSTALL_DIR}"
COPY --from=build "${ESP_TOOLCHAIN_INSTALL_DIR}" "${ESP_TOOLCHAIN_INSTALL_DIR}"
COPY --from=build "${ESP_IDF_INSTALL_DIR}" "${ESP_IDF_INSTALL_DIR}"

COPY xtensa.json "${RUST_INSTALL_DIR}/specs"

ENV CARGO_HOME="${RUST_INSTALL_DIR}/cargo-home"
ENV PATH="${PATH}:${RUST_INSTALL_DIR}/bin:${ESP_TOOLCHAIN_INSTALL_DIR}/xtensa-esp32-elf/bin:${CARGO_HOME}/bin"

ENV XARGO_RUST_SRC="${RUST_INSTALL_DIR}/lib/rustlib/src/rust/src/"
ENV RUSTC="${RUST_INSTALL_DIR}/bin/rustc"
ENV RUST_TARGET_PATH="${RUST_INSTALL_DIR}/specs"

ENV IDF_PATH="${ESP_IDF_INSTALL_DIR}"

RUN :\
 && apt-get update -y \
    -qq 2>/dev/null \
 && apt-get upgrade -y \
    -qq 2>/dev/null \
 && apt-get install -y \
        libssl-dev openssl ca-certificates ssl-cert clang \
    -qq 2>/dev/null \
 && apt-get clean -y \
        -qq 2>/dev/null \
 && apt-get autoremove -y \
        -qq 2>/dev/null \
 && rm -rf \
        /var/tmp/* \
        /var/lib/apt/lists/*

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# && xargo build --release --verbose
RUN : \
 && cargo install xargo

WORKDIR /opt/project

CMD ["xargo", "build", "--release", "--verbose"]
