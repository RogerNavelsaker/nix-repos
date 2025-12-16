# scripts/iso.nix
# Cross-repo script: orchestrates nix-config ISO build + nix-keys key injection
{
  pkgs,
  pog,
}:

pog.pog {
  name = "iso";
  version = "6.0.0";
  description = "Build NixOS ISO with Ventoy disk and run in QEMU";

  arguments = [
    {
      name = "action";
      description = "action: build, rebuild, run, stop, restart, status, ssh, log, copy, path";
    }
  ];

  flags = [
    # Force rebuild (invalidate cache)
    {
      name = "force";
      short = "F";
      bool = true;
      description = "force rebuild, ignore cache";
    }
    # Foreground mode for run
    {
      name = "foreground";
      short = "f";
      bool = true;
      description = "run QEMU in foreground (default: background)";
    }
    # Serial log file
    {
      name = "serial-log";
      short = "";
      description = "serial output log file";
      argument = "FILE";
      default = "/tmp/qemu-serial.log";
    }
    # SSH user
    {
      name = "user";
      short = "u";
      description = "SSH username (default: rona)";
      argument = "USER";
      default = "rona";
    }
    # Output path for copy action
    {
      name = "output";
      short = "o";
      description = "output path for copy action (default: ./nixos.iso)";
      argument = "FILE";
      default = "./nixos.iso";
    }
    # nix-keys directory
    {
      name = "keys-repo";
      short = "";
      description = "path to nix-keys repository (default: ./nix-keys)";
      argument = "DIR";
      default = "./nix-keys";
    }
    # nix-config directory
    {
      name = "config-repo";
      short = "";
      description = "path to nix-config repository (default: ./nix-config)";
      argument = "DIR";
      default = "./nix-config";
    }
    # Hostname for key injection
    {
      name = "host";
      short = "H";
      description = "hostname for key injection (default: iso)";
      argument = "HOST";
      default = "iso";
    }
    # Users for key injection
    {
      name = "users";
      short = "U";
      description = "users to include (comma-separated)";
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
  ];

  script = helpers: ''
    ACTION="$1"
    PID_FILE="/tmp/qemu-iso.pid"
    QEMU_LOG="/tmp/qemu-iso.log"
    ISO_PATH_FILE="/tmp/qemu-iso-path"
    VENTOY_DISK="/tmp/$host-ventoy.img"

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

    # Helper: validate nix-keys repo
    validate_keys_repo() {
      if [ ! -d "$keys_repo" ]; then
        die "Error: nix-keys repository not found: $keys_repo\nUse --keys-repo to specify path"
      fi
      if [ ! -f "$keys_repo/flake.nix" ]; then
        die "Error: Invalid nix-keys repository (no flake.nix): $keys_repo"
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

    # Helper: get ISO path from nix store (builds if needed)
    get_iso_path() {
      validate_config_repo

      # Check if we have a cached path that still exists (unless --force)
      if ! ${helpers.flag "force"}; then
        if ${helpers.file.exists "ISO_PATH_FILE"}; then
          CACHED_PATH=$(cat "$ISO_PATH_FILE")
          if [ -d "$CACHED_PATH" ]; then
            echo "$CACHED_PATH"
            return 0
          fi
        fi
      fi
      # Build and cache the path
      cyan "Building ISO from $config_repo..."
      rm -f "$ISO_PATH_FILE"
      STORE_PATH=$(nix build "$config_repo#nixosConfigurations.iso.config.system.build.isoImage" --no-link --print-out-paths)
      echo "$STORE_PATH" > "$ISO_PATH_FILE"
      echo "$STORE_PATH"
    }

    # Helper: get the actual .iso file path
    get_iso_file() {
      STORE_PATH=$(get_iso_path)
      find "$STORE_PATH" -name "*.iso" -type f | head -1
    }

    # Helper: create Ventoy disk via nix-keys
    create_ventoy_disk() {
      local iso_file="$1"

      validate_keys_repo

      # Build user flag
      USER_FLAG=""
      if ${helpers.var.notEmpty "users"}; then
        USER_FLAG="-u $users"
      fi

      cyan "Creating Ventoy disk via nix-keys (requires Yubikey)..."
      # shellcheck disable=SC2086
      (cd "$keys_repo" && nix develop --command create disk "$host" "$iso_file" $USER_FLAG -o "$VENTOY_DISK") || die "Failed to create Ventoy disk"
    }

    # Action: build (ISO + Ventoy disk)
    do_build() {
      ISO_FILE=$(get_iso_file)
      green "✓ ISO built: $ISO_FILE"

      create_ventoy_disk "$ISO_FILE"
      green "✓ Ventoy disk created: $VENTOY_DISK"
      echo "  Host: $host"
      if ${helpers.var.notEmpty "users"}; then
        echo "  Keys: host + $users"
      else
        echo "  Keys: host only"
      fi
    }

    # Action: path (print ISO store path)
    do_path() {
      ISO_FILE=$(get_iso_file)
      echo "$ISO_FILE"
    }

    # Action: copy (copy ISO out of nix store)
    do_copy() {
      ISO_FILE=$(get_iso_file)
      cyan "Copying ISO to: $output"
      cp "$ISO_FILE" "$output"
      chmod 644 "$output"
      green "✓ ISO copied: $output ($(du -h "$output" | cut -f1))"
    }

    # Action: run (use Ventoy disk)
    do_run() {
      if is_running; then
        die "Error: QEMU is already running (PID: $(get_pid))\nRun 'iso stop' first or use 'iso restart'"
      fi

      # Build if Ventoy disk doesn't exist
      if [ ! -f "$VENTOY_DISK" ]; then
        cyan "Ventoy disk not found, building..."
        do_build
      fi

      green "✓ Using Ventoy disk: $VENTOY_DISK"

      # Detect KVM availability
      if [ -c /dev/kvm ] && [ -r /dev/kvm ]; then
        KVM_FLAG="-enable-kvm"
        green "KVM acceleration: enabled"
      else
        KVM_FLAG=""
        yellow "KVM acceleration: not available (fallback mode)"
      fi

      cyan "Serial logging to: $serial_log"

      # Build QEMU command - boot from Ventoy disk
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

      # Launch QEMU
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
        cyan "  iso ssh      - SSH into guest"
        cyan "  iso log      - View serial output"
        cyan "  iso stop     - Stop QEMU"
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

    # Action: rebuild (force)
    do_rebuild() {
      rm -f "$ISO_PATH_FILE" "$VENTOY_DISK"
      force=true
      do_build
    }

    # Main dispatch
    case "$ACTION" in
      build)
        do_build
        ;;
      rebuild)
        do_rebuild
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
      copy|cp)
        do_copy
        ;;
      "")
        die "Error: Action required\n\nActions:\n  build    - Build ISO + Ventoy disk with key injection\n  rebuild  - Force rebuild (ignore cache)\n  run      - Build (if needed) and run in QEMU\n  stop     - Stop QEMU\n  restart  - Stop and restart QEMU\n  status   - Check if QEMU is running\n  ssh      - SSH into running guest\n  log      - View serial output\n  path     - Print ISO path in nix store\n  copy     - Copy ISO out of nix store (-o <path>)\n\nFlags:\n  -F, --force         - Force rebuild\n  -H, --host HOST     - Hostname for key injection (default: iso)\n  -U, --users USERS   - Users to include (comma-separated)\n  --keys-repo DIR     - Path to nix-keys repo (default: ./nix-keys)\n  --config-repo DIR   - Path to nix-config repo (default: ./nix-config)\n\nExamples:\n  iso build                 # Build ISO + Ventoy disk\n  iso build -H nanoserver   # Use nanoserver keys\n  iso build -U rona         # Include user keys\n  iso run                   # Run in QEMU\n  iso run -f                # Run in foreground\n  iso ssh                   # SSH into guest\n  iso stop"
        ;;
      *)
        die "Unknown action: $ACTION\nValid actions: build, rebuild, run, stop, restart, status, ssh, log, path, copy"
        ;;
    esac
  '';
}
