# Unattended updates for Debian-family hosts

Two gaps, two tools:

- **New kernel (or dbus):** `unattended-upgrades` installs it and drops `/var/run/reboot-required`,
  but only reboots if `Automatic-Reboot` is on. Otherwise the old kernel runs until someone reboots.
- **New library (openssl, libc, ...):** no reboot flag is set. Running daemons (sshd, dockerd, ...) keep
  the old library in memory until restarted. `needrestart` does that, but only if set to automatic;
  its default (interactive) restarts nothing when run unattended.

Docker comes from its own apt repo, which unattended-upgrades ignores unless told otherwise.

## Apply (as root)

```bash
apt-get install -y unattended-upgrades needrestart

tee /etc/apt/apt.conf.d/52-unattended.conf <<'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
// shutdown -r at this clock time, even with users logged in (Automatic-Reboot-WithUsers defaults to true)
Unattended-Upgrade::Automatic-Reboot-Time "04:30";
Unattended-Upgrade::Origins-Pattern:: "origin=Docker,archive=${distro_codename},label=Docker CE";
EOF

tee /etc/needrestart/conf.d/90-auto.conf <<'EOF'
$nrconf{restart} = 'a';
EOF

# Run the upgrade at a fixed quiet time (default: ~06:00 + up to 1h random) so every restart happens
# in the window, before the reboot.
mkdir -p /etc/systemd/system/apt-daily-upgrade.timer.d
tee /etc/systemd/system/apt-daily-upgrade.timer.d/override.conf <<'EOF'
[Timer]
OnCalendar=
OnCalendar=*-*-* 03:30
RandomizedDelaySec=0
EOF
systemctl daemon-reload
```

Other third-party repos need their own `Origins-Pattern::` line; find the fields with
`apt-cache policy | grep 'o='`.

## What happens each night

1. **03:30** upgrades install; `needrestart` restarts services on updated libraries (Docker too, so
   its containers blip for a few seconds).
2. If a kernel/dbus update set the reboot flag (or an earlier one is still pending), `shutdown -r 04:30`
   is scheduled. The reboot happens at 04:30, not immediately.
3. If the upgrade run is still going at 04:30, the reboot slips a day. Keep a generous gap between the
   two times, especially on slow hosts after a long gap without updates.

## Verify

```bash
apt-config dump | grep -E 'Automatic-Reboot|Origins-Pattern'
systemctl list-timers apt-daily-upgrade.timer          # NEXT must show the fixed time
unattended-upgrade --dry-run -d 2>&1 | grep -E 'Allowed origins|upgraded'
needrestart -r l -b      # NEEDRESTART-KSTA: 1 = running kernel is current
```

## Why not a script

The config is a handful of lines and differs per host only in the two times and extra origins. A
wrapper (validation, dry run, idempotence) costs more to maintain than it saves.
