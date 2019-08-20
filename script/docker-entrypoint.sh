#!/bin/bash

if [  "$(ls -A /certs/)" ]; then
  cp /certs/* /usr/local/share/ca-certificates/
  update-ca-certificates
fi


getent group ${JIRA_GROUP} || addgroup -S ${JIRA_GROUP}
getent passwd ${JIRA_USER} || adduser -S ${JIRA_USER}  -G ${JIRA_GROUP} -s "/bin/sh"

homedir=$( getent passwd "${JIRA_USER}" | cut -d: -f6 )

mkdir -p ${homedir}

# check if the `server.xml` file has been changed since the creation of this
# Docker image. If the file has been changed the entrypoint script will not
# perform modifications to the configuration file.
if [ "$(stat -c "%Y" "${JIRA_INSTALL}/conf/server.xml")" -eq "0" ]; then

  if [ -n "${JIRA_CA_P12}" ]; then
    echo "${JIRA_CA_P12}" > "${JIRA_INSTALL}/conf/JIRA.p12.b64"
    base64 -d "${JIRA_INSTALL}/conf/JIRA.p12.b64" > "${JIRA_INSTALL}/conf/JIRA.p12"
    rm "${JIRA_INSTALL}/conf/JIRA.p12.b64"
    JKPASS=$(date +%s | sha256sum | base64 | head -c 32)
    echo $JKPASS > "${JIRA_INSTALL}/conf/jvpass"

    cp "${JIRA_INSTALL}/conf/server.xml" "${JIRA_INSTALL}/conf/server.xml.backup"
    cp "${JIRA_INSTALL}/conf/server.xml.ssl" "${JIRA_INSTALL}/conf/server.xml"
	
	
    ${JAVA_HOME}/bin/keytool -importkeystore -srckeystore "${JIRA_INSTALL}/conf/JIRA.p12" -srcstoretype pkcs12 -srcalias "${JIRA_P12_ALIAS}" -srcstorepass "$JIRA_P12_ST_PASS" -destkeystore "${JIRA_INSTALL}/conf/tomcat-keystore.jks" -deststoretype jks -deststorepass "$JKPASS" -destkeypass "$JKPASS" -destalias host_identity
    chown ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/conf/tomcat-keystore.jks"
    chown ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/conf/JIRA.p12"
    chown ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/conf/jvpass"
    chmod 600 "${JIRA_INSTALL}/conf/jvpass"

    sed -i "s|pathKeystoreFile|${JIRA_INSTALL}/conf/tomcat-keystore.jks|g" "${JIRA_INSTALL}/conf/server.xml"
    sed -i "s/changeit/$JKPASS/g" "${JIRA_INSTALL}/conf/server.xml"

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


  if [ -n "${X_PROXY_NAME}" ]; then
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8080"]' --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${JIRA_INSTALL}/conf/server.xml"
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8443"]' --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_PORT}" ]; then
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8080"]' --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8443"]' --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_SCHEME}" ]; then
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8080"]' --type "attr" --name "scheme" --value "${X_PROXY_SCHEME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ "${X_PROXY_SCHEME}" = "https" ]; then
    xmlstarlet ed -P -S -L --insert '//Connector[@port="8080"]' --type "attr" --name "secure" --value "true" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PATH}" ]; then
    xmlstarlet ed -P -S -L --update '//Context/@path' --value "${X_PATH}" "${JIRA_INSTALL}/conf/server.xml"
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
  chown -Rf ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/conf"
  chown -Rf ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/logs"
  chown -Rf ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/temp"
  chown -Rf ${JIRA_USER}:${JIRA_GROUP} "${JIRA_INSTALL}/work"
fi

if [ "${JIRA_SESSION_TIMEOUT}" -ne 60 ]; then
  sed -i "s/<session-timeout>.*<\/session-timeout>/<session-timeout>${JIRA_SESSION_TIMEOUT}<\/session-timeout>/g" "${JIRA_INSTALL}/atlassian-jira/WEB-INF/web.xml"
fi

if [ -n "${JIRA_DB_USERNAME}" -a -n "${JIRA_DB_PASSWORD}" ]; then

	cp "${JIRA_INSTALL}/dbconfig.xml"  "${JIRA_HOME}/dbconfig.xml"
	chmod 600 "${JIRA_HOME}/dbconfig.xml"
	chown -Rf ${JIRA_USER}:${JIRA_GROUP} "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed -L -u '/jira-database-config/schema-name' -v "${JIRA_DB_SCHEMA}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed -L -u '/jira-database-config/jdbc-datasource/username' -v "${JIRA_DB_USERNAME}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed -L -u '/jira-database-config/jdbc-datasource/password' -v "${JIRA_DB_PASSWORD}" "${JIRA_HOME}/dbconfig.xml"
	xmlstarlet ed -L -u '/jira-database-config/jdbc-datasource/url' -v "jdbc:postgresql://${JIRA_DB_HOSTNAME}:${JIRA_DB_PORT}/${JIRA_DB_NAME}" "${JIRA_HOME}/dbconfig.xml"

fi



exec "$@"
