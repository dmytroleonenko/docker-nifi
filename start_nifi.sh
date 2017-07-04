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
NP="${NIFI_HOME}/conf/nifi.properties"
HOSTN=$(hostname)
HOST_NAME="${HOSTN:-hostname_is_not_set}"

do_site2site_configure() {
  sed -i "s/nifi\.remote\.input\.host=.*/nifi.remote.input.host=${HOST_NAME}${DOMAINPART}/g" "$NP";
  sed -i "s/nifi\.remote\.input\.socket\.port=.*/nifi.remote.input.socket.port=${S2S_PORT}/g" "$NP";
  sed -i "s/nifi\.remote\.input\.secure=.*/nifi.remote.input.secure=$SECURE/g" "$NP";
}




do_cluster_node_configure() {
  # Patching
  cat >/tmp/patch1.nifi.properties <<EOF
nifi.web.http.host=${HOST_NAME}${DOMAINPART}
nifi.web.https.host=${HOST_NAME}${DOMAINPART}
nifi.cluster.protocol.is.secure=$SECURE
nifi.cluster.is.node=true
nifi.cluster.node.address=${HOST_NAME}${DOMAINPART}
nifi.cluster.node.protocol.port=${NODE_PROTOCOL_PORT}
nifi.variable.registry.properties=./conf/environment_properties/nifi_custom.properties
nifi.zookeeper.connect.string=${NODES_LIST}
nifi.zookeeper.root.node=${ZK_ROOT_NODE}
EOF
  awk -F= 'NR==FNR{a[$1]=$0;next;}a[$1]{$0=a[$1]}1' /tmp/patch1.nifi.properties "$NP" > "${NP}.mod";
  cat "${NP}.mod" > "${NP}"
  sed -i "s#<property name=\"Connect String\">.*<#<property name=\"Connect String\">${NODES_LIST}<#g" "${NIFI_HOME}/conf/state-management.xml"
  sed -i "s#/conf/\(authorizations.xml\)#/conf/persistent/\1#;s#/conf/\(users.xml\)#/conf/persistent/\1#" "${NIFI_HOME}/conf/authorizers.xml"
  [ -n "${NIFI_LOG_DIR}" ] && mkdir -p "${NIFI_LOG_DIR}/${HOST_NAME}"


# Bootstrap configuration
  sed -i "s/-Xmx.*/-Xmx$NIFI_JAVA_XMX/" "${NIFI_HOME}/conf/bootstrap.conf"
  sed -i"" -e "s/nifihostname/${HOST_NAME}/" "${NIFI_HOME}/conf/bootstrap.conf"
  [ -n "${JAVA_EXTRA_ARGS}" ] && echo "java.arg.$(($(egrep -o '^java.arg.\d+' bootstrap.conf | awk -F. '{print $3}' | sort -n | tail -n1) + 1 ))=${JAVA_EXTRA_ARGS}" >>"${NIFI_HOME}/conf/bootstrap.conf"
  sed -i "s/-Xms.*/-Xms$NIFI_JAVA_XMS/" "${NIFI_HOME}/conf/bootstrap.conf"
# MyId zookeeper




  if [ -n "$EMBEDED_ZK" ]; then
    sed -i "s/nifi\.state\.management\.embedded\.zookeeper\.start=false/nifi.state.management.embedded.zookeeper.start=true/g" "$NP"
    mkdir -p "${NIFI_HOME}/state/zookeeper"
    echo "${ZK_MYID}" > "${NIFI_HOME}/state/zookeeper/myid"
    # Zookeeper properties
    sed -i "/^server\./,$ d" "${NIFI_HOME}/conf/zookeeper.properties"
    srv=1; IFS=","; for node in $ZK_NODES; do sed -i "\$aserver.$srv=$node:${ZK_MONITOR_PORT}:${ZK_ELECTION_PORT}" "${NIFI_HOME}/conf/zookeeper.properties"; _=$((srv=srv+1)); done
  fi
  sed -i "s/clientPort=.*/clientPort=${ZK_CLIENT_PORT}/g" "${NIFI_HOME}/conf/zookeeper.properties"

if [ "$SECURE" = "true" ]; then
  sed -e "s/nififqdn/${HOST_NAME}${DOMAINPART}/;s/nifihostname/${HOST_NAME}/" "${NIFI_HOME}/conf/environment_properties/csr.json" >csr.json
# shellcheck source=/dev/null
  . "${NIFI_HOME}/conf/environment_properties/password.env"

  if [ ! \( -f /opt/certs/keystore.jks \) -o ! \( -f /opt/certs/truststore.jks \) ]; then
  	cfssl gencert -remote ca:8888 -config "${NIFI_HOME}/conf/environment_properties/ca-auth.json" -profile nifi csr.json | cfssljson -bare nifi -
  	openssl pkcs12 -export -out keystore.pfx -inkey nifi-key.pem -in nifi.pem -certfile "${NIFI_HOME}/conf/environment_properties/ca-chain.pem" -passout pass:"$KEYSTORE_PASSWORD"
  	openssl x509 -outform der -in "${NIFI_HOME}/conf/environment_properties/ca-chain.pem" -out ca-chain.der

  	keytool -importkeystore -alias 1 -srckeystore keystore.pfx -srcstoretype pkcs12 -destkeystore /opt/certs/keystore.jks -deststoretype JKS -destalias nifi-key -srcstorepass "$KEYSTORE_PASSWORD" -deststorepass "$KEYSTORE_PASSWORD"
  	keytool -import -alias nifi-cert -keystore /opt/certs/truststore.jks -file ca-chain.der -storepass "$TRUSTSTORE_PASSWORD" -noprompt -storetype JKS
  fi
  for i in $(seq 0 9) ; do
    ALLOW="${ALLOW}\<property name=\"Node Identity $i\"\>CN=nifi-${i}${DOMAINPART}, OU=NIFI\</property\>"
  done
  # removing default comment out
  perl -i -pe 'BEGIN{undef $/;} s@<!-- Provide the identity.*?\n(.*?$).*-->@$1@smg' "${NIFI_HOME}/conf/authorizers.xml"
  sed -i"" -e 's@<property name="Node Identity 1"></property>@'"${ALLOW}"'@' "${NIFI_HOME}/conf/authorizers.xml"
  sed -i"" -e 's#\(<property name="Initial Admin Identity">\).*\(</property>\)#\1'"${INITIAL_ADMIN_PRINCIPAL}"'\2#' "${NIFI_HOME}/conf/authorizers.xml"

fi

}

do_properties_patching() {
  PATCH_FILES=$(find $1 -follow -maxdepth 1 -type f)
  for f in ${PATCH_FILES}; do
    echo -e "========== PATCHING nifi.properties WITH CONFIGMAP PATCHES : $f ============ "
    awk -F= 'NR==FNR{a[$1]=$0;next;}a[$1]{$0=a[$1]}1' "$f" "$NP" >"$NP.mod";
    cat "$NP.mod" >"$NP"
    rm -f "$NP.mod"
  done
}

start_nifi() {
  "${NIFI_HOME}/bin/nifi.sh" run
}

if [ \( -z "$DO_NOT_TOUCH_CONFIGS" \) -a \( ! -f "/tmp/.configured" \) ]; then
  do_site2site_configure
  do_cluster_node_configure
  touch /tmp/.configured
  [ -d "$PATCH_NIFI_PROPERTIES_PATH" ] && do_properties_patching "${PATCH_NIFI_PROPERTIES_PATH}"
fi

start_nifi
