#!/bin/sh
set -euo pipefail

if [ `uname` = "Darwin" ]; then
    # Use specified macOS SDK, and enforce minimum version
    export CXXFLAGS="$CXXFLAGS -isysroot $CONDA_BUILD_SYSROOT"
else
    # Remove after resolving https://github.com/pyre/pyre/issues/64
    export LDFLAGS="-lrt $LDFLAGS"
fi

mkdir build && cd build

# Strip install prefix (and '/') to compute relative $SP_DIR
# Remove after backporting https://github.com/pyre/pyre/pull/60
relpath(){ $PYTHON -c "print('$1'[len('$2')+1:])"; }
pypkgrel=$(relpath $SP_DIR $PREFIX)

# BUILD_TESTING=y enables pyre's test suite
# Remove after merging https://github.com/pyre/pyre/pull/60
# Override LIBDIR from GNUInstallDirs - would be lib64 on centos
# Specify $PYTHON to avoid using system python
cmake \
    -DBUILD_TESTING=y \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DPYRE_DEST_PACKAGES=$pypkgrel \
    -DPython3_EXECUTABLE=$PYTHON \
    $SRC_DIR

cmake --build . --target install -j${CPU_COUNT}

# Disable TCP test on Docker
# Reenable locale_codec after resolving https://github.com/pyre/pyre/issues/65
ctest \
    -E '(pyre.pkg.ipc.tcp.py|python.locale_codec.py)' \
    --output-on-failure
