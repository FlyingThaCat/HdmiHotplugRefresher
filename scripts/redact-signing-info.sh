#!/bin/bash

# Replace any <string>...</string> that contains 'identifier &quot;' with a placeholder

set -e

TARGET_DIR="${1:-.}"

echo "🔐 Replacing all <string> blocks with 'identifier &quot;' with a placeholder..."

find "$TARGET_DIR" -type f \( -name "*.plist" -o -name "*.entitlements" -o -name "*.swift" -o -name "*.txt" \) | while read -r file; do
    sed -i '' -E \
        -e 's|<string>[^<]*identifier &quot;[^<]*</string>|<string>SIGNING_REQUIREMENT_PLACEHOLDER</string>|g' \
        "$file"

    echo "✔️  Scrubbed: $file"
done

echo "✅ All matching <string> tags replaced."

