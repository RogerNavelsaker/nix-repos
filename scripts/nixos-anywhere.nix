# scripts/nixos-anywhere.nix
# Cross-repo script: deploys nix-config with nix-keys secrets via nixos-anywhere
{ pkgs, pog }:

pog.pog {
  name = "nixos-anywhere";
  version = "1.0.0";
  description = "Deploy NixOS with host keys and FlakeHub token via nixos-anywhere";

  arguments = [
    {
      name = "hostname";
      description = "target hostname (must exist in pass)";
    }
    {
      name = "target";
      description = "target address (user@host or IP)";
    }
  ];

  flags = [
    {
      name = "flake";
      short = "f";
      description = "flake reference (default: ./nix-config)";
      argument = "FLAKE";
      default = "./nix-config";
    }
    {
      name = "keys-repo";
      short = "";
      description = "path to nix-keys repository (default: ./nix-keys)";
      argument = "DIR";
      default = "./nix-keys";
    }
    {
      name = "users";
      short = "u";
      description = "users to include (comma-separated, or '*' for all)";
      argument = "USERS";
      default = "";
    }
    {
      name = "dry-run";
      short = "n";
      bool = true;
      description = "show what would be done without executing";
    }
    {
      name = "remote-build";
      short = "r";
      bool = true;
      description = "build configuration on target machine";
    }
    {
      name = "debug";
      short = "d";
      bool = true;
      description = "enable debug output";
    }
  ];

  runtimeInputs = with pkgs; [
    nixos-anywhere
    openssh
    coreutils
    pass
    gnupg
  ];

  script = helpers: ''
    # Reference pog-generated flag variables (satisfies shellcheck SC2034)
    : "''${dry_run:-}" "''${remote_build:-}"

    HOST="$1"
    TARGET="$2"

    # Validate keys repo
    if [ ! -d "$keys_repo" ]; then
      die "Error: nix-keys repository not found: $keys_repo\nUse --keys-repo to specify path"
    fi

    export PASSWORD_STORE_DIR="$keys_repo/private"

    if ${helpers.var.empty "HOST"}; then
      die "Error: Hostname required\nUsage: nixos-anywhere <hostname> <target>"
    fi

    if ${helpers.var.empty "TARGET"}; then
      die "Error: Target address required\nUsage: nixos-anywhere <hostname> <target>"
    fi

    # Verify host exists in pass
    if ! pass show "hosts/$HOST/ssh_host_ed25519_key" &>/dev/null; then
      die "Error: SSH host key not found in pass: hosts/$HOST/ssh_host_ed25519_key\nRun: genkey host $HOST (in nix-keys)"
    fi

    # Create temp directory for extra files
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf $TEMP_DIR' EXIT

    green "Preparing deployment for host '$HOST' to '$TARGET'"

    # Extract SSH host keys
    cyan "Extracting SSH host keys (requires Yubikey)..."
    mkdir -p "$TEMP_DIR/etc/ssh"
    pass show "hosts/$HOST/ssh_host_ed25519_key" > "$TEMP_DIR/etc/ssh/ssh_host_ed25519_key"
    chmod 600 "$TEMP_DIR/etc/ssh/ssh_host_ed25519_key"

    # Copy public key if exists
    if [ -f "$keys_repo/public/hosts/$HOST/ssh_host_ed25519_key.pub" ]; then
      cp "$keys_repo/public/hosts/$HOST/ssh_host_ed25519_key.pub" "$TEMP_DIR/etc/ssh/"
      chmod 644 "$TEMP_DIR/etc/ssh/ssh_host_ed25519_key.pub"
    fi

    # Extract FlakeHub token
    if pass show "hosts/$HOST/flakehub_token" &>/dev/null; then
      cyan "Extracting FlakeHub token (requires Yubikey)..."
      mkdir -p "$TEMP_DIR/nix/var/determinate"
      pass show "hosts/$HOST/flakehub_token" > "$TEMP_DIR/nix/var/determinate/flakehub-token"
      chmod 600 "$TEMP_DIR/nix/var/determinate/flakehub-token"
    else
      yellow "Warning: No FlakeHub token found for host '$HOST'"
      yellow "Private flakes will not be accessible during deployment"
    fi

    # Extract user keys if specified
    if ${helpers.var.notEmpty "users"}; then
      USER_LIST="$users"
      if [ "$USER_LIST" = "*" ]; then
        # Extract all users
        if [ -d "$keys_repo/public/home" ]; then
          cyan "Extracting all user keys (requires Yubikey)..."
          for user_pub_dir in "$keys_repo/public/home"/*; do
            if [ -d "$user_pub_dir" ]; then
              user=$(basename "$user_pub_dir")
              if pass show "home/$user/id_ed25519" &>/dev/null; then
                mkdir -p "$TEMP_DIR/home/$user/.ssh"
                pass show "home/$user/id_ed25519" > "$TEMP_DIR/home/$user/.ssh/id_ed25519"
                chmod 600 "$TEMP_DIR/home/$user/.ssh/id_ed25519"
                cp "$user_pub_dir"/*.pub "$TEMP_DIR/home/$user/.ssh/" 2>/dev/null || true
                chmod 644 "$TEMP_DIR/home/$user/.ssh/"*.pub 2>/dev/null || true
              fi
            fi
          done
        fi
      else
        # Extract specific users
        IFS=',' read -ra USERS <<< "$USER_LIST"
        for user in "''${USERS[@]}"; do
          user=$(echo "$user" | xargs)  # trim whitespace
          if pass show "home/$user/id_ed25519" &>/dev/null; then
            cyan "Extracting keys for user: $user (requires Yubikey)"
            mkdir -p "$TEMP_DIR/home/$user/.ssh"
            pass show "home/$user/id_ed25519" > "$TEMP_DIR/home/$user/.ssh/id_ed25519"
            chmod 600 "$TEMP_DIR/home/$user/.ssh/id_ed25519"
            cp "$keys_repo/public/home/$user"/*.pub "$TEMP_DIR/home/$user/.ssh/" 2>/dev/null || true
            chmod 644 "$TEMP_DIR/home/$user/.ssh/"*.pub 2>/dev/null || true
          else
            yellow "Warning: User key not found: home/$user/id_ed25519 (skipping)"
          fi
        done
      fi
    fi

    # Show what will be deployed
    echo ""
    cyan "Files to transfer:"
    find "$TEMP_DIR" -type f -exec ls -la {} \; | sed 's|'"$TEMP_DIR"'||'

    # Build command
    FLAKE_REF="$flake#$HOST"
    CMD="nixos-anywhere --flake \"$FLAKE_REF\" --extra-files \"$TEMP_DIR\""

    if ${helpers.flag "remote-build"}; then
      CMD="$CMD --build-on-remote"
    fi

    if ${helpers.flag "debug"}; then
      CMD="$CMD --debug"
    fi

    CMD="$CMD \"$TARGET\""

    echo ""
    cyan "Command:"
    echo "  $CMD"
    echo ""

    if ${helpers.flag "dry-run"}; then
      yellow "Dry run - not executing"
      exit 0
    fi

    green "Starting deployment..."
    echo ""

    # Execute nixos-anywhere
    eval "$CMD"

    echo ""
    green "✓ Deployment complete"
    echo "  Host: $HOST"
    echo "  Target: $TARGET"
    echo "  Flake: $FLAKE_REF"
  '';
}
