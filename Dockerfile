# Start from an Ubuntu base
FROM ubuntu:22.04

# --- SRCML SETUP ---

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages (incl. Python for server)
RUN apt-get update && \
    apt-get install -y \
    curl zip g++ make ninja-build antlr libantlr-dev \
    libxml2-dev libxml2-utils libxslt1-dev \
    libarchive-dev libssl-dev libcurl4-openssl-dev \
    cpio man file dpkg-dev \
    cmake python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Add srcML include files
RUN curl -L http://www.sdml.cs.kent.edu/build/srcML-1.0.0-Boost.tar.gz | \
    tar xz -C /usr/local/include

RUN mkdir -p /srcml/build

COPY ./srcml /srcml

WORKDIR /srcml/build

RUN cmake .. -G Ninja && \
    cmake --build . --config Release --target install

# Set ldconfig so installed libs are linked and available
RUN ldconfig

# --- SERVER SETUP ---

# Install Python packages for server
RUN pip3 install fastapi uvicorn python-multipart

# Add FastAPI server app
COPY ./server/server.py /app/server.py
WORKDIR /app

# Expose port
EXPOSE 8000

# Start FastAPI server
CMD ["uvicorn", "server:app", "--port", "8000"]

