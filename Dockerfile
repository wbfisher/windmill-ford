# Railway Dockerfile for Windmill
# Uses the official Windmill image with Railway-specific configuration

FROM ghcr.io/windmill-labs/windmill:latest

# Copy Windmill configuration files (scripts, flows, apps)
COPY ./windmill /usr/src/app

# Set working directory
WORKDIR /usr/src/app

# Windmill listens on port 8000
# Railway will automatically route public traffic to this port
EXPOSE 8000

# The base Windmill image already includes the startup command
# No need to override CMD
