#!/bin/bash

RUN_DIR=$(cd $(dirname "$0") && pwd)

FORMULAS_BASE=https://gerrit.mcp.mirantis.net/salt-formulas
FORMULAS_PATH=/root/formulas

./$RUN_DIR/salt-master-install.sh

DOMAIN=local
HOSTNAME=$(hostname)
MY_IP=$(ip route get 4.2.2.1 | awk '/via/ {print $7}')

cp /srv/salt/reclass/nodes/foundation-example.yml /srv/salt/reclass/nodes/$HOSTNAME.$DOMAIN.yml
sed -i s/#MY_HOSTNAME/$HOSTNAME/ /srv/salt/reclass/nodes/$HOSTNAME.$DOMAIN.yml
sed -i s/#MY_DOMAIN/$DOMAIN/ /srv/salt/reclass/nodes/$HOSTNAME.$DOMAIN.yml
sed -i s/#MY_IP/$MY_IP/ /srv/salt/reclass/nodes/$HOSTNAME.$DOMAIN.yml
sed -i s/#MY_PXE_INTERFACE/$MY_PXE_INTERFACE/ /srv/salt/reclass/nodes/$HOSTNAME.$DOMAIN.yml

salt-call saltutil.sync_all
salt-call saltutil.refresh_pillar
