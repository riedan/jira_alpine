FROM adoptopenjdk/openjdk11-openj9:alpine

# Configuration variables.
ENV JIRA_HOME     /var/atlassian/jira
ENV JIRA_INSTALL  /opt/atlassian/jira
ENV JIRA_VERSION  8.2.3

ENV JIRA_USER jira
ENV JIRA_GROUP jira
ENV JVM_MINIMUM_MEMORY 2G
ENV JVM_MAXIMUM_MEMORY 10G
ENV JIRA_SESSION_TIMEOUT 60

ENV JIRA_SSL_PROTOCOL TLS
ENV JIRA_SSL_ENABLE_PROTOCOLS true

#create user if not exist
RUN set -eux; \
	getent group ${JIRA_GROUP} || addgroup -S ${JIRA_GROUP}; \
	getent passwd ${JIRA_USER} || adduser -S ${JIRA_USER}  -G ${JIRA_GROUP} -s "/bin/sh";

# Install Atlassian JIRA and helper tools and setup initial home
# directory structure.
RUN set -x \
    && apk add --no-cache curl xmlstarlet bash ttf-dejavu dos2unix tomcat-native \
    && mkdir -p                				"${JIRA_HOME}" \
    && mkdir -p                				"${JIRA_HOME}/caches/indexes" \
    && chmod -R 700            				"${JIRA_HOME}" \
    && chown -Rf ${JIRA_USER}:${JIRA_GROUP}  "${JIRA_HOME}" \
    && mkdir -p                				"${JIRA_INSTALL}/conf/Catalina" \
    && curl -Ls                				"https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${JIRA_VERSION}.tar.gz" | tar -xz --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
	  && rm -f                   				"${JIRA_INSTALL}/lib/postgresql-9.1-903.jdbc4-atlassian-hosted.jar" \
    && curl -Ls                				"https://jdbc.postgresql.org/download/postgresql-42.2.5.jar" -o "${JIRA_INSTALL}/lib/postgresql-42.2.5.jar" \
    && chmod -Rf 700            				"${JIRA_INSTALL}/conf" \
    && chmod -Rf 700            				"${JIRA_INSTALL}/logs" \
    && chmod -Rf 700            				"${JIRA_INSTALL}/temp" \
    && chmod -Rf 700            				"${JIRA_INSTALL}/work" \
    && chown -Rf ${JIRA_USER}:${JIRA_GROUP}	"${JIRA_INSTALL}/conf" \
    && chown -Rf ${JIRA_USER}:${JIRA_GROUP}	"${JIRA_INSTALL}/logs" \
    && chown -Rf ${JIRA_USER}:${JIRA_GROUP}	"${JIRA_INSTALL}/temp" \
    && chown -Rf ${JIRA_USER}:${JIRA_GROUP}	"${JIRA_INSTALL}/work" \
    && sed --in-place          				"s/java version/openjdk version/g" "${JIRA_INSTALL}/bin/check-java.sh" \
    && echo -e                 				"\njira.home=$JIRA_HOME" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    && touch -d "@0"           				"${JIRA_INSTALL}/conf/server.xml" \
    && sed -i								          "s/<session-timeout>.*<\/session-timeout>/<session-timeout>${JIRA_SESSION_TIMEOUT}<\/session-timeout>/g" "${JIRA_INSTALL}/atlassian-jira/WEB-INF/web.xml" \
	  && sed -i 								        "s/JVM_MINIMUM_MEMORY=.*$/JVM_MINIMUM_MEMORY=${JVM_MINIMUM_MEMORY}/g" "${JIRA_INSTALL}/bin/setenv.sh" \
	  && sed -i 								        "s/JVM_MAXIMUM_MEMORY=.*$/JVM_MAXIMUM_MEMORY=${JVM_MAXIMUM_MEMORY}/g" "${JIRA_INSTALL}/bin/setenv.sh" \
    && sed -i                         "1iJAVA_HOME=${JAVA_HOME}\n" "${JIRA_INSTALL}/bin/setenv.sh"

# Expose default HTTP connector port.
EXPOSE 8080
EXPOSE 8443

COPY "script/docker-entrypoint.sh" "/"
COPY "conf/dbconfig.xml" "${JIRA_INSTALL}"
COPY "conf/server.xml" "${JIRA_INSTALL}/conf/server.xml.ssl"

RUN dos2unix "${JIRA_INSTALL}/dbconfig.xml"
RUN dos2unix "${JIRA_INSTALL}/conf/server.xml.ssl"
RUN dos2unix /docker-entrypoint.sh && apk del dos2unix

#make sure the file can be executed
RUN ["chmod", "+x", "/docker-entrypoint.sh"]




ENTRYPOINT ["/docker-entrypoint.sh"]

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/atlassian/jira", "/opt/atlassian/jira/logs"]

# Set the default working directory as the installation directory.
WORKDIR /var/atlassian/jira


# Run Atlassian JIRA as a foreground process by default.
CMD ["sh", "-c", "su - $JIRA_USER -c \"/opt/atlassian/jira/bin/start-jira.sh -fg\"" ]
