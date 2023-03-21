#!/bin/bash

c_error="\e[31m[Fatal]: \e[37m"
c_info="\e[32m[Info]: \e[37m"
c_warn="\e[33m[Warning]: \e[37m"

a_installing_supported_kernel="BBR is not found in the current kernel, but since we should be able to update the kernel of this system, we will be installing a new kernel to replace the current one to enable BBR."
e_not_root="This script must be run as root"
e_no_kernel_mod_available="BBR is not available in the kernel and we cannot change the kernel, please install a supported kernel manually."
v_kern_change_available="We should be able to change the kernel if needed!"
v_container_optimizations_not_available="We have found container-based virtualization, and we cannot apply any optimizations to the system."
t_bbr_deployed="BBR is already deployed."
t_bbr_not_deployed="BBR is not deployed"
t_adjusting_tcp_parameters="Tuning TCP parameters"
t_tcp_parameters_adjusted="Tuning complete"
t_reboot_required="We have installed the new kernel. However, you must reboot your system and rerun this script for the changes to take effect."
k_bbr_available="BBR is available in the kernel, switching to BBR as congestion control"
k_bbr_not_available="BBR is not available in the kernel."
w_do_not_interupt="Installing a new kernel while removing the old kernel. Do not exit the script from this point, or you may end up with a broken system."
INFO() {
    echo -e ${c_info}"$*"
}
WARN() {
    echo -e ${c_warn}"$*"
}
ERROR() {
    echo -e ${c_error}"$*"
}

arch_detect(){
    #detects the architecture of the system
    case "$(uname -m)" in
        x86_64)
            arch="amd64"
            ;;
        i[3456]86)
            arch="i386"
            ;;
        armv6l|armv7l)
            arch="armhf"
            ;;
        aarch64)
            arch="arm64"
            ;;
        *)
            ERROR "Unsupported architecture"
            exit 1
            ;;
    esac

}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        ERROR $e_not_root
        exit 1
    fi
}
check_virt(){
  kernel_mod_available=true
  case $(systemd-detect-virt) in
    "kvm")
        INFO $v_kern_change_available
        ;;
    "lxc")
        WARN $v_container_optimizations_not_available
        kernel_mod_available=false
        exit 1
        ;;
    "openvz")
        WARN $v_container_optimizations_not_available
        kernel_mod_available=false
        exit 1
        ;;
  esac
}
check_kern_ability(){
    #checks if the kernel supports or should support BBR
    sysctl net.ipv4.tcp_available_congestion_control | grep bbr > /dev/null
    if [ $? -eq 0 ]; then
        INFO $k_bbr_available
        bbr_available=true
    else
        INFO $k_bbr_not_available
        bbr_available=false
        kernel_mod_required=true
    fi
}
enable_bbr(){
    echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf
    echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf
    sysctl -p
    INFO "BBR should now be enabled"
}
remove_old_kernel(){
    #removes old kernels
    #dpkg -l | grep linux-headers | awk '{print $2}' | grep $(uname -r) | xargs sudo apt-get purge
    #fuck this, let's just brute force and remove linux kernels matched by uname -r using rm
    rm -rf /boot/*$(uname -r)*
}

update_grub(){
    #updates grub to use the new kernel
    update-grub
}

install_supported_kernel(){
    WARN $w_do_not_interupt
    apt install grub -y
    arch_detect
    echo "deb http://deb.debian.org/debian buster-backports main" >> /etc/apt/sources.list

    # Update package list
    apt-get update

    # Install the latest kernel for 64-bit systems
    apt-get -t buster-backports install linux-headers-6.0.0-0.deb11.6-${arch} -y
    apt-get -t buster-backports install linux-image-6.0.0-0.deb11.6-${arch} -y

    remove_old_kernel
    update_grub
}

bbr(){
    bbr_available=false
    bbr_deployed=false
    kernel_mod_required=false
    if lsmod | grep -q bbr; then
        INFO $t_bbr_deployed
        bbr_available=true
        bbr_deployed=true
        kernel_mod_required=false
    else
        WARN $t_bbr_not_deployed
        bbr_deployed=false
        check_kern_ability
        if [[ $bbr_available = true ]]; then
            enable_bbr
        elif [[ ($kernel_mod_required = true) && ($kernel_mod_available = true)]]; then
            INFO  $a_installing_supported_kernel
            install_supported_kernel
            enable_bbr
            INFO $t_reboot_required
        elif [[ ($kernel_mod_required = true) && ($kernel_mod_available = false)]]; then
            ERROR $e_no_kernel_mod_available
        fi
    fi
}

apply_tcp_tweaks(){
    # tweaks the system tcp stack for larger buffer sizes
    # adjust buffers
    INFO $t_adjusting_tcp_parameters
    tcp_parameters=(
    "net.core.rmem_max=16777216"
    "net.core.wmem_max=16777216"
    "net.ipv4.tcp_rmem=4096 87380 16777216"
    "net.ipv4.tcp_wmem=4096 87380 16777216"
    "net.ipv4.tcp_window_scaling=1"
    "net.ipv4.tcp_mtu_probing=1"
    "net.core.netdev_max_backlog=250000"
    "net.core.somaxconn=65535"
    "net.ipv4.tcp_timestamps=1"
    "net.ipv4.tcp_sack=1"
    )

    for command in "${tcp_parameters[@]}"; do
    sysctl -w "$command"
    done
    sysctl -p
    INFO $t_tcp_parameters_adjusted



}

title() {
	echo '=================================='
    echo '     _                       _   '
    echo '  __| | __ _ _   _  ___ __ _| |_ '
	echo ' / _` |/ _` | | | |/ __/ _` | __|'
	echo '| (_| | (_| | |_| | (_| (_| | |_ '
	echo ' \__,_|\__,_|\__, |\___\__,_|\__|'
	echo '             |___/               '
    echo '=================================='
    echo "© daycat 2023 | MIT"
    check_root
    check_virt
    bbr
    apply_tcp_tweaks
}

title