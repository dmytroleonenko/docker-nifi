FROM       openjdk:alpine
MAINTAINER Dima Leonenko <dmitry.leonenko@gmail.com>
ARG        DIST_MIRROR=http://archive.apache.org/dist/nifi
ARG        VERSION=1.0.0
ENV        NIFI_HOME=/opt/nifi
RUN        apk update  && apk upgrade && apk add --upgrade curl && \
           adduser -h  ${NIFI_HOME} -g "Apache NiFi user" -s /bin/sh -D nifi && \
           mkdir -p ${NIFI_HOME}/logs \
           ${NIFI_HOME}/flowfile_repository \
           ${NIFI_HOME}/database_repository \
           ${NIFI_HOME}/content_repository \
           ${NIFI_HOME}/provenance_repository && \
           curl ${DIST_MIRROR}/${VERSION}/nifi-${VERSION}-bin.tar.gz | tar xvz -C ${NIFI_HOME} && \
           mv ${NIFI_HOME}/nifi-${VERSION}/* ${NIFI_HOME} && \
           chown nifi:nifi -R $NIFI_HOME && \
           rm -rf /var/cache/apk/*
VOLUME     ${NIFI_HOME}/logs \
           ${NIFI_HOME}/flowfile_repository \
           ${NIFI_HOME}/database_repository \
           ${NIFI_HOME}/content_repository \
           ${NIFI_HOME}/provenance_repository \
           /opt/datafiles \
           /opt/scriptfiles \
           /opt/certs
WORKDIR    ${NIFI_HOME}
EXPOSE     8080 8081 8443
WORKDIR    ${NIFI_HOME}
ENV        BANNER_TEXT=Docker-Nifi-1.0.0 \
           INSTANCE_ROLE=cluster-node \
           NODES_LIST=zoo-0.zk:2181,zoo-1.zk:2181,zoo-2.zk:2181 \
           MYID=N/A 
USER       nifi
COPY       nifi-artifacts/lib/ ${NIFI_HOME}/lib/
USER       nifi
COPY	   nifi-artifacts/resources/ ${NIFI_HOME}/resources/
USER       nifi
COPY       nifi-artifacts/conf/ ${NIFI_HOME}/conf/
USER       nifi
COPY       docker-nifi/start_nifi.sh ${NIFI_HOME}/
CMD        /bin/sh start_nifi.sh