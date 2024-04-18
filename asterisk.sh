#!/bin/bash
#
# Asterisk installation script
#
# Author: [Poupix83]
# Version: 1.0.0

warn() {
    echo -e '\e[31m'$1'\e[0m'
}

info() {
    echo -e '\e[36m'$1'\e[0m'
}

# Function to check system privileges
function check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        warn "Ce script doit être exécuté en tant que root" >&2
        exit 1
    else
        info "Privilège Root: OK"
    fi
}

# Function to check package manager
check_package_manager() {
    if command -v apt &>/dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PACKAGE_MANAGER="dnf"
    else
        warn "Neither apt nor dnf found. This script supports only apt and dnf package managers."
        exit 1
    fi
}

# Update package list
update_packages() {
    info "Updating package list..."
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        apt update
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        dnf makecache
    fi
}

# Upgrade installed packages
upgrade_packages() {
    info "Upgrading installed packages..."
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        apt upgrade -y
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        dnf upgrade -y
    fi
}

# SELinux in the permissive mode for RHED
SELinux-permissive_mode() {
    info "Installing required packages..."
    if ["$PACKAGE_MANAGER" == "dnf" ]; then
        setenforce 0
        sed -i 's/\(^SELINUX=\).*/\SELINUX=permissive/' /etc/selinux/config
    fi
}

# Install required system packages for RHED
install_system_packages() {
    info "Installing required packages..."
    if ["$PACKAGE_MANAGER" == "dnf" ]; then
        dnf -y install epel-release
        dnf config-manager --enable crb
    fi
}

# Install required packages
install_packages() {
    info "Installing required packages..."
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        apt install -y curl initscripts
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        dnf group install -y "Development Tools"
        dnf install -y curl chkconfig initscripts git net-tools sqlite-devel psmisc ncurses-devel newt-devel libxml2-devel libtiff-devel
        dnf install -y gtk2-devel libtool libuuid-devel subversion kernel-devel kernel-devel-$(uname -r) crontabs cronie-anacron libedit libedit-devel
    fi
}

# Download and Install Jansson
install_jansson() {
    info "Download and install Jansson..."
    if [ "$PACKAGE_MANAGER" == "dnf" ]; then
        git clone https://github.com/akheron/jansson.git
    fi
    cd jansson/
    # Command to create build source code
    autoreconf -i
    #Compile the package
    ./configure --prefix=/usr/
    #Maintain groups and files
    make
    #Install the package
    make install
}

# Download and Install PJSIP
install_PJSIP() {
    cd ~/
    info "Download and install PJSIP..."
    if [ "$PACKAGE_MANAGER" == "dnf" ]; then
        git clone https://github.com/pjsip/pjproject.git
    fi
    cd pjproject/
    #Compile the package
    ./configure CFLAGS="-DNDEBUG -DPJ_HAS_IPV6=1" --prefix=/usr --libdir=/usr/lib64 --enable-shared --disable-video --disable-sound --disable-opencore-amr
    #Maintain groups and files
    make dep
    make
    #Install the package
    make install
    ldconfig
}

# Test if apparmor active
function is_started() {
    service_name="$1"
    service_status=$(systemctl status "$service_name" | grep "Active: " | awk '{print $2}')
    if [[ $service_status == "active" ]]; then
        info "$service_name started"
        info "apparmor stopped"
        systemctl stop apparmor
    else
        warn "$service_name not started"
    fi
}

# Remove AppArmor package
remove_apparmor() {
    warn "Removing AppArmor package..."
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        apt remove -y apparmor
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        dnf remove -y apparmor
    fi
}

# Download the Asterisk source code
download_asterisk() {
    info "Downloading Asterisk source code..."
    wget -O /tmp http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz
}

# Extract the downloaded file
extract_asterisk() {
    info "Extracting Asterisk source code..."
    tar zxvf /tmp/asterisk-20*.tar.gz -C /usr/src/
    mv asterisk-20* asterisk 
}

# Remove the downloaded tar.gz file
remove_tarball() {
    info "Removing downloaded tar.gz file..."
    rm -rf /tmp/asterisk-20*.tar.gz
}

# Navigate into the extracted Asterisk directory
navigate_to_asterisk_dir() {
    info "Navigating into the extracted Asterisk directory..."
    cd /usr/src/asterisk/
}

# Install prerequisites
install_prerequisites() {
    info "Installing Asterisk prerequisites..."
    contrib/scripts/install_prereq install
}

# Configure Asterisk
configure_asterisk() {
    info "Configuring Asterisk..."
    ./configure --with-jansson-bundled
}
compile_asterisk() {
    info "Compiling Asterisk..."
    ./menuselect/menuselect --enable app_dial --enable app_playback --enable codec_opus --enable format_wav menuselect.makeopts
}
# Install Asterisk
install_asterisk() {
    info "Installing Asterisk..."
    make instal
}

# Install sample configuration files
install_sample_configs() {
    info "Installing sample configuration files..."
    make samples
    mkdir /etc/asterisk/samples
    mv /etc/asterisk/*.* /etc/asterisk/samples/
}

#Make basic-pbx lets you quickly run Asterisk as a simple PBX for testing and experimentation purposes.
install_Make_basic_pbx() {
    echo "Make basic-pbx"
    make basic-pbx
}

# Perform the final configuration
perform_final_config() {
    info "Performing the final configuration..."
    make config
}

# Enable Asterisk to start at boot
enable_asterisk_service() {
    info "Enabling Asterisk to start at boot..."
    systemctl enable asterisk.service
}

# Start the Asterisk service
start_asterisk_service() {
    info "Starting Asterisk service..."
    systemctl start asterisk.service
}

# Check the status of the Asterisk service
check_asterisk_service_status() {
    info "Checking the status of the Asterisk service..."
    systemctl status asterisk.service
}

# Access the Asterisk CLI
access_asterisk_cli() {
    info "Accessing the Asterisk CLI..."
    asterisk -rvvvv
}

# Configuring Asterisk with PJSIP
# Add content to pjsip.conf
add_content_pjsip_conf() {
    echo "Add content to pjsip.conf..."
    cat >>/etc/asterisk/pjsip.conf <<EOL

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[1000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=1000
aors=1000

[1001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=1001
aors=1001

[1000]
type=aor
max_contacts=1
remove_existing=yes

[1001]
type=aor
max_contacts=1
remove_existing=yes

[1000]
type=auth
auth_type=userpass
username=1000
password=1000

[1001]
type=auth
auth_type=userpass
username=1001
password=1001
EOL
}

# Add content to extensions.conf
add_content_extensions_conf() {
    echo "Add to content to extensions.conf..."
    cat >>/etc/asterisk/extensions.conf <<EOL

[from-internal]
exten => 1000,1,Dial(PJSIP/1000)
exten => 1001,1,Dial(PJSIP/1001)
EOL
}

# Clean up
clean() {
    echo "Clean up..."
    make clean
    make distclean
    echo "Asterisk has been successfully installed and configured."
}

# Restart Asterisk and reload configuration...
start_asterisk() {
    echo "Start Asterisk and reload configuration..."
    asterisk -rvvvvvvvvvvvvvvvvvvvv <<<$'core reload\ndialplan reload\nexit\n'
}

clear
check_root
check_package_manager
update_packages
upgrade_packages
SELinux-permissive_mode
install_system_packages
install_packages
install_jansson
install_PJSIP
is_started apparmor
remove_apparmor
download_asterisk
extract_asterisk
remove_tarball
navigate_to_asterisk_dir
install_prerequisites
configure_asterisk
compile_asterisk
install_asterisk
install_sample_configs
install_Make_basic_pbx
perform_final_config
enable_asterisk_service
start_asterisk_service
check_asterisk_service_status
access_asterisk_cli
add_content_pjsip_conf
add_content_extensions_conf
clean
start_asterisk
