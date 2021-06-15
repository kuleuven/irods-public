#!/bin/bash

: ${VERSION:=4.2.9}

POSTGRESQL_NAME=postgres
POSTGRESQL_ROOT_PASSWORD=rootpw
IRODS_NAME=irods
IRODS_HOST=irods.container
IRODS_ZONE=test
IRODS_IMAGE=irods:postgres

docker build -t $IRODS_IMAGE --build-arg VERSION=$VERSION -f Dockerfile.postgres .
docker rm -f $POSTGRESQL_NAME $IRODS_NAME

mkdir -p ssl
test -f ssl/cert.pem || docker run -i --rm -v $(pwd)/ssl:/ssl securefab/openssl req -x509 -nodes -newkey rsa:4096 -keyout /ssl/key.pem -out /ssl/cert.pem -days 365 \
     -subj '/CN=$(IRODS_HOST)' \
     -addext "subjectAltName = DNS:$IRODS_HOST"
cat ssl/cert.pem > ssl/ca-bundle.pem

docker run -d --name $POSTGRESQL_NAME -e POSTGRES_PASSWORD=$POSTGRESQL_ROOT_PASSWORD -e PGPASSWORD=$POSTGRESQL_ROOT_PASSWORD postgres:11
sleep 15
docker exec -i $POSTGRESQL_NAME psql -h localhost -U postgres <<'EOF'
CREATE DATABASE irods;                            
CREATE USER irods WITH ENCRYPTED PASSWORD 'irods';
GRANT ALL PRIVILEGES ON DATABASE irods TO irods;  
EOF

docker run -d --name $IRODS_NAME --link $POSTGRESQL_NAME \
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
  -e DB_SRV_HOST=$POSTGRESQL_NAME \
  -e SSL_CERTIFICATE_CHAIN_FILE=/ssl/cert.pem \
  -e SSL_CERTIFICATE_KEY_FILE=/ssl/key.pem \
  -e SSL_CA_BUNDLE=/ssl/ca-bundle.pem \
  $IRODS_IMAGE

set -e

until docker exec -i $IRODS_NAME /usr/local/bin/healthcheck; do
  sleep 0.5
done

echo Starting stress test
for i in $(seq 1 100); do 
  docker exec -ti irods runuser -u irods -- iadmin lu
done
