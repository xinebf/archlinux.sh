#!/bin/bash
# ZHANG XINZENG
# 2019-05-13
# VM BIOS UEFI
# BIOS: mbr /dev/sda1 bootable 'Linux filesystem'
# UEFI: gpt /dev/sda1 256M 'EFI System'; /dev/sda2 'Linux filesystem'

timedatectl set-ntp true
# timedatectl set-time "2019-05-07 19:19:19"
echo ":: Arch boot process? 1) Syslinux[BIOS]  2) EFISTUB[UEFI]  3) systemd-boot[UEFI]"
read -p "Enter a number (default=3): " arch_boot
arch_boot=${arch_boot:-3}
if [[ "${arch_boot}" == "1" ]]; then
    # cfdisk /dev/sda
    echo -e "o\nn\np\n1\n\n\na\nw" | fdisk /dev/sda
    mkfs.ext4 -L root /dev/sda1
    mount /dev/sda1 /mnt
elif [[ "${arch_boot}" == "2" || "${arch_boot}" == "3" ]]; then
    # cfdisk /dev/sda
    echo -e "g\nn\n1\n\n+256M\nt\n1\nn\n2\n\n\nw" | fdisk /dev/sda
    mkfs.fat -F32 /dev/sda1
    mkfs.ext4 -L root /dev/sda2
    mount /dev/sda2 /mnt
    mkdir /mnt/boot
    mount /dev/sda1 /mnt/boot
    part_uuid=$(blkid -s PARTUUID -o value /dev/sda2)
    # "root=PARTUUID=${part_uuid}" can be replaced with "root=/dev/sda2"
    # -u "root=/dev/sda2 rw initrd=\\initramfs-linux.img"
    # options        root=/dev/sda2 rw
fi
sed -i "s/^Server/#Server/g" /etc/pacman.d/mirrorlist
sed -i "7i Server = https://mirrors.xtom.com/archlinux/\$repo/os/\$arch" /etc/pacman.d/mirrorlist
pacstrap /mnt base base-devel
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
cat << EOF > /mnt/root/archlinux.sh
#!/bin/bash

if [[ "\${1}" == "1" ]]; then
    # pacman -S --noconfirm grub
    # grub-install --target=i386-pc /dev/sda
    # grub-mkconfig -o /boot/grub/grub.cfg
    pacman -S --noconfirm syslinux
    syslinux-install_update -i -a -m
    sed -i "s/sda[0-9]/sda1/g" /boot/syslinux/syslinux.cfg
elif [[ "\${1}" == "2" ]]; then
    pacman -S --noconfirm efibootmgr
    efibootmgr -d /dev/sda -p 1 -c -L "Arch Linux" -l /vmlinuz-linux -u "root=PARTUUID=${part_uuid} rw initrd=\\initramfs-linux.img"
elif [[ "\${1}" == "3" ]]; then
    bootctl --path=/boot install
    cat << BOOTEOF > /boot/loader/entries/arch.conf
title          Arch Linux
linux          /vmlinuz-linux
initrd         /initramfs-linux.img
options        root=PARTUUID=${part_uuid} rw
BOOTEOF
fi
read -p "Enter Password of root (default=archlinux): " root_passwd
root_passwd=\${root_passwd:-archlinux}
echo -e "\${root_passwd}\n\${root_passwd}" | passwd
read -p "Name of new user: (default=meow): " user_name
user_name=\${user_name:-meow}
useradd -m -s /bin/bash \${user_name}
read -p "Enter Password of \${user_name} (default=archlinux): " user_passwd
user_passwd=\${user_passwd:-archlinux}
echo -e "\${user_passwd}\n\${user_passwd}" | passwd \${user_name}
pacman -S --noconfirm openssh
mkdir /home/\${user_name}/.ssh
echo "ssh-ed25519 *** xinebf" >> /home/\${user_name}/.ssh/authorized_keys
chown -R \${user_name}:\${user_name} /home/\${user_name}/.ssh/
cat << BASHEOF >> /home/\${user_name}/.bashrc
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
BASHEOF
systemctl enable dhcpcd
systemctl enable sshd
ln -sf /usr/share/zoneinfo/Asia/Taipei /etc/localtime
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
echo "zh_TW.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
hwclock --systohc
echo ArchLinux > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 ArchLinux.localdomain  ArchLinux" >> /etc/hosts
cat /etc/hostname
echo "\${user_name} ALL=(ALL) ALL" >> /etc/sudoers
echo "\${user_name} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
tail -n 2 /etc/sudoers
sed -i "s/^#Color/Color/g" /etc/pacman.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.d/99-bbr.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-bbr.conf
EOF
chmod +x /mnt/root/archlinux.sh
arch-chroot /mnt /root/archlinux.sh ${arch_boot}
rm -rf /mnt/root/archlinux.sh

umount -R /mnt
echo -e "-_-:\033[32m Done \033[0m"
