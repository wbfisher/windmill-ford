# Railway Dockerfile for Windmill
FROM ghcr.io/windmill-labs/windmill:latest

# Copy Windmill configuration files to the correct location
# Don't overwrite /usr/src/app - use a config directory instead
COPY ./windmill /windmill-config

# Windmill listens on port 8000 by default
EXPOSE 8000

# Set environment to ensure Windmill uses port 8000
# Railway will route external traffic to this port
ENV WM_PORT=8000

# The base Windmill image uses this startup command:
# We keep it as-is, Windmill will use DATABASE_URL from Railway
