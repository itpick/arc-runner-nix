# Stage 1: Build nix tools
FROM nixos/nix:latest AS nix-builder

# Disable seccomp for buildx compatibility
RUN mkdir -p /etc/nix && echo "filter-syscalls = false" >> /etc/nix/nix.conf

RUN nix-channel --update && \
    nix-env -iA nixpkgs.skopeo nixpkgs.jq nixpkgs.cosign nixpkgs.syft nixpkgs.attic-client

# Stage 2: Final runner image
FROM ghcr.io/actions/actions-runner:latest

USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy nix store from builder
COPY --from=nix-builder /nix /nix

# Set permissions for runner user to use nix
RUN chown -R runner:runner /nix && \
    mkdir -p /home/runner/.nix-profile && \
    ln -s /nix/var/nix/profiles/default /home/runner/.nix-profile && \
    chown -R runner:runner /home/runner/.nix-profile

# Configure nix for experimental features
RUN mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "filter-syscalls = false" >> /etc/nix/nix.conf

# Create containers policy.json for skopeo
RUN mkdir -p /etc/containers && \
    echo '{"default":[{"type":"insecureAcceptAnything"}]}' > /etc/containers/policy.json

# Ensure nix binaries are in PATH
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
ENV NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

USER runner
