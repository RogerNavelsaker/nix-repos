# scripts/deploy-key.nix
# Generate and manage deploy keys for private repository CI access
{ pkgs, pog }:

pog.pog {
  name = "deploy-key";
  version = "1.0.0";
  description = "Generate deploy keys for private repository CI access";

  arguments = [
    {
      name = "action";
      description = "action: generate, show, instructions";
    }
  ];

  flags = [
    {
      name = "repo";
      short = "r";
      description = "repository name (default: nix-secrets)";
      argument = "REPO";
      default = "nix-secrets";
    }
    {
      name = "output";
      short = "o";
      description = "output directory for keys (default: ~/.ssh/deploy-keys)";
      argument = "DIR";
      default = "";
    }
    {
      name = "comment";
      short = "c";
      description = "key comment (default: CI deploy key for <repo>)";
      argument = "COMMENT";
      default = "";
    }
  ];

  runtimeInputs = with pkgs; [
    openssh
    coreutils
  ];

  script = _: ''
        ACTION="$1"

        # Set defaults
        OUTPUT_DIR="''${output:-$HOME/.ssh/deploy-keys}"
        KEY_NAME="deploy_$repo"
        KEY_PATH="$OUTPUT_DIR/$KEY_NAME"
        COMMENT="''${comment:-CI deploy key for $repo}"

        # Action: generate
        do_generate() {
          mkdir -p "$OUTPUT_DIR"
          chmod 700 "$OUTPUT_DIR"

          if [ -f "$KEY_PATH" ]; then
            yellow "Deploy key already exists: $KEY_PATH"
            echo ""
            read -p "Overwrite? [y/N] " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
              die "Aborted"
            fi
          fi

          green "Generating deploy key for $repo..."
          ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "$COMMENT"
          chmod 600 "$KEY_PATH"
          chmod 644 "$KEY_PATH.pub"

          echo ""
          green "✓ Deploy key generated"
          echo "  Private key: $KEY_PATH"
          echo "  Public key:  $KEY_PATH.pub"
          echo ""
          do_instructions
        }

        # Action: show
        do_show() {
          if [ ! -f "$KEY_PATH.pub" ]; then
            die "Deploy key not found: $KEY_PATH.pub\nRun: deploy-key generate -r $repo"
          fi

          green "Public key for $repo:"
          echo ""
          cat "$KEY_PATH.pub"
          echo ""
        }

        # Action: instructions
        do_instructions() {
          cyan "=== Setup Instructions ==="
          echo ""
          echo "1. Copy the public key:"
          if [ -f "$KEY_PATH.pub" ]; then
            echo "   cat $KEY_PATH.pub"
          else
            echo "   (run 'deploy-key generate' first)"
          fi
          echo ""
          echo "2. Add deploy key to GitHub:"
          echo "   a. Go to: https://github.com/<owner>/$repo/settings/keys"
          echo "   b. Click 'Add deploy key'"
          echo "   c. Title: 'CI Deploy Key'"
          echo "   d. Paste the public key"
          echo "   e. Check 'Allow write access' if needed"
          echo "   f. Click 'Add key'"
          echo ""
          echo "3. For nix-config to use SSH URL:"
          echo "   Update flake.nix nix-secrets input:"
          echo "   nix-secrets.url = \"git+ssh://git@github.com/<owner>/nix-secrets.git\";"
          echo ""
          echo "4. For GitHub Actions CI:"
          echo "   a. Go to: https://github.com/<owner>/nix-config/settings/secrets/actions"
          echo "   b. Add secret: DEPLOY_KEY_NIX_SECRETS"
          echo "   c. Paste the PRIVATE key content"
          echo ""
          cat << 'WORKFLOW'
    5. In your workflow, add before nix commands:
       - name: Setup SSH deploy key
         run: |
           mkdir -p ~/.ssh
           echo "''${{ secrets.DEPLOY_KEY_NIX_SECRETS }}" > ~/.ssh/deploy_nix_secrets
           chmod 600 ~/.ssh/deploy_nix_secrets
           ssh-keyscan github.com >> ~/.ssh/known_hosts
           cat >> ~/.ssh/config << EOF
           Host github.com-nix-secrets
             HostName github.com
             User git
             IdentityFile ~/.ssh/deploy_nix_secrets
             IdentitiesOnly yes
           EOF
    WORKFLOW
          echo ""
          echo "6. Update nix-secrets URL in flake.nix for CI:"
          echo "   nix-secrets.url = \"git+ssh://git@github.com-nix-secrets/<owner>/nix-secrets.git\";"
          echo ""
        }

        # Main dispatch
        case "$ACTION" in
          generate|gen)
            do_generate
            ;;
          show)
            do_show
            ;;
          instructions|help)
            do_instructions
            ;;
          "")
            die "Error: Action required\n\nActions:\n  generate   - Generate new deploy key pair\n  show       - Display public key\n  instructions - Show setup instructions\n\nFlags:\n  -r, --repo REPO      - Repository name (default: nix-secrets)\n  -o, --output DIR     - Output directory (default: ~/.ssh/deploy-keys)\n  -c, --comment TEXT   - Key comment\n\nExamples:\n  deploy-key generate                    # Generate key for nix-secrets\n  deploy-key generate -r nix-keys        # Generate key for nix-keys\n  deploy-key show                        # Show public key\n  deploy-key instructions                # Show setup guide"
            ;;
          *)
            die "Unknown action: $ACTION\nValid actions: generate, show, instructions"
            ;;
        esac
  '';
}
