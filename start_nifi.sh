#!/bin/sh

set -e

do_site2site_configure() {
#  sed -i "s/nifi\.ui\.banner\.text=.*/nifi.ui.banner.text=${BANNER_TEXT}/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.remote\.input\.host=.*/nifi.remote.input.host=${HOSTNAME}.nifi-cluster/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.remote\.input\.socket\.port=.*/nifi.remote.input.socket.port=10101/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.remote\.input\.secure=true/nifi.remote.input.secure=false/g" ${NIFI_HOME}/conf/nifi.properties
}

do_cluster_node_configure() {
# NiFi properties
  sed -i "s/nifi\.web\.http\.host=.*/nifi.web.http.host=${HOSTNAME}.nifi-cluster/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.cluster\.protocol\.is\.secure=true/nifi.cluster.protocol.is.secure=false/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.cluster\.is\.node=false/nifi.cluster.is.node=true/g" ${NIFI_HOME}/conf/nifi.properties
  if [ -z "$NIFI_USE_HOSTNAME"]; then
    sed -i "s/nifi\.cluster\.node\.address=.*/nifi.cluster.node.address=${HOSTNAME}.nifi-cluster/g" ${NIFI_HOME}/conf/nifi.properties
  else
    sed -i "s/nifi\.cluster\.node\.address=.*/nifi.cluster.node.address=$HOSTNAME.$NAMESPACE/g" ${NIFI_HOME}/conf/nifi.properties
  fi
  sed -i "s/nifi\.cluster\.node\.protocol\.port=.*/nifi.cluster.node.protocol.port=10201/g" ${NIFI_HOME}/conf/nifi.properties
#  sed -i "s/nifi\.state\.management\.embedded\.zookeeper\.start=false/nifi.state.management.embedded.zookeeper.start=true/g" ${NIFI_HOME}/conf/nifi.properties
  sed -i "s/nifi\.zookeeper\.connect\.string=.*/nifi.zookeeper.connect.string=${NODES_LIST}/g" ${NIFI_HOME}/conf/nifi.properties

# State management
  sed -i "s/<property name=\"Connect String\">.*</<property name=\"Connect String\">${NODES_LIST}</g" ${NIFI_HOME}/conf/state-management.xml

# MyId zookeeper
#  mkdir -p ${NIFI_HOME}/state/zookeeper
#  echo ${MYID} > ${NIFI_HOME}/state/zookeeper/myid

# Zookeeper properties
#  sed -i "/^server\.1=/q" ${NIFI_HOME}/conf/zookeeper.properties; sed -i "s/^server\.1=.*/server.1=/g" ${NIFI_HOME}/conf/zookeeper.properties
# DB Authentication
  sed -i"" -e "s/dbcp.obx.url=.\+/dbcp.obx.url=$DBCP_OBX_URL/" \
           -e "s/dbcp.obx.usr=.\+/dbcp.obx.usr=$DBCP_OBX_USR/" \
           -e "s/dbcp.obx.pwd=.\+/dbcp.obx.pwd=$DBCP_OBX_PWD/" \
	   -e "s/resources.path=.\+/resources.path=$RESOURCES_PATH/" \
    ${NIFI_HOME}/conf/nifi_custom.properties
  cp -a ${NIFI_HOME}/lib/bootstrap/jackson*.jar ${NIFI_HOME}/lib/
}

do_site2site_configure

if [ "$INSTANCE_ROLE" == "cluster-node" ]; then
  do_cluster_node_configure
fi

tail -F ${NIFI_HOME}/logs/nifi-app.log &
${NIFI_HOME}/bin/nifi.sh run
