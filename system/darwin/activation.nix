{pkgs, ...}: {
  system.activationScripts.postActivation.text = ''
    echo "Installing/updating LibreWolf..."
    ${pkgs.bash}/bin/bash ${../../scripts/install-librewolf.sh}
  '';
}
