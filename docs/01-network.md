# Stage 1: Network

## Goal

Build the network of a small clinic: one router, three separate segments (servers, workstations, guests), and a firewall that controls the traffic between them.

## Design

- Router: MikroTik CHR (RouterOS 7.24.7), name `rtr-clinic`.
- ether1: WAN, VMware NAT (VMnet8), address from DHCP.
- ether2: Servers, 10.10.10.1/24 (VMware LAN segment `lab-servers`).
- ether3: Workstations, 10.10.20.1/24 (LAN segment `lab-ws`), DHCP pool 10.10.20.100-200.
- ether4: Guest, 10.10.30.1/24 (LAN segment `lab-guest`), DHCP pool 10.10.30.100-200.
- Servers use static addresses. DHCP lease time is 1 hour.
- The router is managed only from the VMware console.

Firewall rules:

- Input: allow established/related, drop invalid, allow ICMP, allow DHCP and DNS from LAN only, drop everything else.
- Forward: allow established/related, drop invalid, workstations to servers only ICMP and TCP 22, LAN to internet allowed, drop everything else.
- Guests have no rule to the servers, so they are blocked.
- ICMP in the input chain is allowed on all interfaces, including WAN. This is a conscious choice for the lab. It can be checked again in the security testing stage.

Servers: `srv-linux01` (Ubuntu Server 26.04.1 LTS) has the static address 10.10.10.10/24 set with netplan. Gateway and DNS are 10.10.10.1.

## Steps

1. Create the VM network segments and connect the router interfaces.
2. Set addresses, comments, interface lists (LAN, WAN) and NAT on the router.
3. Set up DHCP servers for workstations and guests, and DNS on the router.
4. Write the firewall rules for input and forward.
5. Install `srv-linux01` and set the static address.
6. Run the isolation tests (see Verification).
7. Export the router config without secrets: `/export hide-sensitive file=rtr-clinic`. The file is in `network/rtr-clinic.rsc`.

## Verification

Tests from Kali in the workstation segment (10.10.20.200):

- `ping 10.10.10.10` works.
- `nc -vz -w 3 10.10.10.10 22` shows `open`.
- `nc -vz -w 3 10.10.10.10 80` ends with `Connection timed out` (dropped by the firewall).

Test from `srv-linux01`:

- `ping 10.10.20.200` gives 100% packet loss. The server cannot start connections to workstations.

Tests from Kali in the guest segment (10.10.30.200):

- The gateway 10.10.30.1, the internet (1.1.1.1) and DNS (google.com) work.
- `ping 10.10.10.10` gives 100% packet loss and port 22 times out. Guests cannot reach the servers.

Router input check: `nslookup` to the router WAN address from the laptop answered before the input rules were added and stopped answering after.

## Problems and solutions

1. **Router log shows `kernel failure in previous boot`.** Most likely the VM was powered off without a proper shutdown. Solution: stop the router with `/system shutdown`, not with Power Off.
2. **No access to the router config file.** The router is managed only from the VMware console, and the input chain drops SSH. Solution: add a temporary input rule that allows TCP 22 only from the laptop address (192.168.169.1) and only from WAN, copy the file with `scp`, then remove the rule. After that, port 22 was checked again and it was closed.
3. **The temporary rule was not added: `invalid internal item number`.** I used `place-before=[find ...]` with a wrong condition, and it found no rule. Solution: print the input rules, take the number of the last `drop` rule, and use `place-before=<number>`.
4. **The export file had a router `system id` line.** It is not needed in a public repository. Solution: remove this line from the copy and check the file for passwords, keys and users before the commit.
5. **Typo in a firewall comment (`DCHP`).** Found when reading the whole file before the commit. Solution: fix the comment on the router and in the exported file, so they match.
6. **Wrong RouterOS version in `docs/00-planning.md`.** It said 7.25.2, but the router shows 7.24.7. Solution: check the version in the router console and fix the document.