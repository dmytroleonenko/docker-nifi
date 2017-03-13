#!/bin/sh

set -e

#variable defaults
S2S_PORT=${S2S_PORT:-10101}
NIFI_HOME=${NIFI_HOME:-/opt/nifi}
ZK_CLIENT_PORT=${ZK_CLIENT_PORT:-2181}
NODE_PROTOCOL_PORT=${NODE_PROTOCOL_PORT:-10201}
ZK_MONITOR_PORT=${ZK_MONITOR_PORT:-2888}
ZK_ELECTION_PORT=${ZK_ELECTION_PORT:-3888}
ZK_ROOT_NODE=${ZK_ROOT_NODE:-/nifi}
NIFI_JAVA_XMX=${NIFI_JAVA_XMX:-1g}
NIFI_JAVA_XMS=${NIFI_JAVA_XMS:-100m}

SECURE=false;
[ "$IS_SECURE" -eq "true" ] && SECURE=true
[ "$EMBEDED_ZK" -eq "true" ] && ZK_MYID=1


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

  sed -i "s@nifi\.variable\.registry\.properties\=.*@nifi.variable.registry.properties=./conf/environment_properties/nifi_custom.properties@g" ${NIFI_HOME}/conf/nifi.properties

  sed -i "s%nifi\.zookeeper\.connect\.string=.*%nifi.zookeeper.connect.string=${NODES_LIST}%g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s@nifi\.zookeeper\.root\.node=.*@nifi.zookeeper.root.node=${ZK_ROOT_NODE}@g" ${NIFI_HOME}/conf/nifi.properties
# State management
  sed -i "s/<property name=\"Connect String\">.*</<property name=\"Connect String\">${NODES_LIST}</g" ${NIFI_HOME}/conf/state-management.xml
  [ -n "${NIFI_LOG_DIR}" ] && mkdir -p ${NIFI_LOG_DIR}/${HOSTNAME}


# Bootstrap configuration
  sed -i "s/-Xmx.*/-Xmx$NIFI_JAVA_XMX/" ${NIFI_HOME}/conf/bootstrap.conf
  sed -i "s/-Xms.*/-Xms$NIFI_JAVA_XMS/" ${NIFI_HOME}/conf/bootstrap.conf
# MyId zookeeper
  if [ -n "$EMBEDED_ZK" ]; then
    sed -i "s/nifi\.state\.management\.embedded\.zookeeper\.start=false/nifi.state.management.embedded.zookeeper.start=true/g" ${NIFI_HOME}/conf/nifi.properties
    mkdir -p ${NIFI_HOME}/state/zookeeper
    echo ${ZK_MYID} > ${NIFI_HOME}/state/zookeeper/myid
    # Zookeeper properties
    sed -i "/^server\./,$ d" ${NIFI_HOME}/conf/zookeeper.properties
    srv=1; IFS=","; for node in $ZK_NODES; do sed -i "\$aserver.$srv=$node:${ZK_MONITOR_PORT}:${ZK_ELECTION_PORT}" ${NIFI_HOME}/conf/zookeeper.properties; ((srv++)); done
  fi
  sed -i "s/clientPort=.*/clientPort=${ZK_CLIENT_PORT}/g" ${NIFI_HOME}/conf/zookeeper.properties
  # KeyStore and Truststore passwords
  sed -i "s@nifi\.security\.keyPasswd=.*@nifi.security.keyPasswd=$NIFI_KEYSTORE_PASSWD@;s@nifi\.security\.keystorePasswd=.*@nifi.security.keystorePasswd=$NIFI_KEYSTORE_PASSWD@" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s@nifi\.security\.truststorePasswd=.*@nifi.security.truststorePasswd=$NIFI_TRUSTSTORE_PASSWD@" ${NIFI_HOME}/conf/nifi.properties
}

if [ -z "$DO_NOT_TOUCH_CONFIGS" ]; then
  do_site2site_configure
  do_cluster_node_configure
fi

${NIFI_HOME}/bin/nifi.sh run
