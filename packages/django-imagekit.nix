{
  lib,
  buildPythonPackage,
  django,
  fetchFromGitHub,
  pillow,
  pythonOlder,
  pilkit,
  django-appconf,
  setuptools,
}:

buildPythonPackage rec {
  pname = "django-imagekit";
  version = "5.0.0";
  pyproject = true;

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "matthewwithanm";
    repo = pname;
    rev = "master";
    hash = "sha256-OESWH2Gw2HdubfxWocG1Os3grN4IdbbJKW1n6fl94Dc=";
  };

  nativeBuildInputs = [ setuptools ];

  propagatedBuildInputs = [
    django
    pillow
    pilkit
    django-appconf
  ];

  # tests only executable in vagrant
  doCheck = false;

  meta = with lib; {
    description = "ImageKit is a Django app for processing images";
    homepage = "https://github.com/matthewwithanm/django-imagekit/";
    changelog = "https://github.com/matthewwithanm/django-imagekit/";
    license = licenses.bsd2;
  };
}
