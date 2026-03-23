{
  vim-tidal,
  difftastic-src,
}: final: prev: let
  packages = import ./packages.nix {inherit vim-tidal difftastic-src;} final prev;
  fixes = import ./fixes.nix final prev;
in
  packages // fixes
