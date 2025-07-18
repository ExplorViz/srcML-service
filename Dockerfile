# Start from an Ubuntu base
FROM ubuntu:22.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    curl zip g++ make ninja-build antlr libantlr-dev \
    libxml2-dev libxml2-utils libxslt1-dev \
    libarchive-dev libssl-dev libcurl4-openssl-dev \
    cpio man file dpkg-dev \
    cmake && \
    rm -rf /var/lib/apt/lists/*

# Add srcML include files
RUN curl -L http://www.sdml.cs.kent.edu/build/srcML-1.0.0-Boost.tar.gz | \
    tar xz -C /usr/local/include

# Create build directory
RUN mkdir -p /srcml/build

# Copy your source code into the container (update `.` as needed)
COPY . /srcml

# Set working directory
WORKDIR /srcml/build

# Configure and build using CMake and Ninja
RUN cmake .. -G Ninja && \
    cmake --build . --config Release --target install

# Set ldconfig so installed libs are available
RUN ldconfig

# Validate srcML works (can be used in entrypoint or test phase)
RUN srcml --version && \
    srcml --text="int a;" -l C++

# Default command (can be overridden)
ENTRYPOINT [ "srcml" ]

