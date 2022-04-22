FROM registry.access.redhat.com/ubi8/podman:latest 

# These should be overridden in template deployment to interact with Azure service
ENV AZP_URL=http://dummyurl \
    AZP_POOL=Default \
    AZP_TOKEN=token \
    AZP_AGENT_NAME=myagent
# If a working directory was specified, create that directory
ENV AZP_WORK=/_work
ARG AZP_AGENT_VERSION=2.187.2
ARG OPENSHIFT_VERSION=4.9.7
ENV OPENSHIFT_BINARY_FILE="openshift-client-linux-${OPENSHIFT_VERSION}.tar.gz" \
    OPENSHIFT_4_CLIENT_BINARY_URL=https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_VERSION}/${OPENSHIFT_BINARY_FILE} \
    _BUILDAH_STARTED_IN_USERNS="" \
    BUILDAH_ISOLATION=chroot \
    STORAGE_DRIVER=vfs \
    HOME=/home/podman

USER root

# Setup for azure and tools
RUN dnf update -y && \
    dnf install -y --setopt=tsflags=nodocs git skopeo podman-docker --exclude container-selinux && \
    dnf install -y --setopt=tsflags=nodocs java-1.8.0-openjdk-devel java-11-openjdk-devel && \
    dnf clean all && \
    chown -R podman:0 /home/podman && \
    chmod -R 775 /home/podman && \
    chmod -R 775 /etc/alternatives && \
    chmod -R 775 /var/lib/alternatives && \
    chmod -R 775 /usr/lib/jvm && \
    chmod -R 775 /usr/bin && \
    chmod 775 /usr/share/man/man1 && \
    mkdir -p /var/lib/origin && \
    chmod 775 /var/lib/origin && \
    chmod u-s /usr/bin/newuidmap && \
    chmod u-s /usr/bin/newgidmap && \
    rm -f /var/logs/* && \
    mkdir -p "$AZP_WORK" && \
    mkdir -p /azp/agent/_diag && \
    mkdir -p /usr/local/bin 

WORKDIR $HOME

# Get the oc binary
RUN curl  ${OPENSHIFT_4_CLIENT_BINARY_URL} > ${OPENSHIFT_BINARY_FILE} && \
    tar xzf ${OPENSHIFT_BINARY_FILE} -C /usr/local/bin &&  \
    rm -rf ${OPENSHIFT_BINARY_FILE} && \
    chmod +x /usr/local/bin/oc 

# Configure Azure specific JDK variables
ENV JAVA_HOME_8_X64=/etc/alternatives/java_sdk_1.8.0 \
    JAVA_HOME_11_X64=/etc/alternatives/java_sdk_11
        
# Download and extract the agent package
RUN curl https://vstsagentpackage.azureedge.net/agent/$AZP_AGENT_VERSION/vsts-agent-linux-x64-$AZP_AGENT_VERSION.tar.gz > vsts-agent-linux-x64-$AZP_AGENT_VERSION.tar.gz && \
    tar zxvf vsts-agent-linux-x64-$AZP_AGENT_VERSION.tar.gz && \
    rm -rf vsts-agent-linux-x64-$AZP_AGENT_VERSION.tar.gz 

# Install the agent software
RUN /bin/bash -c 'chmod +x ./bin/installdependencies.sh' && \
    /bin/bash -c './bin/installdependencies.sh' && \
    chmod -R 775 "$AZP_WORK" && \
    chown -R podman:root "$AZP_WORK" && \
    chmod -R 775 /azp && \
    chown -R podman:root /azp

USER 1000

# AgentService.js understands how to handle agent self-update and restart
ENTRYPOINT /bin/bash -c '/azp/agent/bin/Agent.Listener configure --unattended \
  --agent "${AZP_AGENT_NAME}-${MY_POD_NAME}" \
  --url "$AZP_URL" \
  --auth PAT \
  --token "$AZP_TOKEN" \
  --pool "${AZP_POOL}" \
  --work /_work \
  --replace \
  --acceptTeeEula && \
   /azp/agent/externals/node/bin/node /azp/agent/bin/AgentService.js interactive --once'



