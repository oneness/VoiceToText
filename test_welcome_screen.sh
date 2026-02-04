#!/bin/bash

# Test script to verify WelcomeScreen implementation

cd "$(dirname "$0")"

echo "Testing WelcomeScreen Implementation..."
echo ""

# Check if files exist
echo "1. Checking if SetupChecker.swift exists..."
if [ -f "VoiceToText/Resources/SetupChecker.swift" ]; then
    echo "   ✓ SetupChecker.swift found"
else
    echo "   ✗ SetupChecker.swift not found"
    exit 1
fi

echo ""
echo "2. Checking if WelcomeViewController.swift exists..."
if [ -f "VoiceToText/Resources/WelcomeViewController.swift" ]; then
    echo "   ✓ WelcomeViewController.swift found"
else
    echo "   ✗ WelcomeViewController.swift not found"
    exit 1
fi

echo ""
echo "3. Checking AppDelegate.swift integration..."
if grep -q "showWelcomeScreen" VoiceToText/App/AppDelegate.swift; then
    echo "   ✓ AppDelegate integration found"
else
    echo "   ✗ AppDelegate integration not found"
    exit 1
fi

echo ""
echo "4. Checking test file has WelcomeScreen tests..."
if grep -q "SetupChecker" VoiceToTextTests/VoiceToTextTests.swift; then
    echo "   ✓ SetupChecker tests found"
else
    echo "   ✗ SetupChecker tests not found"
    exit 1
fi

if grep -q "WelcomeViewController" VoiceToTextTests/VoiceToTextTests.swift; then
    echo "   ✓ WelcomeViewController tests found"
else
    echo "   ✗ WelcomeViewController tests not found"
    exit 1
fi

echo ""
echo "5. Checking SetupChecker implementation..."
if grep -q "class SetupChecker" VoiceToText/Resources/SetupChecker.swift; then
    echo "   ✓ SetupChecker class found"
else
    echo "   ✗ SetupChecker class not found"
    exit 1
fi

if grep -q "func hasCompletedSetup" VoiceToText/Resources/SetupChecker.swift; then
    echo "   ✓ hasCompletedSetup method found"
else
    echo "   ✗ hasCompletedSetup method not found"
    exit 1
fi

if grep -q "func markSetupComplete" VoiceToText/Resources/SetupChecker.swift; then
    echo "   ✓ markSetupComplete method found"
else
    echo "   ✗ markSetupComplete method not found"
    exit 1
fi

echo ""
echo "6. Checking WelcomeViewController implementation..."
if grep -q "class WelcomeViewController" VoiceToText/Resources/WelcomeViewController.swift; then
    echo "   ✓ WelcomeViewController class found"
else
    echo "   ✗ WelcomeViewController class not found"
    exit 1
fi

if grep -q "struct SetupStep" VoiceToText/Resources/WelcomeViewController.swift; then
    echo "   ✓ SetupStep struct found"
else
    echo "   ✗ SetupStep struct not found"
    exit 1
fi

if grep -q "struct WelcomeView" VoiceToText/Resources/WelcomeViewController.swift; then
    echo "   ✓ WelcomeView SwiftUI view found"
else
    echo "   ✗ WelcomeView SwiftUI view not found"
    exit 1
fi

echo ""
echo "All checks passed! ✓"
echo ""
echo "Files created:"
echo "  - VoiceToText/Resources/SetupChecker.swift"
echo "  - VoiceToText/Resources/WelcomeViewController.swift"
echo ""
echo "Files modified:"
echo "  - VoiceToText/App/AppDelegate.swift"
echo "  - VoiceToTextTests/VoiceToTextTests.swift"
