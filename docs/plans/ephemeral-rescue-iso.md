# Ephemeral YubiKey-Gated NixOS Rescue ISO

## Goal
Build a reusable NixOS rescue ISO that boots into RAM, uses a YubiKey-backed GPG/SOPS flow to unlock only the credentials needed for rescue access, joins Tailscale with a unique runtime hostname, and provides SSH access for installing a final NixOS system with disko and nixos-anywhere.

## Non-goals

- Persisting rescue Tailscale state or rescue credentials.
- Making the rescue ISO a general-purpose production operating system.
- Giving the rescue Tailscale identity unrestricted access to the tailnet.
- Replacing the final host configuration with runtime-generated configuration.
- Introducing shared abstractions in nix-lib before duplication is demonstrated.

## Repository ownership

- `nix-config`: ISO boot stages, runtime identity, Tailscale service, target host, disko, facter, installation workflow, QEMU tests.
- `nix-secrets`: SOPS layout and lifecycle policy for the restricted rescue auth key.
- `nix-keys`: encrypted key/pass-store layout and YubiKey/GPG material contract.
- `nix-lib`: only generic helpers proven necessary after nix-config implementation.
- `nix-repos`: coordination, cross-repository verification, and operator documentation.

## Execution steps

1. Define the boot contract.
   - Trace initrd key loading, Ventoy media mounting, GPG agent startup, SOPS availability, stage-2 service ordering, SSH startup, and Tailscale startup.
   - Decide exactly which files may exist in the initrd, `/run`, and persistent storage.
   - Preserve existing key material handling unless a smaller safe path is demonstrated.
   - Verify with `nixos-rebuild dry-build` for the ISO and a boot-stage test in QEMU.

2. Define the secret and key contracts.
   - Document the SOPS secret path and allowed Tailscale tag.
   - Require a restricted rescue auth key, with rotation and revocation instructions.
   - Document YubiKey/GPG/pass-store paths for SSH host/deploy keys and the rescue auth key.
   - Verify with SOPS validation/decryption tests that do not emit plaintext into the repository.

3. Implement runtime identity.
   - Derive a short hostname suffix from DMI product UUID, then machine-id, then MAC address.
   - Hash or truncate identifiers before exposing them as hostnames.
   - Use `rescue-<suffix>` for Tailscale, while keeping the ISO's static NixOS hostname harmless.
   - Verify two concurrent QEMU boots produce distinct hostnames and node registrations.

## Boot contract decisions and baseline (2026-09-29)

- The ISO's current `boot.initrd.postDeviceCommands` and `postMountCommands` attempt to mount Ventoy, start PC/SC/GPG, decrypt persistent host/deploy SSH keys, then remove the GPG home and unmount the media. This path is not yet validated on hardware or in QEMU.
- Stage 1 (initrd): only transient mounts, GPG agent state, and any explicitly required unlock material may exist; all are RAM-backed and removed before stage-2 handoff. Do not install host/deploy private keys into the target root for rescue access.
- Stage 2: `/run` is the only location for decrypted rescue credentials and generated runtime identity. Never write rescue credentials to `/etc`, `/nix/store`, `/persist`, or the Ventoy volume.
- SSH must be key-only and must not start until a runtime authorized key is present; no password or default root access. A boot without the YubiKey remains a usable local installer but exposes no remote rescue access.
- Tailscale state must remain memory-only, use a unique `rescue-<suffix>` node name and a dedicated restricted rescue tag, and start only after secret decryption and network readiness. Remove the auth-key file from `/run` after `tailscale up` succeeds; verify and provision a single-use/short-lived key separately. Keep daemon state in memory until shutdown.
- Baseline violations found and corrected in the working tree this turn: Tailscale now uses its SOPS secret under `/run`, memory-only state, a hashed runtime hostname, and `tag:rescue`; SSH disables root/password auth and requires successful SOPS activation; the YubiKey-decrypted host key is placed under `/run/rescue` and removed after SOPS activation; only an operator public key is copied for inbound SSH. Deploy/user private keys are no longer copied into the rescue root.
- The ISO is configured without integrated Home Manager. Its derivation evaluates and the dry-run build passes, but the closure still contains about 815 store paths; “minimal” still needs deliberate package/profile reduction after boot behavior is secured.
- The updated stage ordering and SSH/Tailscale policy are Nix-evaluated, but GPG/YubiKey decryption and QEMU boot behavior remain unverified. The existing encrypted Tailscale auth key has not been confirmed to permit `tag:rescue`; provision it through the secrets task before expecting a successful tailnet join.
- The existing SOPS file has both age and PGP recipients, but this workstation lacks the configured age identity. A local SOPS decryption attempt reached the YubiKey encryption subkey but timed out awaiting card interaction; no secret was decrypted or displayed. Validate the GPG flow interactively before depending on it. Keep the PIN retry counter untouched if pinentry behavior is uncertain.

4. Harden Tailscale startup.
   - Start only after networking and secret/key prerequisites are ready.
   - Read the auth key from `/run`, not `/etc` or `/persist`.
   - Use `--state=mem:` and a restricted rescue tag.
   - Remove the plaintext auth key after successful authentication and on shutdown where practical.
   - Verify missing YubiKey, failed decryption, invalid auth key, and offline-network behavior.

5. Add the final install target.
   - Add a real disko layout and stop relying on placeholder filesystem labels.
   - Generate and commit a target-specific nixos-facter report.
   - Configure final SSH and Tailscale independently from rescue credentials.
   - Remove `initialPassword = "changeme"` and require keys or SOPS-managed credentials.
   - Verify with `nix flake check` and a disposable QEMU disk.

6. Integrate installation.
   - Document connecting to the already-booted ISO over Tailscale/SSH.
   - Use nixos-anywhere with the custom/direct installer path appropriate for an already-running NixOS installer; avoid an unnecessary second kexec.
   - Confirm disko is pointed at the intended disposable disk before destructive execution.
   - Verify a complete QEMU install and reboot into the final system.

7. Harden and document operations.
   - Document auth-key rotation/revocation, lost media/YubiKey response, and tailnet ACL assumptions.
   - Add a preflight checklist that identifies the target, disk, tailnet hostname, and expected final SSH key.
   - Add failure recovery instructions for Tailscale, SOPS, GPG, and disko failures.
   - Run `seeds doctor`, `mulch doctor`, `nix flake check`, ISO build, QEMU smoke test, and review the final diff.

## Verification gates

- No plaintext rescue auth key appears in the Nix store, ISO contents, Git history, `/etc`, or persistent storage.
- The ISO boots without a YubiKey but does not join Tailscale or expose privileged SSH access.
- Two simultaneous boots receive distinct Tailscale hostnames.
- Tailscale state disappears after reboot.
- Final installation uses only the declared flake, disko layout, and facter report.
- A disposable QEMU installation succeeds before testing physical hosts.

## Rollback

- Revoke the rescue auth key and remove its tailnet ACL tag.
- Stop distributing the ISO.
- Revert the rescue service and secret-layout commits independently from final-host changes.
- Preserve the previous known-good ISO until the new image passes all gates.

## Open questions

- Whether Tailscale auth should be an ephemeral single-use key per operator session or a tightly scoped reusable rescue key.
- Whether the rescue ISO should use the existing Ventoy/YubiKey pass-store flow or a smaller dedicated SOPS input.
- Exact nixos-anywhere invocation for the already-booted custom ISO and target architecture.
