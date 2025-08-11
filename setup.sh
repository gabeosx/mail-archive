#!/bin/bash
# setup.sh - Initial setup script for Email Archiving Cookbook

set -e

echo "🚀 Email Archiving Cookbook Setup"
echo "=================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp env.example .env
    echo "✅ Created .env file"
    echo "⚠️  Please edit .env file with your credentials before proceeding"
    echo "   - Yahoo email and app password"
    echo "   - Backblaze B2 credentials"
    echo "   - Web interface username and password"
    exit 0
else
    echo "✅ .env file already exists"
fi

# Make scripts executable
echo "🔧 Making scripts executable..."
chmod +x scripts/*.sh
chmod +x setup.sh

# Set proper permissions for .env
chmod 600 .env

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env file with your credentials"
echo "2. Start Dovecot and Roundcube: docker compose up -d dovecot roundcube"
echo "3. Run initial sync: ./scripts/sync_and_index.sh"
echo "4. Access web interface at http://localhost:8080"
echo ""
echo "For more information, see README.md" 