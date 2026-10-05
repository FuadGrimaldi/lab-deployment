FROM ubuntu:noble

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

RUN apt-get update && \
    apt-get install -y python3 python3-apt gpg ca-certificates bash gnupg sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN chmod 1777 /tmp && chown root:root /tmp

RUN useradd -m -s /bin/bash -G sudo maintainer && \
    mkdir -p /etc/sudoers.d && \
    echo "maintainer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/maintainer && \
    chmod 0440 /etc/sudoers.d/maintainer

CMD ["sleep", "infinity"]