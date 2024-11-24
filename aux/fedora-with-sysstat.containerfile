# Use Fedora as the base image
FROM fedora:latest

# Install sysstat and clean up cache to keep the image small
RUN dnf install -y sysstat && \
    dnf clean all

# Set the entry point for the container (optional)
ENTRYPOINT ["/bin/bash"]
