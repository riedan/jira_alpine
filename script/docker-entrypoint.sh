#!/bin/bash

# check if the `server.xml` file has been changed since the creation of this
# Docker image. If the file has been changed the entrypoint script will not
# perform modifications to the configuration file.
if [ "$(stat -c "%Y" "${JIRA_INSTALL}/conf/server.xml")" -eq "0" ]; then
  if [ -n "${X_PROXY_NAME}" ]; then
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8080"]' --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_PORT}" ]; then
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8080"]' --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_SCHEME}" ]; then
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8080"]' --type "attr" --name "scheme" --value "${X_PROXY_SCHEME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ "${X_PROXY_SCHEME}" = "https" ]; then
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8080"]' --type "attr" --name "secure" --value "true" "${JIRA_INSTALL}/conf/server.xml"
    xmlstarlet ed -P -S -L --update '//Connector[@port="8080"]/@redirectPort' --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PATH}" ]; then
    xmlstarlet ed -P -S -L --update '//Context/@path' --value "${X_PATH}" "${JIRA_INSTALL}/conf/server.xml"
  fi

  if [ -n "${JIRA_CA_P12}" ]; then
    echo "${JIRA_CA_P12}" > "${JIRA_INSTALL}/conf/JIRA.p12.b64"
    base64 -d "${JIRA_INSTALL}/conf/JIRA.p12.b64" > "${JIRA_INSTALL}/conf/JIRA.p12"
    rm "${JIRA_INSTALL}/conf/JIRA.p12.b64"
    JKPASS=$(date +%s | sha256sum | base64 | head -c 32)
    echo $JKPASS > "${JIRA_INSTALL}/conf/jvpass"

    ${JAVA_HOME}/bin/keytool -importkeystore -srckeystore "${JIRA_INSTALL}/conf/JIRA.p12" -srcstoretype pkcs12 -srcalias "${JIRA_P12_ALIAS}" -srcstorepass "$JIRA_P12_ST_PASS" -destkeystore "${JIRA_INSTALL}/conf/tomcat-keystore.jks" -deststoretype jks -deststorepass "$JKPASS" -destkeypass "$JKPASS" -destalias host_identity
    chown ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/conf/tomcat-keystore.jks"
    chown ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/conf/JIRA.p12"
    chown ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/conf/jvpass"
    chmod 700 "${JIRA_INSTALL}/conf/jvpass"


     # from https://confluence.atlassian.com/adminjiraserver/running-jira-applications-over-ssl-or-https-938847764.html
    xmlstarlet ed -P -S -L -s '/Server/Service' -t elem -n ConnectorTMP -v "" \
        -i //ConnectorTMP -t attr -n "protocol" -v "org.apache.coyote.http11.Http11NioProtocol" \
        -i //ConnectorTMP -t attr -n "maxHttpHeaderSize" -v "8192" \
        -i //ConnectorTMP -t attr -n "acceptCount" -v "100" \
        -i //ConnectorTMP -t attr -n "enableLookups" -v "false" \
        -i //ConnectorTMP -t attr -n "disableUploadTimeout" -v "true" \
        -i //ConnectorTMP -t attr -n "port" -v "8443" \
        -i //ConnectorTMP -t attr -n "scheme" -v "https" \
        -i //ConnectorTMP -t attr -n "maxThreads" -v "150" \
        -i //ConnectorTMP -t attr -n "secure" -v "true" \
        -i //ConnectorTMP -t attr -n "SSLEnabled" -v "true" \
        -i //ConnectorTMP -t attr -n "keystoreFile" -v "${JIRA_INSTALL}/conf/tomcat-keystore.jks" \
        -i //ConnectorTMP -t attr -n "keystorePass" -v "$JKPASS" \
        -i //ConnectorTMP -t attr -n "clientAuth" -v "false" \
        -i //ConnectorTMP -t attr -n "sslEnabledProtocols" -v "$JIRA_SSL_ENABLE_PROTOCOLS" \
        -i //ConnectorTMP -t attr -n "useBodyEncodingForURI" -v "true" \
        -i //ConnectorTMP -t attr -n "keystoreType" -v "JKS" \
        -r //ConnectorTMP -v Connector \
        "${JIRA_INSTALL}/conf/server.xml"

     xmlstarlet ed -P -S -L --update '//Connector[@port="8080"]/@redirectPort'  -v "8443" "${JIRA_INSTALL}/conf/server.xml"
     xmlstarlet ed -P -S -L -u '//Connector[@port="8080"]/@relaxedQueryChars'  --value "[]|" "${JIRA_INSTALL}/conf/server.xml"
     xmlstarlet ed -P -S -u '//Connector[@port="8080"]/@relaxedPathChars' --value "[]|{}^&#x5c;&#x60;&quot;&lt;&gt;" "${JIRA_INSTALL}/conf/server.xml" | sed 's/\&amp;/\&/g' > "${JIRA_INSTALL}/conf/server.xml"

    xmlstarlet ed -P -S -L -N x="http://java.sun.com/xml/ns/javaee" -s "/x:web-app" -t elem -n "security-constraintTMP" -v "" \
        -s "/x:web-app/security-constraintTMP" -t elem -n "web-resource-collectionTMP" -v "" \
        -s "///web-resource-collectionTMP" -t elem -n "web-resource-name" -v "all-except-attachments" \
        -s "///web-resource-collectionTMP" -t elem -n "url-pattern" -v "*.jsp" \
        -s "///web-resource-collectionTMP" -t elem -n "url-pattern" -v "*.jspa" \
        -s "///web-resource-collectionTMP" -t elem -n "url-pattern" -v "/browse/*" \
        -s "///web-resource-collectionTMP" -t elem -n "url-pattern" -v "/issues/*" \
        -s "/x:web-app/security-constraintTMP" -t elem -n "user-data-constraintTMP" -v "" \
        -s "///user-data-constraintTMP" -t elem -n "transport-guarantee" -v "CONFIDENTIAL" \
        -r "//security-constraintTMP" -v "security-constraint" \
        -r "///web-resource-collectionTMP" -v "web-resource-collection" \
        -r "///user-data-constraintTMP" -v "user-data-constraint" \
        "${JIRA_INSTALL}/atlassian-jira/WEB-INF/web.xml"

    unset JIRA_P12_ST_PASS
    unset JIRA_CA_P12
    unset JKPASS

    rm "${JIRA_INSTALL}/conf/JIRA.p12"
  fi
fi

if [ "${JVM_MINIMUM_MEMORY}" != "2G" ]; then
	sed -i 	"s/JVM_MINIMUM_MEMORY=.*$/JVM_MINIMUM_MEMORY=${JVM_MINIMUM_MEMORY}/g" "${JIRA_INSTALL}/bin/setenv.sh"

fi 
 
if [ "${JVM_MAXIMUM_MEMORY}" != "10G" ]; then
  sed -i "s/JVM_MAXIMUM_MEMORY=.*$/JVM_MAXIMUM_MEMORY=${JVM_MAXIMUM_MEMORY}/g" "${JIRA_INSTALL}/bin/setenv.sh" 
fi 

if [ ${JIRA_USER} != "jira" ]; then
  getent group ${JIRA_GROUP} || addgroup -S ${JIRA_GROUP}
  getent passwd ${JIRA_USER} || adduser -S ${JIRA_USER}  -G ${JIRA_GROUP} -s "/bin/bash" -h "${JIRA_HOME}"
  mkdir -p "${JIRA_HOME}"
  mkdir -p "${JIRA_HOME}/caches/indexes"
  chown -R ${JIRA_USER}:${JIRA_GROUP} "${JIRA_HOME}"
  chown -R ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/conf"
  chown -R ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/logs"
  chown -R ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/temp"
  chown -R ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/work"
fi

if [ "${JIRA_SESSION_TIMEOUT}" -ne 60 ]; then
  sed -i "s/<session-timeout>.*<\/session-timeout>/<session-timeout>${JIRA_SESSION_TIMEOUT}<\/session-timeout>/g" "${JIRA_INSTALL}/atlassian-jira/WEB-INF/web.xml"
fi

if [ -n "${JIRA_DB_USERNAME}" -a -n "${JIRA_DB_PASSWORD}" ]; then

	cp "${JIRA_INSTALL}/dbconfig.xml"  "${JIRA_HOME}/dbconfig.xml"
	chmod 700 "${JIRA_HOME}/dbconfig.xml"
	chown -R ${JIRA_USER}:${JIRA_GROUP} "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed -L -u '/jira-database-config/jdbc-datasource/username' -v "${JIRA_DB_USERNAME}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed -L -u '/jira-database-config/jdbc-datasource/password' -v "${JIRA_DB_PASSWORD}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed -L -u '/jira-database-config/jdbc-datasource/url' -v "jdbc:postgresql://${JIRA_DB_HOSTNAME}:${JIRA_DB_PORT}/${JIRA_DB_SCHEMA}" "${JIRA_HOME}/dbconfig.xml"
fi



exec "$@"