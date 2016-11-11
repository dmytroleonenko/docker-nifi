FROM       xemuliam/nifi-base
MAINTAINER Viacheslav Kalashnikov <xemuliam@gmail.com>
LABEL      VERSION="1.0.0" \
           RUN="docker run -d -p 8080:8080 -p 8443:8443 xemuliam/nifi"
ENV        BANNER_TEXT=Docker-Nifi-1.0.0 \
           INSTANCE_ROLE=cluster-node \
           NODES_LIST=zoo-0.zk:2181,zoo-1.zk:2181,zoo-2.zk:2181 \
           MYID=N/A
COPY       docker-nifi/start_nifi.sh /${NIFI_HOME}/
COPY       nifi-artifacts/ /${NIFI_HOME}/
VOLUME     /opt/datafiles \
           /opt/scriptfiles \
           /opt/certs
WORKDIR    ${NIFI_HOME}
RUN        chmod +x ./start_nifi.sh
CMD        ./start_nifi.sh
