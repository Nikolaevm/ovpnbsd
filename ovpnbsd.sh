#!/usr/local/bin/bash
echo "openvpn freeBSD setup v1.1b"
EASY=/usr/local/share/easy-rsa
OVPN=/usr/local/etc/openvpn
IPFWOPEN="ipfw add 32000 allow ip from any to any"
ME=`basename $0`
echo  > $OVPN/openvpn.conf;

helpscript()
{
	echo "HOW IT WORKS?"
	sleep 1
    echo "EASY:)"
	sleep 1
    echo "USE: $ME options..."
    echo "OPTIONS:"
    echo "  -h            HELP."
    echo "  -c number     HOW MANY KEYS WILL BE GENERATED."
    echo "  -i ip         USE only selected ip."
    echo "  -a            1 IP ADDRESS = 1 CLIENT.(IN DEVELOPMENT SORRY.AVILABLE IN NEXT UPDATE)"
    echo "example:  sh $ME -c 12                  # generate 12 clients, use base ip"
    echo "example:  sh $ME -c 5 -i 95.211.211.211 # generate 12 clients ,use 95.211.211.211 as main"
    echo "2015 maxN / amhost"
    echo
}
if [ $# = 0 ]; then
    echo "SOMTHING WENT WRONG" 
    helpscript
fi

presetup()
{
	ASSUME_ALWAYS_YES=yes
	pkg install -y nano
	pkg install -y bash
	pkg install -y openvpn
	pkg install -y easy-rsa
	pkg install -y wget
}
vpnnet()
{
	ipfw nat 123 config ip $BASEIP log
	ipfw add 10 nat 123 ip from 10.8.0.0/24 to any
	ipfw add 20 nat 123 ip from any to $BASEIP
}
prepare()
{
	mkdir -p /usr/local/etc/openvpn
	mkdir -p /usr/local/etc/openvpn/keys
	mkdir -p /usr/local/etc/openvpn/ccd
	cd $EASY
}
prepareipfw()
{
	kldload ipfw ; ${IPFWOPEN} ; kldload ipfw_nat.ko ; 
	sysctl net.inet.ip.forwarding=1 
}
makeserverkeys()
{
	chmod +x build-dh vars clean-all pkitool whichopensslcnf
	./clean-all
	. ./vars
	./clean-all
	./build-dh 
	./pkitool --initca 
	./pkitool --server server 
	}
makeclients()
{
	j=1;
	k=1;
	cd $EASY
	. ./vars
	for i in `seq 1  ${HMC}`; 
	do 
		j=$((j+3)); 
		./pkitool client-$i;
		mkdir -p /home/openvpn/client-$i;
		mkdir -p /home/openvpn/client-$i/keys;
		cp keys/ca.crt keys/client-$i.crt keys/client-$i.key /home/openvpn/client-$i/keys/;
		echo "10.8.0.$j 10.8.0.$((j+1))" > /usr/local/etc/openvpn/ccd/client-$i;
		echo "client-$i,10.8.0.$j" >> $OVPN/ipp.txt;
		clientconf;
	done > /dev/null 2>&1
	echo "$HMC keys are generated. done.." 
}
aftersetup()
{
	echo 'gateway_enable="YES"' >> /etc/rc.conf
	echo 'openvpn_enable="YES"' >> /etc/rc.conf
	echo 'firewall_enable="YES"' >> /etc/rc.conf
	echo 'firewall_nat_enable="YES"' >> /etc/rc.conf
	echo 'firewall_type="open"' >> /etc/rc.conf
	echo "firewall_script=\"/etc/rc.firewall\"" >> /etc/rc.conf
	/usr/local/etc/rc.d/openvpn start
}
easymake(){
	cd $EASY
	echo "server keys in progress.."
	makeserverkeys > /dev/null 2>&1
	echo "clients keys in progress.."
	makeclients
}
vpnconf(){
	cp $EASY/keys/ca.crt $EASY/keys/server.crt $EASY/keys/server.key $EASY/keys/dh*.pem $OVPN/;
	DH=$(ls $OVPN | grep dh);
	echo "port 1194" >> $OVPN/openvpn.conf;
	echo "proto udp" >> $OVPN/openvpn.conf;
	echo "dev tun" >> $OVPN/openvpn.conf;
	echo "ca ca.crt" >> $OVPN/openvpn.conf;
	echo "cert server.crt" >> $OVPN/openvpn.conf;
	echo "key server.key" >> $OVPN/openvpn.conf;
	echo "dh $DH" >> $OVPN/openvpn.conf;
	echo "server 10.8.0.0 255.255.255.0" >> $OVPN/openvpn.conf;
	echo "keepalive 10 120" >> $OVPN/openvpn.conf;
	echo "comp-lzo" >> $OVPN/openvpn.conf;
	echo "persist-key" >> $OVPN/openvpn.conf;
	echo "persist-tun" >> $OVPN/openvpn.conf;
	echo "status openvpn-status.log" >> $OVPN/openvpn.conf;
	echo "log-append  openvpn.log" >> $OVPN/openvpn.conf;
	echo "verb 3" >> $OVPN/openvpn.conf;
	echo "push \"redirect-gateway def1\"" >> $OVPN/openvpn.conf;
	echo "push \"dhcp-option DNS 8.8.8.8\"" >> $OVPN/openvpn.conf;
	echo "client-config-dir ccd" >> $OVPN/openvpn.conf;
	echo "push \"redirect-gateway def1 bypass-dhcp\"" >> $OVPN/openvpn.conf;
	echo "ifconfig-pool-persist ipp.txt" >> $OVPN/openvpn.conf;
}
clientconf()
{
	echo "cert keys/client-$i.crt" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "key keys/client-$i.key" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "ca keys/ca.crt" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "remote 1194" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "client" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "dev tun" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "redirect-gateway" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "proto udp" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "resolv-retry infinite" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "nobind" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "persist-key" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "persist-tun" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "comp-lzo" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "verb 3" >> /home/openvpn/client-$i/client-$i.ovpn
	echo "mute 20" >> /home/openvpn/client-$i/client-$i.ovpn
}
while getopts "ghc:i::a" opt ;
do
    case $opt in
        h)  echo "USE $ME -h";
            helpscript;
            exit 1
        ;;
        i) 	BASEIP=$OPTARG;
			echo "${IPFWOPEN}" >> firenat.txt
			ipfw nat 123 config ip ${BASEIP} log > /dev/null 2>&1;
			echo "ipfw nat 123 config ip ${BASEIP} log" >> firenat.txt
			ipfw add 10 nat 123 ip from 10.8.0.0/24 to any > /dev/null 2>&1;
			echo "ipfw add 10 nat 123 ip from 10.8.0.0/24 to any" >> firenat.txt
			ipfw add 20 nat 123 ip from any to ${BASEIP} > /dev/null 2>&1;
			echo "ipfw add 20 nat 123 ip from any to ${BASEIP}" >> firenat.txt
			while read rules;do echo "${rules}" >> /etc/rc.firewall;done < firenat.txt
			echo "local ${BASEIP}" >> $OVPN/openvpn.conf;
			ls /home/openvpn/ > clients.txt
			while read confs; 
			do 
				sed -i "" -e "s#remote\ 1194#remote\ ${BASEIP}\ 1194#g" /home/openvpn/${confs}/${confs}.ovpn ;
			done < clients.txt > /dev/null 2>&1
        ;;
        a) 	echo `ifconfig | awk '/inet /{print $2}' | grep -v "127.0.0.1"` > IPS.txt;
			HMC="$(cat IPS.txt | wc -l)";
			echo "in development, sorry."
			exit 1
			###########################
			######## to do here #######
			###########################
			
            ;;
        c) 	HMC=$OPTARG;
			BASEIP=`ifconfig | awk '/inet /{print $2}' | grep -v "127.0.0.1" | grep -v "localhost" | head -n 1`
			pkg install -y bash
			echo "instaling pakages.."
			presetup > /dev/null 2>&1;
			echo "lets making some dirs.."
			prepare > /dev/null 2>&1;
			echo "and firewall rules.."
			echo "packet_write_wait: Connection to host: Broken pipe"
			sleep 1
			echo "joke:)"
			echo "in progress: dh2048.pem , server & clients keys/certs"
			prepareipfw > /dev/null 2>&1;
			easymake > /dev/null 2>&1;
			vpnconf;
			aftersetup;
			echo "configured ${HMC} clients"
		   	echo "all done! clients keys with configs in /home/openvpn/";
		;;
		g)	######################################
			#### generate additional clients #####
			############## in develop ############
			######## to do here ##################
			######################################
			echo "nothing to do"
			exit 1
		;;
        *) 	echo "SOMTHING WRONG";
            echo "USE $ME -h";
            helpscript;
            exit 1
        ;;
    esac
done

