# stage 1
FROM tensorflow/tensorflow:latest-gpu as build

RUN apt-get update && apt-get install -y --no-install-recommends \
  cmake libvdpau-dev && \
  rm -rf /var/lib/apt/lists/*

COPY cuda-control.tar /tmp

ARG version

RUN cd /tmp && tar xvf /tmp/cuda-control.tar && \
    cd /tmp/cuda-control && mkdir vcuda-${version} && \
    cd vcuda-${version} && cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make

RUN cd /tmp/cuda-control && tar cf /tmp/vcuda.tar.gz -c vcuda-${version}

# stage 2
FROM centos:7 as rpmpkg

RUN yum install -y rpm-build
RUN mkdir -p /root/rpmbuild/{SPECS,SOURCES}

COPY vcuda.spec /root/rpmbuild/SPECS
COPY --from=build /tmp/vcuda.tar.gz /root/rpmbuild/SOURCES

RUN echo '%_topdir /root/rpmbuild' > /root/.rpmmacros \
  && echo '%__os_install_post %{nil}' >> /root/.rpmmacros \
  && echo '%debug_package %{nil}' >> /root/.rpmmacros

WORKDIR /root/rpmbuild/SPECS

ARG version
ARG commit

RUN rpmbuild -bb --quiet \
  --define 'version '${version}'' \
  --define 'commit '${commit}'' \
  vcuda.spec

# stage 3
FROM tensorflow/tensorflow:latest-gpu

ARG version
ARG commit

RUN apt install -y alien

COPY --from=rpmpkg  /root/rpmbuild/RPMS/x86_64/vcuda-${version}-${commit}.el7.x86_64.rpm /tmp
RUN alien --install /tmp/vcuda-${version}-${commit}.el7.x86_64.rpm

RUN cp /usr/lib64/libcuda-control.so /lib64/libcontroller.so &&\
  cp /usr/lib64/libcuda-control.so /usr/local/cuda/lib64/libcontroller.so &&\
  cp /usr/lib64/libcuda-control.so /usr/local/cuda/lib64/libcuda.so &&\
  cp /usr/lib64/libcuda-control.so /usr/local/cuda/lib64/libcuda.so.1 &&\
  cp /usr/lib64/libcuda-control.so /usr/local/cuda/lib64/libnvidia-ml.so &&\
  cp /usr/lib64/libcuda-control.so /usr/local/cuda/lib64/libnvidia-ml.so.1