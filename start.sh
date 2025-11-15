#!/bin/bash
# Start script for Railway deployment
# This is a fallback in case Railway doesn't detect the Dockerfile

set -e

echo "========================================="
echo "Starting Windmill on Railway"
echo "========================================="

# Check required environment variables
if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL environment variable is required"
    echo "Please add a PostgreSQL service in Railway and link it to this service"
    exit 1
fi

echo "✓ DATABASE_URL is set"

# Export Windmill-specific variables
export MODE="${MODE:-standalone}"
export WM_BASE_URL="${WM_BASE_URL:-https://$RAILWAY_PUBLIC_DOMAIN}"
export DISABLE_SECURE_COOKIES="${DISABLE_SECURE_COOKIES:-false}"

echo "Starting Windmill in $MODE mode..."
echo "Base URL: $WM_BASE_URL"

# Note: This script is a placeholder
# Railway should use the Dockerfile to run the Windmill image directly
echo ""
echo "NOTE: For production deployment, use Railway's Docker deployment"
echo "See DEPLOYMENT.md for detailed instructions"
echo ""

# If running this script, we're likely in a non-Docker context
# which won't work for Windmill
echo "ERROR: This service must be deployed using Docker"
echo ""
echo "In Railway:"
echo "1. Go to your service settings"
echo "2. Under 'Deploy', ensure 'Builder' is set to 'Dockerfile'"
echo "3. Redeploy the service"
exit 1
