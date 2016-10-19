FROM       xemuliam/nifi-base
MAINTAINER Viacheslav Kalashnikov <xemuliam@gmail.com>
LABEL      VERSION="1.0.0" \
           RUN="docker run -d -p 8080:8080 -p 8443:8443 xemuliam/nifi"
ENV        INSTANCE_ROLE=cluster-node \
           NODES_LIST=zoo-0:2181,zoo-1:2181,zoo-2:2181 \
           MYID=N/A
COPY       start_nifi.sh /${NIFI_HOME}/
COPY       zookeeper.properties /${NIFI_HOME}/conf/
VOLUME     /opt/datafiles \
           /opt/scriptfiles \
           /opt/certs
WORKDIR    ${NIFI_HOME}
RUN        chmod +x ./start_nifi.sh
CMD        ./start_nifi.sh
