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
    rev = "ab2458b2043034e2528c1f9969d6b631a3d69a4a";
    hash = "sha256-+UOvDjLTrMy9i5T2P70DoBOoxdshkGHEwxcu3Hfzf+4=";
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
