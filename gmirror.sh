#!/usr/local/bin/bash
FDN=`gpart show | head -n 1 | awk '{print $4}'`
SDN=`gpart show | head -n 1 | awk '{print $4}' | sed "s/0/1/g"`
TDN=`gpart show | head -n 1 | awk '{print $4}' | sed "s/0/2/g"`
FRDN=`gpart show | head -n 1 | awk '{print $4}' | sed "s/0/3/g"`
raidtype1step1(){
	gpart backup ${FDN} > ${FDN}.gpt
	gpart restore -F /dev/${SDN} < ${FDN}.gpt
	gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ${SDN}
	addgeom(){
		gmirror label -vb round-robin boot /dev/${SDN}p1
		gmirror label -vb round-robin root /dev/${SDN}p2
		gmirror label -vb round-robin swap /dev/${SDN}p3
		gmirror label -vb round-robin var /dev/${SDN}p4
		gmirror label -vb round-robin tmp /dev/${SDN}p5
		gmirror label -vb round-robin usr /dev/${SDN}p6
		gmirror load
		sed -i "" "/sshd/d" /etc/rc.conf
		sed -i "" "/geom_mirror_load/d" /boot/loader.conf
		sed -i "" "/geom_stripe_load/d" /boot/loader.conf
		echo geom_mirror_load="YES" >> /boot/loader.conf
		echo sshd_enable="YES" >> /etc/rc.conf
	}
	makenewfs(){
		newfs -U /dev/mirror/root
		newfs -U /dev/mirror/var
		newfs -U /dev/mirror/tmp
		newfs -U /dev/mirror/usr
	}

	makefstab(){
		mv /etc/fstab /etc/fstab.old
		echo  "#Device Mountpoint FSType Options Dump Pass#" >> /etc/fstab
		echo "/dev/mirror/root /  ufs rw 1 1" >> /etc/fstab
		echo "/dev/mirror/swap         none                swap          sw        0        0" >> /etc/fstab
		echo "/dev/mirror/var         /var                  ufs          rw        2        2" >> /etc/fstab
		echo "/dev/mirror/tmp         /tmp                  ufs          rw        2        2" >> /etc/fstab
		echo "/dev/mirror/usr         /usr                  ufs          rw        2        2" >> /etc/fstab
		cat /etc/fstab
	}
	rsyncmount(){
		mount /dev/mirror/root /mnt
		mkdir /mnt/var
		mkdir /mnt/usr
		mkdir /mnt/tmp
		mount /dev/mirror/usr /mnt/usr
		mount /dev/mirror/var /mnt/var
		mount /dev/mirror/tmp /mnt/tmp
		echo "raidstep" > /root/raid.txt
		rsync -aAHX --delete  --exclude "/mnt" / /mnt
		umount /mnt/usr;
		umount /mnt/var;
		umount /mnt/tmp;
		umount /mnt;
	}
	if [[ $(cat /etc/fstab | grep -v "^#" | grep /dev/ | awk '{print $1}' | grep -v proc | wc -l) -eq "5" ]];
	 then 
		echo "good";
		addgeom;
		makenewfs;
		makefstab;
		rsyncmount;
		echo raidone > /root/raid.txt
		#reboot;
	else 
		echo "not goot";
		exit 1; 
	fi 
}
raidstep2(){
	gmirror insert boot /dev/${FDN}p1
	gmirror insert root /dev/${FDN}p2
	gmirror insert swap /dev/${FDN}p3
	gmirror insert var /dev/${FDN}p4
	gmirror insert tmp /dev/${FDN}p5
	gmirror insert usr /dev/${FDN}p6
	echo "done" > /root/raid.txt	
}
raidtype10step1(){
	parts(){
		gpart backup ${FDN} > ${FDN}.gpt;
		gpart restore -F /dev/${SDN} < ${FDN}.gpt;
		gpart restore -F /dev/${TDN} < ${FDN}.gpt;
		gpart restore -F /dev/${FRDN} < ${FDN}.gpt;
		gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ${SDN};
		gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ${TDN};
		gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 ${FRDN};
	}
	makegeo(){
		gmirror label -vb round-robin boot /dev/${SDN}p1 /dev/${FRDN}p1 /dev/${TDN}p1;
		gmirror label -vb round-robin root /dev/${SDN}p2 /dev/${FRDN}p2 /dev/${TDN}p2;
		gmirror label -vb round-robin swap /dev/${SDN}p3 /dev/${FRDN}p3 /dev/${TDN}p3;
		gmirror label -vb round-robin var /dev/${SDN}p4  /dev/${FRDN}p4  /dev/${TDN}p4;
		gmirror label -vb round-robin tmp /dev/${SDN}p5 /dev/${FRDN}p5 /dev/${TDN}p5;
		gmirror load;
		kldload geom_stripe;
		gmirror label -vb round-robin usr1
		 /dev/${TDN}p6 /dev/${FRDN}p6;
		gmirror label -vb round-robin usr /dev/${SDN}p6;
		gstripe label -v stripe1 /dev/mirror/usr /dev/mirror/usr1;
		bsdlabel -w /dev/stripe/stripe1;
	
	}
	fsmake(){
		newfs -U /dev/mirror/root;
		newfs -U /dev/mirror/var;
		newfs -U /dev/mirror/tmp;
		newfs -U /dev/stripe/stripe1a;
	}
	loadrc(){
		sed -i "" "/sshd/d" /etc/rc.conf;
		echo sshd_enable="YES" >> /etc/rc.conf;
		if [ -f /boot/loader.conf ]; 
		then
			sed -i "" "/geom_mirror_load/d" /boot/loader.conf;
			sed -i "" "/geom_stripe_load/d" /boot/loader.conf;
			echo geom_mirror_load="YES" >> /boot/loader.conf;
			echo geom_stripe_load="YES" >> /boot/loader.conf;
		else
			echo geom_mirror_load="YES" >> /boot/loader.conf;
			echo geom_stripe_load="YES" >> /boot/loader.conf;
		fi
	}
	fstab(){
		mv /etc/fstab /etc/fstab.old;
		echo "#Device                 Mountpoint            FSType       Options   Dump Pass#" >> /etc/fstab;
		echo "/dev/mirror/root        /                     ufs          rw        1        1" >> /etc/fstab;
		echo "/dev/mirror/swap        none                  swap         sw        0        0" >> /etc/fstab;
		echo "/dev/mirror/var         /var                  ufs          rw        2        2" >> /etc/fstab;
		echo "/dev/mirror/tmp         /tmp                  ufs          rw        2        2" >> /etc/fstab;
		echo "/dev/stripe/stripe1a    /usr                  ufs          rw        2        2" >> /etc/fstab;
		cat /etc/fstab;
	}
	moutrsy(){
		mount /dev/mirror/root /mnt;
		mkdir /mnt/usr /mnt/tmp /mnt/var;
		mount /dev/stripe/stripe1a /mnt/usr;
		mount /dev/mirror/var /mnt/var;
		mount /dev/mirror/tmp /mnt/tmp;
		rsync -aAHX --delete --exclude "/mnt" / /mnt;
		mkdir /mnt/mnt;
		umount /mnt/usr;
		umount /mnt/var;
		umount /mnt/tmp;
		umount /mnt;
	}
	if [[ $(cat /etc/fstab | grep -v "^#" | grep /dev/ | awk '{print $1}' | grep -v proc | wc -l) -eq "5" ]];
	then 
		echo "good";
		parts;
		makegeo;
		fsmake;
		loadrc;
		fstab;
		echo raid > /root/raid.txt
		moutrsy;
		#reboot;
	else 
		echo "not goot";
		exit 1; 
	fi 
}

if [ -f raid.txt ]; then
	raidstep2;
else
	if [[ $(gpart show | grep "=>" | wc -l) -eq "4" ]]; then
		raidtype10step1;
	else
		raidtype1step1;
	fi
fi