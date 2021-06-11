FROM centos:7

ARG VERSION

ADD etc/yum.repos.d/ /etc/yum.repos.d/

RUN groupadd -r -g 594 irods && \
  useradd -r -c 'iRODS Administrator' -d /var/lib/irods -s /bin/bash -u 599 -g 594 irods

RUN yum install -y epel-release

RUN yum install -y \
  irods-server-${VERSION} \
  irods-runtime-${VERSION} \
  irods-icommands-${VERSION} \
  irods-database-plugin-mysql-${VERSION} \
  irods-rule-engine-plugin-python-${VERSION}.0 \
  irods-devel-${VERSION} \
  irods-rule-engine-plugin-audit-amqp-${VERSION}.0 \
#  irods-rule-engine-plugin-logical-quotas-${VERSION}.0 \
#  irods-rule-engine-plugin-metadata-guard-${VERSION}.0 \
  irods-rule-engine-plugin-unified-storage-tiering-${VERSION}.0 \
  irods-resource-plugin-s3-${VERSION}.0 \
  unixODBC \
  supervisor \
  gettext \
  jq \
  haproxy \
  python-pip \
  python-enum \
  libexif-devel libxml2-devel samtools-htslib \
  crontabs \
  mailx \
  nc \
  lnav

# Use more recent mysql odbc connector
RUN yum localinstall -y https://repo.mysql.com/yum/mysql-connectors-community/el/7/x86_64/mysql-connector-odbc-8.0.25-1.el7.x86_64.rpm

RUN yum install -y netcdf-devel gcc hdf5-devel

RUN echo set smtp=smtp://smtp.network.local:25 >> /etc/mail.rc
RUN echo set from=irods@network.local >> /etc/mail.rc

RUN pip install --upgrade pip==18.0 setuptools==18.0 && pip install cython && pip install \
  jsonschema \
  irods-avu-json \
  requests==2.6.0 \
  requests-cache==0.5.2 \
  xmltodict \
  jinja2 \
  pathvalidate \
  netcdf4 \
  pandas

ADD etc/ /etc/
ADD ${SHORT_TIER}/etc/ /etc/
ADD bin/ /usr/local/bin/
ADD irods/server_config.json.tmpl /etc/irods/
ADD irods/irods_environment.json.tmpl /etc/irods/

RUN apply-patches

RUN mkdir -p /etc/irods/ssl && openssl dhparam -2 -out /etc/irods/ssl/dhparams.pem 2048
RUN mkdir -p /tmp/oidc

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]

ENV SERVER=irods.network.local \
  ZONE=zone_name \
  ADMIN_USER=rods \
  ADMIN_PASS=hunter2 \
  SRV_NEGOTIATION_KEY= \
  SRV_ZONE_KEY= \
  CTRL_PLANE_KEY= \
  SRV_PORT=1247 \
  SRV_PORT_RANGE_START=20000 \
  SRV_PORT_RANGE_END=20199 \
  DB_NAME= \
  DB_USER= \
  DB_PASSWORD= \
  DB_SRV_HOST=mysql.network.local \
  DB_SRV_PORT=3306 \
  DEFAULT_VAULT_DIR=/vault \
  SSL_CERTIFICATE_CHAIN_FILE= \
  SSL_CERTIFICATE_KEY_FILE= \
  SSL_CA_BUNDLE= \
  RE_RULEBASE_SET="rules-local core" \
  PYTHON_RULESETS="rules_local" \
  AMQP=ANONYMOUS@localhost:5672 \
  DEFAULT_RESOURCE=default

# Irods port
EXPOSE 1247

# Control plane port - only to be used with consumers
EXPOSE 1248
