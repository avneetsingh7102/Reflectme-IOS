#!/bin/bash
# Reflect.Me iOS — Project Setup Script
# Run this after installing Xcode to regenerate the .xcodeproj

set -e

echo "🔧 Setting up Reflect.Me iOS..."

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "⚠️  Xcode is not installed. Please install it from the Mac App Store."
    echo "   After installation, run: sudo xcode-select -s /Applications/Xcode.app"
    exit 1
fi

# Check for XcodeGen
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "⚠️  Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        brew install xcodegen
    fi
fi

# Generate the Xcode project
echo "⚙️  Generating Xcode project..."
xcodegen generate

echo ""
echo "✅ Setup complete!"
echo "   Open Reflect.xcodeproj in Xcode and press ⌘+R to run."
echo ""
