# Docker Alpine Curl

Like it says, it's a docker image built with jira on openjdk:8-alpine with curl and bash

Available from docker hub as [riedan/jira_alpine](https://hub.docker.com/r/riedan/jira_alpine)

## Usage

    docker run riedan/jira_alpine
    
 Then simply navigate your preferred browser to `http://[dockerhost]:8080` and finish the configuration.
    
## Configuration

You can configure a small set of things by supplying the following environment variables

| Environment Variable   | Description |
| ---------------------- | ----------- |
| X_PROXY_NAME           | Sets the Tomcat Connectors `ProxyName` attribute |
| X_PROXY_PORT           | Sets the Tomcat Connectors `ProxyPort` attribute |
| X_PROXY_SCHEME         | If set to `https` the Tomcat Connectors `secure=true` and `redirectPort` equal to `X_PROXY_PORT`   |
| X_PATH                 | Sets the Tomcat connectors `path` attribute |
| JIRA_USER              | TODO |
| JIRA_GROUP             | TODO |
| JVM_MINIMUM_MEMORY     | TODO |
| JVM_MAXIMUM_MEMORY     | TODO |
| JIRA_HOME              | TODO |
| JIRA_SESSION_TIMEOUT   | TODO |
| JIRA_DB_USERNAME       | TODO |
| JIRA_DB_PASSWORD       | TODO |
| JIRA_DB_HOSTNAME       | TODO |
| JIRA_DB_PORT           | TODO |
| JIRA_DB_SCHEMA         | TODO |
| JIRA_DB_PORT           | TODO |
| JIRA_CA_P12            | TODO |
| JIRA_P12_ALIAS         | TODO |
| $JIRA_P12_ST_PASS      | TODO |
| JIRA_SSL_PROTOCOL      | TODO |
| JIRA_SSL_ENABLE_PROTOCOLS | TODO |
