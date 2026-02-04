#!/bin/bash

# Verification script for GroqTranscriber implementation

echo "=== Verifying GroqTranscriber Implementation ==="
echo ""

# Check if all required files exist
echo "Checking required files..."
files=(
    "VoiceToText/Managers/GroqTranscriber.swift"
    "VoiceToText/Managers/HTTPClient.swift"
    "VoiceToText/Managers/TranscriptionService.swift"
    "VoiceToText/Models/TranscriptionError.swift"
    "VoiceToTextTests/VoiceToTextTests.swift"
)

all_exist=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
        all_exist=false
    fi
done
echo ""

# Check for protocol conformance
echo "Checking protocol conformance..."
if grep -q "struct GroqTranscriber: TranscriptionService" VoiceToText/Managers/GroqTranscriber.swift; then
    echo "✓ GroqTranscriber conforms to TranscriptionService"
else
    echo "✗ GroqTranscriber does not conform to TranscriptionService"
fi
echo ""

# Check for API key handling
echo "Checking API key handling..."
if grep -q "ProcessInfo.processInfo.environment\[\"GROQ_API_KEY\"\]" VoiceToText/Managers/GroqTranscriber.swift; then
    echo "✓ API key is read from environment variable"
else
    echo "✗ API key environment variable handling not found"
fi

if grep -q "static let shared" VoiceToText/Managers/GroqTranscriber.swift; then
    echo "✓ Shared singleton exists"
else
    echo "✗ Shared singleton not found"
fi
echo ""

# Check for HTTP client dependency injection
echo "Checking dependency injection..."
if grep -q "private let httpClient: HTTPClient" VoiceToText/Managers/GroqTranscriber.swift; then
    echo "✓ HTTP client is injected via constructor"
else
    echo "✗ HTTP client dependency injection not found"
fi
echo ""

# Check for error handling
echo "Checking error handling..."
if grep -q "throw TranscriptionError" VoiceToText/Managers/GroqTranscriber.swift; then
    echo "✓ Throws TranscriptionError"
else
    echo "✗ Error handling not found"
fi
echo ""

# Check tests
echo "Checking tests..."
test_count=$(grep -c '@Test' VoiceToTextTests/VoiceToTextTests.swift)
echo "✓ Found $test_count tests"

if grep -q "MockHTTPClient" VoiceToTextTests/VoiceToTextTests.swift; then
    echo "✓ Mock HTTP client for testing exists"
else
    echo "✗ Mock HTTP client not found"
fi
echo ""

# Check for hardcoded API keys (should not exist)
echo "Checking for hardcoded API keys..."
if grep -i "gsk_" VoiceToText/Managers/GroqTranscriber.swift | grep -v "//"; then
    echo "✗ WARNING: Possible hardcoded API key found!"
else
    echo "✓ No hardcoded API keys detected"
fi
echo ""

echo "=== Verification Complete ==="
