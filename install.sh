#!/bin/bash

#
# Doğukan Öksüz
# https://dogukan.dev
# me@dogukan.dev
#
# Bu script HyperV üzerinde Pardus kullanmak için yazılmıştır.
# https://github.com/mimura1133/linux-vm-tools üzerindeki script Pardus'a uyarlanmıştır.
#

###############################################################################
# Makinemizi en son sürüme yükseltelim.
#

if [ "$(id -u)" -ne 0 ]; then
    echo 'Bu betik sadece root yetkisi ile çalıştırılabilir. sudo ./install.sh şeklinde deneyebilirsiniz.' >&2
    exit 1
fi

apt update && apt upgrade -y

if [ -f /var/run/reboot-required ]; then
    echo "Kuruluma devam edebilmek için sistemi yeniden başlatmanız gereklidir." >&2
    echo "Lütfen yeniden başlatın ve kurulum betiğini yeniden çalıştırın." >&2
    exit 1
fi

###############################################################################
# XRDP
#

# Pardus Hyper-V Daemon paketini kuralım.
apt install -y hyperv-daemons

# XRDP servisini kuralım
apt install -y xrdp

systemctl stop xrdp
systemctl stop xrdp-sesman

# XRP ini dosyalarını düzenleyelim.
# vsock transport kullan.
sed -i_orig -e 's/use_vsock=false/use_vsock=true/g' /etc/xrdp/xrdp.ini
# rdp security kullan.
sed -i_orig -e 's/security_layer=negotiate/security_layer=rdp/g' /etc/xrdp/xrdp.ini
# şifreleme doğrulamasını kaldır.
sed -i_orig -e 's/crypt_level=high/crypt_level=none/g' /etc/xrdp/xrdp.ini
# sıkıştırmayı devre dışı bırak, localde çalışıyoruz.
sed -i_orig -e 's/bitmap_compression=true/bitmap_compression=false/g' /etc/xrdp/xrdp.ini

# Paylaşılan diskleri shared-drives klasörü altına taşıyalım.
sed -i -e 's/FuseMountName=thinclient_drives/FuseMountName=shared-drives/g' /etc/xrdp/sesman.ini

# Giriş yapabilecek kullanıcıları ayarlayalım.
sed -i_orig -e 's/allowed_users=console/allowed_users=anybody/g' /etc/X11/Xwrapper.config

# vmw modülünü devredışı bırakalım.
if [ ! -e /etc/modprobe.d/blacklist_vmw_vsock_vmci_transport.conf ]; then
cat >> /etc/modprobe.d/blacklist_vmw_vsock_vmci_transport.conf <<EOF
blacklist vmw_vsock_vmci_transport
EOF
fi

# hv_sock modülünün yüklendiğinden emin olalım
if [ ! -e /etc/modules-load.d/hv_sock.conf ]; then
echo "hv_sock" > /etc/modules-load.d/hv_sock.conf
fi

# XRDP politikalarını değiştirelim.
cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla <<EOF
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# Servisleri başlatalım
systemctl daemon-reload
systemctl start xrdp

#
# XRDP -- Son
###############################################################################

echo "Kurulum tamamlanmıştır."
echo "Makinenizin çözünürlüğünü arttırmak için bu mesajdan sonra gücü tamamen kapatın."
echo "Ardından PowerShell'i Windows üzerinde yönetici olarak çalıştırın ve aşağıdaki komutu girin."
echo 'Set-VM "(KENDI VM ISMINIZ)" -EnhancedSessionTransportType HVSocket'
echo "https://dogukan.dev"
