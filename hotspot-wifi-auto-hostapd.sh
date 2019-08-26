#!/bin/bash
#################
#Script de roteador wifi automatico
#v 1.0
#CONFIGURADO PARA SUPORTAR 20 CONEXOES
#by: DOUGLAS VITOR
#################

read -p 'LIGAR[L] ou DESLIGAR[d] ? ' PER
case $PER in
l|L ) PER=1 ;;
d|D ) PER=0 ;;
* ) echo "ARGUMENTO INVALIDO." ;;
esac

if [ $PER == 1 ]
then
read -p 'ATUALIZAR/INSTALAR PACOTES NECESSARIOS? [s/N] ' ATT
case $ATT in
s|S ) apt-get update && apt-get install isc-dhcp-server hostapd -y ;;
n|N ) echo "CONTINUANDO SCRIPT..." ;;
* ) echo "ARGUMENTO INVALIDO." ;;
esac

read -p 'DIGITE UMA SENHA PARA O ROTEADOR : ' SENH

echo "##########################################################"
echo '  VAMOS CONFIGURAR AS PLACAS DE REDE QUE RECEBE/ENVIA NET '
read -p 'PLACA QUE RECEBE INTERNET EX. eth0 : ' RECE
case $RECE in
eth0 ) RECE=eth0 ;;
wlan0 ) RECE=wlan0 ;;
wlan1 ) RECE=wlan1 ;;
wlan2 ) RECE=wlan2 ;;
* ) echo 'ARGUMENTO INVALIDO.' ;;
esac

read -p 'PLACA QUE ENVIA INTERNET EX. wlan0 : ' ENVI
case $ENVI in
eth0 ) ENVI=eth0 ;;
wlan0 ) ENVI=wlan0 ;;
wlan1 ) ENVI=wlan1 ;;
wlan2 ) ENVI=wlan2 ;;
* ) echo 'ARGUMENTO INVALIDO.' ;;
esac
echo "##########################################################"

cp /etc/dhcp/dhcpd.conf /etc/dhcp/bkp_dhcpd.conf &&

echo 'authoritative;
subnet 192.168.30.0 netmask 255.255.255.0 {
	range 192.168.30.10 192.168.30.30;
	option broadcast-address 192.168.30.255;
	option routers 192.168.30.1;
	default-lease-time 600;
	max-lease-time 7200;
	option domain-name "local";
	option domain-name-servers 8.8.8.8, 8.8.4.4;
}
' > /etc/dhcp/dhcpd.conf &&

cp /etc/default/isc-dhcp-server /etc/default/bkp_isc-dhcp-server &&
echo 'INTERFACESv4="'$ENVI'"' > /etc/default/isc-dhcp-server &&
echo 'INTERFACESv6="'$ENVI'"' >> /etc/default/isc-dhcp-server &&

cp /etc/network/interfaces /etc/network/bkp_interfaces &&

echo 'auto lo

iface lo inet loopback' > /etc/network/interfaces &&
echo 'iface '$RECE' inet dhcp
#iface wlan1 inet dhcp

allow-hotplug '$ENVI >> /etc/network/interfaces &&
echo 'iface '$ENVI' inet static
 address 192.168.30.1
 netmask 255.255.255.0

#iface wlan0 inet manual
#wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
#iface default inet dhcp
' >> /etc/network/interfaces &&

ifconfig $ENVI 192.168.30.1

echo 'interface='$ENVI > /etc/hostapd/hostapd.conf &&
echo '#driver=rtl871xdrv
ssid=TEMP
country_code=US
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2' >> /etc/hostapd/hostapd.conf &&
echo 'wpa_passphrase='$SENH >> /etc/hostapd/hostapd.conf &&
echo 'wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
wpa_group_rekey=86400
ieee80211n=1
wme_enabled=1
' >> /etc/hostapd/hostapd.conf &&

cp /etc/default/hostapd /etc/default/bkp_hostapd &&

echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd &&
cp /etc/sysctl.conf /etc/bkp_sysctl.conf &&

echo 'net.ipv4.ip_forward=1' > /etc/sysctl.conf &&

#echo 1 > /proc/sys/net/ipv4/ip_forward &&

sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
iptables -F
iptables -t nat -F
iptables -t nat -A POSTROUTING -o $RECE -j MASQUERADE
iptables -A FORWARD -i $RECE -o $ENVI -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $ENVI -o $RECE -j ACCEPT
sh -c "iptables-save > /etc/iptables/rules.v4"


#dhcpd -cf /etc/dhcp/dhcpd.conf -pf /var/run/dhcpd.pid $ENVI
service isc-dhcp-server start &&

/usr/sbin/hostapd /etc/hostapd/hostapd.conf &

echo "##########################################################"
echo "			ROTEADOR LIGADO!			"
echo "##########################################################"
fi

if [ $PER == 0 ]
then
echo "PARANDO ISC-DHCP-SERVER"
service isc-dhcp-server stop &&

echo "PARANDO HOSTAPD"
service hostapd stop &&

echo "RESTAURANDO DHCPD.CONF"
cat /etc/dhcp/bkp_dhcpd.conf > /etc/dhcp/dhcpd.conf &&
rm /etc/dhcp/bkp_dhcpd.conf &&

echo "RESTAURANDO ISC-DHCP-SERVER"
cat /etc/default/bkp_isc-dhcp-server > /etc/default/isc-dhcp-server &&
rm /etc/default/bkp_isc-dhcp-server &&

echo "RESTAURANDO INTERFACES"
cat /etc/network/bkp_interfaces > /etc/network/interfaces &&
rm /etc/network/bkp_interfaces &&
echo 'source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback ' > /etc/network/interfaces

ifconfig $ENVI down &&
service networking restart &&
ifconfig $ENVI up &&

echo "REMOVENDO HOSTAPD.CONF"
rm /etc/hostapd/hostapd.conf

echo "RESTAURANDO HOSTAPD"
cat /etc/default/bkp_hostapd > /etc/default/hostapd &&
rm /etc/default/bkp_hostapd &&

echo "RESTAURANDO SYSCTL.CONF"
cat /etc/bkp_sysctl.conf > /etc/sysctl.conf &&
rm /etc/bkp_sysctl.conf &&

iptables -F
iptables -t nat -F


echo "##########################################################"
echo "			ROTEADOR DESLIGADO!			"
echo "##########################################################"
fi
exit 0

