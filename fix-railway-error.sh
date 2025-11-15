#!/bin/bash
# Fix Railway TOML Error - Run this in your GitHub repo

echo "========================================="
echo "Railway TOML Error Fix"
echo "========================================="
echo ""
echo "This will remove the invalid railway.toml from your repo"
echo ""

# Check if in git repository
if [ ! -d .git ]; then
    echo "ERROR: Not in a git repository"
    echo "Please run this from your project's GitHub repo"
    exit 1
fi

# Remove railway.toml if it exists
if [ -f railway.toml ]; then
    echo "Found railway.toml - removing..."
    git rm railway.toml
    echo "✅ Removed railway.toml"
else
    echo "No railway.toml found in current directory"
fi

# Remove railway.json if it exists (not needed)
if [ -f railway.json ]; then
    echo "Found railway.json - removing..."
    git rm railway.json
    echo "✅ Removed railway.json"
fi

# Add .railwayignore if not exists
if [ ! -f .railwayignore ]; then
    echo "Creating .railwayignore..."
    cat > .railwayignore << 'EOF'
# Railway ignore file
railway.toml
*.toml
.env
.env.local
node_modules/
*.log
.DS_Store
EOF
    git add .railwayignore
    echo "✅ Created .railwayignore"
fi

# Commit changes
echo ""
echo "Committing changes..."
git commit -m "Remove railway.toml - use docker-compose.yml for deployment"

echo ""
echo "✅ Fixed! Now push to GitHub:"
echo "   git push origin main"
echo ""
echo "Then in Railway:"
echo "1. Delete the current deployment if it exists"
echo "2. Create new project → Deploy from GitHub"
echo "3. Select your repo"
echo "4. Railway will auto-detect docker-compose.yml"
echo ""
echo "========================================="
