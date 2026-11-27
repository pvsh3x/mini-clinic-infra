# 2026-11-27 12:28:50 by RouterOS 7.24.7
#
/interface ethernet
set [ find default-name=ether1 ] comment="WAN (NAT)" disable-running-check=no
set [ find default-name=ether2 ] comment="Servers (lab-servers)" \
    disable-running-check=no
set [ find default-name=ether3 ] comment="Workstation (lab-ws)" \
    disable-running-check=no
set [ find default-name=ether4 ] comment="Guest (lab-guest)" \
    disable-running-check=no
/interface list
add name=WAN
add name=LAN
/ip pool
add name=pool-ws ranges=10.10.20.100-10.10.20.200
add name=pool-guest ranges=10.10.30.100-10.10.30.200
/ip dhcp-server
add address-pool=pool-ws interface=ether3 lease-time=1h name=dhcp-ws
add address-pool=pool-guest interface=ether4 lease-time=1h name=dhcp-guest
/interface list member
add interface=ether2 list=LAN
add interface=ether3 list=LAN
add interface=ether4 list=LAN
add interface=ether1 list=WAN
/ip address
add address=10.10.10.1/24 comment="Servers gateway" interface=ether2 network=\
    10.10.10.0
add address=10.10.20.1/24 comment="Workstations gateway" interface=ether3 \
    network=10.10.20.0
add address=10.10.30.1/24 comment="Guest gateway" interface=ether4 network=\
    10.10.30.0
/ip dhcp-client
add interface=ether1 name=client1
/ip dhcp-server network
add address=10.10.20.0/24 comment=Workstations dns-server=10.10.10.10 \
    gateway=10.10.20.1
add address=10.10.30.0/24 comment=Guest dns-server=10.10.10.10 gateway=\
    10.10.30.1
/ip dns
set allow-remote-requests=yes
/ip firewall filter
add action=accept chain=input comment="in: established" connection-state=\
    established,related,untracked
add action=drop chain=input comment="in: invalid" connection-state=invalid
add action=accept chain=input comment="in: icmp" protocol=icmp
add action=accept chain=input comment="in: DHCP" dst-port=67 \
    in-interface-list=LAN protocol=udp
add action=accept chain=input comment="in: DNS udp" dst-port=53 \
    in-interface-list=LAN protocol=udp
add action=accept chain=input comment="in: DNS tcp" dst-port=53 \
    in-interface-list=LAN protocol=tcp
add action=drop chain=input comment="in: drop rest"
add action=accept chain=forward comment="fwd: established" connection-state=\
    established,related,untracked
add action=drop chain=forward comment="fwd: invalid" connection-state=invalid
add action=accept chain=forward comment="ws>srv icmp" dst-address=\
    10.10.10.0/24 protocol=icmp src-address=10.10.20.0/24
add action=accept chain=forward comment="ws>srv ssh" dst-address=\
    10.10.10.0/24 dst-port=22 protocol=tcp src-address=10.10.20.0/24
add action=accept chain=forward comment="fwd: LAN to internet" \
    in-interface-list=LAN out-interface-list=WAN
add action=accept chain=forward comment="ws>dns udp" dst-address=10.10.10.10 \
    dst-port=53 protocol=udp src-address=10.10.20.0/24
add action=accept chain=forward comment="ws>dns tcp" dst-address=10.10.10.10 \
    dst-port=53 protocol=tcp src-address=10.10.20.0/24
add action=accept chain=forward comment="guest>dns udp" dst-address=\
    10.10.10.10 dst-port=53 protocol=udp src-address=10.10.30.0/24
add action=accept chain=forward comment="guest>dns tcp" dst-address=\
    10.10.10.10 dst-port=53 protocol=tcp src-address=10.10.30.0/24
add action=drop chain=forward comment="fwd: drop rest"
/ip firewall nat
add action=masquerade chain=srcnat comment="NAT to WAN" out-interface=ether1
/system identity
set name=rtr-clinic
