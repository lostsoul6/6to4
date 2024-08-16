#!/bin/bash

echo "Which server is this?"
echo "1) Outside"
echo "2) Iran"
echo "3) Remove tunnels"
read -p "Select an option (1, 2 or 3): " server_choice

setup_rc_local() {
    FILE="/etc/rc.local"
    commands="$1"
    command_block=$(cat <<EOF
#! /bin/bash

$commands

exit 0
EOF
)
    echo "$command_block" | sudo tee $FILE
    chmod +x $FILE
    echo "Commands added to /etc/rc.local"
}

if [ "$server_choice" -eq 1 ]; then
    read -p "Enter the IP outside: " ipkharej
    read -p "Enter the IP Iran: " ipiran

    commands=$(cat <<EOF
ip tunnel add 6to4_To_IR mode sit remote $ipiran local $ipkharej
ip -6 addr add 2009:499:1d10:e1d::2/64 dev 6to4_To_IR
ip link set 6to4_To_IR mtu 1480
ip link set 6to4_To_IR up

ip -6 tunnel add GRE6Tun_To_IR mode ip6gre remote 2009:499:1d10:e1d::1 local 2009:499:1d10:e1d::2
ip addr add 180.18.18.2/30 dev GRE6Tun_To_IR
ip link set GRE6Tun_To_IR mtu 1436
ip link set GRE6Tun_To_IR up
{ echo "nameserver 8.8.8.8"; echo "nameserver 1.1.1.1"; } >  /etc/resolv.conf
EOF
)

    eval "$commands"
    setup_rc_local "$commands"
    echo "Commands executed for the outside server."

elif [ "$server_choice" -eq 2 ]; then
    read -p "Enter the IP Iran: " ipiran
    read -p "Enter the IP outside: " ipkharej

    commands=$(cat <<EOF
ip tunnel add 6to4_To_KH mode sit remote $ipkharej local $ipiran
ip -6 addr add 2009:499:1d10:e1d::1/64 dev 6to4_To_KH
ip link set 6to4_To_KH mtu 1480
ip link set 6to4_To_KH up

ip -6 tunnel add GRE6Tun_To_KH mode ip6gre remote 2009:499:1d10:e1d::2 local 2009:499:1d10:e1d::1
ip addr add 180.18.18.1/30 dev GRE6Tun_To_KH
ip link set GRE6Tun_To_KH mtu 1436
ip link set GRE6Tun_To_KH up

sysctl net.ipv4.ip_forward=1
iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination 180.18.18.1
iptables -t nat -A PREROUTING -j DNAT --to-destination 180.18.18.2
iptables -t nat -A POSTROUTING -j MASQUERADE
{ echo "nameserver 8.8.8.8"; echo "nameserver 1.1.1.1"; } >  /etc/resolv.conf
EOF
)

    eval "$commands"
    setup_rc_local "$commands"
    echo "Commands executed for the Iran server."

elif [ "$server_choice" -eq 3 ]; then
    ip tunnel del 6to4_To_IR 2>/dev/null
    ip tunnel del GRE6Tun_To_IR 2>/dev/null
    ip tunnel del 6to4_To_KH 2>/dev/null
    ip tunnel del GRE6Tun_To_KH 2>/dev/null

    iptables -t nat -D PREROUTING -p tcp --dport 22 -j DNAT --to-destination 180.18.18.1 2>/dev/null
    iptables -t nat -D PREROUTING -j DNAT --to-destination 180.18.18.2 2>/dev/null
    iptables -t nat -D POSTROUTING -j MASQUERADE 2>/dev/null

    sudo rm -f /etc/rc.local

    echo "Tunnels and /etc/rc.local removed."

else
    echo "Invalid option. Please select 1, 2 or 3."
fi
