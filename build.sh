#!/usr/bin/env bash
set -e

# ====== Configurable Versions ======
TMUX_VERSION=${3:-3.5a}
LIBEVENT_VERSION=${4:-2.1.12}
OPENSSL_VERSION=${5:-3.3.0}
UTF8PROC_VERSION=${6:-2.9.0}

# ====== Directories ======
INSTALL_PREFIX=$1
BUILD_DIR=$2

if [ -z "$INSTALL_PREFIX" ] || [ -z "$BUILD_DIR" ]; then
  echo "Usage: $0 <install_prefix> <build_dir> [tmux_version] [libevent_version] [openssl_version] [utf8proc_version]"
  exit 1
fi

if ! xcode-select -p &>/dev/null; then
  echo "Xcode Command Line Tools are not installed. Please install them and try again."
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
rm -rf "$INSTALL_PREFIX"
mkdir -p "$INSTALL_PREFIX"/{bin,lib,include}

export PATH="$INSTALL_PREFIX/bin:$PATH"
export CFLAGS="-I$INSTALL_PREFIX/include"
export LDFLAGS="-L$INSTALL_PREFIX/lib"

# ====== Build OpenSSL (static only) ======
echo "Building OpenSSL $OPENSSL_VERSION (static)..."
cd "$BUILD_DIR"
curl -LO "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz"
tar -xzf "openssl-$OPENSSL_VERSION.tar.gz"
cd "openssl-$OPENSSL_VERSION"
./Configure no-shared no-dso --prefix="$INSTALL_PREFIX" darwin64-$(uname -m)-cc
make -j"$(sysctl -n hw.ncpu)"
make install_sw

# ====== Build libevent (static only) ======
echo "Building libevent $LIBEVENT_VERSION (static)..."
cd "$BUILD_DIR"
curl -LO "https://github.com/libevent/libevent/releases/download/release-$LIBEVENT_VERSION-stable/libevent-$LIBEVENT_VERSION-stable.tar.gz"
tar -xzf "libevent-$LIBEVENT_VERSION-stable.tar.gz"
cd "libevent-$LIBEVENT_VERSION-stable"
./configure --prefix="$INSTALL_PREFIX" --disable-shared --enable-static
make -j"$(sysctl -n hw.ncpu)"
make install

# ====== Build utf8proc (static only) ======
echo "Building utf8proc $UTF8PROC_VERSION (static)..."
cd "$BUILD_DIR"
curl -LO "https://github.com/JuliaStrings/utf8proc/releases/download/v$UTF8PROC_VERSION/utf8proc-$UTF8PROC_VERSION.tar.gz"
tar -xzf "utf8proc-$UTF8PROC_VERSION.tar.gz"
cd "utf8proc-$UTF8PROC_VERSION"
make clean
make -j"$(sysctl -n hw.ncpu)" libutf8proc.a
make prefix="$INSTALL_PREFIX" install

# ====== Build tmux (link statically to deps) ======
echo "Building tmux $TMUX_VERSION (static deps)..."
cd "$BUILD_DIR"
curl -LO "https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/tmux-$TMUX_VERSION.tar.gz"
tar -xzf "tmux-$TMUX_VERSION.tar.gz"
cd "tmux-$TMUX_VERSION"

# Use static libraries for dependencies
export LIBS="$INSTALL_PREFIX/lib/libevent.a $INSTALL_PREFIX/lib/libutf8proc.a $INSTALL_PREFIX/lib/libssl.a $INSTALL_PREFIX/lib/libcrypto.a -lz -lm"
export LIBUTF8PROC_CFLAGS="-I$INSTALL_PREFIX/include"
export LIBUTF8PROC_LIBS="$INSTALL_PREFIX/lib/libutf8proc.a"

./configure --prefix="$INSTALL_PREFIX" \
  --enable-utf8proc \
  CFLAGS="-I$INSTALL_PREFIX/include" \
  LDFLAGS="-L$INSTALL_PREFIX/lib" \
  LIBS="$LIBS"

make -j"$(sysctl -n hw.ncpu)"
make install

echo ""
echo "tmux $TMUX_VERSION installed successfully in $INSTALL_PREFIX."
echo "You can run it directly: $INSTALL_PREFIX/bin/tmux"
echo "No DYLD_LIBRARY_PATH or install_name_tool needed!"
