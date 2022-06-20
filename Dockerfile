ARG UBUNTU_VERSION=20.04
ARG OPEN5GS_TAG=v2.4.8

FROM ubuntu:${UBUNTU_VERSION} as open5gs-builder 
LABEL open5gs-builder=true 
ARG OPEN5GS_REPO=https://github.com/open5gs/open5gs
ARG OPEN5GS_TAG=${OPEN5GS_TAG}

RUN apt update && \ 
    DEBIAN_FRONTEND=noninteractive apt install -y \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        ninja-build \
        build-essential \
        flex \
        bison \
        git \ 
        libsctp-dev \ 
        libgnutls28-dev \ 
        libgcrypt-dev \ 
        libssl-dev \ 
        libidn11-dev \ 
        libmongoc-dev \ 
        libbson-dev \ 
        libyaml-dev \
        libnghttp2-dev \ 
        libmicrohttpd-dev \ 
        libcurl4-gnutls-dev \ 
        libnghttp2-dev \ 
        libtins-dev \
        libtalloc-dev \
        meson \
    && mkdir open5gs \
    && git clone $OPEN5GS_REPO open5gs \
    && cd open5gs \
    && git checkout ${OPEN5GS_TAG} \
    && meson build --prefix=`pwd`/install \
    && ninja -C build \
    && cd build \
    && ninja install


FROM ubuntu:${UBUNTU_VERSION}
ARG DIR_INSTALL=/open5gs/install
ARG DIR_CONFIGS=/open5gs/configs

RUN apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y \
        flex \
        bison \
        libgnutls28-dev \
        libgcrypt-dev \
        libssl-dev \
        libidn11-dev \
        libmongoc-dev \
        libbson-dev \
        libsctp-dev \
        libyaml-dev \
        libmicrohttpd-dev \
        libcurl4-gnutls-dev \
        libnghttp2-dev \
        libtins-dev \
        libtalloc-dev \        
        iproute2 \ 
        iptables \
        iputils-ping \ 
        tcpdump \
        net-tools \
        less

COPY --from=open5gs-builder ${DIR_INSTALL}/bin/ /usr/bin/
COPY --from=open5gs-builder ${DIR_INSTALL}/etc/open5gs/*.yaml /open5gs/install/etc/open5gs/
COPY --from=open5gs-builder ${DIR_INSTALL}/etc/freeDiameter/  /open5gs/install/etc/freeDiameter/
COPY --from=open5gs-builder ${DIR_INSTALL}/lib/*/libogs*.so* /usr/lib/x86_64-linux-gnu/
COPY --from=open5gs-builder ${DIR_INSTALL}/lib/*/libfd*.so* /usr/lib/x86_64-linux-gnu/
COPY --from=open5gs-builder ${DIR_INSTALL}/lib/*/freeDiameter/*.fdx /open5gs/install/lib/x86_64-linux-gnu/freeDiameter/
COPY --from=open5gs-builder ${DIR_CONFIGS}/freeDiameter/*.pem /open5gs/install/etc/freeDiameter/
COPY --from=open5gs-builder ${DIR_INSTALL}/../misc/db/open5gs-dbctl /usr/bin

RUN mkdir -p /open5gs/install/var/log/open5gs

