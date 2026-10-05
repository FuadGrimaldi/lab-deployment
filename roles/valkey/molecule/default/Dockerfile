FROM ubuntu:noble

RUN apt-get update && \
    apt-get install -y python3 python3-apt gpg apt-utils dpkg-dev sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN chmod 1777 /tmp && chown root:root /tmp

# Set up a non-root user for Ansible to run as
RUN useradd -m -s /bin/bash -G sudo maintainer && \
    echo "maintainer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/maintainer && \
    chmod 0440 /etc/sudoers.d/maintainer
    
CMD ["sleep", "infinity"]