{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}: let
  version = "2.1.27";
in
  buildNpmPackage {
    pname = "gitlab-mcp";
    inherit version;

    src = fetchFromGitHub {
      owner = "zereight";
      repo = "gitlab-mcp";
      rev = "v${version}";
      hash = "sha256-ZWcqxmAEvZHmWh+u0fa3iScz+uN8oZrIWI+Zu5VV5Mo=";
    };

    npmDepsHash = "sha256-z/Y4R95mmqu9AQHq9eU31q3Ewz9/n6aCEzz3yGEUOxc=";

    meta = {
      description = "GitLab MCP server (projects, merge requests, issues, pipelines, wiki, releases)";
      homepage = "https://github.com/zereight/gitlab-mcp";
      license = lib.licenses.mit;
      mainProgram = "mcp-gitlab";
    };
  }
