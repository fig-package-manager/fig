# syntax=docker/dockerfile:1.4
FROM rockylinux:9

RUN yum install --enablerepo=devel -y git @Development perl-IPC-Cmd zlib-devel libffi-devel libyaml-devel perl-FindBin perl-Pod-Html && yum clean all

ADD https://github.com/asdf-vm/asdf/releases/download/v0.16.7/asdf-v0.16.7-linux-amd64.tar.gz /tmp/asdf.tgz
RUN cd /usr/local/bin && tar xzf /tmp/asdf.tgz && rm -f /tmp/asdf.tgz
ENV ASDF_DATA_DIR=/opt/asdf
RUN echo "PATH=$ASDF_DATA_DIR/shims:\$PATH" >> /etc/profile.d/asdf.sh && . /etc/profile.d/asdf.sh
RUN asdf plugin add ruby

# Define Ruby versions as build args
ARG RUBY_VERSIONS="3.1.2 3.3.7"
ARG DEFAULT_RUBY="3.3.7"

# Install specified Ruby versions
RUN for version in $RUBY_VERSIONS; do \
      asdf install ruby $version; \
    done && \
    rm -f /tmp/ruby-build.* && \
    asdf set -u ruby $DEFAULT_RUBY

# Install cmake
ARG CMAKE_VERSION=3.24.4
RUN mkdir -p /usr/local/cmake && curl -Ls https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-x86_64.tar.gz | tar xz -C /usr/local/cmake --strip-components 1 && \
    ln -s /usr/local/cmake/bin/cmake /usr/bin

# Install GitHub CLI (distro-agnostic method)
ARG GH_VERSION=2.46.0
RUN mkdir -p /usr/local/gh && \
    curl -Ls https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz | \
    tar xz -C /usr/local/gh --strip-components 1 && \
    ln -s /usr/local/gh/bin/gh /usr/bin/gh

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
