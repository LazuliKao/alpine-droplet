#!/bin/sh

# Enable openssh server
rc-update add sshd default

# Copy reserved-ipv6.sh to /usr/local/bin and make it executable
cp reserved-ipv6.sh /usr/local/bin/reserved-ipv6.sh
chmod +x /usr/local/bin/reserved-ipv6.sh

# Create OpenRC service to run reserved-ipv6.sh at every boot
cat > /etc/init.d/reserved-ipv6 <<-EOF
#!/sbin/openrc-run
command="/usr/local/bin/reserved-ipv6.sh"
command_background="no"
depend() {
    need net.eth0
}
EOF

# Make the service executable and enable it
chmod +x /etc/init.d/reserved-ipv6
rc-update add reserved-ipv6 default

# Configure networking
cat > /etc/network/interfaces <<-EOF
iface lo inet loopback
iface eth0 inet dhcp
EOF

ln -s networking /etc/init.d/net.lo
ln -s networking /etc/init.d/net.eth0

rc-update add net.eth0 default
rc-update add net.lo boot

# Create root ssh directory
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Grab config from DigitalOcean metadata service
cat > /bin/do-init <<-EOF
#!/bin/sh
resize2fs /dev/vda
wget -T 5 http://169.254.169.254/metadata/v1/hostname    -q -O /etc/hostname
wget -T 5 http://169.254.169.254/metadata/v1/public-keys -q -O /root/.ssh/authorized_keys
hostname -F /etc/hostname
chmod 600 /root/.ssh/authorized_keys

apk add --no-cache docker
rc-update add docker boot
rc-service docker start

# Install Oh My Zsh for root user
sh -c "$$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set zsh as default shell for root
# chsh -s /bin/zsh root
sed -i 's|/bin/ash|/bin/zsh|' /etc/passwd

rc-update del do-init default
exit 0
EOF

# Create do-init OpenRC service
cat > /etc/init.d/do-init <<-EOF
#!/sbin/openrc-run
depend() {
    need net.eth0
}
command="/bin/do-init"
command_args=""
pidfile="/tmp/do-init.pid"
EOF

# Make do-init and service executable
chmod +x /etc/init.d/do-init
chmod +x /bin/do-init

# Enable do-init service
rc-update add do-init default

# Configure Oh My Zsh
cat > /root/.zshrc <<-EOF
# Path to your oh-my-zsh installation.
export ZSH="/root/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
plugins=(git docker docker-compose)

source \$ZSH/oh-my-zsh.sh

# User configuration
export PATH=\$PATH:/usr/local/bin

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF