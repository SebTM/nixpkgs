{ lib
, stdenv
, fetchurl
, makeWrapper
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, cups
, dbus
, expat
, gdk-pixbuf
, glib
, gtk3
, libX11
, libXcomposite
, libXdamage
, libXext
, libXfixes
, libXrandr
, libdrm
, libxcb
, libxkbcommon
, libxshmfence
, mesa
, nspr
, nss
, pango
, systemd
, xdg-utils
, libudev
, xorg
}:
stdenv.mkDerivation rec {
  pname = "1password";
  version = "8.1.2-2.BETA";

  src = fetchurl {
    url = "https://downloads.1password.com/linux/tar/beta/x86_64/1password-${version}.x64.tar.gz";
    sha256 = "10rj2qahdqq76jm09cvw7g1bzrrh5pdy446yz2p0pf5n9hha8hp6";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;
  dontPatchELF = true;

  installPhase =
    let rpath = lib.makeLibraryPath [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libX11
      libXcomposite
      libXdamage
      libXext
      libXfixes
      libXrandr
      libdrm
      libxcb
      libxkbcommon
      libxshmfence
      mesa
      nspr
      nss
      pango
      systemd
    ] + ":${stdenv.cc.cc.lib}/lib64";
    in ''
      runHook preInstall

      mkdir -p $out/bin $out/share/1password
      cp -a * $out/share/1password

      # Desktop file
      install -Dt $out/share/applications resources/${pname}.desktop
      substituteInPlace $out/share/applications/${pname}.desktop \
        --replace 'Exec=/opt/1Password/${pname}' 'Exec=${pname}'

      # Icons
      cp -a resources/icons $out/share

      interp="$(cat $NIX_CC/nix-support/dynamic-linker)"
      patchelf --set-interpreter $interp $out/share/1password/{1password,1Password-BrowserSupport,1Password-KeyringHelper}
      patchelf --set-rpath ${rpath}:$out/share/1password $out/share/1password/{1password,1Password-BrowserSupport,1Password-KeyringHelper}
      for file in $(find $out -type f -name \*.so\* ); do
        patchelf --set-rpath ${rpath}:$out/share/1password $file
      done

      makeWrapper $out/share/1password/1password $out/bin/1password \
        --prefix PATH : ${xdg-utils}/bin \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc libudev xorg.libXtst ]}"

      mv $out/share/1password/1Password-KeyringHelper $out/share/1password/1Password-KeyringHelper2
      ln -sf /run/wrappers/bin/_1password-keyring-helper $out/share/1password/1Password-KeyringHelper

      install -D -m0644 com.1password.1Password.policy \
        $out/share/polkit-1/actions/com.1password.1Password.policy

      runHook postInstall
    '';

  passthru.updateScript = ./update.sh;

  meta = with lib; {
    description = "Multi-platform password manager";
    homepage = "https://1password.com/";
    license = licenses.unfree;
    maintainers = with maintainers; [ timstott savannidgerinel ];
    platforms = [ "x86_64-linux" ];
  };
}