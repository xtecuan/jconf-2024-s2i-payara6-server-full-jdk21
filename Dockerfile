FROM registry.redhat.io/ubi9/openjdk-21:latest
LABEL maintainer="Julian Tadeo Rivera-Pineda <xtecuan@protonmail.com>"
LABEL io.k8s.description="Platform for building Jakarta EE Applications using Payara6 Server Full jdk21" \
      io.k8s.display-name="builder Payara6-Server-Full-jdk21" \
      io.openshift.expose-services="8080:http,8181:https,4848:https" \
      io.openshift.tags="builder,Payara6-Server-Full-jdk21,Java,JakartaEE" \
      org.jboss.deployments-dir="/opt/payara/appserver/glassfish/domains/production/autodeploy" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i"

# Default glassfish ports to expose
# 4848: admin console
# 9009: debug port (JPDA)
# 8080: http
# 8181: https
EXPOSE 4848 9009 8080 8181
ENV PAYARA_VERSION=6.2024.10
ENV PAYARA_PKG=http://nexus.crc.testing:8081/repository/xtesoft-binary-resources/jconf2024/payara-6/payara-${PAYARA_VERSION}.zip
ENV PAYARA_SHA1=7387b9f76dbda96349b3a33e49b5bf65b379d5c4
ENV TINI_VERSION=v0.18.0
ENV TINI_SHA1=f5ecc50719e8f3c94b3d36c38349002e10f2032f
# Initialize the configurable environment variables
ENV VAR1=julian.rivera
ENV DOMAIN_NAME=production
ENV HOME_DIR=/opt/payara\
    PAYARA_DIR=/opt/payara/appserver\
    SCRIPT_DIR=/opt/payara/scripts\
    CONFIG_DIR=/opt/payara/config\
    DEPLOY_DIR=/opt/payara/deployments\
    OC_DEPLOYMENT_DIR=/deployments\
    PASSWORD_FILE=/opt/payara/passwordFile\
    # glassfish Server Domain options
    DOMAIN_DEFAULT=domain1\
    #DOMAIN_NAME=spi\
    ADMIN_USER=admin\
    ADMIN_PASSWORD=adminadmin\
    # Utility environment variables
    JVM_ARGS=\
    GLASSFISH_ARGS=\
    DEPLOY_PROPS=\
    POSTBOOT_COMMANDS=/opt/payara/config/post-boot-commands.asadmin\
    POSTBOOT_COMMANDS_FINAL=/opt/payara/config/post-boot-commands-final.asadmin\
    PREBOOT_COMMANDS=/opt/payara/config/pre-boot-commands.asadmin \
    PREBOOT_COMMANDS_FINAL=/opt/payara/config/pre-boot-commands-final.asadmin
    #DEPLOY_ENV=dev

ENV PATH="${PATH}:${PAYARA_DIR}/bin"
ENV BUILDER_VERSION 1.0
ENV HTTP_PROXY $HTTP_PROXY
ENV HTTPS_PROXY $HTTPS_PROXY
ENV TZ="America/El_Salvador"

USER root

#Set the timezone
RUN rm -f /etc/localtime && ln -s /usr/share/zoneinfo/${TZ} /etc/localtime




# Create and set the glassfish user and working directory owned by the new user

RUN mkdir -p ${CONFIG_DIR} && \
    mkdir -p ${CONFIG_DIR}/dev && \
    mkdir -p ${CONFIG_DIR}/qa && \
    mkdir -p ${CONFIG_DIR}/prod && \
    mkdir -p ${SCRIPT_DIR} && \
    mkdir -p ${HOME_DIR}/bin && \
    mkdir -p ${HOME_DIR}/bin/init.d && \
    ln -s ${OC_DEPLOYMENT_DIR}  ${DEPLOY_DIR} && \
    chown -R default:1001 ${HOME_DIR} && \
    # Install required packages
    microdnf install -y wget unzip nano && \
    microdnf install tzdata -y && \
    microdnf install fontconfig -y && \
    microdnf install dejavu-sans-fonts -y && \
    microdnf install jq -y && \
    microdnf install openssl -y && \
    date && \
    microdnf clean all -y && \
    chgrp -R 0 ${HOME_DIR} && \
    chmod -R g+rwX ${HOME_DIR}

# Install tini as minimized init system
RUN wget --no-verbose -O /tini    http://nexus.crc.testing:8081/repository/xtesoft-binary-resources/tini/v0.18.0/tini/tini  && \
    echo "${TINI_SHA1} /tini" | sha1sum -c - && \
    chmod +x /tini


# TODO: Copy the S2I scripts to /usr/libexec/s2i, since openshift/base-centos7 image
# sets io.openshift.s2i.scripts-url label that way, or update that label
COPY ./s2i/bin/ /usr/libexec/s2i

# Patch s2i-core on /opt/jboss/container/s2i/core
COPY --chown=default:1001 s2i/core/s2i-core ${JBOSS_CONTAINER_S2I_CORE_MODULE}
RUN chmod a+x ${JBOSS_CONTAINER_S2I_CORE_MODULE}/s2i-core


# Copy across docker scripts
COPY --chown=default:1001 bin/*.sh ${SCRIPT_DIR}/
RUN mkdir -p ${SCRIPT_DIR}/init.d && \
    chmod +x ${SCRIPT_DIR}/*

#COPY --chown=default:1001  scripts/bin/*.sh $HOME_DIR/bin
#ENV PATH=$PATH:$HOME_DIR/bin
#COPY --chown=default:1001  scripts/init.d/*.sh $HOME_DIR/bin/init.d
#ENV PATH=$PATH:$HOME_DIR/bin/init.d
#RUN chmod a+x $HOME_DIR/bin/*.sh && \
#    chmod a+x $HOME_DIR/bin/init.d/*.sh


USER 1001
WORKDIR ${HOME_DIR}

# Download and unzip the glassfish distribution
RUN wget --no-verbose -O payara.zip ${PAYARA_PKG} && \
    echo "${PAYARA_SHA1} *payara.zip" | sha1sum -c - && \
    unzip -qq payara.zip -d ./ && \
    mv payara*/ appserver && \
    # Configure the password file for configuring glassfish
    ADMIN_PASSWORD=${ADMIN_PASSWORD} && \
    export AS_ADMIN_PASSWORD=${ADMIN_PASSWORD} && \
    echo "AS_ADMIN_PASSWORD=\nAS_ADMIN_NEWPASSWORD=${ADMIN_PASSWORD}" > /tmp/tmpfile && \
    echo "AS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" >> ${PASSWORD_FILE} && \
    # Configure the glassfish domain
    ${PAYARA_DIR}/bin/asadmin delete-domain ${DOMAIN_DEFAULT} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER}  --passwordfile=${PASSWORD_FILE} create-domain ${DOMAIN_NAME} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER}  --passwordfile=${PASSWORD_FILE} start-domain ${DOMAIN_NAME} && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER}  --passwordfile=${PASSWORD_FILE} enable-secure-admin && \
    for MEMORY_JVM_OPTION in $(${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER}  --passwordfile=${PASSWORD_FILE}  list-jvm-options | grep "Xm[sx]"); do\
        ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER}  --passwordfile=${PASSWORD_FILE}   delete-jvm-options $MEMORY_JVM_OPTION;\
    done && \
    #create-config.sh && \
    #rm -rfv $HOME_DIR/bin/*.sh && \
    #rm -rfv $HOME_DIR/bin/init.d/*.sh && \
    ${PAYARA_DIR}/bin/asadmin --user=${ADMIN_USER}  --passwordfile=${PASSWORD_FILE}  stop-domain ${DOMAIN_NAME} && \
    # Cleanup unused files
    rm -rf \
        /tmp/tmpFile \
        glassfish.zip \
        ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/osgi-cache \
        ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/logs 
        #${PASSWORD_FILE}
USER root
RUN chgrp -R 0 ${HOME_DIR} && \
    chmod -R g=u ${HOME_DIR} 


USER 1001
WORKDIR ${HOME_DIR}

# TODO: Set the default CMD for the image
ENTRYPOINT ["/tini", "--"]
CMD ${SCRIPT_DIR}/entrypoint.sh
#CMD ["/usr/libexec/s2i/usage"]
