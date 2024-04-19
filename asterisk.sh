#!/bin/bash
#
# Asterisk installation script
#
# Author: [Poupix83]
# Version: 1.0.3

warn() {
    echo -e '\e[31m'$1'\e[0m'
}

info() {
    echo -e '\e[36m'$1'\e[0m'
}

# Function to check system privileges
function check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        warn "Ce script doit être exécuté en tant que root" 
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
        warn "Neither apt or dnf found. This script supports only apt and dnf package managers."
        exit 1
    fi
}

# Update package list
update_packages() {
    info "Updating package list..."
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        apt update &>/dev/null;
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        dnf makecache &>/dev/null;
    fi
}

# Upgrade installed packages
upgrade_packages() {
    info "Upgrading installed packages..."
           $PACKAGE_MANAGER upgrade -y &>/dev/null;
}

# SELinux in the permissive mode for RHED
SELinux-permissive_mode() {
    info "Installing required packages..."
    if [ "$PACKAGE_MANAGER" == "dnf" ]; then
        setenforce 0 &>/dev/null;
    fi
}

# Install required system packages for RHED
install_system_packages() {
    info "Installing required packages..."
    if [ "$PACKAGE_MANAGER" == "dnf" ]; then
        dnf -y install epel-release &>/dev/null;
        dnf config-manager --enable crb &>/dev/null;
    fi
}

# Install required packages
install_packages() {
    info "Installing required packages..."
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        $PACKAGE_MANAGER install -y curl initscripts &>/dev/null;
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
       $PACKAGE_MANAGER group install -y "Development Tools" &>/dev/null;
        $PACKAGE_MANAGER install -y curl wget chkconfig initscripts git net-tools sqlite-devel psmisc ncurses-devel newt-devel libxml2-devel libtiff-devel &>/dev/null;
        $PACKAGE_MANAGER install -y gtk2-devel libtool libuuid-devel subversion kernel-devel kernel-devel-$(uname -r) crontabs cronie-anacron libedit libedit-devel &>/dev/null;
    fi
}

# Download and Install Jansson
install_jansson() {
    info "Download and install Jansson..."
    if [ "$PACKAGE_MANAGER" == "dnf" ]; then
        git clone https://github.com/akheron/jansson.git &>/dev/null;
    fi
    cd jansson/
    # Command to create build source code
    autoreconf -i &>/dev/null;
    #Compile the package
    ./configure --prefix=/usr/ &>/dev/null;
    #Maintain groups and files
    make &>/dev/null;
    #Install the package
    make install &>/dev/null;
}

# Download and Install PJSIP
install_PJSIP() {
    cd ~/
    info "Download and install PJSIP..."
    if [ "$PACKAGE_MANAGER" == "dnf" ]; then
        git clone https://github.com/pjsip/pjproject.git &>/dev/null;
    fi
    cd pjproject/
    #Compile the package
    ./configure CFLAGS="-DNDEBUG -DPJ_HAS_IPV6=1" --prefix=/usr --libdir=/usr/lib64 --enable-shared --disable-video --disable-sound --disable-opencore-amr &>/dev/null;
    #Maintain groups and files
    make dep &>/dev/null;
    make &>/dev/null;
    #Install the package
    make install &>/dev/null;
    ldconfig &>/dev/null;
}

# Test if apparmor active
function is_started() {
   if [ -d "/etc/apparmor" ]; then
        info "AppArmor est deja installer." 
        apt -y remove apparmor &>/dev/null;
        rm -rf /etc/apparmor*
    else
        info "AppArmor n'est pas installer."
    fi
}

# Download the Asterisk source code
download_asterisk() {
    info "Downloading Asterisk source code..."
    wget -O /tmp/asterisk-20.tar.gz http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz &>/dev/null;
}

# Extract the downloaded file 
extract_asterisk() {
    info "Extracting Asterisk source code..."
    tar zxvf /tmp/asterisk-20.tar.gz -C /usr/src/ &>/dev/null;
    mv /usr/src/asterisk-20* /usr/src/asterisk &>/dev/null;
}

# Remove the downloaded tar.gz file
remove_tarball() {
    info "Removing downloaded tar.gz file..."
    rm -rf /tmp/asterisk-20*.tar.gz &>/dev/null;
}

# Navigate into the extracted Asterisk directory
navigate_to_asterisk_dir() {
    info "Navigating into the extracted Asterisk directory..."
    cd /usr/src/asterisk/
}

# Install prerequisites
install_prerequisites() {
    info "Installing Asterisk prerequisites..."
    contrib/scripts/install_prereq install &>/dev/null;
}

# Configure Asterisk
configure_asterisk() {
    info "Configuring Asterisk..."
    ./configure --with-jansson-bundled &>/dev/null;
}
compile_asterisk() {
    info "Compiling Asterisk..."
    make menuselect.makeopts &>/dev/null;
    ./menuselect/menuselect --enable app_dial --enable app_playback --enable codec_opus --enable format_wav menuselect.makeopts &>/dev/null;
}
# Install Asterisk
install_asterisk() {
    info "Installing Asterisk..."
    make install &>/dev/null;
}

# Install sample configuration files
install_sample_configs() {
    info "Installing sample configuration files..."
    make samples &>/dev/null;
    mkdir /etc/asterisk/samples &>/dev/null;
    mv -rf /etc/asterisk/*.* /etc/asterisk/samples/ &>/dev/null;
}

#Make basic-pbx lets you quickly run Asterisk as a simple PBX for testing and experimentation purposes.
install_Make_basic_pbx() {
    echo "Make basic-pbx"
    make basic-pbx &>/dev/null;
}

# Perform the final configuration
perform_final_config() {
    info "Performing the final configuration..."
    make config &>/dev/null;
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
    asterisk -rvvv <<<$'exit\n'
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
    make clean &>/dev/null;
    make distclean &>/dev/null;
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
    info "Time to update and upgrade packages:$SECONDS"
    SELinux-permissive_mode
    install_system_packages
    info "Time to install system packages:$SECONDS"
    install_packages
    info "Time to install packages:$SECONDS"
    install_jansson
    info "Time to install Jansson:$SECONDS"
    install_PJSIP
    info "Time to install PJSIP:$SECONDS"
    is_started apparmor
    download_asterisk
    extract_asterisk
    remove_tarball
    navigate_to_asterisk_dir
    install_prerequisites
    info "Time to install prerequisites:$SECONDS"
    configure_asterisk
    info "Time to configure Asterisk:$SECONDS"
    compile_asterisk
    info "Time to compile Asterisk:$SECONDS"
    install_asterisk
    info "Time to install Asterisk:$SECONDS"
    install_sample_configs
    info "Time to install sample configs:$SECONDS"
    install_Make_basic_pbx
    info "Time to install Make basic-pbx:$SECONDS"
    perform_final_config
    info "Time to perform final config:$SECONDS"
    enable_asterisk_service
    start_asterisk_service
    check_asterisk_service_status
    access_asterisk_cli
    add_content_pjsip_conf
    add_content_extensions_conf
    clean
    info "Time to clean:$SECONDS"
    start_asterisk
    info "Final time:$SECONDS"
