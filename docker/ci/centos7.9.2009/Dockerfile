FROM centos:centos7.9.2009

# fix repos for EOL centos
ADD https://raw.githubusercontent.com/AtlasGondal/centos7-eol-repo-fix/main/CentOS-Base.repo /etc/yum.repos.d/
COPY vault-scl.repo /etc/yum.repos.d/
RUN yum install -y epel-release && yum clean all

# install system dependencies
RUN yum install -y git perl-IPC-Cmd zlib-devel libffi-devel libyaml-devel perl-CPAN \
    devtoolset-11 devtoolset-11-elfutils-libelf-devel curl

# enable devtoolset by default
RUN echo "source /opt/rh/devtoolset-11/enable" >> /etc/profile.d/devtoolset-11.sh

# install cmake
ARG CMAKE_VERSION=3.24.4
RUN mkdir -p /usr/local/cmake && \
    curl -Ls https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-x86_64.tar.gz | \
    tar xz -C /usr/local/cmake --strip-components 1 && \
    ln -s /usr/local/cmake/bin/cmake /usr/bin

# install required perl modules
RUN perl -e 'use List::Util qw(pairs)' || cpan List::Util || cpan List::Util

# install asdf for ruby version management
ADD https://github.com/asdf-vm/asdf/releases/download/v0.16.7/asdf-v0.16.7-linux-amd64.tar.gz /tmp/asdf.tgz
RUN cd /usr/local/bin && tar xzf /tmp/asdf.tgz
ENV ASDF_DATA_DIR=/opt/asdf
ENV PATH="${ASDF_DATA_DIR}/bin:${ASDF_DATA_DIR}/shims:${PATH}"

# install ruby versions
RUN asdf plugin add ruby && \
    asdf install ruby 3.1.2 && \
    asdf install ruby 3.3.7
RUN asdf set -u ruby 3.3.7

# profile.d scripts for interactive shells
RUN echo "PATH=${ASDF_DATA_DIR}/shims:${ASDF_DATA_DIR}/bin:\$PATH" >> /etc/profile.d/asdf.sh

# direct ENV vars for basic non-interactive shells
ENV LD_LIBRARY_PATH="/opt/rh/devtoolset-11/root/usr/lib64:/opt/rh/devtoolset-11/root/usr/lib:${LD_LIBRARY_PATH}"
ENV CC="/opt/rh/devtoolset-11/root/usr/bin/gcc"
ENV CXX="/opt/rh/devtoolset-11/root/usr/bin/g++"

# entrypoint wrapper for robust command execution
RUN echo '#!/bin/bash\nsource /etc/profile.d/asdf.sh\nsource /etc/profile.d/devtoolset-11.sh\nexec "$@"' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
