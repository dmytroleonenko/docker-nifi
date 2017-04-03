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
  sed -i "s#\(authorizations.xml\)#persistent/\1#;s#\(users.xml\)#persistent/\1#" ${NIFI_HOME}/conf/authorizers.xml
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
  sed -e "s@nififqdn@${HOSTNAME}${DOMAINPART}@;s@nifihostname@${HOSTNAME}@" ${NIFI_HOME}/conf/environment_properties/csr.json >csr.json"
  source ${NIFI_HOME}/conf/environment_properties/password.env
  cfssl gencert -remote ca:8888 -config ${NIFI_HOME}/conf/environment_properties/ca-auth.json -profile nifi csr.json | cfssljson -bare nifi -
  openssl pkcs12 -export -out keystore.pfx -inkey nifi-key.pem -in nifi.pem -certfile ${NIFI_HOME}/conf/environment_properties/ca-chain.pem -passout $KEYSTORE_PASSWORD
  openssl x509 -outform der -in ${NIFI_HOME}/conf/environment_properties/ca-chain.pem -out ca-chain.der
  
  keytool -importkeystore -alias 1 -srckeystore keystore.pfx -srcstoretype pkcs12 -destkeystore keystore.jks -deststoretype JKS -destalias nifi-key -srckeypass $KEYSTORE_PASSWORD -destkeypass $KEYSTORE_PASSWORD
  keytool -import -alias nifi-cert -keystore truststore.jks -file ca-chain.der -storepass $TRUSTSTORE_PASSWORD -noprompt -storetype JKS
  for i in $(seq 0 9) ; do
    ALLOW="${ALLOW}<property name=\"Node Identity $i\">CN=nifi-${i}${DOMAINPART}, OU=NIFI</property>"
  done
  # removing default comment out
  perl -i -pe 'BEGIN{undef $/;} s@<!-- Provide the identity.*?\n(.*?$).*-->@$1@smg' ${NIFI_HOME}/conf/authorizers.xml
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
