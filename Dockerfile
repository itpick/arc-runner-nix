# Stage 1: Build nix tools and extract only what's needed
FROM nixos/nix:latest AS nix-builder

# Disable seccomp for buildx compatibility
RUN mkdir -p /etc/nix && echo "filter-syscalls = false" >> /etc/nix/nix.conf

# Install tools and collect the closure
RUN nix-channel --update && \
    nix-env -iA nixpkgs.skopeo nixpkgs.jq nixpkgs.cosign nixpkgs.syft && \
    # Get only the required store paths (closure) for the profile
    nix-store --query --requisites /nix/var/nix/profiles/default > /tmp/closure-paths.txt && \
    # Create a minimal nix store with just what we need
    mkdir -p /nix-minimal/nix/store && \
    mkdir -p /nix-minimal/nix/var/nix/profiles && \
    mkdir -p /nix-minimal/nix/var/nix/gcroots && \
    # Copy only the closure
    cat /tmp/closure-paths.txt | xargs -I {} cp -a {} /nix-minimal/nix/store/ && \
    # Copy the profile
    cp -a /nix/var/nix/profiles/default /nix-minimal/nix/var/nix/profiles/ && \
    cp -aL /nix/var/nix/profiles/default /nix-minimal/nix/var/nix/profiles/default-link

# Stage 2: Final runner image
FROM ghcr.io/actions/actions-runner:latest

USER root

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy only the minimal nix closure (not full store)
COPY --from=nix-builder /nix-minimal/nix /nix

# Fix permissions and symlinks
RUN chown -R runner:runner /nix && \
    mkdir -p /home/runner/.nix-profile && \
    ln -sf /nix/var/nix/profiles/default /home/runner/.nix-profile/profile && \
    chown -R runner:runner /home/runner/.nix-profile

# Create containers policy.json for skopeo
RUN mkdir -p /etc/containers && \
    echo '{"default":[{"type":"insecureAcceptAnything"}]}' > /etc/containers/policy.json

# Ensure nix binaries are in PATH
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
ENV SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
ENV NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"

USER runner
