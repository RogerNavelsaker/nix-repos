# scripts/iso.nix
# Cross-repo script: QEMU testing for NixOS ISO with Ventoy disk
# Uses ventoy script to create disk, then runs in QEMU
{
  pkgs,
  pog,
}:

pog.pog {
  name = "iso";
  version = "8.0.0";
  description = "QEMU testing for NixOS ISO with Ventoy disk (GPG/Yubikey boot unlock)";

  arguments = [
    {
      name = "action";
      description = "action: build, run, stop, restart, status, ssh, log, path";
    }
  ];

  flags = [
    {
      name = "force";
      short = "F";
      bool = true;
      description = "force rebuild, ignore cache";
    }
    {
      name = "foreground";
      short = "f";
      bool = true;
      description = "run QEMU in foreground (default: background)";
    }
    {
      name = "serial-log";
      short = "";
      description = "serial output log file";
      argument = "FILE";
      default = "/tmp/qemu-serial.log";
    }
    {
      name = "user";
      short = "u";
      description = "SSH username (default: rona)";
      argument = "USER";
      default = "rona";
    }
    {
      name = "disk";
      short = "d";
      description = "Ventoy disk image to use (builds if not specified)";
      argument = "FILE";
      default = "";
    }
    {
      name = "host";
      short = "H";
      description = "hostname for build (default: iso)";
      argument = "HOST";
      default = "iso";
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
      short = "U";
      description = "users to include in injection (comma-separated or '*')";
      argument = "USERS";
      default = "";
    }
  ];

  runtimeInputs = with pkgs; [
    qemu
    OVMF
    nix
    openssh
    coreutils
    ventoy
    libguestfs-with-appliance
    util-linux
    findutils
    tree
    gnutar
    gzip
  ];

  script = helpers: ''
        ACTION="$1"
        PID_FILE="/tmp/qemu-iso.pid"
        QEMU_LOG="/tmp/qemu-iso.log"
        VENTOY_DISK_CACHE="/tmp/$host-ventoy.img"

        # Helper: check if QEMU is running
        is_running() {
          if ${helpers.file.exists "PID_FILE"}; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
              return 0
            else
              rm -f "$PID_FILE"
              return 1
            fi
          fi
          return 1
        }

        # Helper: get PID if running
        get_pid() {
          if ${helpers.file.exists "PID_FILE"}; then
            cat "$PID_FILE"
          fi
        }

        # Helper: validate repos
        validate_keys_repo() {
          if [ ! -d "$keys_repo" ]; then
            die "Error: nix-keys repository not found: $keys_repo\nUse --keys-repo to specify path"
          fi
        }

        validate_config_repo() {
          if [ ! -d "$config_repo" ]; then
            die "Error: nix-config repository not found: $config_repo\nUse --config-repo to specify path"
          fi
        }

        # Helper: get or build Ventoy disk
        get_ventoy_disk() {
          if ${helpers.var.notEmpty "disk"}; then
            if [ ! -f "$disk" ]; then
              die "Error: Disk image not found: $disk"
            fi
            echo "$disk"
          else
            # Check for cached disk (unless --force)
            if ! ${helpers.flag "force"} && [ -f "$VENTOY_DISK_CACHE" ]; then
              echo "$VENTOY_DISK_CACHE"
              return 0
            fi

            # Build using ventoy script logic inline
            validate_config_repo
            validate_keys_repo

            cyan "Building Ventoy disk..."

            # Build ISO
            cyan "Building ISO from $config_repo..."
            STORE_PATH=$(nix build "$config_repo#nixosConfigurations.$host.config.system.build.isoImage" --no-link --print-out-paths 2>/dev/null) || \
            STORE_PATH=$(nix build "$config_repo#nixosConfigurations.iso.config.system.build.isoImage" --no-link --print-out-paths)
            ISO_FILE=$(find "$STORE_PATH" -name "*.iso" -type f | head -1)

            if [ ! -f "$ISO_FILE" ]; then
              die "Error: Could not build ISO"
            fi
            green "✓ ISO: $ISO_FILE"

            # Create injection archive
            cyan "Creating injection archive from $keys_repo..."
            INJECTION_FILE="/tmp/$host-injection.tar.gz"
            TEMP_DIR=$(mktemp -d)

            ORIGINAL_DIR="$(pwd)"
            cd "$keys_repo" || die "Failed to enter nix-keys repo"

            mkdir -p "$TEMP_DIR/private"
            [ -f "./private/.gpg-id" ] && cp "./private/.gpg-id" "$TEMP_DIR/private/"

            if [ -d "./private/hosts/$host" ]; then
              mkdir -p "$TEMP_DIR/private/hosts/$host"
              cp -r "./private/hosts/$host"/* "$TEMP_DIR/private/hosts/$host/" 2>/dev/null || true
            fi

            if [ -d "./private/hosts/common" ]; then
              mkdir -p "$TEMP_DIR/private/hosts/common"
              cp -r "./private/hosts/common"/* "$TEMP_DIR/private/hosts/common/" 2>/dev/null || true
            fi

            if ${helpers.var.notEmpty "users"}; then
              if [ "$users" = "*" ]; then
                [ -d "./private/users" ] && cp -r "./private/users" "$TEMP_DIR/private/"
              else
                IFS=',' read -ra USER_LIST <<< "$users"
                for u in "''${USER_LIST[@]}"; do
                  u=$(echo "$u" | xargs)
                  if [ -d "./private/users/$u" ]; then
                    mkdir -p "$TEMP_DIR/private/users/$u"
                    cp -r "./private/users/$u"/* "$TEMP_DIR/private/users/$u/"
                  fi
                done
              fi
            fi

            if [ -d "./private/users/common" ]; then
              mkdir -p "$TEMP_DIR/private/users/common"
              cp -r "./private/users/common"/* "$TEMP_DIR/private/users/common/" 2>/dev/null || true
            fi

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
                IFS=',' read -ra USER_LIST <<< "$users"
                for u in "''${USER_LIST[@]}"; do
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

            cd "$TEMP_DIR" || die "Failed to change directory"
            tar czf "$INJECTION_FILE" ./* 2>/dev/null || tar czf "$INJECTION_FILE" ./*
            rm -rf "$TEMP_DIR"
            cd "$ORIGINAL_DIR" || die "Failed to return"

            green "✓ Injection archive: $INJECTION_FILE"

            # Create Ventoy disk
            cyan "Creating Ventoy disk..."
            ISO_SIZE=$(stat -c%s "$ISO_FILE")
            INJECTION_SIZE=$(stat -c%s "$INJECTION_FILE")
            DISK_MB=$(( (ISO_SIZE + INJECTION_SIZE) / 1048576 + 150 ))
            DISK_MB=$(( ((DISK_MB + 63) / 64) * 64 ))
            [ "$DISK_MB" -lt 512 ] && DISK_MB=512

            truncate -s "''${DISK_MB}M" "$VENTOY_DISK_CACHE"

            LOOP_DEV=$(sudo losetup --show -f "$VENTOY_DISK_CACHE") || die "Failed to create loopback"
            sudo ventoy -i -g "$LOOP_DEV" || { sudo losetup -d "$LOOP_DEV"; die "Failed to install Ventoy"; }
            sudo losetup -d "$LOOP_DEV"

            MOUNT_POINT=$(mktemp -d)
            sleep 1
            guestmount -a "$VENTOY_DISK_CACHE" -m /dev/sda1 "$MOUNT_POINT" || die "Failed to mount"

            cp "$ISO_FILE" "$MOUNT_POINT/nixos.iso"
            tar xzf "$INJECTION_FILE" -C "$MOUNT_POINT/"

            mkdir -p "$MOUNT_POINT/ventoy"
            cat > "$MOUNT_POINT/ventoy/ventoy.json" << 'VENTOY_EOF'
    {
      "control": [
        { "VTOY_MENU_TIMEOUT": "5" },
        { "VTOY_DEFAULT_IMAGE": "/nixos.iso" }
      ]
    }
    VENTOY_EOF

            fusermount -u "$MOUNT_POINT"
            rmdir "$MOUNT_POINT"

            green "✓ Ventoy disk: $VENTOY_DISK_CACHE"
            echo "$VENTOY_DISK_CACHE"
          fi
        }

        # Helper: get ISO path from nix store
        get_iso_path() {
          validate_config_repo
          STORE_PATH=$(nix build "$config_repo#nixosConfigurations.$host.config.system.build.isoImage" --no-link --print-out-paths 2>/dev/null) || \
          STORE_PATH=$(nix build "$config_repo#nixosConfigurations.iso.config.system.build.isoImage" --no-link --print-out-paths)
          find "$STORE_PATH" -name "*.iso" -type f | head -1
        }

        # Action: build
        do_build() {
          VENTOY_DISK=$(get_ventoy_disk)
          green "✓ Ventoy disk ready: $VENTOY_DISK"
          echo "  Host: $host"
          echo "  Mode: GPG/Yubikey boot-time unlock"
        }

        # Action: path
        do_path() {
          ISO_FILE=$(get_iso_path)
          echo "$ISO_FILE"
        }

        # Action: run
        do_run() {
          if is_running; then
            die "Error: QEMU is already running (PID: $(get_pid))\nRun 'iso stop' first or use 'iso restart'"
          fi

          VENTOY_DISK=$(get_ventoy_disk)
          green "✓ Using Ventoy disk: $VENTOY_DISK"

          # Detect KVM
          if [ -c /dev/kvm ] && [ -r /dev/kvm ]; then
            KVM_FLAG="-enable-kvm"
            green "KVM acceleration: enabled"
          else
            KVM_FLAG=""
            yellow "KVM acceleration: not available"
          fi

          cyan "Serial logging to: $serial_log"

          # shellcheck disable=SC2206
          QEMU_ARGS=(
            $KVM_FLAG
            -m 4096
            -smp 2
            -drive "if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF.fd"
            -drive "if=virtio,format=raw,file=$VENTOY_DISK"
            -boot c
            -net nic "-net" "user,hostfwd=tcp::2222-:22"
            -serial "file:$serial_log"
          )

          if ${helpers.flag "foreground"}; then
            echo ""
            green "Starting QEMU (foreground)..."
            cyan "SSH: ssh -p 2222 $user@localhost"
            echo ""
            qemu-system-x86_64 "''${QEMU_ARGS[@]}"
          else
            echo ""
            green "Starting QEMU (background)..."

            nohup qemu-system-x86_64 "''${QEMU_ARGS[@]}" > "$QEMU_LOG" 2>&1 &
            QEMU_PID=$!
            echo "$QEMU_PID" > "$PID_FILE"

            sleep 1
            if kill -0 "$QEMU_PID" 2>/dev/null; then
              echo ""
              green "✓ QEMU started (PID: $QEMU_PID)"
              cyan "  SSH: ssh -p 2222 $user@localhost"
              cyan "  iso ssh      - SSH into guest"
              cyan "  iso log      - View serial output"
              cyan "  iso status   - Check status"
              cyan "  iso stop     - Stop QEMU"
              echo ""
              yellow "Note: Insert Yubikey during boot for key decryption"
            else
              die "Error: QEMU failed to start\nCheck: cat $QEMU_LOG"
            fi
          fi
        }

        # Action: stop
        do_stop() {
          if is_running; then
            PID=$(get_pid)
            echo "Stopping QEMU (PID: $PID)..."
            kill "$PID"
            rm -f "$PID_FILE"
            green "✓ QEMU stopped"
          else
            yellow "QEMU is not running"
          fi
        }

        # Action: restart
        do_restart() {
          do_stop
          sleep 1
          do_run
        }

        # Action: status
        do_status() {
          if is_running; then
            PID=$(get_pid)
            green "QEMU is running (PID: $PID)"
            cyan "  iso ssh   - SSH into guest"
            cyan "  iso log   - View serial output"
            cyan "  iso stop  - Stop QEMU"
          else
            yellow "QEMU is not running"
            cyan "  iso run   - Start QEMU"
          fi
        }

        # Action: ssh
        do_ssh() {
          if ! is_running; then
            die "QEMU is not running. Start with: iso run"
          fi
          cyan "Connecting to guest as $user..."
          ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 "$user@localhost"
        }

        # Action: log
        do_log() {
          if ${helpers.file.exists "serial_log"}; then
            cyan "Serial log: $serial_log (Ctrl+C to exit)"
            tail -f "$serial_log"
          else
            die "No serial log found: $serial_log\nQEMU may not have started yet"
          fi
        }

        # Main dispatch
        case "$ACTION" in
          build)
            do_build
            ;;
          run)
            do_run
            ;;
          stop)
            do_stop
            ;;
          restart)
            do_restart
            ;;
          status)
            do_status
            ;;
          ssh)
            do_ssh
            ;;
          log|logs)
            do_log
            ;;
          path)
            do_path
            ;;
          "")
            die "Error: Action required\n\nActions:\n  build    - Build Ventoy disk (ISO + injection)\n  run      - Build (if needed) and run in QEMU\n  stop     - Stop QEMU\n  restart  - Stop and restart QEMU\n  status   - Check if QEMU is running\n  ssh      - SSH into running guest\n  log      - View serial output\n  path     - Print ISO path in nix store\n\nFlags:\n  -F, --force           - Force rebuild\n  -f, --foreground      - Run QEMU in foreground\n  -d, --disk FILE       - Use existing Ventoy disk\n  -H, --host HOST       - Hostname for build (default: iso)\n  -U, --users USERS     - Users to include in injection\n  --keys-repo DIR       - Path to nix-keys repo\n  --config-repo DIR     - Path to nix-config repo\n\nExamples:\n  iso build                   # Build Ventoy disk\n  iso build -H nanoserver     # Build for specific host\n  iso run                     # Run in QEMU (insert Yubikey at boot)\n  iso run -f                  # Run in foreground\n  iso run -d ./custom.img     # Use pre-built disk\n  iso ssh                     # SSH into guest\n  iso stop"
            ;;
          *)
            die "Unknown action: $ACTION\nValid actions: build, run, stop, restart, status, ssh, log, path"
            ;;
        esac
  '';
}
