#!/usr/bin/env bash

# Premier script à lancer

. ./Core/init
. ./Core/conf

# Création du dossier de validation d'étapes
try mkdir -p ${SCRIPTPATH}/${STEPPATH}

echo
echo "Mise à l'heure du système"
if $( task_check ${LIVECD_DATETIME}_LIVECD_DATETIME $STEPPATH )
then
	try ntpd -4 -q -g
	task_done ${LIVECD_DATETIME}_LIVECD_DATETIME $STEPPATH
else
	task_skip ${LIVECD_DATETIME}_LIVECD_DATETIME
fi

echo
echo "Partitionnement du disque dur et initialisation du système de fichier…"
if $( task_check ${SYSTEM_PARTITION}_SYSTEM_PARTITION $STEPPATH )
then
	try parted -s -a optimal /dev/${DISK} mklabel gpt
	try parted -s -a optimal /dev/${DISK} unit mib
	try parted -s -a optimal /dev/${DISK} mkpart primary 1 3
	try parted -s -a optimal /dev/${DISK} name 1 grub
	try parted -s -a optimal /dev/${DISK} set 1 bios_grub on
	try parted -s -a optimal /dev/${DISK} mkpart primary ext2 3 131
	try parted -s -a optimal /dev/${DISK} name 2 boot
	try parted -s -a optimal /dev/${DISK} mkpart primary ext4 '131 -1'
	try parted -s -a optimal /dev/${DISK} name 3 rootfs
	try parted -s -a optimal /dev/${DISK} set 2 boot on
	try parted -s -a optimal /dev/${DISK} print
	try mkfs.ext2 -F /dev/${DISK}2
	try mkfs.ext4 -F /dev/${DISK}3
	task_done ${SYSTEM_PARTITION}_SYSTEM_PARTITION $STEPPATH
else
	task_skip ${SYSTEM_PARTITION}_SYSTEM_PARTITION
fi

echo
echo "Montage de la partition racine…"
if $( task_check ${SYSTEM_MOUNT}_SYSTEM_MOUNT $STEPPATH )
then
	try mount /dev/${DISK}3 $ROOTPATH
	task_done ${SYSTEM_MOUNT}_SYSTEM_MOUNT $STEPPATH
else
	task_skip ${SYSTEM_MOUNT}_SYSTEM_MOUNT
fi

echo
echo "Initialisation du swap…"
if $( task_check ${SYSTEM_SWAP}_SYSTEM_SWAP $STEPPATH )
then
	try fallocate -l ${SWAP} ${ROOTPATH}/swapfile
	try chmod 600 ${ROOTPATH}/swapfile
	try mkswap ${ROOTPATH}/swapfile
	try swapon ${ROOTPATH}/swapfile
	task_done ${SYSTEM_SWAP}_SYSTEM_SWAP $STEPPATH
else
	task_skip ${SYSTEM_SWAP}_SYSTEM_SWAP
fi

echo
echo "Installation du stage3…"
if $( task_check ${SYSTEM_STAGE3}_SYSTEM_STAGE3 $STEPPATH )
then
	cd $ROOTPATH

	echo "- Téléchargement de l'archive stage3…"
	MIRROR=distfiles.gentoo.org
  FOLDER=releases/amd64/autobuilds/current-install-amd64-minimal
	IMAGE="stage3-amd64-\w*.tar.bz2"
	FILE=$(wget -4 -q http://${MIRROR}/${FOLDER}/ -O - | grep -o -e "${IMAGE}" | uniq)
	wget -4 -c http://${MIRROR}/${FOLDER}/${FILE}
	wget -4 -c http://${MIRROR}/${FOLDER}/${FILE}.DIGESTS

	echo "- Vérification de l'archive stage3…"
	try grep "$( sha512sum $FILE )" ${FILE}.DIGESTS

	echo "- Décompression de l'archive stage3…"
	try tar xvjpf stage3-*.tar.bz2 --xattrs --numeric-owner

	cd -

	task_done ${SYSTEM_STAGE3}_SYSTEM_STAGE3 $STEPPATH
else
	task_skip ${SYSTEM_STAGE3}_SYSTEM_STAGE3
fi

echo
echo "Customisation du make.conf…"
if $( task_check ${SYSTEM_MAKECONF}_SYSTEM_MAKECONF $STEPPATH )
then
	try sed -i.bck 's/\(CFLAGS="\)/\1-march=native /' ${ROOTPATH}/etc/portage/make.conf
	try rm ${ROOTPATH}/etc/portage/make.conf.bck

	try sed -i.bck 's/\(USE\)=".*"/\1="smp branding symlink systemd nls unicode unicode3 \\\n     logrotate \\\n     zsh-completion \\\n     vim-syntax \\\n     nls nfs samba \\\n     X xft dri opengl xinerama \\\n     gtk gtk3 libnotify \\\n     cairo pango \\\n     imagemagick gif jpeg png tiff \\\n     truetype \\\n     pulseaudio alsa \\\n     mp3 \\\n     archive \\\n     nsplugin \\\n     subversion git \\\n     ssh \\\n     geoip \\\n     kerberos \\\n     -consolekit \\\n     -gnome -eds -kde -qt4 -qt5 \\\n     -nautilus -gnome-online-accounts"/' ${ROOTPATH}/etc/portage/make.conf
	try rm ${ROOTPATH}/etc/portage/make.conf.bck

	echo '' >> ${ROOTPATH}/etc/portage/make.conf
	echo '# Clavier/Souris' >> ${ROOTPATH}/etc/portage/make.conf
	echo 'INPUT_DEVICES="'${INPUT_DEVICES}'"' >> ${ROOTPATH}/etc/portage/make.conf
	echo '# Carte Vidéo' >> ${ROOTPATH}/etc/portage/make.conf
	echo 'VIDEO_CARDS="'${VIDEO_CARDS}'"' >> ${ROOTPATH}/etc/portage/make.conf

	echo '' >> ${ROOTPATH}/etc/portage/make.conf
	echo '# Priorité de portage' >> ${ROOTPATH}/etc/portage/make.conf
	echo 'PORTAGE_NICENESS=15' >> ${ROOTPATH}/etc/portage/make.conf

	echo '' >> ${ROOTPATH}/etc/portage/make.conf
	echo '# Activer la compilation en parallèle' >> ${ROOTPATH}/etc/portage/make.conf
	NBCPU=$( cat /proc/cpuinfo | grep processor | wc -l )
	echo 'MAKEOPTS="-j'${NBCPU}'-l'${NBCPU}'"' >> ${ROOTPATH}/etc/portage/make.conf

	echo '' >> ${ROOTPATH}/etc/portage/make.conf
	echo '# Activer CCACHE' >> ${ROOTPATH}/etc/portage/make.conf
	echo 'FEATURES="ccache"' >> ${ROOTPATH}/etc/portage/make.conf
	echo 'CCACHE_SIZE="'$CCACHE'"' >> ${ROOTPATH}/etc/portage/make.conf

	echo '' >> ${ROOTPATH}/etc/portage/make.conf
	echo '# Langue des applications' >> ${ROOTPATH}/etc/portage/make.conf
	echo 'LINGUAS="'${LANG}'"' >> ${ROOTPATH}/etc/portage/make.conf
	echo 'L10N="'${LANG}'"' >> ${ROOTPATH}/etc/portage/make.conf

	try mirrorselect -i -o >> ${ROOTPATH}/etc/portage/make.conf

	try mkdir -p ${ROOTPATH}/etc/portage/repos.conf
	try cp ${ROOTPATH}/usr/share/portage/config/repos.conf ${ROOTPATH}/etc/portage/repos.conf/gentoo.conf

	try mkdir -p ${ROOTPATH}/etc/portage/package.use/

	echo '# À investiguer' >> ${ROOTPATH}/etc/portage/package.use/desktop-file-utils
	echo 'dev-util/desktop-file-utils -emacs' >> ${ROOTPATH}/etc/portage/package.use/desktop-file-utils

	echo 'dev-libs/libxml2 python' >> ${ROOTPATH}/etc/portage/package.use/baobab
	echo 'dev-libs/glib dbus' >> ${ROOTPATH}/etc/portage/package.use/baobab

	echo 'dev-libs/libxml2 icu' >> ${ROOTPATH}/etc/portage/package.use/chromium
	echo 'media-libs/libvpx svc' >> ${ROOTPATH}/etc/portage/package.use/chromium
	echo 'sys-libs/zlib minizip' >> ${ROOTPATH}/etc/portage/package.use/chromium
	echo 'media-libs/harfbuzz icu' >> ${ROOTPATH}/etc/portage/package.use/chromium
	echo 'media-libs/libvpx postproc' >> ${ROOTPATH}/etc/portage/package.use/chromium
	echo 'app-text/ghostscript-gpl cups' >> ${ROOTPATH}/etc/portage/package.use/chromium
	echo 'www-client/chromium -gtk3' >> ${ROOTPATH}/etc/portage/package.use/chromium

	echo 'net-misc/iputils -caps -filecaps' >> ${ROOTPATH}/etc/portage/package.use/cifs-utils
	echo 'sys-libs/tevent python' >> ${ROOTPATH}/etc/portage/package.use/cifs-utils
	echo 'sys-libs/ntdb python' >> ${ROOTPATH}/etc/portage/package.use/cifs-utils
	echo 'sys-libs/tdb python' >> ${ROOTPATH}/etc/portage/package.use/cifs-utils

	echo 'net-print/cups -java' >> ${ROOTPATH}/etc/portage/package.use/cups

	echo 'app-editors/emacs -cairo' >> ${ROOTPATH}/etc/portage/package.use/emacs

	echo 'media-libs/imlib2 X' >> ${ROOTPATH}/etc/portage/package.use/feh

	echo 'dev-vcs/subversion -dso perl' >> ${ROOTPATH}/etc/portage/package.use/git

	echo 'x11-misc/ktsuss sudo' >> ${ROOTPATH}/etc/portage/package.use/ktuss

	echo 'net-analyzer/nmap nping' >> ${ROOTPATH}/etc/portage/package.use/nmap

	echo 'net-fs/samba winbind' >> ${ROOTPATH}/etc/portage/package.use/samba

	echo 'app-admin/sudo offensive' >> ${ROOTPATH}/etc/portage/package.use/sudo

	echo 'app-text/xmlto text' >> ${ROOTPATH}/etc/portage/package.use/xmlto

	try mkdir -p ${ROOTPATH}/etc/portage/package.keywords/

	echo 'x11-base/xorg-server ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/xorg-x11
	echo 'x11-base/xorg-drivers ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/xorg-x11
	if [[ $VIRTUALBOX -eq 1 ]]
	then
		echo '- Virtualbox detected'
		echo 'x11-drivers/xf86-video-virtualbox ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/xorg-x11
		echo 'app-emulation/virtualbox-guest-additions ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/xorg-x11
	fi

	echo 'virtual/emacs ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/emacs
	echo 'app-editors/emacs ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/emacs

	echo 'www-client/firefox ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/firefox

	echo 'media-sound/playerctl ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/playerctl

	echo 'app-misc/screenfetch ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/screenfetch

	echo 'dev-vcs/subversion ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/subversion

	echo 'net-analyzer/wireshark ~amd64' >> ${ROOTPATH}/etc/portage/package.keywords/wireshark

	try mkdir -p ${ROOTPATH}/etc/portage/package.license/

	echo 'www-plugins/adobe-flash AdobeFlash-11.x' >> ${ROOTPATH}/etc/portage/package.license/adobe-flash

	task_done ${SYSTEM_MAKECONF}_SYSTEM_MAKECONF $STEPPATH
else
	task_skip ${SYSTEM_MAKECONF}_SYSTEM_MAKECONF
fi

echo
echo "Copie de resolv.conf dans le nouveau système…"
if $( task_check ${SYSTEM_DNS}_SYSTEM_DNS $STEPPATH )
then
	try cp -vL /etc/resolv.conf ${ROOTPATH}/etc/
	task_done ${SYSTEM_DNS}_SYSTEM_DNS $STEPPATH
else
	task_skip ${SYSTEM_DNS}_SYSTEM_DNS
fi

echo
echo "Montage des systèmes de fichier nécessaires…"
if $( task_check ${SYSTEM_MOUNTFORCHROOT}_SYSTEM_MOUNTFORCHROOT $STEPPATH )
then
	try mount -t proc /proc ${ROOTPATH}/proc
	try mount --rbind /sys ${ROOTPATH}/sys
	try mount --make-rslave ${ROOTPATH}/sys
	try mount --rbind /dev ${ROOTPATH}/dev
	try mount --make-rslave ${ROOTPATH}/dev
	task_done ${SYSTEM_MOUNTFORCHROOT}_SYSTEM_MOUNTFORCHROOT $STEPPATH
else
	task_skip ${SYSTEM_MOUNTFORCHROOT}_SYSTEM_MOUNTFORCHROOT
fi

#echo
#echo "Copie des scripts pour la suite…"
#if $( task_check ${SYSTEM_COPYSCRIPTS}_SYSTEM_COPYSCRIPTS $STEPPATH )
#then
#	try mkdir -p ${ROOTPATH}/root/${SCRIPTPATH}/
#	try cp ./init ${ROOTPATH}/root/${SCRIPTPATH}/
#	try cp ./gentoo-prepare-system.sh ${ROOTPATH}/root/${SCRIPTPATH}/
#	try cp ./gentoo-finalize-installation.sh ${ROOTPATH}/root/${SCRIPTPATH}/
#	try cp ./gentoo-finalize-configuration.sh ${ROOTPATH}/root/${SCRIPTPATH}/
#	try cp .toprc ${ROOTPATH}/root/${SCRIPTPATH}/
#
#	try rm -rf ${ROOTPATH}/root/${SCRIPTPATH}/${STEPPATH}/
#	try mkdir -p ${ROOTPATH}/root/${SCRIPTPATH}/${STEPPATH}/
#	try cp ${STEPPATH}/* ${ROOTPATH}/root/${SCRIPTPATH}/${STEPPATH}/
#
#	task_done ${SYSTEM_COPYSCRIPTS}_SYSTEM_COPYSCRIPTS $STEPPATH
#else
#	task_skip ${SYSTEM_COPYSCRIPTS}_SYSTEM_COPYSCRIPTS
#fi

#echo
#echo "Activation de l'amorce pour l'étape chroot…"
#if $( task_check ${SYSTEM_ACTIVATECHROOT}_SYSTEM_ACTIVATECHROOT $STEPPATH )
#then
#	echo '# À supprimer une fois exécuté' >> ${ROOTPATH}/root/.bashrc
#	echo 'cd /root/'${SCRIPTPATH} >> ${ROOTPATH}/root/.bashrc
#	echo './gentoo-prepare-system.sh' >> ${ROOTPATH}/root/.bashrc
#	echo 'exit' >> ${ROOTPATH}/root/.bashrc
#
#	task_done ${SYSTEM_ACTIVATECHROOT}_SYSTEM_ACTIVATECHROOT $STEPPATH
#else
#	task_skip ${SYSTEM_ACTIVATECHROOT}_SYSTEM_ACTIVATECHROOT
#fi
#echo
#echo "Plongée dans le système de fichiers…"
#if $( task_check ${SYSTEM_CHROOT}_SYSTEM_CHROOT $STEPPATH )
#then
#	try chroot $ROOTPATH /bin/bash
#	task_done ${SYSTEM_CHROOT}_SYSTEM_CHROOT $STEPPATH
#else
#	task_skip ${SYSTEM_CHROOT}_SYSTEM_CHROOT
#fi

#echo
#echo "Activation de l'amorce pour la finalisation de l'installation…"
#if $( task_check ${SYSTEM_ACTIVATEFINALINSTALL}_SYSTEM_ACTIVATEFINALINSTALL $STEPPATH )
#then
#	try sed -i.bck '/# À supprimer une fois exécuté/d' ${ROOTPATH}/root/.bashrc
#	try sed -i.bck '/cd \/root\/.*/d' ${ROOTPATH}/root/.bashrc
#	try sed -i.bck '/.\/gentoo-prepare-system.sh/d' ${ROOTPATH}/root/.bashrc
#	try sed -i.bck '/exit/d' ${ROOTPATH}/root/.bashrc
#	try rm ${ROOTPATH}/root/.bashrc.bck
#
#	echo '# À supprimer une fois exécuté' >> ${ROOTPATH}/root/.bash_profile
#	echo 'cd /root/'${SCRIPTPATH} >> ${ROOTPATH}/root/.bash_profile
#	echo 'screen -S FinalizeInstallation ./gentoo-finalize-installation.sh' >> ${ROOTPATH}/root/.bash_profile
#
#	task_done ${SYSTEM_ACTIVATEFINALINSTALL}_SYSTEM_ACTIVATEFINALINSTALL $STEPPATH
#else
#	task_skip ${SYSTEM_ACTIVATEFINALINSTALL}_SYSTEM_ACTIVATEFINALINSTALL
#fi

echo
echo "Récupération des étapes franchies par le chroot…"
if $( task_check ${SYSTEM_GETCHROOTSTEPS}_SYSTEM_GETCHROOTSTEPS $STEPPATH )
then
	try cp ${ROOTPATH}/root/${SCRIPTPATH}/${STEPPATH}/* ${STEPPATH}/

	task_done ${SYSTEM_GETCHROOTSTEPS}_SYSTEM_GETCHROOTSTEPS $STEPPATH
else
	task_skip ${SYSTEM_GETCHROOTSTEPS}_SYSTEM_GETCHROOTSTEPS
fi

echo
echo "Démontage des partitions…"
if $( task_check ${SYSTEM_UMOUNT}_SYSTEM_UMOUNT $STEPPATH )
then
	try umount -l ${ROOTPATH}/dev{/shm,/pts,}
	try umount -R ${ROOTPATH}
	task_done ${SYSTEM_UMOUNT}_SYSTEM_UMOUNT $STEPPATH
else
	task_skip ${SYSTEM_UMOUNT}_SYSTEM_UMOUNT
fi

echo
echo "Tout est fini, le reboot est possible !"

exit 0

