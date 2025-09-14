#!/bin/bash

# setup-development.sh
# Script to set up development environment for SpendConscience
# This script copies environment variables from your shell to a local plist file

set -e

echo "🚀 Setting up SpendConscience development environment..."

# Check if required environment variables are available
if [ -z "$PLAID_CLIENT" ] || [ -z "$PLAID_SANDBOX_API" ]; then
    echo "❌ Error: Required environment variables not found."
    echo ""
    echo "Please ensure you have the following variables set in your shell:"
    echo "  - PLAID_CLIENT"
    echo "  - PLAID_SANDBOX_API"
    echo ""
    echo "You can add them to your ~/.zshrc or ~/.bashrc file:"
    echo '  export PLAID_CLIENT="your_client_id_here"'
    echo '  export PLAID_SANDBOX_API="your_sandbox_secret_here"'
    echo ""
    echo "Then run: source ~/.zshrc (or ~/.bashrc)"
    exit 1
fi

# Create the plist file in the app folder
PLIST_FILE="SpendConscience/Config.Development.plist"

echo "📝 Creating $PLIST_FILE with your configuration..."

cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PlaidClientID</key>
	<string>$PLAID_CLIENT</string>
	<key>PlaidSandboxAPI</key>
	<string>$PLAID_SANDBOX_API</string>
	<key>Environment</key>
	<string>sandbox</string>
	<key>DebugMode</key>
	<true/>
</dict>
</plist>
EOF

# Also create the development xcconfig for backward compatibility
CONFIG_FILE="Config.Development.xcconfig"

echo "📝 Also creating $CONFIG_FILE for backward compatibility..."

cat > "$CONFIG_FILE" << EOF
//
//  Config.Development.xcconfig
//  SpendConscience
//
//  Development-specific configuration
//  This file is auto-generated and should NOT be committed to git
//

#include "Config.xcconfig"

// Plaid API Configuration from environment variables
PLAID_CLIENT = $PLAID_CLIENT
PLAID_SANDBOX_API = $PLAID_SANDBOX_API

// Development-specific settings
DEBUG_MODE = YES
ENABLE_PLAID_SANDBOX = YES
EOF

echo "✅ Development environment configured successfully!"
echo ""
echo "📋 Configuration summary:"
echo "  - PLAID_CLIENT: ${PLAID_CLIENT:0:8}..."
echo "  - PLAID_SANDBOX_API: ${PLAID_SANDBOX_API:0:8}..."
echo ""
echo "📁 Files created:"
echo "  - $PLIST_FILE (for app runtime configuration)"
echo "  - $CONFIG_FILE (for Xcode builds)"
echo ""
echo "🔐 Security note: Both files are ignored by git and won't be committed."
echo ""
echo "🏗️  Next steps for your team:"
echo "  1. Each developer should run: ./setup-development.sh"
echo "  2. Add ConfigurationLoader.swift to your Xcode project"
echo "  3. Add $PLIST_FILE to your Xcode project"
echo "  4. Build and test - API keys will be loaded automatically from plist!"
echo ""
echo "✨ No manual Xcode configuration needed!"
# This script copies environment variables from your shell to a local plist file

set -e

echo "🚀 Setting up SpendConscience development environment..."

# Check if required environment variables are available
if [ -z "$PLAID_CLIENT" ] || [ -z "$PLAID_SANDBOX_API" ]; then
    echo "❌ Error: Required environment variables not found."
    echo ""
    echo "Please ensure you have the following variables set in your shell:"
    echo "  - PLAID_CLIENT"
    echo "  - PLAID_SANDBOX_API"
    echo ""
    echo "You can add them to your ~/.zshrc or ~/.bashrc file:"
    echo '  export PLAID_CLIENT="your_client_id_here"'
    echo '  export PLAID_SANDBOX_API="your_sandbox_secret_here"'
    echo ""
    echo "Then run: source ~/.zshrc (or ~/.bashrc)"
    exit 1
fi

# Create the plist file
PLIST_FILE="Config.Development.plist"

echo "📝 Creating $PLIST_FILE with your configuration..."

cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PlaidClientID</key>
	<string>$PLAID_CLIENT</string>
	<key>PlaidSandboxAPI</key>
	<string>$PLAID_SANDBOX_API</string>
	<key>Environment</key>
	<string>sandbox</string>
	<key>DebugMode</key>
	<true/>
</dict>
</plist>
EOF

# Also create the development xcconfig for backward compatibility
CONFIG_FILE="Config.Development.xcconfig"

echo "📝 Also creating $CONFIG_FILE for backward compatibility..."

cat > "$CONFIG_FILE" << EOF
//
//  Config.Development.xcconfig
//  SpendConscience
//
//  Development-specific configuration
//  This file is auto-generated and should NOT be committed to git
//

#include "Config.xcconfig"

// Plaid API Configuration from environment variables
PLAID_CLIENT = $PLAID_CLIENT
PLAID_SANDBOX_API = $PLAID_SANDBOX_API

// Development-specific settings
DEBUG_MODE = YES
ENABLE_PLAID_SANDBOX = YES
EOF

echo "✅ Development environment configured successfully!"
echo ""
echo "📋 Configuration summary:"
echo "  - PLAID_CLIENT: ${PLAID_CLIENT:0:8}..."
echo "  - PLAID_SANDBOX_API: ${PLAID_SANDBOX_API:0:8}..."
echo ""
echo "� Files created:"
echo "  - $ENV_FILE (for app runtime)"
echo "  - $CONFIG_FILE (for Xcode builds)"
echo ""
echo "🔐 Security note: Both files are ignored by git and won't be committed."
echo ""
echo "🏗️  Next steps for your team:"
echo "  1. Each developer should run: ./setup-development.sh"
echo "  2. Add EnvironmentLoader.swift to your Xcode project"
echo "  3. Build and test - API keys will be loaded automatically!"
echo ""
echo "✨ No manual Xcode configuration needed!"