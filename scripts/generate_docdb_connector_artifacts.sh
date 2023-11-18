#!/bin/sh
mkdir -p /tmp/certs
cd /tmp
# download mongodb connector package
wget https://repo1.maven.org/maven2/org/mongodb/kafka/mongo-kafka-connect/1.10.0/mongo-kafka-connect-1.10.0-all.jar  -P docdb-connector/mongo-connector/
wget https://github.com/aws-samples/msk-config-providers/releases/download/r0.1.0/msk-config-providers-0.1.0-with-dependencies.zip  -P docdb-connector/msk-config-provi$
unzip docdb-connector/msk-config-providers/msk-config-providers-0.1.0-with-dependencies.zip -d docdb-connector/msk-config-providers/
rm docdb-connector/msk-config-providers/msk-config-providers-0.1.0-with-dependencies.zip
zip -r docdb-connector-plugin.zip docdb-connector

# Generate trust store
mydir=/tmp/certs
truststore=${mydir}/rds-truststore.jks
storepassword=fVfOuHCw

curl -sS "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem" > ${mydir}/global-bundle.pem
awk 'split_after == 1 {n++;split_after=0} /-----END CERTIFICATE-----/ {split_after=1}{print > "rds-ca-" n ".pem"}' < ${mydir}/global-bundle.pem

for CERT in rds-ca-*; do
  alias=$(openssl x509 -noout -text -in $CERT | perl -ne 'next unless /Subject:/; s/.*(CN=|CN = )//; print')
  echo "Importing $alias"
  keytool -import -file ${CERT} -alias "${alias}" -storepass ${storepassword} -keystore ${truststore} -noprompt
  rm $CERT
done

rm ${mydir}/global-bundle.pem

echo "Trust store content is: "

keytool -list -v -keystore "$truststore" -storepass ${storepassword} | grep Alias | cut -d " " -f3- | while read alias
do
   expiry=`keytool -list -v -keystore "$truststore" -storepass ${storepassword} -alias "${alias}" | grep Valid | perl -ne 'if(/until: (.*?)\n/) { print "$1\n"; }'`
   echo " Certificate ${alias} expires in '$expiry'"
done
