{
  pkgs,
  inputs,
  ...
}: let
  schemeToml = builtins.fromTOML (builtins.readFile "${inputs.earthtone-nvim}/extras/base16-earthtone-light.toml");
in {
  fonts.packages = [
    pkgs.nerd-fonts.monaspace
    pkgs.inter
  ];

  stylix = {
    enable = true;
    base16Scheme = schemeToml.palette // {inherit (schemeToml.scheme) name author;};
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.monaspace;
        name = "MonaspiceAr Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.inter;
        name = "Inter";
      };
      emoji = {
        package = pkgs.emptyDirectory // {meta.mainProgram = "empty-file";};
        name = "";
      };
      sizes = {
        applications = 13;
        desktop = 12;
        popups = 12;
        terminal = 16;
      };
    };
    polarity = "light";
  };
}
