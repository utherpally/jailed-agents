{
  description = "Run LLM agent in sandbox environment";
  inputs = {
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  nixConfig = {
    extra-substituters = [
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  outputs =
    {
      self,
      jail-nix,
      llm-agents,
    }:
    {
      lib = {
        mkJailedClaudeCode =
          {
            pkgs,
            extraPkgs ? [ ],
            permissions ? [ ],
          }:
          self.lib.mkJailedAgent {
            inherit pkgs;
            name = "jailed-claude";
            agent = agents: agents.claude-code;
            permissions =
              combinators:
              with combinators;
              [
                (readwrite (noescape "~/.claude"))
                (readwrite (noescape "~/.claude.json"))
                (add-pkg-deps extraPkgs)
              ]
              ++ (pkgs.lib.toFunction permissions combinators);
          };
        mkJailedOpenCode =
          {
            pkgs,
            extraPkgs ? [ ],
            permissions ? [ ],
          }:
          self.lib.mkJailedAgent {
            inherit pkgs;
            name = "jailed-opencode";
            agent = agents: agents.opencode;
            permissions =
              combinators:
              with combinators;
              [
                (readwrite (noescape "~/.config/opencode"))
                (add-pkg-deps extraPkgs)
              ]
              ++ (pkgs.lib.toFunction permissions combinators);
          };
        mkJailedPi =
          {
            pkgs,
            extraPkgs ? [ ],
            permissions ? [ ],
          }:
          self.lib.mkJailedAgent {
            inherit pkgs;
            name = "jailed-pi";
            agent = agents: agents.pi;
            permissions =
              combinators:
              with combinators;
              [
                (readwrite (noescape "~/.config/pi"))
                (add-pkg-deps extraPkgs)
              ]
              ++ (pkgs.lib.toFunction permissions combinators);
          };
        mkJailedAgent =
          {
            name,
            agent,
            pkgs,
            permissions ? [ ],
            defaultOption ? true,
            defaultPkg ? true,
          }:
          let
            inherit (pkgs.lib) toFunction optionals;
            jail = jail-nix.lib.init pkgs;
            combinators = jail.combinators;
            agents = self.packages.${pkgs.stdenv.hostPlatform.system};
            jail-agent = toFunction agent agents;
            jail-permissions = toFunction permissions combinators;

            defaultOptions = with combinators; [
              network
              time-zone
              no-new-session
              mount-cwd
            ];
            defaultPkgs = with pkgs; [
              bashInteractive
              curl
              wget
              jq
              git
              which
              ripgrep
              gnugrep
              gawkInteractive
              ps
              findutils
              gzip
              unzip
              gnutar
              diffutils
              libnotify
            ];
          in
          jail name jail-agent (
            (optionals defaultOption defaultOptions)
            ++ (optionals defaultPkg [ (combinators.add-pkg-deps defaultPkgs) ])
            ++ jail-permissions
          );
      };
      # Re-export llm agents
      packages = llm-agents.packages // {
        x86_64-linux = llm-agents.packages.x86_64-linux // {
          pi =
            let
              pi-agent = llm-agents.packages.x86_64-linux.pi;
              nixpkgs = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.nixpkgs;
              pkgs =
                (import (fetchTarball {
                  url = "https://github.com/nixos/nixpkgs/archive/${nixpkgs.locked.rev}.tar.gz";
                  sha256 = nixpkgs.locked.narHash;
                }) { system = "x86_64-linux"; });
            in
            pkgs.stdenvNoCC.mkDerivation {
              inherit (pi-agent) pname version meta;
              dontUnpack = true;
              dontBuild = true;
              nativeBuildInputs = with pkgs; [
                makeWrapper
              ];
              installPhase = ''
                makeWrapper "${pi-agent}/bin/pi" "$out/bin/pi" \
                  --inherit-argv0 \
                  --set-default PI_CONFIG_DIR '~/.config/pi' \
                  --set-default PI_CODING_AGENT_DIR '~/.config/pi/agent'
              '';
            };
        };
      };
    };
}
