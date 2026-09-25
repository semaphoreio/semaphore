{
  description = "front development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/50ab793786d9de88ee30ec4e4c24fb4236fc2674";
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
            pkgs.nodejs_20
            pkgs.gnumake
            pkgs.git
            pkgs.curl
          ];

          shellHook = ''
            export MIX_HOME="$PWD/.nix-mix"
            export HEX_HOME="$PWD/.nix-hex"
            export PATH="$MIX_HOME/bin:$HEX_HOME/bin:$PATH"
            export ERL_AFLAGS="-kernel shell_history enabled"

            mkdir -p "$MIX_HOME" "$HEX_HOME"

            if [ ! -d "$MIX_HOME/archives" ]; then
              mix local.hex --force --if-missing
              mix local.rebar --force --if-missing
            fi

            if [ -f env/.env.internal-apis ]; then
              set -a
              . env/.env.internal-apis
              set +a
            fi

            export TZ="''${TZ:-UTC}"
            export MIX_ENV="''${MIX_ENV:-dev}"
            export BASE_DOMAIN="''${BASE_DOMAIN:-localhost}"
            export SECRET_KEY_BASE="''${SECRET_KEY_BASE:-keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure}"
            export SESSION_SIGNING_SALT="''${SESSION_SIGNING_SALT:-keyboard-cat-please-use-this-only-for-dev-and-testing-it-is-insecure}"
            export WORKFLOW_TEMPLATES_YAMLS_PATH="''${WORKFLOW_TEMPLATES_YAMLS_PATH:-$PWD/workflow_templates/saas}"
            export SEED_SELF_HOSTED_AGENTS="''${SEED_SELF_HOSTED_AGENTS:-true}"
            export SEED_CLOUD_MACHINES="''${SEED_CLOUD_MACHINES:-true}"
            export EXCLUDE_STUBS="''${EXCLUDE_STUBS:-InstanceConfigMock}"
          '';
        };
      });
}
