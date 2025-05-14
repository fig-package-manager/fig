# syntax=docker/dockerfile:1.4
FROM ubuntu:20.04

#RUN yum install --enablerepo=powertools -y git @Development perl-IPC-Cmd zlib-devel libffi-devel libyaml-devel && yum clean all
RUN apt-get update && \
    apt-get install -y git && \
    apt-get install -y curl zlib1g-dev build-essential libyaml-0-2 libffi-dev libyaml-dev && \
    apt-get clean

ADD https://github.com/asdf-vm/asdf/releases/download/v0.16.7/asdf-v0.16.7-linux-amd64.tar.gz /tmp/asdf.tgz
RUN cd /usr/local/bin && tar xzf /tmp/asdf.tgz
ENV ASDF_DATA_DIR=/opt/asdf
RUN echo "PATH=$ASDF_DATA_DIR/shims:\$PATH" >> /etc/profile.d/asdf.sh && . /etc/profile.d/asdf.sh
RUN asdf plugin add ruby

RUN asdf install ruby 3.3.7 && asdf set -u ruby 3.3.7

# Install cmake
ARG CMAKE_VERSION=3.24.4
RUN mkdir -p /usr/local/cmake && curl -Ls https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-x86_64.tar.gz | tar xz -C /usr/local/cmake --strip-components 1 && \
    ln -s /usr/local/cmake/bin/cmake /usr/bin

# entrypoint wrapper for robust command execution
RUN <<'EOR'
cat <<'EOF' >/entrypoint.sh
#!/bin/bash
source /etc/profile
exec "$@"
EOF
chmod +x /entrypoint.sh
EOR

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
