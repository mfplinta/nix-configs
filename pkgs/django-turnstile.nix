{
  lib,
  buildPythonPackage,
  django,
  fetchFromGitHub,
  pythonOlder,
  setuptools,
}:

buildPythonPackage rec {
  pname = "django-turnstile";
  version = "0.1.1";
  pyproject = true;

  disabled = pythonOlder "3.6";

  src = fetchFromGitHub {
    owner = "zmh-program";
    repo = pname;
    rev = "e91e13420a5e278d8f7f6a35d9e56c39e0b9105e";
    hash = "sha256-3kPNPhvOsN66ktwACduROizmSEIYzvOFBBq6oH9UK5Q=";
  };

  nativeBuildInputs = [ setuptools ];

  propagatedBuildInputs = [
    django
  ];

  doCheck = false;

  meta = with lib; {
    description = "Add Cloudflare Turnstile validator widget to the forms of your django project.";
    homepage = "https://github.com/zmh-program/django-turnstile";
    changelog = "https://github.com/zmh-program/django-turnstile";
    license = licenses.mit;
  };
}
