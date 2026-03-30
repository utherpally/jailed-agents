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
            jail = jail-nix.lib.init pkgs;
            combinators = jail.combinators;
            agents = llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
            jail-agent = pkgs.lib.toFunction agent agents;
            jail-permissions = pkgs.lib.toFunction permissions combinators;

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
            optionals = pkgs.lib.optionals;
          in
          jail name jail-agent (
            (optionals defaultOption defaultOptions)
            ++ (optionals defaultPkg [ (combinators.add-pkg-deps defaultPkgs) ])
            ++ jail-permissions
          );
      };
      # Re-export llm agents
      packages = llm-agents.packages;
    };
}
