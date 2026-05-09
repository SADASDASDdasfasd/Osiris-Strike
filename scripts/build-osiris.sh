#!/bin/bash
set -e

WORKDIR=$(pwd)
CHROOT=$WORKDIR/chroot
IMAGE=$WORKDIR/image

echo "=== Building Osiris-Strike Pentest (Kali-like) ==="

# Bootstrap
sudo debootstrap --arch=amd64 noble $CHROOT http://archive.ubuntu.com/ubuntu/

sudo mount --bind /dev $CHROOT/dev
sudo mount --bind /run $CHROOT/run

sudo chroot $CHROOT /bin/bash << 'CHROOT_END'
set -e
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

export DEBIAN_FRONTEND=noninteractive

echo "osiris" > /etc/hostname
echo "127.0.1.1 osiris" >> /etc/hosts

cat << EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
EOF

apt update && apt upgrade -y

# Core + Desktop + Live
apt install -y sudo casper ubiquity ubiquity-casper ubiquity-frontend-gtk linux-generic xfce4 xfce4-goodies network-manager grub-common grub-efi-amd64-signed shim-signed

# Pentest Tools
apt install -y nmap metasploit-framework wireshark aircrack-ng sqlmap john hashcat hydra dirb gobuster feroxbuster ffuf netcat-traditional socat neofetch htop terminator git curl vim

# User
useradd -m -s /bin/bash osiris
echo "osiris:osiris" | chpasswd
usermod -aG sudo osiris
echo "osiris ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/osiris

# MOTD
cat << EOF > /etc/motd
   _____  _____ _____ _____ ____  _____ 
  |  _  \/  ___/  ___|  ___|  _ \|  __ \
  | | | |\ `--.| |__ | |__ | |_) | |__) |
  | | | | `--. \  __||  __||  _ <|  ___/ 
  | |/ / /\__/ / |___| |___| |_) | |     
  |___/  \____/\____/\____/|____/|_|     
     Osiris-Strike - Rise from the Ashes
          Pentest Edition
EOF

apt autoremove -y && apt clean
CHROOT_END

# Prepare image
sudo mkdir -p $IMAGE/{casper,boot/grub}

# Kernel
sudo cp $CHROOT/boot/vmlinuz-*-generic $IMAGE/casper/vmlinuz || true
sudo cp $CHROOT/boot/initrd.img-*-generic $IMAGE/casper/initrd || true

# Squashfs
echo "Creating squashfs..."
sudo mksquashfs $CHROOT $IMAGE/casper/filesystem.squashfs -e boot -e proc -e run -e sys -e tmp -e dev -comp xz || true

# GRUB config
cat << 'EOF' > $IMAGE/boot/grub/grub.cfg
set default="0"
set timeout=5

menuentry "Osiris-Strike Live (Try)" {
    linux /casper/vmlinuz boot=casper quiet splash
    initrd /casper/initrd
}

menuentry "Install Osiris-Strike" {
    linux /casper/vmlinuz boot=casper only-ubiquity quiet splash
    initrd /casper/initrd
}
EOF

# Create ISO
cd $IMAGE
sudo xorriso -as mkisofs -r -V "Osiris-Strike" -J -l \
    -boot-info-table -b boot/grub/i386-pc/eltorito.img \
    -c boot/boot.cat --boot-load-size 4 \
    -eltorito-alt-boot -e EFI/BOOT/bootx64.efi -no-emul-boot \
    -o $WORKDIR/osiris.iso .

echo "=== Osiris-Strike ISO build completed! ==="
ls -lh $WORKDIR/osiris.iso || echo "Check if ISO was created"