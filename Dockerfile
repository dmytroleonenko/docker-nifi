FROM       alpine:3.6 AS perlbrew
RUN        apk --no-cache add openssl-dev lzo-dev xz-dev expat-dev alpine-sdk wget curl bash perl && ln -fs /bin/bash /bin/sh;
RUN        curl -s https://raw.githubusercontent.com/gugod/App-perlbrew/master/perlbrew-install | bash
RUN        source ~/perl5/perlbrew/etc/bashrc && perlbrew install perl-5.10.1 -n -j8
RUN        curl -Lo /usr/local/bin/cpanm https://raw.githubusercontent.com/miyagawa/cpanminus/master/cpanm && \
           chmod +x /usr/local/bin/cpanm
ENV        PATH="/root/perl5/perlbrew/perls/perl-5.10.1/bin:$PATH"
RUN        cpanm App::cpanminus && \
           cpanm --force Algorithm::Diff App::cpanminus Archive::Extract Archive::Zip B::Hooks::EndOfScope Barcode::Code128 Bit::Vector CAM::PDF CPAN CPAN::Meta CPAN::Meta::Check CPAN::Meta::Requirements CPAN::Meta::YAML Capture::Tiny Carp::Clan Class::Data::Inheritable Class::Inspector Class::Load Class::Singleton Class::Tiny Clone Compress::LZF Compress::LZO Compress::Raw::Bzip2 Compress::Raw::Lzma Compress::Raw::Zlib Crypt::RC4 Cwd DBD::CSV DBI Data::OptList Date::Calc Date::Manip DateTime DateTime::Locale DateTime::TimeZone Devel::CheckBin Devel::CheckLib Devel::GlobalDestruction Devel::GlobalDestruction::XS Devel::StackTrace Digest::Perl::MD5 Dist::CheckConflicts Encode Encode::Locale Encode::compat Eval::Closure Exception::Class ExtUtils::CBuilder ExtUtils::Config ExtUtils::Constant ExtUtils::Helpers ExtUtils::Install ExtUtils::InstallPaths ExtUtils::MakeMaker ExtUtils::ParseXS File::Copy::Recursive File::Listing File::ShareDir File::ShareDir::Install File::Temp Font::TTF GD GD::Barcode HTML::HTML5::Entities HTML::Parser HTML::Tagset HTML::Tree HTTP::Cookies HTTP::Daemon HTTP::Date HTTP::Message HTTP::Negotiate IO::CaptureOutput IO::Compress::Lzf IO::Compress::Lzma IO::Compress::Lzop IO::HTML IO::String IO::Stringy IPC::Cmd IPC::Run3 Importer JSON::PP LWP::MediaTypes List::AllUtils List::MoreUtils List::SomeUtils List::SomeUtils::XS List::Util List::UtilsBy Local::Works::Fine MIME::Base64 MRO::Compat Math::Base::Convert Mock::Config Module::Build Module::Build::Tiny Module::CoreList Module::Implementation Module::Load Module::Load::Conditional Module::Metadata Module::Runtime Net::HTTP Number::Format OLE::Storage_Lite PDF::API2 PDF::Create Package::Stash Package::Stash::XS Params::Util Params::Validate Params::ValidationCompiler Parse::CPAN::Meta Path::Tiny Perl::OSType Role::Tiny SQL::Statement SUPER Scope::Guard Socket Specio Spreadsheet::ParseExcel Spreadsheet::XLSX Storable Sub::Exporter Sub::Exporter::Progressive Sub::Identify Sub::Info Sub::Install Sub::Name Sub::Uplevel Term::Table Test2::Plugin::NoWarnings Test2::Suite Test::Deep Test::Exception Test::Fatal Test::File::ShareDir Test::Harness Test::Inter Test::LeakTrace Test::MockModule Test::Needs Test::NoWarnings Test::Output Test::Requires Test::RequiresInternet Test::Simple Test::Tester Test::Warnings Test::Without::Module Text::CSV Text::CSV_XS Text::Diff Text::Iconv Text::PDF Text::ParseWords Text::Reform Text::Soundex Text::Unidecode Time::HiRes Time::Local Try::Tiny URI Variable::Magic WWW::RobotRules XML::Parser YAML::LibYAML || true

FROM       openjdk:alpine
MAINTAINER Dima Leonenko <dmitry.leonenko@gmail.com>
COPY --from=perlbrew /root/perl5/perlbrew/perls/perl-5.10.1/ /opt/perl-5.10.1/
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
ENV        PERL5LIB="/opt/perl-5.10.1/lib/5.10.1/"
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
