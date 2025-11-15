#!/bin/bash
# SMSI Fleet Dashboard - Quick Setup Script

echo "======================================"
echo "SMSI Fleet Dashboard Setup"
echo "======================================"
echo ""

# Check for Railway CLI
if ! command -v railway &> /dev/null; then
    echo "Railway CLI not found. Installing..."
    npm install -g @railway/cli
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is required for local testing"
    echo "Please install Docker Desktop first"
    exit 1
fi

# Menu
echo "Select deployment option:"
echo "1) Local Development (Docker Compose)"
echo "2) Deploy to Railway"
echo "3) Setup Environment Variables"
echo "4) Run Tests"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo "Starting local development environment..."
        
        # Copy environment template if not exists
        if [ ! -f .env ]; then
            cp .env.example .env
            echo "Created .env file - please edit with your Ford Pro credentials"
            echo "Opening .env file..."
            ${EDITOR:-nano} .env
        fi
        
        # Start services
        docker-compose up -d
        echo ""
        echo "✅ Local environment started!"
        echo "📊 Windmill: http://localhost:8000"
        echo "🔐 Default login: admin@windmill.dev / changeme"
        echo ""
        echo "To view logs: docker-compose logs -f"
        echo "To stop: docker-compose down"
        ;;
        
    2)
        echo "Deploying to Railway..."
        
        # Check for .env
        if [ ! -f .env ]; then
            cp .env.example .env
            echo "Created .env file - please edit with your credentials first"
            ${EDITOR:-nano} .env
            echo ""
        fi
        
        # Login to Railway
        railway login
        
        # Create project
        echo "Creating new Railway project..."
        railway init
        
        # Deploy with docker-compose
        echo "Deploying services..."
        railway up --docker-compose
        
        echo ""
        echo "✅ Deployment initiated!"
        echo "📊 Check Railway dashboard for URLs and status"
        echo "⚙️  Configure environment variables in Railway dashboard"
        ;;
        
    3)
        echo "Setting up environment variables..."
        
        if [ -f .env ]; then
            echo "Current .env file exists. Edit or replace? (e/r/cancel)"
            read -p "> " env_choice
            case $env_choice in
                e) ${EDITOR:-nano} .env ;;
                r) cp .env.example .env && ${EDITOR:-nano} .env ;;
                *) echo "Cancelled" ;;
            esac
        else
            cp .env.example .env
            echo "Created .env file from template"
            ${EDITOR:-nano} .env
        fi
        
        echo ""
        echo "Required variables:"
        echo "  FORD_PRO_CLIENT_ID - Your Ford Pro API client ID"
        echo "  FORD_PRO_CLIENT_SECRET - Your Ford Pro API secret"
        echo "  FORD_PRO_FLEET_ID - Your fleet identifier"
        echo ""
        echo "Optional:"
        echo "  SMTP settings for email alerts"
        echo "  Slack webhook for notifications"
        ;;
        
    4)
        echo "Running system tests..."
        
        # Start services if not running
        if ! docker-compose ps | grep -q "Up"; then
            echo "Starting services..."
            docker-compose up -d
            sleep 10
        fi
        
        # Test database connection
        echo -n "Testing fleet database connection... "
        docker-compose exec fleet-db pg_isready -U smsi && echo "✅ OK" || echo "❌ FAILED"
        
        # Test Windmill
        echo -n "Testing Windmill API... "
        curl -s http://localhost:8000/api/version > /dev/null && echo "✅ OK" || echo "❌ FAILED"
        
        # Check schema
        echo -n "Checking database schema... "
        docker-compose exec fleet-db psql -U smsi -d fleet_metrics -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" > /dev/null && echo "✅ OK" || echo "❌ FAILED"
        
        echo ""
        echo "Test complete!"
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "======================================"
echo "Need help? Check:"
echo "  - README.md for overview"
echo "  - DEPLOYMENT.md for detailed setup"
echo "  - QUICK_REFERENCE.md for operations"
echo "======================================" 
