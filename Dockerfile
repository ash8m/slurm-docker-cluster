FROM docker.io/almalinux/9-init AS base

LABEL org.opencontainers.image.source="https://github.com/giovtorres/slurm-docker-cluster" \
      org.opencontainers.image.title="slurm-docker-cluster" \
      org.opencontainers.image.description="Slurm Docker cluster on Rocky Linux 8" \
      org.label-schema.docker.cmd="docker-compose up -d" \
      maintainer="Giovanni Torres"

RUN set -ex \
    && yum makecache \
    && yum -y update \
    && yum -y install dnf-plugins-core \
    && yum config-manager --set-enabled crb \
    && yum -y install \
       wget \
       bzip2 \
       perl \
       gcc \
       gcc-c++\
       git \
       gnupg \
       make \
       munge \
       munge-devel \
       python3-devel \
       python3-pip \
       python3 \
       mariadb-server \
       mariadb-devel \
       psmisc \
       bash-completion \
       vim-enhanced \
       http-parser-devel \
       json-c-devel \
       freeipa-client \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN alternatives --install /usr/bin/python python /usr/bin/python3 10

RUN pip3 install Cython pytest

ARG GOSU_VERSION=1.17

RUN set -ex \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

ARG SLURM_TAG

RUN set -x \
    && git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && pushd slurm \
    && ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin  --libdir=/usr/lib64 \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && popd \
    && rm -rf slurm \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm \
    && mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key

COPY slurm.conf /etc/slurm/slurm.conf

FROM base as slurmdbd
COPY slurmdbd/slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN set -x \
    && chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 600 /etc/slurm/slurmdbd.conf
COPY slurmdbd/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

FROM base as slurmctld
# Copy openportal config files into /etc/openportal/
# Copy unit files into systemd's local config dir
# Set their permissions
# Copy helper scripts and set their permissions
# Enable the services so they start when systemd launches

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN git clone https://github.com/isambard-sc/openportal.git && \
    cd openportal && \
    make
RUN cd openportal && \
    cp target/debug/op-cluster /usr/bin/ && \
    cp target/debug/op-slurm /usr/bin/ && \
    cp target/debug/op-filesystem /usr/bin/ && \
    cp target/debug/op-freeipa /usr/bin/
RUN mkdir -p /project /scratch

RUN mkdir /etc/openportal
COPY op-config/* /etc/openportal/
COPY slurmctld/*.service /etc/systemd/system/
COPY op-service/* /etc/systemd/system/
RUN chmod 644 /etc/systemd/system/munged.service \
    && chmod 644 /etc/systemd/system/slurmctld.service \
    && chmod 644 /etc/systemd/system/ipa-enroll.service \
    && chmod 644 /etc/systemd/system/op-*
COPY slurmctld/start-slurmctld.sh /usr/local/bin/start-slurmctld.sh
COPY slurmctld/ipa-enroll.sh /usr/local/bin/ipa-enroll.sh
RUN chmod 755 /usr/local/bin/start-slurmctld.sh \
    && chmod 755 /usr/local/bin/ipa-enroll.sh
RUN systemctl enable munged.service \
    && systemctl enable slurmctld.service \
    && systemctl enable ipa-enroll.service \
    && systemctl enable op-cluster.service \
    && systemctl enable op-filesystem.service \
    && systemctl enable op-slurm.service \
    && systemctl enable op-freeipa.service 
ENTRYPOINT ["/sbin/init"]

FROM base as slurmd
# Copy unit files into systemd's local config dir
# Set their permissions
# Copy helper scripts and set their permissions
# Enable the services so they start when systemd launches
COPY slurmd/munged.service /etc/systemd/system/munged.service
COPY slurmd/slurmd.service /etc/systemd/system/slurmd.service
COPY slurmd/ipa-enroll.service /etc/systemd/system/ipa-enroll.service
RUN chmod 644 /etc/systemd/system/munged.service \
    && chmod 644 /etc/systemd/system/slurmd.service \
    && chmod 644 /etc/systemd/system/ipa-enroll.service
COPY slurmd/start-slurmd.sh /usr/local/bin/start-slurmd.sh
COPY slurmd/ipa-enroll.sh /usr/local/bin/ipa-enroll.sh
RUN chmod 755 /usr/local/bin/start-slurmd.sh \
    && chmod 755 /usr/local/bin/ipa-enroll.sh
RUN systemctl enable munged.service \
    && systemctl enable slurmd.service \
    && systemctl enable ipa-enroll.service
ENTRYPOINT ["/sbin/init"]
