# Dockerfile for Railway deployment
# This runs the Windmill application
# Databases should be deployed as separate Railway PostgreSQL services

FROM ghcr.io/windmill-labs/windmill:latest

# Expose the default Windmill port
EXPOSE 8000

# Copy Windmill configuration
COPY ./windmill /usr/src/app

# Set working directory
WORKDIR /usr/src/app

# Railway will automatically set PORT environment variable
# Windmill uses port 8000 by default
ENV PORT=8000

# The Windmill image already has a startup command, so we don't need to override it
# CMD is already set in the base image
# Note: Railway handles healthchecks via railway.json
