# Stage 2: Hardening srv-linux01

## Overview

This stage secures the Linux server `srv-linux01` and turns it into the DNS server of the lab.

| Item | Value |
|------|-------|
| OS | Ubuntu Server 26.04.1 |
| IP address | 10.10.10.10/24 (static, netplan, interface ens33) |
| Network | Servers (10.10.10.0/24) |
| Admin user | pwned |

## 1. SSH hardening

I use an SSH key (ed25519) with a passphrase instead of a password.

File: `/etc/ssh/sshd_config.d/00-hardening.conf`

```
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
MaxAuthTries 3
```

What it does:
- No password login. Only the key works.
- Root cannot log in over SSH.
- Only 3 login tries per connection.

## 2. Firewall (ufw)

Default policy: deny all incoming, allow all outgoing.

Allowed incoming:
- tcp 22 (SSH) from 10.10.20.0/24 (Workstations)
- tcp and udp 53 (DNS) from 10.10.20.0/24 (Workstations)
- tcp and udp 53 (DNS) from 10.10.30.0/24 (Guest)

Guest network has no SSH access to the server.

## 3. Brute-force protection (fail2ban)

File: `/etc/fail2ban/jail.d/sshd.local`

```
[sshd]
enabled = true
backend = systemd
maxretry = 3
findtime = 10m
bantime = 1h
```

Three failed logins in 10 minutes ban the IP for 1 hour.

## 4. Automatic security updates

Package: `unattended-upgrades`.
File: `/etc/apt/apt.conf.d/20auto-upgrades` is enabled.
Only the security sources are used.


## 5. DNS server (AdGuard Home)

`srv-linux01` is the DNS server for Workstations and Guest. AdGuard Home blocks ads and trackers.

- Installed in `/opt/AdGuardHome` as a systemd service.
- DNS listens on port 53 on all interfaces.
- The web panel listens only on `127.0.0.1:3001`. It is not open to the network.

To open the panel, I use an SSH tunnel from the admin workstation (Kali):

```
ssh -L 3001:127.0.0.1:3001 pwned@10.10.10.10
```

Then I open `http://127.0.0.1:3001` in the browser.

Port 53 was used by `systemd-resolved`. I turned off its stub listener:

File: `/etc/systemd/resolved.conf.d/adguardhome.conf`

```
[Resolve]
DNSStubListener=no
```

`/etc/resolv.conf` now points to `/run/systemd/resolve/resolv.conf`.

## 6. Router changes (rtr-clinic)

New forward rules. They are placed before `fwd: drop rest`:

| Comment | Source | Destination | Port |
|---------|--------|-------------|------|
| ws>dns udp | 10.10.20.0/24 | 10.10.10.10 | udp 53 |
| ws>dns tcp | 10.10.20.0/24 | 10.10.10.10 | tcp 53 |
| guest>dns udp | 10.10.30.0/24 | 10.10.10.10 | udp 53 |
| guest>dns tcp | 10.10.30.0/24 | 10.10.10.10 | tcp 53 |

The DHCP networks for Workstations and Guest now give `dns-server=10.10.10.10`.

The full router config is in `network/rtr-clinic.rsc`.

## 7. Tests

Tested from Kali (Workstations, 10.10.20.200):

- `/etc/resolv.conf` shows `10.10.10.10`.
- `ubuntu.com` resolves normally.
- `doubleclick.net` and `ads.mozilla.org` are blocked (answer `0.0.0.0`).
- All requests are visible in the AdGuard Query Log with client `10.10.20.200`.

## Problems and solutions

**1. AdGuard setup wizard could not use port 3000.**
Error: `address already in use` on `127.0.0.1:3000`.
Solution: I set the web panel to port 3001.

**2. Port 53 was busy.**
`systemd-resolved` was using it.
Solution: I turned off the stub listener and switched `resolv.conf`.

**3. No route from the laptop to the Servers network.**
Solution: I manage the server from Kali in the Workstations network. I did not open a hole from the WAN side.

**4. New DNS rules could be below `drop rest`.**
Firewall rules work from top to bottom, so a rule below `drop rest` never works.
Solution: I added the rules with `place-before=[find comment="fwd: drop rest"]`.

**5. Clients used the router as DNS.**
Solution: I set `dns-server=10.10.10.10` in both DHCP networks.

**6. The AdGuard panel is not available without an SSH tunnel.**
This is on purpose, because the panel listens only on localhost. I start the tunnel before I work.

**7. SSH to the router was blocked from Workstations.**
The `input` chain drops everything except DHCP, DNS and ICMP. To export the config, I added a temporary rule for one IP (Kali), then removed it. The temporary rule is not in the saved config.