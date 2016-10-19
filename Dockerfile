FROM       xemuliam/nifi-base
MAINTAINER Viacheslav Kalashnikov <xemuliam@gmail.com>
LABEL      VERSION="1.0.0" \
           RUN="docker run -d -p 8080:8080 -p 8443:8443 xemuliam/nifi"
ENV        BANNER_TEXT=Docker-Nifi-1.0.0 \
           INSTANCE_ROLE=cluster-node \
           NODES_LIST=zoo-0.zk:2181,zoo-1.zk:2181,zoo-2.zk:2181 \
           MYID=N/A
COPY       start_nifi.sh /${NIFI_HOME}/
COPY       zookeeper.properties /${NIFI_HOME}/conf/
COPY       bootstrap.conf /${NIFI_HOME}/conf/
COPY       flow.xml.gz /${NIFI_HOME}/conf/
COPY       jackson-annotations-2.6.0.jar /${NIFI_HOME}/lib/
COPY       jackson-core-2.6.1.jar /${NIFI_HOME}/lib/
COPY       jackson-databind-2.6.1.jar /${NIFI_HOME}/lib/
COPY       newar.nifi.processors.launchrules-1.0.0.1_20161012161408.nar /${NIFI_HOME}/lib/
COPY       newar.nifi.processors.parsemap-1.0.0.1_20161012133625.nar /${NIFI_HOME}/lib/
VOLUME     /opt/datafiles \
           /opt/scriptfiles \
           /opt/certs
WORKDIR    ${NIFI_HOME}
RUN        chmod +x ./start_nifi.sh
CMD        ./start_nifi.sh
