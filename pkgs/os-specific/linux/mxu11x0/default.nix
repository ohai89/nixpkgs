{
  lib,
  stdenv,
  fetchurl,
  kernel,
}:

let
  srcs = import ./srcs.nix { inherit fetchurl; };
in
stdenv.mkDerivation rec {
  pname = "mxu11x0";

  src =
    if lib.versionAtLeast kernel.version "6.0" then
      srcs.mxu11x0_6.src
    else if lib.versionAtLeast kernel.version "5.0" then
      srcs.mxu11x0_5.src
    else
      srcs.mxu11x0_4.src;
  mxu_version =
    if lib.versionAtLeast kernel.version "6.0" then
      srcs.mxu11x0_6.version
    else if lib.versionAtLeast kernel.version "5.0" then
      srcs.mxu11x0_5.version
    else
      srcs.mxu11x0_4.version;

  version = mxu_version + "-${kernel.version}";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  preBuild = ''
    echo "--- Running preBuild hook to patch C code ---"

    # 1. Change function 'mxu1_break' return type from 'void' to 'int'.
    sed -i 's/static void mxu1_break/static int mxu1_break/' driver/mxu11x0.c

    # 2. Fix the 'return;' with no value.
    #    The error log says this is at line 1747.
    sed -i '1747s/return;/return 0;/' driver/mxu11x0.c

    # 3. Add 'return 0;' at the end of the function.
    #    The log says the error is at line 1760 (the closing brace).
    #    We use 'i' (insert) to add 'return 0;' *before* line 1760.
    sed -i '1760i return 0;' driver/mxu11x0.c

    echo "--- Patching complete ---"
  '';

  buildPhase = ''
    runHook preBuild

    make -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" \
        M="$(pwd)/driver" \
        modules
  '';

  installPhase = ''
    install -v -D -m 644 ./driver/mxu11x0.ko "$out/lib/modules/${kernel.modDirVersion}/kernel/drivers/usb/serial/mxu11x0.ko"
    install -v -D -m 644 ./driver/mxu11x0.ko "$out/lib/modules/${kernel.modDirVersion}/misc/mxu11x0.ko"
  '';

  dontStrip = true;

  enableParallelBuilding = true;

  hardeningDisable = [ "pic" ];

  meta = with lib; {
    description = "MOXA UPort 11x0 USB to Serial Hub driver";
    homepage = "https://www.moxa.com/en/products/industrial-edge-connectivity/usb-to-serial-converters-usb-hubs/usb-to-serial-converters/uport-1000-series";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ uralbash ];
    platforms = platforms.linux;
    # broken due to API change in write_room() > v5.14-rc1
    # https://github.com/torvalds/linux/commit/94cc7aeaf6c0cff0b8aeb7cb3579cee46b923560
    broken = (kernel.kernelAtLeast "5.14") && (lib.versionOlder kernel.version "6.0");
  };
}
