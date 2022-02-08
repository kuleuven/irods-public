#!/bin/bash

: ${VERSION:=4.2.11}

MYSQL_NAME=mysql
MYSQL_ROOT_PASSWORD=rootpw
IRODS_NAME=irods
IRODS_HOST=irods.container
IRODS_ZONE=test
IRODS_IMAGE=irods:mysql

docker build -t $IRODS_IMAGE --build-arg VERSION=$VERSION .
docker rm -f $MYSQL_NAME $IRODS_NAME

mkdir -p ssl
test -f ssl/cert.pem || docker run -i --rm -v $(pwd)/ssl:/ssl securefab/openssl req -x509 -nodes -newkey rsa:4096 -keyout /ssl/key.pem -out /ssl/cert.pem -days 365 \
     -subj '/CN=$(IRODS_HOST)' \
     -addext "subjectAltName = DNS:$IRODS_HOST"
cat ssl/cert.pem > ssl/ca-bundle.pem

docker run -d --name $MYSQL_NAME -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD mysql:8
sleep 15
docker exec -i $MYSQL_NAME mysql -h localhost -uroot -p$MYSQL_ROOT_PASSWORD <<'EOF'
CREATE DATABASE irods;
ALTER DATABASE irods CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'irods'@'%' IDENTIFIED WITH mysql_native_password BY 'irods';
GRANT ALL ON irods.* TO 'irods'@'%';
SET GLOBAL TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET GLOBAL log_bin_trust_function_creators = 1;
EOF

docker run -d --name $IRODS_NAME --link $MYSQL_NAME \
  --hostname $IRODS_HOST \
  -v $(pwd)/ssl:/ssl \
  -e SERVER=$IRODS_HOST \
  -e ZONE=$IRODS_ZONE \
  -e SRV_NEGOTIATION_KEY=$(openssl rand -hex 16) \
  -e SRV_ZONE_KEY=$(openssl rand -hex 16) \
  -e CTRL_PLANE_KEY=$(openssl rand -hex 16) \
  -e DB_NAME=irods \
  -e DB_USER=irods \
  -e DB_PASSWORD=irods \
  -e DB_SRV_HOST=$MYSQL_NAME \
  -e SSL_CERTIFICATE_CHAIN_FILE=/ssl/cert.pem \
  -e SSL_CERTIFICATE_KEY_FILE=/ssl/key.pem \
  -e SSL_CA_BUNDLE=/ssl/ca-bundle.pem \
  $IRODS_IMAGE

set -e

until docker exec -i $IRODS_NAME /usr/local/bin/healthcheck; do
  sleep 0.5
done

echo IRODS ready
