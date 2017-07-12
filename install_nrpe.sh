#!/bin/bash
#
# Copyright (C) 2016 - Dorance Martinez C
# Author: Dorance Martinez C dorancemc@gmail.com
# SPDX-License-Identifier: GPL-3.0+
#
# Descripcion: Script para installar nrpe
# Version: 0.2.1 - 12-jul-2017
# Validado en : Debian >=6, Ubuntu >=16, Centos >=6, openSuSE >=42
#


NRPE_version="3.2.0"
TEMP_PATH="/tmp/nagios_`date +%Y%m%d%H%M%S`"
INSTALL_PATH="/opt/nagios"
NAGIOS_USER="nagios"

linux_variant() {
  if [ -f "/etc/debian_version" ]; then
    if ! command_exists lsb_release ; then
      apt-get install -y lsb-release
    fi
    distro=$(lsb_release -s -i | tr '[:upper:]' '[:lower:]')
    flavour=$(lsb_release -s -c )
    version=$(lsb_release -s -r | cut -d. -f1 )
  elif [ -f "/etc/redhat-release" ]; then
    distro="rh"
    flavour=$(cat /etc/redhat-release | cut -d" " -f1 | tr '[:upper:]' '[:lower:]' )
    version=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1 )
  elif [ -f "/etc/SuSE-release" ]; then
    distro="suse"
    flavour=$(cat /etc/SuSE-release | head -1 | cut -d" " -f1 | tr '[:upper:]' '[:lower:]' )
    version=$(cat /etc/SuSE-release | grep -i version | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1 )
  else
    distro="unknown"
  fi
}

command_exists () {
    type "$1" &> /dev/null ;
}

user_exist() {
  if id "$1" >/dev/null 2>&1; then
    echo "user $1 exists"
  else
    groupadd $1 ; useradd -m -d $2 -g $1 $1
  fi
}

file_exist() {
  if [ -f $1 ]; then
    cp ${1} ${1}-backup_`date +%Y%m%d%H%M%S`
  fi
}

debian() {
  if [ $version -ge 8 ]; then
    INIT_TYPE="systemd"
    CMD_STARTUP="systemctl enable nrpe.service"
  else
    INIT_TYPE="sysv"
    CMD_STARTUP="update-rc.d nrpe defaults"
  fi
  debian_ubuntu_pkgs &&
  return 0
}

raspbian() {
  debian
}

ubuntu() {
  if [ $version -ge 16 ]; then
    INIT_TYPE="systemd"
    CMD_STARTUP="systemctl enable nrpe.service"
  else
    INIT_TYPE="sysv"
    CMD_STARTUP="update-rc.d nrpe defaults"
  fi
  debian_ubuntu_pkgs &&
  return 0
}

debian_ubuntu_pkgs() {
  if [ "$nrpe_install" = "git" ]; then
    if ! command_exists git ; then
      apt-get install -y git
    fi
  fi
  apt-get install -y wget gcc libssl-dev libkrb5-dev make fping &&
  installar_nrpe &&
  return 0
}

rh() {
  if [ $version -ge 7 ]; then
    INIT_TYPE="systemd"
    CMD_STARTUP="systemctl enable nrpe.service"
  else
    INIT_TYPE="sysv"
    CMD_STARTUP="chkconfig nrpe on"
  fi
  if [ "$nrpe_install" = "git" ]; then
    if ! command_exists git ; then
      yum install git -y
    fi
  fi
  yum install -y wget gcc make fping krb5-devel openssl-devel &&
  installar_nrpe &&
  return 0
}

suse() {
  if [ $version -ge 12 ]; then
    INIT_TYPE="systemd"
    CMD_STARTUP="systemctl enable nrpe.service"
  else
    INIT_TYPE="sysv"
    CMD_STARTUP="chkconfig nrpe on"
  fi
  if [ "$nrpe_install" = "git" ]; then
    if ! command_exists git ; then
      zypper --non-interactive install git
    fi
  fi
  zypper --non-interactive install wget gcc make fping krb5-devel libopenssl-devel
  installar_nrpe &&
  return 0
}

unknown() {
  echo "distro no reconocida por este script :( "
  exit 1
}

installar_nrpe() {
  user_exist ${NAGIOS_USER} ${INSTALL_PATH} &&
  file_exist ${INSTALL_PATH}/etc/nrpe.cfg &&
  if [ "$nrpe_install" = "git" ]; then
    git clone https://github.com/NagiosEnterprises/nrpe.git ${TEMP_PATH}/nrpe-${NRPE_version}
  else
    mkdir -p ${TEMP_PATH} &&
    wget https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-${NRPE_version}/nrpe-${NRPE_version}.tar.gz -O ${TEMP_PATH}/nrpe-${NRPE_version}.tar.gz &&
    tar -zxvf ${TEMP_PATH}/nrpe-${NRPE_version}.tar.gz -C ${TEMP_PATH}
  fi
  cd ${TEMP_PATH}/nrpe-${NRPE_version} && ./configure --prefix=${INSTALL_PATH} --enable-ssl --enable-command-args --with-nrpe-user=${NAGIOS_USER} --with-nrpe-group=${NAGIOS_USER} --with-nagios-user=${NAGIOS_USER} --with-nagios-group=${NAGIOS_USER} --with-opsys=linux --with-dist-type=${distro} --with-init-type=${INIT_TYPE} &&
  mkdir -p /opt/nagios && chown -R ${NAGIOS_USER}: ${INSTALL_PATH} &&
  make all && make install && make install-plugin && make install-daemon && make install-config && make install-init &&
  mkdir -p ${INSTALL_PATH}/etc/nrpe/ &&
  echo "include_dir=${INSTALL_PATH}/etc/nrpe" >>${INSTALL_PATH}/etc/nrpe.cfg &&
  $CMD_STARTUP &&
  return 0
}

run_core() {
  linux_variant
  $distro &&
  rm -rf ${TEMP_PATH} &&
  return 0
}

run_core &&
exit 0
