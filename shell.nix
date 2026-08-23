{ pkgs ? import <nixpkgs> { } }:

let
  # OpenWrt host packages invoke unprefixed binutils. GCC's wrappers load the
  # LTO plugin, while target packages continue using their cross-prefixed tools.
  gccLtoBinutils = pkgs.runCommand "gcc-lto-binutils" {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  } ''
    mkdir -p "$out/bin"
    for tool in ar nm ranlib; do
      makeWrapper "${pkgs.stdenv.cc.cc}/bin/gcc-$tool" "$out/bin/$tool" \
        --prefix PATH : "${pkgs.binutils}/bin"
      ln -s "$tool" "$out/bin/gcc-$tool"
    done
  '';
in
pkgs.mkShell {
  # OpenWrt supplies its own target hardening flags. Nix's host wrapper cannot
  # add format-security while GCC bootstraps its variable-format diagnostics.
  hardeningDisable = [ "format" ];

  # Go's bootstrap emits host tools before the OpenWrt cross toolchain exists.
  # Point those generic-linux executables at NixOS's actual glibc loader.
  GO_LDSO = pkgs.stdenv.cc.bintools.dynamicLinker;

  buildInputs = with pkgs; [
    bash
    binutils
    bison
    bzip2
    cacert
    ccache
    cpio
    coreutils
    curl
    diffutils
    file
    findutils
    flex
    gcc
    gawk
    gettext
    git
    gnumake
    intltool
    libelf
    libxml2
    libxslt
    mercurial
    ncurses
    openssl
    patch
    perl
    pkg-config
    python3
    quilt
    rsync
    subversion
    swig
    unzip
    wget
    which
    xz
    zlib
    zstd
  ];

  shellHook = ''
    export PATH="${gccLtoBinutils}/bin:$PATH"
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    export SSL_CERT_DIR="${pkgs.cacert}/etc/ssl/certs"
  '';
}
