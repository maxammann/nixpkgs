{ lib
, stdenv
, buildGoModule
, fetchFromGitHub
, go-md2man
, installShellFiles
, pkg-config
, gpgme
, lvm2
, btrfs-progs
, libapparmor
, libselinux
, libseccomp
}:

buildGoModule rec {
  pname = "buildah";
  version = "1.29.1";

  src = fetchFromGitHub {
    owner = "containers";
    repo = "buildah";
    rev = "v${version}";
    hash = "sha256-l21mirarWEOd+XxyM0YgfDiA1JSEr/uqREmBS22C9fs=";
  };

  outputs = [ "out" "man" ];

  vendorHash = null;

  doCheck = false;

  nativeBuildInputs = [ go-md2man installShellFiles pkg-config ];

  buildInputs = [
    gpgme
  ] ++ lib.optionals stdenv.isLinux [
    btrfs-progs
    libapparmor
    libseccomp
    libselinux
    lvm2
  ];

  buildPhase = ''
    runHook preBuild
    patchShebangs .
    make bin/buildah
    make -C docs GOMD2MAN="go-md2man"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/buildah $out/bin/buildah
    installShellCompletion --bash contrib/completions/bash/buildah
    make -C docs install PREFIX="$man"
    runHook postInstall
  '';

  meta = with lib; {
    description = "A tool which facilitates building OCI images";
    homepage = "https://buildah.io/";
    changelog = "https://github.com/containers/buildah/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = with maintainers; [ Profpatsch ] ++ teams.podman.members;
  };
}
