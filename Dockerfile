# Use Ubuntu latest as the base image
FROM ubuntu:latest

# Create a non-sudo user named 'hadoopuser'
RUN useradd -m -s /bin/bash hadoopuser

# Expose Hadoop ports
EXPOSE 22 9000 50070 12345 8032 8030 8031 8088 8033

# Update package index and install dependencies
RUN apt-get update && \
    apt-get install -y\
    apt-utils \
    openjdk-8-jdk \
    build-essential \
    autoconf \
    libtool \
    libibverbs-dev \
    librdmacm-dev \
    libnuma-dev \
    libssl-dev \
    openmpi-bin \
    libopenmpi-dev \
    libcrypto++-dev \
    maven \
    libsasl2-dev \
    git \
    sudo \
    nano \
    vim \
    openssh-server && \
    apt-get clean

COPY /RDMA /RDMA
RUN chmod -R 777 /RDMA
# Switch to the non-sudo user 'hadoopuser'
USER hadoopuser
# Set the default command to bash
CMD ["bash"]
