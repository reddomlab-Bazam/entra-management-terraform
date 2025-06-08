#!/bin/bash
set -e

echo "🔧 Starting secure production deployment..."

# Remove old vulnerable packages
echo "Cleaning previous installation..."
rm -rf node_modules package-lock.json

# Install with production settings
echo "Installing secure dependencies..."
npm ci --production --no-audit --prefer-offline

# Security audit
echo "Running security audit..."
npm audit --audit-level high

# Verify Node.js version
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Check for security vulnerabilities
AUDIT_RESULT=$(npm audit --audit-level high --json 2>/dev/null || echo '{"vulnerabilities":{}}')
HIGH_VULNS=$(echo "$AUDIT_RESULT" | grep -o '"high":[0-9]*' | cut -d':' -f2 || echo "0")
CRITICAL_VULNS=$(echo "$AUDIT_RESULT" | grep -o '"critical":[0-9]*' | cut -d':' -f2 || echo "0")

if [ "$HIGH_VULNS" != "0" ] || [ "$CRITICAL_VULNS" != "0" ]; then
    echo "❌ Security vulnerabilities detected: High($HIGH_VULNS) Critical($CRITICAL_VULNS)"
    exit 1
fi

echo "✅ Deployment completed successfully - no security vulnerabilities detected"