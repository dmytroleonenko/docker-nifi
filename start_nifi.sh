#!/bin/sh

set -e

#variable defaults
S2S_PORT=${S2S_PORT:-2881}
NIFI_HOME=${NIFI_HOME:-/opt/nifi}
ZK_CLIENT_PORT=${ZK_CLIENT_PORT:-2181}
NODE_PROTOCOL_PORT=${NODE_PROTOCOL_PORT:-10201}
ZK_MONITOR_PORT=${ZK_MONITOR_PORT:-2888}
ZK_ELECTION_PORT=${ZK_ELECTION_PORT:-3888}
ZK_ROOT_NODE=${ZK_ROOT_NODE:-nifi}
SECURE=false;
[ -n "$IS_SECURE"] && SECURE=true
[ -z "$NODES_LIST" ] && ZK_MYID=1


do_site2site_configure() {
  sed -i "s/nifi\.remote\.input\.host=.*/nifi.remote.input.host=${HOSTNAME}${DOMAINPART}/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.remote\.input\.socket\.port=.*/nifi.remote.input.socket.port=${S2S_PORT}/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.remote\.input\.secure=true/nifi.remote.input.secure=$SECURE/g" ${NIFI_HOME}/conf/nifi.properties
}


do_cluster_node_configure() {
# NiFi properties
  sed -i "s/nifi\.web\.http\.host=.*/nifi.web.http.host=${HOSTNAME}${DOMAINPART}/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.cluster\.protocol\.is\.secure=.*/nifi.cluster.protocol.is.secure=$SECURE/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.cluster\.is\.node=false/nifi.cluster.is.node=true/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.cluster\.node\.address=.*/nifi.cluster.node.address=${HOSTNAME}${DOMAINPART}/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.cluster\.node\.protocol\.port=.*/nifi.cluster.node.protocol.port=${NODE_PROTOCOL_PORT}/g" ${NIFI_HOME}/conf/nifi.properties

  sed -i "s/nifi\.variable\.registry\.properties\=.*/nifi.variable.registry.properties=./conf/environment_properties/nifi_custom.properties/g" ${NIFI_HOME}/conf/nifi.properties

  sed -i "s%nifi\.zookeeper\.connect\.string=.*%nifi.zookeeper.connect.string=${NODES_LIST}%g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s@nifi\.zookeeper\.root\.node=.*@nifi.zookeeper.root.node=${ZK_ROOT_NODE}@g" ${NIFI_HOME}/conf/nifi.properties
# State management
  sed -i "s/<property name=\"Connect String\">.*</<property name=\"Connect String\">${NODES_LIST}</g" ${NIFI_HOME}/conf/state-management.xml
  [ -n "${NIFI_LOG_DIR}" ] && mkdir -p ${NIFI_LOG_DIR}/${HOSTNAME}

# MyId zookeeper
  if [ -z "$NODES_LIST" ]; then
    sed -i "s/nifi\.state\.management\.embedded\.zookeeper\.start=false/nifi.state.management.embedded.zookeeper.start=true/g" ${NIFI_HOME}/conf/nifi.properties
    mkdir -p ${NIFI_HOME}/state/zookeeper
    echo ${ZK_MYID} > ${NIFI_HOME}/state/zookeeper/myid
    # Zookeeper properties
    sed -i "/^server\./,$ d" ${NIFI_HOME}/conf/zookeeper.properties
    srv=1; IFS=","; for node in $ZK_NODES; do sed -i "\$aserver.$srv=$node:${ZK_MONITOR_PORT}:${ZK_ELECTION_PORT}" ${NIFI_HOME}/conf/zookeeper.properties; ((srv++)); done
  fi
  sed -i "s/clientPort=.*/clientPort=${ZK_CLIENT_PORT}/g" ${NIFI_HOME}/conf/zookeeper.properties

  cp -a ${NIFI_HOME}/lib/bootstrap/jackson*.jar ${NIFI_HOME}/lib/
}

if [ -z "$DO_NOT_TOUCH_CONFIGS" ]; then
  do_site2site_configure
  do_cluster_node_configure
fi

${NIFI_HOME}/bin/nifi.sh run
