{
  description = "Billing Elixir development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        erlang = pkgs.beam.packages.erlang_25;
        elixir = erlang.elixir_1_14;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            elixir
            pkgs.erlang_25
            pkgs.nodejs_22
            pkgs.gnumake
          ];

          shellHook = ''
            export MIX_HOME="$PWD/.nix-mix"
            export HEX_HOME="$PWD/.nix-hex"
            export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"
            export ERL_AFLAGS="-kernel shell_history enabled"

            # Create dirs if they don't exist
            mkdir -p "$MIX_HOME" "$HEX_HOME"

            # Install hex and rebar if not present
            if [ ! -f "$MIX_HOME/rebar3" ]; then
              mix local.hex --force --if-missing
              mix local.rebar --force --if-missing
            fi
          '';
        };
      });
}
