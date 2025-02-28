{ lib
, stdenv
, callPackage
, fetchFromGitHub
, fetchurl
, autoPatchelfHook
, makeWrapper
, buildNpmPackage
, cmake
, avahi
, libevdev
, libpulseaudio
, xorg
, libxcb
, openssl
, libopus
, ffmpeg_5-full
, boost
, pkg-config
, libdrm
, wayland
, libffi
, libcap
, mesa
, curl
, libva
, libvdpau
, numactl
, amf-headers
, svt-av1
, vulkan-loader
, cudaSupport ? false
, cudaPackages ? {}
}:
let
  libcbs = callPackage ./libcbs.nix { };
  # get cmake file used to find external ffmpeg from previous sunshine version
  findFfmpeg = fetchurl {
    url = "https://raw.githubusercontent.com/LizardByte/Sunshine/6702802829869547708dfec98db5b8cbef39be89/cmake/FindFFMPEG.cmake";
    sha256 = "sha256:1hl3sffv1z8ghdql5y9flk41v74asvh23y6jmaypll84f1s6k1xa";
  };
in
stdenv.mkDerivation rec {
  pname = "sunshine";
  version = "0.18.4";

  src = fetchFromGitHub {
    owner = "LizardByte";
    repo = "Sunshine";
    rev = "v${version}";
    sha256 = "sha256-nPUWBka/fl1oTB0vTv6qyL7EHh7ptFnxwfV/jYtloTc=";
    fetchSubmodules = true;
  };

  # remove pre-built ffmpeg; use ffmpeg from nixpkgs
  patches = [ ./ffmpeg.diff ];

  # fetch node_modules needed for webui
  ui = buildNpmPackage {
    inherit src version;
    pname = "sunshine-ui";
    npmDepsHash = "sha256-k8Vfi/57AbGxYFPYSNh8bv4KqHnZjk3BDp8SJQHzuR8=";

    dontNpmBuild = true;

    # use generated package-lock.json upstream does not provide one
    postPatch = ''
      cp ${./package-lock.json} ./package-lock.json
    '';

    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    autoPatchelfHook
    makeWrapper
  ] ++ lib.optionals cudaSupport [
    cudaPackages.autoAddOpenGLRunpathHook
  ];

  buildInputs = [
    libcbs
    avahi
    ffmpeg_5-full
    libevdev
    libpulseaudio
    xorg.libX11
    libxcb
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXtst
    openssl
    libopus
    boost
    libdrm
    wayland
    libffi
    libevdev
    libcap
    libdrm
    curl
    libva
    libvdpau
    numactl
    mesa
    amf-headers
    svt-av1
  ] ++ lib.optionals cudaSupport [
    cudaPackages.cudatoolkit
  ];

  runtimeDependencies = [
    avahi
    mesa
    xorg.libXrandr
    libxcb
  ];

  CXXFLAGS = [
    "-Wno-format-security"
  ];
  CFLAGS = [
    "-Wno-format-security"
  ];

  cmakeFlags = [
    "-Wno-dev"
  ];

  postPatch = ''
    # fix hardcoded libevdev path
    substituteInPlace CMakeLists.txt \
      --replace '/usr/include/libevdev-1.0' '${libevdev}/include/libevdev-1.0'

    # add FindFFMPEG to source tree
    cp ${findFfmpeg} cmake/FindFFMPEG.cmake
  '';

  preBuild = ''
    # copy node_modules where they can be picked up by build
    mkdir -p ../node_modules
    cp -r ${ui}/node_modules/* ../node_modules
  '';

  # allow Sunshine to find libvulkan
  postFixup = lib.optionalString cudaSupport ''
    wrapProgram $out/bin/sunshine \
      --set LD_LIBRARY_PATH ${lib.makeLibraryPath [ vulkan-loader ]}
  '';

  meta = with lib; {
    description = "Sunshine is a Game stream host for Moonlight.";
    homepage = "https://github.com/LizardByte/Sunshine";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ devusb ];
    platforms = platforms.linux;
  };
}
