# WildFly 21 
FROM jboss/wildfly:21.0.0.Final

# Wildfly Console params
ENV WILDFLY_USER admin
ENV WILDFLY_PASS adminPassword

# Database
ENV DB_NAME personal
ENV DB_USER andrea
ENV DB_PASS password
ENV DB_URI db:3306

ENV MYSQL_VERSION 8.0.22
ENV JBOSS_CLI /opt/jboss/wildfly/bin/jboss-cli.sh
ENV DEPLOYMENT_DIR /opt/jboss/wildfly/standalone/deployments/
#ENV JAVA_OPTS

# Setting up WildFly Admin Console
RUN echo "=> Adding WildFly administrator"
RUN $JBOSS_HOME/bin/add-user.sh -u $WILDFLY_USER -p $WILDFLY_PASS --silent

# Configure Wildfly server
RUN echo "=> Starting WildFly server" && \
      bash -c '$JBOSS_HOME/bin/standalone.sh &' && \
    echo "=> Waiting for the server to boot" && \
      bash -c 'until `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null | grep -q running`; do echo `$JBOSS_CLI -c ":read-attribute(name=server-state)" 2> /dev/null`; sleep 1; done' && \
    echo "=> Downloading MySQL driver" && \
      curl --location --output /tmp/mysql-connector-java-${MYSQL_VERSION}.jar --url http://search.maven.org/remotecontent?filepath=mysql/mysql-connector-java/${MYSQL_VERSION}/mysql-connector-java-${MYSQL_VERSION}.jar && \
    echo "=> Adding MySQL module" && \
      $JBOSS_CLI --connect --command="module add --name=com.mysql --resources=/tmp/mysql-connector-java-${MYSQL_VERSION}.jar --dependencies=javax.api,javax.transaction.api" && \
    echo "=> Adding MySQL driver" && \
      $JBOSS_CLI --connect --command="/subsystem=datasources/jdbc-driver=mysql:add(driver-name=mysql,driver-module-name=com.mysql)" && \
    echo "=> Creating a new datasource" && \
      $JBOSS_CLI --connect --command="data-source add \
        --name=${DB_NAME}DS \
        --jndi-name=java:/${DB_NAME}DS \
        --user-name=${DB_USER} \
        --password=${DB_PASS} \
        --driver-name=mysql \
        --connection-url=jdbc:mysql://${DB_URI}/${DB_NAME}?serverTimezone=UTC \
        --use-ccm=false \
        --max-pool-size=25 \
        --blocking-timeout-wait-millis=5000 \
        --enabled=true" && \
    echo "=> Shutting down WildFly and Cleaning up" && \
      $JBOSS_CLI --connect --command=":shutdown" && \
      rm -rf $JBOSS_HOME/standalone/configuration/standalone_xml_history/ $JBOSS_HOME/standalone/log/* && \
      rm -f /tmp/*.jar

# Expose http, admin ad debug ports
EXPOSE 8080 9990 5005

#echo "=> Restarting WildFly"
# Set the default command to run on boot
# This will boot WildFly in the standalone mode and bind to all interfaces
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0", "--debug", "*:5005"]
