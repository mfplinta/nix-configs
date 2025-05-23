{ stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "bibata-modern-ice";
  version = "2.0.6";

  src = builtins.fetchTarball {
    url = "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz";
    sha256 = "01acywlhs45hisa16ydmyq5r8zr49f7rnf6smz6k3x6avm0wsvs8";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons/Bibata-Modern-Ice
    mv * $out/share/icons/Bibata-Modern-Ice

    runHook postInstall
  '';
}
