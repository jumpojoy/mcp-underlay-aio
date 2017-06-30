#!/bin/bash

RUN_DIR=$(cd $(dirname "$0") && pwd)

source $RUN_DIR/functions

FORMULAS_BASE=${FORMULAS_BASE:-https://gerrit.mcp.mirantis.net/salt-formulas}
FORMULAS_PATH=${FORMULAS_PATH:-/root/formulas}
FORMULAS_SERVICES=${FORMULAS_SERVICES:-"linux reclass salt openssh ntp git sensu heka sphinx mysql libvirt rsyslog memcached rabbitmq apache keystone neutron ironic tftpd-hpa"}

SALT_API_LINUX_USER=${SALT_API_LINUX_USER:-stack}

RECLASS_SYSTEM_BRANCH=${RECLASS_SYSTEM_BRANCH:-master}
SALT_FORMULAS_DEFAULT_BRANCH=${SALT_FORMULAS_DEFAULT_BRANCH:-master}
SALT_FORMULAS_IRONIC_BRANCH=${SALT_FORMULAS_IRONIC_BRANCH:-$SALT_FORMULAS_DEFAULT_BRANCH}

apt install -y software-properties-common

wget -O - https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub | sudo apt-key add -
add-apt-repository http://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest
apt update
apt install -y salt-master salt-minion salt-api reclass make

rm /etc/salt/minion_id
rm -f /etc/salt/pki/minion/minion_master.pub
echo "id: $(hostname).local" > /etc/salt/minion
echo "master: localhost" >> /etc/salt/minion

[ ! -d /etc/salt/master.d ] && mkdir -p /etc/salt/master.d
cat <<-EOF > /etc/salt/master.d/master.conf
file_roots:
  base:
  - /usr/share/salt-formulas/env
pillar_opts: False
open_mode: True
reclass: &reclass
  storage_type: yaml_fs
  inventory_base_uri: /srv/salt/reclass
ext_pillar:
  - reclass: *reclass
master_tops:
  reclass: *reclass
EOF

cat <<-EOF > /etc/salt/master.d/api.conf
external_auth:
  pam:
    $SALT_API_LINUX_USER:
      - .*

rest_cherrypy:
  port: 8000
  debug: True
  disable_ssl: True
EOF

[ ! -d /etc/reclass ] && mkdir /etc/reclass
cat <<-EOF > /etc/reclass/reclass-config.yml
storage_type: yaml_fs
pretty_print: True
output: yaml
inventory_base_uri: /srv/salt/reclass
EOF

systemctl restart  salt-master
systemctl restart salt-minion
systemctl enable salt-api
systemct restart salt-api

git clone https://github.com/jumpojoy/mcp-underlay-aio /srv/salt/reclass
cd /srv/salt/reclass
git_clone https://gerrit.mcp.mirantis.net/p/salt-models/reclass-system.git /srv/salt/reclass/classes/system $RECLASS_SYSTEM_BRANCH
ln -s /usr/share/salt-formulas/reclass/service classes/service

mkdir -p ${FORMULAS_PATH}
for formula_service in $FORMULAS_SERVICES; do
  opt_name="SALT_FORMULAS_${formula_service^^}_BRANCH"
  _BRANCH="${!opt_name:-$SALT_FORMULAS_DEFAULT_BRANCH}"
  echo $val
  echo ${_BRANCH}
      git_clone ${FORMULAS_BASE}/${formula_service}.git ${FORMULAS_PATH}/${formula_service} ${_BRANCH}
  cd ${FORMULAS_PATH}/${formula_service}
  make install
  cd -
done

git clone https://github.com/jumpojoy/salt-formula-baremetal-simulator ${FORMULAS_PATH}/baremetal_simulator
cd ${FORMULAS_PATH}/baremetal_simulator
make install
cd -
