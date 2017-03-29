FROM       openjdk:alpine
MAINTAINER Dima Leonenko <dmitry.leonenko@gmail.com>
ARG        DIST_MIRROR=http://archive.apache.org/dist/nifi
ARG        VERSION=1.1.2
ENV        NIFI_HOME=/opt/nifi
RUN        apk update  && apk upgrade && apk add --upgrade curl && \
           adduser -h  ${NIFI_HOME} -g "Apache NiFi user" -s /bin/sh -D nifi && \
           mkdir -p ${NIFI_HOME}/logs \
           ${NIFI_HOME}/flowfile_repository \
           ${NIFI_HOME}/database_repository \
           ${NIFI_HOME}/content_repository \
           ${NIFI_HOME}/provenance_repository \
           ${NIFI_HOME}/environment_properties && \
           curl ${DIST_MIRROR}/${VERSION}/nifi-${VERSION}-bin.tar.gz | tar xvz -C ${NIFI_HOME} && \
           mv ${NIFI_HOME}/nifi-${VERSION}/* ${NIFI_HOME} && \
           chown nifi:nifi -R $NIFI_HOME && \
           rm -rf /var/cache/apk/*
ADD        http://tn-alpine-repo.s3-website-us-east-1.amazonaws.com/-5838a3a8.rsa.pub /etc/apk/keys/
RUN        echo 'http://tn-alpine-repo.s3-website-us-east-1.amazonaws.com/' >>/etc/apk/repositories && apk add --update perl perl-app-cpanminus perl-archive-extract perl-archive-zip perl-b-hooks-endofscope perl-bit-vector perl-cam-pdf perl-carp-clan \
perl-class-singleton perl-clone perl-compress-raw-bzip2 perl-compress-raw-zlib perl-cpan-meta perl-cpan-meta-check perl-cpan-meta-requirements perl-cpan-meta-yaml \
perl-crypt-rc4 perl-date-calc perl-date-manip perl-datetime perl-datetime-locale perl-datetime-timezone perl-dbd-csv perl-dbi perl-digest-perl-md5 \
perl-dist-checkconflicts perl-encode-locale perl-file-listing perl-file-temp perl-html-parser perl-html-tagset perl-html-tree perl-http-cookies perl-http-daemon \
perl-http-date perl-http-message perl-http-negotiate perl-io-html perl-io-stringy perl-json-pp perl-list-allutils perl-list-someutils perl-list-someutils-xs \
perl-list-utilsby perl-lwp-mediatypes perl-math-base-convert perl-mime-base64 perl-module-build perl-module-implementation perl-module-load perl-module-load-conditional \
perl-module-metadata perl-module-runtime perl-namespace-autoclean perl-namespace-clean perl-net-http perl-number-format perl-ole-storage_lite perl-package-stash \
perl-package-stash-xs perl-params-util perl-params-validate perl-pathtools perl-scalar-list-utils perl-socket perl-spreadsheet-parseexcel perl-spreadsheet-xlsx \
perl-sql-statement perl-sub-exporter-progressive perl-sub-identify perl-sub-uplevel perl-super perl-test-deep perl-test-exception perl-test-fatal perl-test-harness \
perl-test-inter perl-test-leaktrace perl-test-mockmodule perl-test-nowarnings perl-test-requires perl-test-warnings perl-text-csv perl-text-csv_xs perl-text-parsewords \
perl-text-pdf perl-text-soundex perl-text-unidecode perl-time-hires perl-time-local perl-try-tiny perl-uri perl-variable-magic perl-www-robotrules perl-xml-parser ; rm -rf /var/cache/apk/*
ARG        NIFI_TOOLKIT_VERSION=1.1.2
RUN	   curl http://apache.mirrors.tds.net/nifi/$NIFI_TOOLKIT_VERSION/nifi-toolkit-$NIFI_TOOLKIT_VERSION-bin.tar.gz | tar xvz -C ${NIFI_HOME} && \
           chown nifi:nifi -R $NIFI_HOME/nifi-toolkit-$NIFI_TOOLKIT_VERSION
VOLUME     ${NIFI_HOME}/logs \
           ${NIFI_HOME}/flowfile_repository \
           ${NIFI_HOME}/database_repository \
           ${NIFI_HOME}/content_repository \
           ${NIFI_HOME}/provenance_repository \
           ${NIFI_HOME}/environment_properties \
           /opt/datafiles \
           /opt/scriptfiles \
           /opt/certs
WORKDIR    ${NIFI_HOME}
EXPOSE     8080 8081 8443
ENV        BANNER_TEXT=Docker-Nifi-1.1.2

ADD        artifacts.secure.tar /opt/nifi/
COPY       docker-nifi/nifi-env.sh ${NIFI_HOME}/bin/nifi-env.sh
ADD        artifacts.lib.tar /opt/nifi/
ADD        artifacts.resources.tar /opt/nifi/
ADD        artifacts.conf.tar /opt/nifi/
COPY       docker-nifi/start_nifi.sh ${NIFI_HOME}/
COPY       docker-nifi/login-identity-providers.xml ${NIFI_HOME}/conf
CMD        /bin/sh start_nifi.sh
USER       nifi
