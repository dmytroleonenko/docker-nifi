#!/bin/sh -x

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
CA_SERVER_NAME=${CA_SERVER_NAME:-ca-server}
CA_TCP_PORT=${CA_TCP_PORT:-9114}
NIFI_TOOLKIT_VERSION=${NIFI_TOOLKIT_VERSION:-1.1.2}
SECURE=false;
[ "$IS_SECURE" = "true" ] && SECURE=true
[ "$EMBEDED_ZK" = "true" ] && ZK_MYID=1
NP="${NIFI_HOME}/conf/nifi.properties"

do_site2site_configure() {
  sed -i "s/nifi\.remote\.input\.host=.*/nifi.remote.input.host=${HOSTNAME}${DOMAINPART}/g" $NP; ls -la $NP
  sed -i "s/nifi\.remote\.input\.socket\.port=.*/nifi.remote.input.socket.port=${S2S_PORT}/g" $NP; ls -la $NP
  sed -i "s/nifi\.remote\.input\.secure=.*/nifi.remote.input.secure=$SECURE/g" $NP; ls -la $NP
}


do_cluster_node_configure() {
  # Patching
  cat >/tmp/patch1.nifi.properties <<EOF
nifi.web.http.host=${HOSTNAME}${DOMAINPART}
nifi.web.https.host=${HOSTNAME}${DOMAINPART}
nifi.cluster.protocol.is.secure=$SECURE
nifi.cluster.is.node=true
nifi.cluster.node.address=${HOSTNAME}${DOMAINPART}
nifi.cluster.node.protocol.port=${NODE_PROTOCOL_PORT}
nifi.variable.registry.properties=./conf/environment_properties/nifi_custom.properties
nifi.zookeeper.connect.string=${NODES_LIST}
nifi.zookeeper.root.node=${ZK_ROOT_NODE}
EOF
  awk -F= 'NR==FNR{a[$1]=$0;next;}a[$1]{$0=a[$1]}1' /tmp/patch1.nifi.properties $NP > ${NP}.mod ;
  cat ${NP}.mod > ${NP}
  sed -i "s#<property name=\"Connect String\">.*<#<property name=\"Connect String\">${NODES_LIST}<#g" ${NIFI_HOME}/conf/state-management.xml
  sed -i "s#\(authorizations.xml\)#efs/${HOSTNAME}${DOMAINPART}-\1#;s#\(users.xml\)#efs/${HOSTNAME}${DOMAINPART}-\1#" ${NIFI_HOME}/conf/authorizers.xml
  [ -n "${NIFI_LOG_DIR}" ] && mkdir -p ${NIFI_LOG_DIR}/${HOSTNAME}


# Bootstrap configuration
  sed -i "s/-Xmx.*/-Xmx$NIFI_JAVA_XMX/" ${NIFI_HOME}/conf/bootstrap.conf
  sed -i "s/-Xms.*/-Xms$NIFI_JAVA_XMS/" ${NIFI_HOME}/conf/bootstrap.conf
# MyId zookeeper
  if [ -n "$EMBEDED_ZK" ]; then
    sed -i "s/nifi\.state\.management\.embedded\.zookeeper\.start=false/nifi.state.management.embedded.zookeeper.start=true/g" $NP
    mkdir -p ${NIFI_HOME}/state/zookeeper
    echo ${ZK_MYID} > ${NIFI_HOME}/state/zookeeper/myid
    # Zookeeper properties
    sed -i "/^server\./,$ d" ${NIFI_HOME}/conf/zookeeper.properties
    srv=1; IFS=","; for node in $ZK_NODES; do sed -i "\$aserver.$srv=$node:${ZK_MONITOR_PORT}:${ZK_ELECTION_PORT}" ${NIFI_HOME}/conf/zookeeper.properties; ((srv++)); done
  fi
  sed -i "s/clientPort=.*/clientPort=${ZK_CLIENT_PORT}/g" ${NIFI_HOME}/conf/zookeeper.properties


if [ "$SECURE" = "true" ]; then
  if [ -z "${CA_SERVER_TOKEN}" ]; then echo "CA_SERVER_TOKEN variable must be configured. Get it from the CA server config.json stored on EFS" 1>&1 ; exit 1; fi

  ${NIFI_HOME}/nifi-toolkit-${NIFI_TOOLKIT_VERSION}/bin/tls-toolkit.sh  client -c ${CA_SERVER_NAME} -t ${CA_SERVER_TOKEN} -p ${CA_TCP_PORT} -D "CN=${HOSTNAME}${DOMAINPART}, OU=NIFI"
  KSP=$(grep keyStorePassword config.json | sed -e 's/.*: "\(.*\)",/\1/')
  KP=$(grep keyPassword config.json | sed -e 's/.*: "\(.*\)",/\1/')
  TP=$(grep trustStorePassword config.json | sed -e 's/.*: "\(.*\)",/\1/')
  sed -i"" -e "s@\(nifi\.security\.keystore=\).*@\1/opt/nifi/keystore.jks@;s@\(nifi\.security\.keystoreType=\).*@\1jks@;s@\(nifi\.security\.keystorePasswd=\).*@\1${KSP}@;s@\(nifi\.security\.keyPasswd=\).*@\1${KP}@;s@\(nifi\.security\.truststore=\).*@\1/opt/nifi/truststore.jks@;s@\(nifi\.security\.truststoreType=\).*@\1jks@;s@\(nifi\.security\.truststorePasswd=\).*@\1${TP}@" $NP
  for i in $(seq 0 9) ; do
    ALLOW="${ALLOW}<property name=\"Node Identity $i\">CN=nifi-${i}${DOMAINPART}, OU=NIFI</property>"
  done
  sed -i"" -e "s@<property name=\"Node Identity 1\"></property>@$ALLOW@" ${NIFI_HOME}/conf/authorizers.xml
  sed -i"" -e "s@# \(nifi\.security\.identity\.mapping\.pattern\.kerb\)@\1@;s@# \(nifi\.security\.identity\.mapping\.value\.kerb\)@\1@" $NP
fi
}

do_properties_patching() {
  PATCH_FILES=$(find $1 -follow -maxdepth 1 -type f)
  for f in ${PATCH_FILES}; do
  echo -e "========== PATCHING nifi.properties WITH CONFIGMAP PATCHES : $f ============ "
  awk -F= 'NR==FNR{a[$1]=$0;next;}a[$1]{$0=a[$1]}1' $f $NP >$NP.mod;
  cat $NP.mod >$NP
  done
}

if [ -z "$DO_NOT_TOUCH_CONFIGS" ]; then
  do_site2site_configure
  do_cluster_node_configure
  [ -d "$PATCH_NIFI_PROPERTIES_PATH" ] && do_properties_patching $PATCH_NIFI_PROPERTIES_PATH
fi

${NIFI_HOME}/bin/nifi.sh run
