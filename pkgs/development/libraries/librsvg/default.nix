{ lib
, stdenv
, fetchurl
, pkg-config
, glib
, gdk-pixbuf
, pango
, cairo
, libxml2
, bzip2
, libintl
, darwin
, rustc
, cargo
, gnome3
, vala
, gobject-introspection
, nixosTests
}:

stdenv.mkDerivation rec {
  pname = "librsvg";
  version = "2.50.4";

  outputs = [ "out" "dev" "installedTests" ];

  src = fetchurl {
    url = "mirror://gnome/sources/${pname}/${lib.versions.majorMinor version}/${pname}-${version}.tar.xz";
    sha256 = "18s0c5bqj88gj5lf62mfprvhwfibnkrxi6h2r2si0b4p9dxi1dis";
  };

  nativeBuildInputs = [
    pkg-config
    rustc
    cargo
    vala
    gobject-introspection
  ] ++ lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
    ApplicationServices
  ]);

  buildInputs = [
    libxml2
    bzip2
    pango
    libintl
  ] ++ lib.optionals stdenv.isDarwin [
    darwin.libobjc
  ];

  propagatedBuildInputs = [
    glib
    gdk-pixbuf
    cairo
  ];

  configureFlags = [
    "--enable-introspection"
    "--enable-vala"
    "--enable-installed-tests"
    "--enable-always-build-tests"
  ] ++ lib.optional stdenv.isDarwin "--disable-Bsymbolic";

  makeFlags = [
    "installed_test_metadir=${placeholder "installedTests"}/share/installed-tests/RSVG"
    "installed_testdir=${placeholder "installedTests"}/libexec/installed-tests/RSVG"
  ];

  NIX_CFLAGS_COMPILE = if stdenv.isDarwin then "-I${cairo.dev}/include/cairo" else null;

  NIX_LDFLAGS = if stdenv.isDarwin then "-lobjc" else null;

  doCheck = false; # all tests fail on libtool-generated rsvg-convert not being able to find coreutils

  # It wants to add loaders and update the loaders.cache in gdk-pixbuf
  # Patching the Makefiles to it creates rsvg specific loaders and the
  # relevant loader.cache here.
  # The loaders.cache can be used by setting GDK_PIXBUF_MODULE_FILE to
  # point to this file in a wrapper.
  postConfigure = ''
    GDK_PIXBUF=$out/lib/gdk-pixbuf-2.0/2.10.0
    mkdir -p $GDK_PIXBUF/loaders
    sed -e "s#gdk_pixbuf_moduledir = .*#gdk_pixbuf_moduledir = $GDK_PIXBUF/loaders#" \
        -i gdk-pixbuf-loader/Makefile
    sed -e "s#gdk_pixbuf_cache_file = .*#gdk_pixbuf_cache_file = $GDK_PIXBUF/loaders.cache#" \
        -i gdk-pixbuf-loader/Makefile
    sed -e "s#\$(GDK_PIXBUF_QUERYLOADERS)#GDK_PIXBUF_MODULEDIR=$GDK_PIXBUF/loaders \$(GDK_PIXBUF_QUERYLOADERS)#" \
         -i gdk-pixbuf-loader/Makefile

    # Fix thumbnailer path
    sed -e "s#@bindir@\(/gdk-pixbuf-thumbnailer\)#${gdk-pixbuf}/bin\1#g" \
        -i gdk-pixbuf-loader/librsvg.thumbnailer.in
  '';

  # Merge gdkpixbuf and librsvg loaders
  postInstall = ''
    mv $GDK_PIXBUF/loaders.cache $GDK_PIXBUF/loaders.cache.tmp
    cat ${gdk-pixbuf.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache $GDK_PIXBUF/loaders.cache.tmp > $GDK_PIXBUF/loaders.cache
    rm $GDK_PIXBUF/loaders.cache.tmp
  '';

  passthru = {
    updateScript = gnome3.updateScript {
      packageName = pname;
      versionPolicy = "odd-unstable";
    };
  };

  meta = with lib; {
    description = "A small library to render SVG images to Cairo surfaces";
    homepage = "https://wiki.gnome.org/Projects/LibRsvg";
    license = licenses.lgpl2Plus;
    maintainers = teams.gnome.members;
    platforms = platforms.unix;
  };
}
