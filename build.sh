#!/usr/bin/env bash
set -e

# ====== Configurable Versions ======
TMUX_VERSION=${3:-3.5a}
LIBEVENT_VERSION=${4:-2.1.12}
NCURSES_VERSION=${5:-6.5}
OPENSSL_VERSION=${6:-3.0.16}
UTF8PROC_VERSION=${7:-2.10.0}

# ====== Directories ======
INSTALL_PREFIX=${1:-$PWD/tmux}
BUILD_DIR=${2:-$PWD/build}

# Print the usage message
usage() {
  echo "Usage: $0 [install_prefix] [build_dir] [tmux_version] [libevent_version] [ncurses_version] [openssl_version] [utf8proc_version]"
  echo "Example: $0 ~/bin ~/build 3.5a 2.1.12 6.5 3.0.16 2.10.0"
}

usage

echo "Installation Parameters:"
echo "  Install prefix: $INSTALL_PREFIX"
echo "  Build directory: $BUILD_DIR"
echo "  tmux version: $TMUX_VERSION"
echo "  libevent version: $LIBEVENT_VERSION"
echo "  ncurses version: $NCURSES_VERSION"
echo "  openssl version: $OPENSSL_VERSION"
echo "  utf8proc version: $UTF8PROC_VERSION"

read -p "Do you want to proceed with the installation using these parameters? (y/n): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
  echo "Installation canceled."
  exit 0
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

# ====== Build ncurses (static only) ======
echo "Building ncurses $NCURSES_VERSION (static)..."
cd "$BUILD_DIR"
curl -LO "https://ftp.gnu.org/gnu/ncurses/ncurses-$NCURSES_VERSION.tar.gz"
tar -xzf "ncurses-$NCURSES_VERSION.tar.gz"
cd "ncurses-$NCURSES_VERSION"
./configure --prefix="$INSTALL_PREFIX" --with-shared=no --with-normal --with-cxx-binding --with-cxx --enable-widec --with-static --without-debug --without-ada --without-manpages --without-tests --without-progs
make -j"$(sysctl -n hw.ncpu)"
make install

# For wide-character support, create symlinks for ncursesw
cd "$INSTALL_PREFIX/lib"
for lib in ncurses form panel menu; do
  if [ -f "lib${lib}w.a" ]; then
    ln -sf "lib${lib}w.a" "lib${lib}.a"
  fi
done
cd "$INSTALL_PREFIX/include"
if [ -d "ncursesw" ]; then
  ln -sf ncursesw/* .
fi

# ====== Build tmux ======
echo "Building tmux $TMUX_VERSION ..."
cd "$BUILD_DIR"
curl -LO "https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/tmux-$TMUX_VERSION.tar.gz"
tar -xzf "tmux-$TMUX_VERSION.tar.gz"
cd "tmux-$TMUX_VERSION"

# Use static libraries for dependencies
export LIBS="$INSTALL_PREFIX/lib/libevent.a $INSTALL_PREFIX/lib/libutf8proc.a $INSTALL_PREFIX/lib/libssl.a $INSTALL_PREFIX/lib/libcrypto.a $INSTALL_PREFIX/lib/libncurses.a $INSTALL_PREFIX/lib/libpanel.a $INSTALL_PREFIX/lib/libmenu.a $INSTALL_PREFIX/lib/libform.a -lz -lm"
export LIBUTF8PROC_CFLAGS="-I$INSTALL_PREFIX/include"
export LIBUTF8PROC_LIBS="$INSTALL_PREFIX/lib/libutf8proc.a"

./configure --prefix="$INSTALL_PREFIX" \
  --enable-utf8proc \
  CFLAGS="-I$INSTALL_PREFIX/include" \
  LDFLAGS="-L$INSTALL_PREFIX/lib" \
  LIBS="$LIBS" \
  CPPFLAGS="-I$INSTALL_PREFIX/include" \
  PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig"

make -j"$(sysctl -n hw.ncpu)"
make install

# ====== Cleanup ======
echo ""
echo "Cleaning up build files..."

rm -rf "$BUILD_DIR"

echo ""
echo "tmux $TMUX_VERSION installed successfully in $INSTALL_PREFIX."
echo "You can run it directly: $INSTALL_PREFIX/bin/tmux"
echo "Or add $INSTALL_PREFIX/bin to your PATH."
