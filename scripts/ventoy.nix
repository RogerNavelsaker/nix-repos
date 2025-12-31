# scripts/ventoy.nix
# Cross-repo script: Create Ventoy disk from nix-config ISO and nix-keys injection archive
# ISO from nix-config, injection archive from nix-keys (encrypted, GPG unlock at boot)
{
  pkgs,
  pog,
}:

pog.pog {
  name = "ventoy";
  version = "2.0.0";
  description = "Create Ventoy disk from ISO and injection archive";

  arguments = [
    {
      name = "action";
      description = "action: create, info";
    }
  ];

  flags = [
    {
      name = "host";
      short = "H";
      description = "hostname for ISO and key lookup (default: iso)";
      argument = "HOST";
      default = "iso";
    }
    {
      name = "output";
      short = "o";
      description = "output disk image path";
      argument = "FILE";
      default = "";
    }
    {
      name = "iso";
      short = "i";
      description = "ISO file path (builds from nix-config if not specified)";
      argument = "FILE";
      default = "";
    }
    {
      name = "injection";
      short = "I";
      description = "injection archive from nix-keys (creates from nix-keys if not specified)";
      argument = "FILE";
      default = "";
    }
    {
      name = "keys-repo";
      short = "";
      description = "path to nix-keys repository (default: ./nix-keys)";
      argument = "DIR";
      default = "./nix-keys";
    }
    {
      name = "config-repo";
      short = "";
      description = "path to nix-config repository (default: ./nix-config)";
      argument = "DIR";
      default = "./nix-config";
    }
    {
      name = "users";
      short = "u";
      description = "users to include in injection (comma-separated or '*')";
      argument = "USERS";
      default = "";
    }
  ];

  runtimeInputs = with pkgs; [
    ventoy
    libguestfs-with-appliance
    util-linux
    coreutils
    findutils
    tree
    gnutar
    gzip
    nix
  ];

  script = helpers: ''
        ACTION="$1"

        # Helper: validate nix-keys repo
        validate_keys_repo() {
          if [ ! -d "$keys_repo" ]; then
            die "Error: nix-keys repository not found: $keys_repo\nUse --keys-repo to specify path"
          fi
          if [ ! -d "$keys_repo/private" ]; then
            die "Error: Invalid nix-keys repository (no private/ directory): $keys_repo"
          fi
          if [ ! -d "$keys_repo/public" ]; then
            die "Error: Invalid nix-keys repository (no public/ directory): $keys_repo"
          fi
        }

        # Helper: validate nix-config repo
        validate_config_repo() {
          if [ ! -d "$config_repo" ]; then
            die "Error: nix-config repository not found: $config_repo\nUse --config-repo to specify path"
          fi
          if [ ! -f "$config_repo/flake.nix" ]; then
            die "Error: Invalid nix-config repository (no flake.nix): $config_repo"
          fi
        }

        # Helper: get or build ISO
        get_iso_file() {
          if ${helpers.var.notEmpty "iso"}; then
            if [ ! -f "$iso" ]; then
              die "Error: ISO file not found: $iso"
            fi
            echo "$iso"
          else
            validate_config_repo
            cyan "Building ISO from $config_repo..."
            STORE_PATH=$(nix build "$config_repo#nixosConfigurations.$host.config.system.build.isoImage" --no-link --print-out-paths 2>/dev/null) || \
            STORE_PATH=$(nix build "$config_repo#nixosConfigurations.iso.config.system.build.isoImage" --no-link --print-out-paths)
            find "$STORE_PATH" -name "*.iso" -type f | head -1
          fi
        }

        # Helper: get or create injection archive
        get_injection_archive() {
          if ${helpers.var.notEmpty "injection"}; then
            if [ ! -f "$injection" ]; then
              die "Error: Injection archive not found: $injection"
            fi
            echo "$injection"
          else
            validate_keys_repo
            cyan "Creating injection archive from $keys_repo..."

            # Create injection archive in temp location
            INJECTION_FILE="/tmp/$host-injection.tar.gz"

            ORIGINAL_DIR="$(pwd)"
            cd "$keys_repo" || die "Failed to enter nix-keys repo"

            # Build the injection archive structure
            TEMP_DIR=$(mktemp -d)

            # Copy encrypted pass store
            mkdir -p "$TEMP_DIR/private"
            [ -f "./private/.gpg-id" ] && cp "./private/.gpg-id" "$TEMP_DIR/private/"

            # Copy host keys
            if [ -d "./private/hosts/$host" ]; then
              mkdir -p "$TEMP_DIR/private/hosts/$host"
              cp -r "./private/hosts/$host"/* "$TEMP_DIR/private/hosts/$host/" 2>/dev/null || true
            fi

            # Copy common host files
            if [ -d "./private/hosts/common" ]; then
              mkdir -p "$TEMP_DIR/private/hosts/common"
              cp -r "./private/hosts/common"/* "$TEMP_DIR/private/hosts/common/" 2>/dev/null || true
            fi

            # Copy user keys if specified
            if ${helpers.var.notEmpty "users"}; then
              if [ "$users" = "*" ]; then
                [ -d "./private/users" ] && cp -r "./private/users" "$TEMP_DIR/private/"
              else
                IFS=',' read -ra USERS <<< "$users"
                for u in "''${USERS[@]}"; do
                  u=$(echo "$u" | xargs)
                  if [ -d "./private/users/$u" ]; then
                    mkdir -p "$TEMP_DIR/private/users/$u"
                    cp -r "./private/users/$u"/* "$TEMP_DIR/private/users/$u/"
                  fi
                done
              fi
            fi

            # Copy common user files
            if [ -d "./private/users/common" ]; then
              mkdir -p "$TEMP_DIR/private/users/common"
              cp -r "./private/users/common"/* "$TEMP_DIR/private/users/common/" 2>/dev/null || true
            fi

            # Copy public keys
            mkdir -p "$TEMP_DIR/public"
            if [ -d "./public/hosts/$host" ]; then
              mkdir -p "$TEMP_DIR/public/hosts/$host"
              cp -r "./public/hosts/$host"/* "$TEMP_DIR/public/hosts/$host/" 2>/dev/null || true
            fi
            if [ -d "./public/hosts/common" ]; then
              mkdir -p "$TEMP_DIR/public/hosts/common"
              cp -r "./public/hosts/common"/* "$TEMP_DIR/public/hosts/common/" 2>/dev/null || true
            fi

            if ${helpers.var.notEmpty "users"}; then
              if [ "$users" = "*" ]; then
                [ -d "./public/users" ] && cp -r "./public/users" "$TEMP_DIR/public/"
              else
                IFS=',' read -ra USERS <<< "$users"
                for u in "''${USERS[@]}"; do
                  u=$(echo "$u" | xargs)
                  if [ -d "./public/users/$u" ]; then
                    mkdir -p "$TEMP_DIR/public/users/$u"
                    cp -r "./public/users/$u"/* "$TEMP_DIR/public/users/$u/"
                  fi
                done
              fi
            fi

            if [ -d "./public/users/common" ]; then
              mkdir -p "$TEMP_DIR/public/users/common"
              cp -r "./public/users/common"/* "$TEMP_DIR/public/users/common/" 2>/dev/null || true
            fi

            # Create archive
            cd "$TEMP_DIR" || die "Failed to change directory"
            tar czf "$INJECTION_FILE" ./* 2>/dev/null || tar czf "$INJECTION_FILE" ./*
            rm -rf "$TEMP_DIR"

            cd "$ORIGINAL_DIR" || die "Failed to return"

            echo "$INJECTION_FILE"
          fi
        }

        # Cleanup function
        cleanup_on_exit() {
          if [ -n "$MOUNT_POINT" ] && mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
            fusermount -u "$MOUNT_POINT" 2>/dev/null || true
          fi
          [ -n "$MOUNT_POINT" ] && rmdir "$MOUNT_POINT" 2>/dev/null || true
          [ -n "$LOOP_DEV" ] && sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
        }

        # Action: create
        do_create() {
          # Get ISO file
          ISO_FILE=$(get_iso_file)
          if [ ! -f "$ISO_FILE" ]; then
            die "Error: Could not get ISO file"
          fi
          green "✓ ISO: $ISO_FILE"

          # Get injection archive
          INJECTION_ARCHIVE=$(get_injection_archive)
          if [ ! -f "$INJECTION_ARCHIVE" ]; then
            die "Error: Could not get injection archive"
          fi
          green "✓ Injection archive: $INJECTION_ARCHIVE"

          OUTPUT="$output"
          if ${helpers.var.empty "OUTPUT"}; then
            OUTPUT="/tmp/$host-ventoy.img"
          fi

          trap cleanup_on_exit EXIT

          ISO_NAME=$(basename "$ISO_FILE")
          echo ""
          green "Creating Ventoy disk"
          echo "  Host: $host"
          echo "  ISO: $ISO_NAME"
          echo "  Output: $OUTPUT"
          echo "  Mode: GPG/Yubikey boot-time unlock"
          echo ""

          # Calculate disk size
          ISO_SIZE=$(stat -c%s "$ISO_FILE")
          INJECTION_SIZE=$(stat -c%s "$INJECTION_ARCHIVE")
          DISK_MB=$(( (ISO_SIZE + INJECTION_SIZE) / 1048576 + 150 ))
          DISK_MB=$(( ((DISK_MB + 63) / 64) * 64 ))
          if [ "$DISK_MB" -lt 512 ]; then
            DISK_MB=512
          fi

          cyan "Creating disk image (''${DISK_MB}MB)..."
          truncate -s "''${DISK_MB}M" "$OUTPUT"

          # Install Ventoy (requires sudo for losetup)
          cyan "Installing Ventoy to disk image (requires sudo)..."
          if ! sudo -n true 2>/dev/null; then
            yellow "Sudo access required for Ventoy installation."
          fi

          LOOP_DEV=$(sudo losetup --show -f "$OUTPUT") || die "Failed to create loopback device"

          # Install Ventoy in non-interactive mode with GPT
          sudo ventoy -i -g "$LOOP_DEV" || {
            sudo losetup -d "$LOOP_DEV"
            die "Failed to install Ventoy"
          }

          # Detach loopback - remount with guestmount
          sudo losetup -d "$LOOP_DEV"
          LOOP_DEV=""

          # Mount with guestmount (FUSE, no root needed)
          cyan "Mounting Ventoy partition..."
          MOUNT_POINT=$(mktemp -d)
          sleep 1

          guestmount -a "$OUTPUT" -m /dev/sda1 "$MOUNT_POINT" || die "Failed to mount Ventoy partition"

          # Copy ISO
          cyan "Copying ISO to disk..."
          cp "$ISO_FILE" "$MOUNT_POINT/nixos.iso" || die "Failed to copy ISO"

          # Extract injection archive
          cyan "Extracting injection archive..."
          tar xzf "$INJECTION_ARCHIVE" -C "$MOUNT_POINT/" || die "Failed to extract injection archive"

          # Create Ventoy configuration
          cyan "Writing Ventoy configuration..."
          mkdir -p "$MOUNT_POINT/ventoy"

          cat > "$MOUNT_POINT/ventoy/ventoy.json" << 'VENTOY_EOF'
    {
      "control": [
        { "VTOY_MENU_TIMEOUT": "5" },
        { "VTOY_DEFAULT_IMAGE": "/nixos.iso" }
      ]
    }
    VENTOY_EOF

          # Show contents
          echo ""
          cyan "Disk contents:"
          ls -lh "$MOUNT_POINT"
          echo ""
          cyan "Key structure:"
          tree -L 3 "$MOUNT_POINT/private" 2>/dev/null || find "$MOUNT_POINT/private" -type f 2>/dev/null | head -20

          # Unmount
          cyan "Unmounting..."
          fusermount -u "$MOUNT_POINT"
          rmdir "$MOUNT_POINT"
          MOUNT_POINT=""

          ACTUAL_SIZE=$(du -h "$OUTPUT" | cut -f1)

          echo ""
          green "✓ Ventoy disk created: $OUTPUT"
          echo "  Host: $host"
          echo "  Size: $ACTUAL_SIZE"
          echo "  Mode: GPG/Yubikey boot-time unlock"
          echo ""
          yellow "Boot-time requirements:"
          echo "  - Yubikey with GPG key must be inserted during boot"
          echo "  - Touch required to decrypt keys"
          echo ""
          cyan "Test with QEMU:"
          echo "  iso run --disk $OUTPUT"
        }

        # Action: info
        do_info() {
          validate_keys_repo

          echo "nix-keys repository: $keys_repo"
          echo ""
          echo "Available hosts:"
          for host_dir in "$keys_repo/private/hosts"/*; do
            if [ -d "$host_dir" ]; then
              host_name=$(basename "$host_dir")
              if [ "$host_name" != "common" ]; then
                echo "  - $host_name"
              fi
            fi
          done
          echo ""
          echo "Available users:"
          for user_dir in "$keys_repo/private/users"/*; do
            if [ -d "$user_dir" ]; then
              user_name=$(basename "$user_dir")
              if [ "$user_name" != "common" ]; then
                echo "  - $user_name"
              fi
            fi
          done
        }

        # Main dispatch
        case "$ACTION" in
          create)
            do_create
            ;;
          info)
            do_info
            ;;
          "")
            die "Error: Action required\n\nActions:\n  create   - Create Ventoy disk with ISO and injection archive\n  info     - Show available hosts and users\n\nFlags:\n  -H, --host HOST         - Hostname for ISO/key lookup (default: iso)\n  -o, --output FILE       - Output disk image path\n  -i, --iso FILE          - ISO file (builds from nix-config if not specified)\n  -I, --injection FILE    - Injection archive (creates from nix-keys if not specified)\n  -u, --users USERS       - Users to include (comma-separated or '*')\n  --keys-repo DIR         - Path to nix-keys repo (default: ./nix-keys)\n  --config-repo DIR       - Path to nix-config repo (default: ./nix-config)\n\nExamples:\n  ventoy create                          # Create for 'iso' host\n  ventoy create -H nanoserver            # Create for specific host\n  ventoy create -u rona                  # Include user keys\n  ventoy create -i ./my.iso              # Use pre-built ISO\n  ventoy create -I ./injection.tar.gz   # Use pre-built injection\n  ventoy info                            # List available hosts/users"
            ;;
          *)
            die "Unknown action: $ACTION\nValid actions: create, info"
            ;;
        esac
  '';
}
