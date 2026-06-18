#!/usr/bin/env bash

openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -out ca.crt \
  -subj "/C=BR/ST=Local/L=Local/O=MinhaCA/CN=cerberus.local CA"
openssl genrsa -out cerberus.key 4096

cat << EOF > cerberus.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = cerberus.local
DNS.2 = *.cerberus.local
EOF

openssl req -new -key cerberus.key -out cerberus.csr \
  -subj "/C=BR/ST=Local/L=Local/O=MinhaOrg/CN=cerberus.local"

openssl x509 -req -in cerberus.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out cerberus.crt -days 825 \
  -sha256 -extfile cerberus.ext
