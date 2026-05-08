{...}: {
  custom.llm.rules = {
    nix.source = ../../../config/llm/rules/nix.md;
    lua.source = ../../../config/llm/rules/lua.md;
    rust.source = ../../../config/llm/rules/rust.md;
    go.source = ../../../config/llm/rules/go.md;
    solidity.source = ../../../config/llm/rules/solidity.md;
  };
}
