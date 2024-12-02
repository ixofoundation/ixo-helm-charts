FROM rust:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    protobuf-compiler

# Clone and build Hermes
RUN git clone https://github.com/informalsystems/ibc-rs.git /hermes
WORKDIR /hermes
RUN cargo build --release --bin hermes

# Set the executable
RUN mv target/release/hermes /usr/local/bin/hermes
ENTRYPOINT ["hermes"]
