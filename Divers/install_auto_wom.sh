#!/bin/bash
set -e

#######################
# CONFIG #
#######################
LAN_IF="enx00051bb1d216"
WAN_IF="eth0"
VPN_IF="tun0"
VPN_CLIENT_NAME="config_openvpn_routed_zabuza"
OPENVPN_CONF_DIR="/etc/openvpn/client"
VPN_USER="zabuza"
VPN_PASS="AzertyZabuza"
WEBMIN_PORT=10000
MOTIONEYE_PORT=8765
SSHD_CONFIG="/etc/ssh/sshd_config"

### Réseau / IP
VPN_CLIENT_IP="192.168.27.67"   # IP LOCALE du client VPN (tun0)
LAN_BASE_IP="192.168.101."
LAN_NET="$LAN_BASE_IP""0/24"
CAM_START=101
CAM_COUNT=6

FFMPEG_SRC_DIR="$HOME/ffmpeg_sources"

###################################
# DEFINITIONS DE FONCTIONS UTILES #
###################################
install_if_missing() {
    dpkg -s "$1" &>/dev/null || apt install -y "$1"
}

start_service_if_stopped() {
    systemctl is-active --quiet "$1" || systemctl start "$1"
}

enable_service() {
    systemctl enable "$1"
}

#################
# SYNCHRO DATE  #
#################
echo "=== Configuration NTP et Timezone ==="
install_if_missing systemd-timesyncd
systemctl restart systemd-timesyncd
timedatectl set-ntp true
timedatectl set-timezone Europe/Paris

#######################
# INSTALLATION WEBMIN #
#######################
if ! command -v webmin &>/dev/null; then
    echo "=== Installation Webmin ==="
    rm -f /etc/apt/sources.list.d/webmin.list
    curl -o webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
    sh webmin-setup-repo.sh
    apt-get install webmin --install-recommends -y
fi
start_service_if_stopped webmin
enable_service webmin

##########################
# INSTALLATION MOTIONEYE #
##########################
if [ ! -d "$HOME/motioneye" ]; then
    echo "=== Installation MotionEye ==="
    install_if_missing python3-virtualenv
    virtualenv -p /usr/bin/python3 motioneye
    source motioneye/bin/activate
    pip install --upgrade pip
    pip install motioneye
    motioneye_init
fi
start_service_if_stopped motioneye
enable_service motioneye

########################
# INSTALLATION OPENVPN #
########################
install_if_missing openvpn iptables iptables-persistent netfilter-persistent

if [ -f /etc/openvpn/server/server.conf ]; then
    mv /etc/openvpn/server/server.conf /etc/openvpn/server/server.conf.disabled
    systemctl stop openvpn@server
    systemctl disable openvpn@server
fi

mkdir -p "$OPENVPN_CONF_DIR"
AUTH_FILE="$OPENVPN_CONF_DIR/$VPN_CLIENT_NAME.auth"
echo -e "$VPN_USER\n$VPN_PASS" > "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
sed -i \
  -e "s|^[[:space:]]*auth-user-pass\(.*\)$|auth-user-pass $AUTH_FILE|" \
  -e "s/\<interact\>/nointeract/" \
  "$OPENVPN_CONF_DIR/$VPN_CLIENT_NAME.conf"

systemctl enable --now openvpn-client@"$VPN_CLIENT_NAME"

echo "=== Attente de l'interface VPN $VPN_IF ==="
until ip link show "$VPN_IF" &>/dev/null; do sleep 1; done
echo "$VPN_IF détecté"

################
# ROUTAGE IP   #
################
sysctl -w net.ipv4.ip_forward=1
grep -qxF "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

#######################
# CONFIG IPTABLES     #
#######################
# RESET IPTABLES
iptables -F
iptables -t nat -F
iptables -X
# PAR DEFAUT
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

#######################
# PORTS LAN / WAN
#######################
LAN_PORT_BASIC=9000
LAN_PORT_RTMP=1935
LAN_PORT_HTTP=80
LAN_PORT_HTTPS=443
LAN_PORT_RTSP=554
LAN_PORT_ONVIF=8000

WAN_PORT_BASIC=9001
WAN_PORT_RTMP=1931
WAN_PORT_HTTP=81
WAN_PORT_HTTPS=1443
WAN_PORT_RTSP=551
WAN_PORT_ONVIF=8001

for ((i=0; i<CAM_COUNT; i++)); do
    CAM_IP="${LAN_BASE_IP}$((CAM_START + i))"
    iptables -t nat -A PREROUTING -i tun0 -m addrtype --dst-type LOCAL -p tcp --dport $((WAN_PORT_BASIC + i)) -j DNAT --to "${CAM_IP}:${LAN_PORT_BASIC}"
    iptables -t nat -A PREROUTING -i tun0 -m addrtype --dst-type LOCAL -p tcp --dport $((WAN_PORT_RTMP + i)) -j DNAT --to "${CAM_IP}:${LAN_PORT_RTMP}"
    iptables -t nat -A PREROUTING -i tun0 -m addrtype --dst-type LOCAL -p tcp --dport $((WAN_PORT_HTTP + i)) -j DNAT --to "${CAM_IP}:${LAN_PORT_HTTP}"
    iptables -t nat -A PREROUTING -i tun0 -m addrtype --dst-type LOCAL -p tcp --dport $(((i+1)*1000 + 443)) -j DNAT --to "${CAM_IP}:${LAN_PORT_HTTPS}"
    iptables -t nat -A PREROUTING -i tun0 -m addrtype --dst-type LOCAL -p tcp --dport $((WAN_PORT_RTSP + i)) -j DNAT --to "${CAM_IP}:${LAN_PORT_RTSP}"
    iptables -t nat -A PREROUTING -i tun0 -m addrtype --dst-type LOCAL -p tcp --dport $((WAN_PORT_ONVIF + i)) -j DNAT --to "${CAM_IP}:${LAN_PORT_ONVIF}"
done

#######################
# FORWARD (VIDÉO SAFE)
#######################
# Autoriser les flux déjà établis / retours
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# VPN -> LAN (accès aux caméras via DNAT)
iptables -A FORWARD -i "$VPN_IF" -o "$LAN_IF" -j ACCEPT
# LAN -> VPN (retours uniquement, pas d'initiation depuis le LAN)
iptables -A FORWARD -i "$LAN_IF" -o "$VPN_IF" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Optionnel : bloquer toute sortie LAN directe vers le WAN
iptables -A FORWARD -i "$LAN_IF" -o "$WAN_IF" -j DROP

#######################
# NAT (SNAT VPN -> LAN)
#######################
# Masquerade du réseau VPN vers le LAN (OBLIGATOIRE pour le DNAT)
iptables -t nat -A POSTROUTING -s 192.168.27.0/24 -o "$LAN_IF" -j MASQUERADE

#######################
# PROFIL CONNTRACK OPTIMISÉ POUR RTSP/RTMP/ONVIF
#######################
# Taille maximale table conntrack
sysctl -w net.netfilter.nf_conntrack_max=262144

# Timeout TCP long pour flux vidéo
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=7200
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_close_wait=60

# Timeout UDP pour flux RTSP/RTP
sysctl -w net.netfilter.nf_conntrack_udp_timeout=30
sysctl -w net.netfilter.nf_conntrack_udp_timeout_stream=180

# Désactiver les helpers automatiques (souvent problématiques pour CCTV)
sysctl -w net.netfilter.nf_conntrack_helper=0

# Rendre permanent
grep -qxF "net.netfilter.nf_conntrack_max=262144" /etc/sysctl.conf || echo "net.netfilter.nf_conntrack_max=262144" >> /etc/sysctl.conf
grep -qxF "net.netfilter.nf_conntrack_tcp_timeout_established=7200" /etc/sysctl.conf || echo "net.netfilter.nf_conntrack_tcp_timeout_established=7200" >> /etc/sysctl.conf
grep -qxF "net.netfilter.nf_conntrack_tcp_timeout_close_wait=60" /etc/sysctl.conf || echo "net.netfilter.nf_conntrack_tcp_timeout_close_wait=60" >> /etc/sysctl.conf
grep -qxF "net.netfilter.nf_conntrack_udp_timeout=30" /etc/sysctl.conf || echo "net.netfilter.nf_conntrack_udp_timeout=30" >> /etc/sysctl.conf
grep -qxF "net.netfilter.nf_conntrack_udp_timeout_stream=180" /etc/sysctl.conf || echo "net.netfilter.nf_conntrack_udp_timeout_stream=180" >> /etc/sysctl.conf
grep -qxF "net.netfilter.nf_conntrack_helper=0" /etc/sysctl.conf || echo "net.netfilter.nf_conntrack_helper=0" >> /etc/sysctl.conf
sysctl -p

#######################
# SAUVEGARDE
#######################
netfilter-persistent save

#######################
# INSTALL FFMPEG X265 #
#######################
echo "=== Installation des dépendances pour compilation ffmpeg ==="
grep -Eq "^[^#]*\bnon-free\b" /etc/apt/sources.list || \
echo "deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware" >> /etc/apt/sources.list
apt update
apt install -y autoconf automake build-essential cmake git-core libass-dev libfreetype6-dev \
libgnutls28-dev libsdl2-dev libtool libva-dev libvdpau-dev libvorbis-dev libxcb1-dev \
libxcb-shm0-dev libxcb-xfixes0-dev pkg-config texinfo wget yasm zlib1g-dev libx264-dev \
libnuma-dev libvpx-dev libfdk-aac-dev libmp3lame-dev

FFMPEG_SRC_DIR="${FFMPEG_SRC_DIR:-/usr/local/src/ffmpeg_build}"
mkdir -p "$FFMPEG_SRC_DIR"
cd "$FFMPEG_SRC_DIR"

# Fonction pour compiler libx265
compile_x265() {
    if ! pkg-config --exists x265; then
        echo "=== Compilation libx265 ==="
        if [ ! -d "$FFMPEG_SRC_DIR/x265" ]; then
            git clone https://bitbucket.org/multicoreware/x265_git x265
        fi
        cd x265/build/linux
        cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=/usr/local -DENABLE_SHARED=ON ../../source
        make -j$(nproc)
        make install
        cd "$FFMPEG_SRC_DIR"
    else
        echo "libx265 déjà installée, compilation ignorée."
    fi
}

# Fonction pour compiler FFmpeg
compile_ffmpeg() {
    if [ ! -d "$FFMPEG_SRC_DIR/ffmpeg" ]; then
        echo "=== Compilation FFmpeg ==="
        git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
    fi

    cd "$FFMPEG_SRC_DIR/ffmpeg"

    # Configure FFmpeg avec les libs communes
    ./configure --prefix=/usr/local --pkg-config-flags="--static" \
        --extra-cflags="-I/usr/local/include" \
        --extra-ldflags="-L/usr/local/lib" \
        --extra-libs="-lpthread -lm" \
        --bindir=/usr/local/bin \
        --enable-gpl --enable-nonfree \
        --enable-libx265 --enable-libx264 \
        --enable-libfdk-aac --enable-libmp3lame \
        --enable-libvorbis --enable-libvpx

    make -j$(nproc)
    make install
    hash -r
}

# Exécution
compile_x265
compile_ffmpeg

##################################
# AUTOREMEDIATION SYSTEMD TIMERS #
##################################
echo "=== Création services et timers systemd pour autoremediation ==="

create_timer() {
SERVICE=$1
TIMER_NAME="${SERVICE}-autoremediation"
SERVICE_FILE="/etc/systemd/system/${SERVICE}-autoremediation.service"
TIMER_FILE="/etc/systemd/system/${SERVICE}-autoremediation.timer"

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Auto-restart $SERVICE if inactive
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'systemctl is-active --quiet $SERVICE || systemctl start $SERVICE'
EOF

cat <<EOF > "$TIMER_FILE"
[Unit]
Description=Run autoremediation for $SERVICE every 30 minutes
[Timer]
OnBootSec=1min
OnUnitActiveSec=30min
Persistent=true
[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now "${TIMER_NAME}.timer"
}

create_timer "openvpn-client@$VPN_CLIENT_NAME"
create_timer "webmin"
create_timer "motioneye"

##################################
# RESTORATION DE CONFIG SSH      #
##################################
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"

if ! grep -q "^AllowUsers.*\bjaffar\b" "$SSHD_CONFIG"; then
    echo "AllowUsers jaffar" >> "$SSHD_CONFIG"
fi

if systemctl is-active --quiet sshd; then
    systemctl restart sshd
else
    service ssh restart
fi

echo "=== Services et ffmpeg avec libx265 configurés. Autoremediation via systemd timers toutes les 30 min ==="
