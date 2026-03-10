{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "youtube-mcp-server";
  version = "1.0.0-unstable-2025-04-06";

  src = fetchFromGitHub {
    owner = "ZubeidHendricks";
    repo = "youtube-mcp-server";
    rev = "4152fb93fc4da723e3c6092e6c63497fc571e5a2";
    hash = "sha256-ApWkf7Q3MMjd16MnU4QOYNUQBBCHz7kkaEsR+sdFvRI=";
  };

  postPatch = ''
    cp ${./youtube-mcp-server-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-rXTzTzDc/lmwOZlzjOpttpVCbEScheNOVrNr6knDm94=";

  meta = {
    description = "YouTube MCP server for AI language models";
    homepage = "https://github.com/ZubeidHendricks/youtube-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "zubeid-youtube-mcp-server";
  };
}
