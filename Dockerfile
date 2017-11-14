FROM openjdk:8

# Configuration variables.
ENV JIRA_HOME     /var/atlassian/jira
ENV JIRA_INSTALL  /opt/atlassian/jira
ENV JIRA_VERSION  7.5.2
ENV JIRA_USER jirauser
ENV JIRA_GROUP jirauser

# Set User and UserGroup
RUN addgroup ${JIRA_GROUP} \
    && useradd -r -u 999 -g ${JIRA_GROUP} ${JIRA_USER}

# Install helper tools and setup initial home
RUN set -x \
    && echo "deb http://ftp.debian.org/debian jessie-backports main" > /etc/apt/sources.list.d/jessie-backports.list \
    && apt-get update --quiet \
    && apt-get install --quiet --yes --no-install-recommends xmlstarlet \
    && apt-get install --quiet --yes --no-install-recommends -t jessie-backports libtcnative-1 \
    && apt-get clean

# Install Atlassian JIRA and directory structure.
RUN set -x \
    && mkdir -p                "${JIRA_HOME}/caches/indexes" \
    && chmod -R 700            "${JIRA_HOME}" \
    && chown -R ${JIRA_USER}:${JIRA_GROUP}  "${JIRA_HOME}"
    && mkdir -p                "${JIRA_INSTALL}/conf/Catalina" \
    && curl -Ls                "https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${JIRA_VERSION}.tar.gz" | tar -xz --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.38.tar.gz" | tar -xz --directory "${JIRA_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-java-5.1.38/mysql-connector-java-5.1.38-bin.jar" \
    && rm -f                   "${JIRA_INSTALL}/lib/postgresql-9.1-903.jdbc4-atlassian-hosted.jar" \
    && curl -Ls                "https://jdbc.postgresql.org/download/postgresql-9.4.1212.jar" -o "${JIRA_INSTALL}/lib/postgresql-9.4.1212.jar" \
    && chmod -R 700            "${JIRA_INSTALL}" \
    && chown -R ${JIRA_USER}:${JIRA_GROUP}  "${JIRA_INSTALL}" \
    && sed --in-place          "s/java version/openjdk version/g" "${JIRA_INSTALL}/bin/check-java.sh" \
    && echo -e                 "\njira.home=$JIRA_HOME" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    && touch -d "@0"           "${JIRA_INSTALL}/conf/server.xml" \
    && xmlstarlet ed --inplace -s '//Service[@name="Catalina"]' -t "elem" -n 'Connector port="8009" URIEncoding="UTF-8" enableLookups="false" protocol="AJP/1.3"' "${JIRA_INSTALL}/conf/server.xml"

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER jirauser:jirauser

# Expose default HTTP connector port.
EXPOSE 8080 8009

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME /var/atlassian/jira /opt/atlassian/jira/logs

# Set the default working directory as the installation directory.
WORKDIR /var/atlassian/jira

COPY "docker-entrypoint.sh" "/"
ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Atlassian JIRA as a foreground process by default.
CMD ["/opt/atlassian/jira/bin/catalina.sh", "run"]
