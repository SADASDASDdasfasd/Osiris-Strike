#!/bin/bash
set -e

WORKDIR=$(pwd)
CHROOT=$WORKDIR/chroot
IMAGE=$WORKDIR/image

echo "=== Building Osiris-Strike Pentest (Kali-like) ==="

# Bootstrap Ubuntu 24.04
sudo debootstrap --arch=amd64 noble $CHROOT http://archive.ubuntu.com/ubuntu/

sudo mount --bind /dev $CHROOT/dev
sudo mount --bind /run $CHROOT/run

sudo chroot $CHROOT /bin/bash << 'CHROOT_END'
set -e
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

echo "osiris" > /etc/hostname
echo "127.0.1.1 osiris" >> /etc/hosts

cat << EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
EOF

apt update && apt upgrade -y

# Core System + Live + Desktop
apt install -y sudo casper ubiquity ubiquity-casper ubiquity-frontend-gtk linux-generic xfce4 xfce4-goodies network-manager grub-efi-amd64-signed shim-signed

# Pentest Tools
apt install -y nmap metasploit-framework wireshark aircrack-ng sqlmap john hashcat hydra dirb gobuster feroxbuster ffuf neofetch htop terminator git curl vim netcat-traditional

# More tools
apt install -y kali-tools-top10 kali-tools-web kali-tools-wireless || echo "Some Kali repos not added yet"

useradd -m -s /bin/bash osiris
echo "osiris:osiris" | chpasswd
usermod -aG sudo osiris
echo "osiris ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/osiris

cat << EOF > /etc/motd
   _____  _____ _____ _____ ____  _____ 
  |  _  \/  ___/  ___|  ___|  _ \|  __ \\
  | | | |\ `--.| |__ | |__ | |_) | |__) |
  | | | | `--. \  __||  __||  _ <|  ___/ 
  | |/ / /\__/ / |___| |___| |_) | |     
  |___/  \____/\____/\____/|____/|_|     
     Osiris-Strike - Rise from the Ashes
     Pentest Edition
EOF

apt autoremove -y && apt clean
CHROOT_END

# Build image
sudo mkdir -p $IMAGE/casper
sudo cp $CHROOT/boot/vmlinuz-*-generic $IMAGE/casper/vmlinuz || echo "Kernel copy warning"
sudo cp $CHROOT/boot/initrd.img-*-generic $IMAGE/casper/initrd || echo "Initrd copy warning"

sudo mksquashfs $CHROOT $IMAGE/casper/filesystem.squashfs -e boot -e proc -e run -e sys -e tmp -e dev || echo "Squashfs done"

# Simple ISO (note: this may need refinement)
cd $IMAGE
sudo xorriso -as mkisofs -r -V "Osiris-Strike" -J -l -o $WORKDIR/osiris.iso . || echo "ISO created with possible issues"

echo "=== Osiris-Strike built! ==="
ls -lh $WORKDIR/osiris.iso