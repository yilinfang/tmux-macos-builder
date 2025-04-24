# tmux-macos-builder

A script to automatically build tmux on MacOS without Homebrew or MacPorts.

## Prerequisites

- Xcode command line tools

## Usage

```bash
git clone https://github.com/yilinfang/tmux-macos-builder.git
cd tmux-macos-builder
chmod +x build.sh
./build.sh [install_prefix] [build_dir] [tmux_version] [libevent_version] [ncurses_version] [openssl_version] [utf8proc_version]
```

## Arguments

- `install_prefix`: The directory where tmux and its dependencies will be installed. Default is `$PWD/tmux`.
- `build_dir`: The directory where the build will take place. Default is `$PWD/build`.
- `tmux_version`: The version of tmux to build. Default is `3.5a`.
- `libevent_version`: The version of libevent to build. Default is `2.1.12`.
- `ncurses_version`: The version of ncurses to build. Default is `6.5`.
- `openssl_version`: The version of OpenSSL to build. Default is `3.0.16`.
- `utf8proc_version`: The version of utf8proc to build. Default is `2.10.0`.
