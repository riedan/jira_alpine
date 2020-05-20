FROM adoptopenjdk/openjdk8:alpine

# Configuration variables.
ENV JIRA_HOME     /var/atlassian/jira
ENV JIRA_INSTALL_DIR  /opt/atlassian/jira


ENV RUN_USER                                        jira
ENV RUN_GROUP                                       jira
ENV RUN_UID                                         2001
ENV RUN_GID                                         2001

ENV ATL_SSLENABLED 'False'

WORKDIR $JIRA_HOME

# Expose HTTP port
EXPOSE 8080
EXPOSE 8443

CMD ["/entrypoint.py"]
ENTRYPOINT ["tini", "--"]


RUN apk add --no-cache ca-certificates wget curl openssh bash procps openssl perl ttf-dejavu tini python3 py3-jinja2 tzdata tomcat-native fontconfig-dev fontconfig libxtst libxtst-dev cups-libs freetype freetype-dev

# Workaround for AdoptOpenJDK Alpine fontconfig bug
RUN ln -s /lib/libuuid.so.1 /usr/lib/libuuid.so.1 \
    && ln -s /lib/libc.musl-x86_64.so.1 /usr/lib/libc.musl-x86_64.so.1
ENV LD_LIBRARY_PATH /usr/lib

ARG JIRA_VERSION=8.3.4
ARG DOWNLOAD_URL=https://product-downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-${JIRA_VERSION}.tar.gz


#create user if not exist
RUN set -eux; \
	getent group ${RUN_GROUP} || addgroup -g ${RUN_GID} -S ${RUN_GROUP}; \
	getent passwd ${RUN_USER} || adduser --uid ${RUN_UID}  -S ${RUN_USER}  -G ${RUN_GROUP} -s "/bin/bash";

# Install Atlassian JIRA and helper tools and setup initial home
# directory structure.
RUN set -x \
  && mkdir -p                                     ${JIRA_INSTALL_DIR} \
  && curl -L --silent                             ${DOWNLOAD_URL} | tar -xz --strip-components=1 -C "${JIRA_INSTALL_DIR}" \
  && rm -f                   				              "${JIRA_INSTALL_DIR}/lib/postgresql-9.4.1212.jar" \
  && curl -Ls                				              "https://jdbc.postgresql.org/download/postgresql-42.2.9.jar" -o "${JIRA_INSTALL_DIR}/lib/postgresql-42.2.9.jar" \
  && chmod -R "u=rwX,g=rX,o=rX"                   ${JIRA_INSTALL_DIR}/ \
  && chown -R root.                               ${JIRA_INSTALL_DIR}/ \
  && chown -R ${RUN_USER}:${RUN_GROUP}            ${JIRA_INSTALL_DIR}/logs \
  && chown -R ${RUN_USER}:${RUN_GROUP}            ${JIRA_INSTALL_DIR}/temp \
  && chown -R ${RUN_USER}:${RUN_GROUP}            ${JIRA_INSTALL_DIR}/work \
  \
  && sed -i -e 's/^JVM_SUPPORT_RECOMMENDED_ARGS=""$/: \${JVM_SUPPORT_RECOMMENDED_ARGS:=""}/g' ${JIRA_INSTALL_DIR}/bin/setenv.sh \
  && sed -i -e 's/^JVM_\(.*\)_MEMORY="\(.*\)"$/: \${JVM_\1_MEMORY:=\2}/g' ${JIRA_INSTALL_DIR}/bin/setenv.sh \
  \
  && touch /etc/container_id \
  && chown ${RUN_USER}:${RUN_GROUP}               /etc/container_id \
  && chown -R ${RUN_USER}:${RUN_GROUP}            ${JIRA_HOME}

VOLUME ["${JIRA_HOME}"] # Must be declared after setting perms

COPY entrypoint.py \
     shared-components/image/entrypoint_helpers.py  /
COPY shared-components/support                      /opt/atlassian/support
COPY config/*                                       /opt/atlassian/etc/


RUN chmod +x /entrypoint.py
RUN chmod +x /entrypoint_helpers.py
