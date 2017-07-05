FROM       alpine:3.6
RUN        apk --no-cache add openssl-dev lzo-dev xz-dev expat-dev alpine-sdk wget curl bash perl && ln -fs /bin/bash /bin/sh;
RUN        curl -s https://raw.githubusercontent.com/gugod/App-perlbrew/master/perlbrew-install | bash
RUN        source ~/perl5/perlbrew/etc/bashrc && perlbrew install perl-5.10.1 -n -j8
RUN        curl -Lo /usr/local/bin/cpanm https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm && \
           chmod +x /usr/local/bin/cpanm && \
ENV        PATH="/root/perl5/perlbrew/perls/perl-5.10.1/bin:$PATH"
RUN        cpanm App::cpanminus && \
           cpanm --force App::cpanminus Archive::Extract Archive::Zip B::Hooks::EndOfScope Bit::Vector CAM::PDF CPAN::Meta CPAN::Meta::Check CPAN::Meta::Requirements CPAN::Meta::YAML Carp::Clan Class::Singleton Clone Compress::Raw::Bzip2 Compress::Raw::Zlib Crypt::RC4 Cwd DBD::CSV DBI Date::Calc Date::Manip DateTime DateTime::Locale DateTime::TimeZone Digest::Perl::MD5 Dist::CheckConflicts Encode Encode::Locale ExtUtils::MakeMaker File::Listing File::Temp HTML::Parser HTML::Tagset HTML::Tree HTTP::Cookies HTTP::Daemon HTTP::Date HTTP::Message HTTP::Negotiate Compress::Zlib IO::HTML IO::Stringy JSON::PP LWP LWP::MediaTypes List::AllUtils List::SomeUtils List::SomeUtils::XS List::Util List::UtilsBy MIME::Base64 Math::Base::Convert Module::Build Module::Implementation Module::Load Module::Load::Conditional Module::Metadata Module::Runtime Net::HTTP Number::Format OLE::Storage_Lite Package::Stash Package::Stash::XS Params::Util Params::Validate SQL::Statement Socket Spreadsheet::ParseExcel Spreadsheet::XLSX Sub::Exporter::Progressive Sub::Identify Sub::Uplevel Test::Deep Test::Exception Test::Fatal Test::Harness Test::Inter Test::LeakTrace Test::MockModule Test::NoWarnings Test::Requires Test::Simple Test::Warnings Text::CSV Text::CSV_XS Text::PDF Text::ParseWords Text::Soundex Text::Unidecode Time::HiRes Time::Local Try::Tiny URI Variable::Magic WWW::RobotRules XML::Parser namespace::autoclean namespace::clean

FROM       openjdk:alpine
MAINTAINER Dima Leonenko <dmitry.leonenko@gmail.com>
COPY --from=0 /root/perl5/perlbrew/perls/perl-5.10.1 /opt/ 
ARG        DIST_MIRROR=http://archive.apache.org/dist/nifi
ARG        VERSION=1.1.2
ENV        BANNER_TEXT=Docker-Nifi-1.1.2
ENV        NIFI_HOME=/opt/nifi
ENV        PATH="/opt/perl-5.10.1/bin:$PATH"
RUN        apk add --no-cache curl bash wget xz-libs lzo expat openssl&& \
           adduser -h  ${NIFI_HOME} -g "Apache NiFi user" -s /bin/sh -D nifi && \
           mkdir -p ${NIFI_HOME}/logs \
           ${NIFI_HOME}/flowfile_repository \
           ${NIFI_HOME}/database_repository \
           ${NIFI_HOME}/content_repository \
           ${NIFI_HOME}/provenance_repository \
           ${NIFI_HOME}/environment_properties && \
           curl ${DIST_MIRROR}/${VERSION}/nifi-${VERSION}-bin.tar.gz | tar xvz -C ${NIFI_HOME} && \
           mv ${NIFI_HOME}/nifi-${VERSION}/* ${NIFI_HOME} && \
           chown nifi:nifi -R $NIFI_HOME
RUN        curl http://tn-alpine-repo.s3-website-us-east-1.amazonaws.com/bin.tar | tar -C /usr/local/bin/ -xvf -
RUN	   ln -s /opt/certs/keystore.jks /opt/nifi/keystore.jks; ln -s /opt/certs/truststore.jks /opt/nifi/truststore.jks
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

COPY       nifi-artifacts/secure/ ${NIFI_HOME}/secure/
COPY       docker-nifi/nifi-env.sh ${NIFI_HOME}/bin/nifi-env.sh
COPY       nifi-artifacts/lib/ ${NIFI_HOME}/lib/
COPY       nifi-artifacts/resources/ ${NIFI_HOME}/resources/
COPY       nifi-artifacts/conf/ ${NIFI_HOME}/conf/
COPY       docker-nifi/start_nifi.sh ${NIFI_HOME}/
COPY       docker-nifi/login-identity-providers.xml ${NIFI_HOME}/conf
RUN        chown -R nifi:nifi ${NIFI_HOME}
CMD        /bin/sh start_nifi.sh
USER       1000
