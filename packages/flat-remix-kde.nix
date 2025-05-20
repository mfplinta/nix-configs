{ stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation rec {
  pname = "flat-remix-kde";
  version = "18ac464";

  src = fetchFromGitHub {
    owner = "daniruiz";
    repo = pname;
    rev = "18ac464d5b77dd140aeb6c6b98d687c086959247";
    hash = "sha256-5tce2vG1B9O6mC6GRSP0B6qgDShotRilYP7h8a5knRc=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    mv color-schemes $out/share/color-schemes

    mkdir -p $out/share/aurorae
    mv aurorae/themes $out/share/aurorae/themes

    runHook postInstall
  '';
}
