# Railway Dockerfile for Windmill
FROM ghcr.io/windmill-labs/windmill:latest

# Install PostgreSQL client for healthchecks
USER root
RUN apt-get update && apt-get install -y postgresql-client curl && rm -rf /var/lib/apt/lists/*

# Copy Windmill configuration files to the correct location
# Don't overwrite /usr/src/app - use a config directory instead
COPY ./windmill /windmill-config

# Create startup script with better error handling
COPY <<'EOF' /startup.sh
#!/bin/bash
set -e

echo "========================================="
echo "Windmill Railway Startup"
echo "========================================="

# Check for required DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    echo "❌ ERROR: DATABASE_URL environment variable is not set!"
    echo ""
    echo "To fix this in Railway:"
    echo "1. Create a PostgreSQL service: New → Database → PostgreSQL"
    echo "2. Name it 'windmill-db'"
    echo "3. Go to your Windmill service → Variables tab"
    echo "4. Add: DATABASE_URL=\${{windmill-db.DATABASE_URL}}"
    echo "5. Add: MODE=standalone"
    echo "6. Add: WM_BASE_URL=https://\${{RAILWAY_PUBLIC_DOMAIN}}"
    echo "7. Redeploy this service"
    echo ""
    echo "See RAILWAY-QUICK-START.md for detailed instructions"
    exit 1
fi

echo "✓ DATABASE_URL is configured"
echo "✓ Starting Windmill on port ${PORT:-8000}"
echo "✓ Mode: ${MODE:-standalone}"
echo "✓ Base URL: ${WM_BASE_URL}"
echo ""

# Start Windmill (the default command from the base image)
exec windmill
EOF

# Create healthcheck script
COPY <<'EOF' /healthcheck.sh
#!/bin/bash
# Healthcheck script that uses the PORT environment variable
curl -f http://localhost:${PORT:-8000}/api/version || exit 1
EOF

RUN chmod +x /startup.sh /healthcheck.sh

# Windmill listens on port 8000 by default
EXPOSE 8000

# Set environment to ensure Windmill uses port 8000
# Railway will route external traffic to this port
ENV PORT=8000
ENV WM_PORT=8000

# Add healthcheck to help Railway know when the service is ready
# Uses /healthcheck.sh which reads the PORT environment variable
HEALTHCHECK --interval=10s --timeout=5s --start-period=90s --retries=3 \
    CMD ["/healthcheck.sh"]

# Use our startup script
CMD ["/startup.sh"]
