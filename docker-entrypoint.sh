#!/bin/bash

# check if the `server.xml` file has been changed since the creation of this
# Docker image. If the file has been changed the entrypoint script will not
# perform modifications to the configuration file.
if [ "$(stat -c "%Y" "${JIRA_INSTALL}/conf/server.xml")" -eq "0" ]; then
  if [ -n "${X_PROXY_NAME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_PORT}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_SCHEME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "scheme" --value "${X_PROXY_SCHEME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ "${X_PROXY_SCHEME}" = "https" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "secure" --value "true" "${JIRA_INSTALL}/conf/server.xml"
    xmlstarlet ed --inplace --pf --ps --update '//Connector[@port="8080"]/@redirectPort' --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PATH}" ]; then
    xmlstarlet ed --inplace --pf --ps --update '//Context/@path' --value "${X_PATH}" "${JIRA_INSTALL}/conf/server.xml"
  fi
fi

if [ "${JVM_MINIMUM_MEMORY}" != "2G" ]; then
	sed -i 	"s/JVM_MINIMUM_MEMORY=.*\n/JVM_MINIMUM_MEMORY=${JVM_MINIMUM_MEMORY}\n/g" "${JIRA_INSTALL}/bin/user.sh"

fi 
 
if [ "${JVM_MAXIMUM_MEMORY}" != "10G" ]; then
  sed -i "s/JVM_MAXIMUM_MEMORY=.*\n/JVM_MAXIMUM_MEMORY=${JVM_MAXIMUM_MEMORY}\n/g" "${JIRA_INSTALL}/bin/user.sh" 
fi 

if [ "${JIRA_USER}" != "jira" ]; then
  getent group ${JIRA_GROUP} || addgroup -S ${JIRA_GROUP}
  getent passwd ${JIRA_USER} || adduser -S ${JIRA_USER} ${JIRA_GROUP}
  mkdir -p "${JIRA_HOME}" 
  mkdir -p "${JIRA_HOME}/caches/indexes" 
  chmod -R 700 "${JIRA_HOME}" 
  chown -R ${JIRA_USER}:${JIRA_GROUP}  "${JIRA_HOME}" 
  sed -i "s/JIRA=.*\n/JIRA=${JIRA_USER}\n/g" "${JIRA_INSTALL}/bin/user.sh" 
fi  
   
if [ "${JIRA_SESSION_TIMEOUT}" -ne 60 ]; then
  sed -i "s/<session-timeout>.*<\/session-timeout>/<session-timeout>${JIRA_SESSION_TIMEOUT}<\/session-timeout>/g" "${JIRA_INSTALL}/atlassian-jira/WEB-INF/web.xml"
fi
			

exec "$@"