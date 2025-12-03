#!/bin/bash
set -e

CORE_LOGIC_FILE="core_logic.sh"
TEMPLATE_FILE="setup_flutter.template.sh"
OUTPUT_FILE="setup_flutter.sh"

if [ ! -f "$CORE_LOGIC_FILE" ]; then
    echo "❌ Error: '$CORE_LOGIC_FILE' not found. Aborting."
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Error: '$TEMPLATE_FILE' not found. Aborting."
    exit 1
fi

# Base64 encode the core logic, remove newlines for single-line injection
PAYLOAD=$(base64 -w 0 "$CORE_LOGIC_FILE")

# Use sed to replace the placeholder in the template and create the output file
sed "s|REPLACE_ME|$PAYLOAD|" "$TEMPLATE_FILE" > "$OUTPUT_FILE"

chmod +x "$OUTPUT_FILE"

echo "✅ Successfully hydrated '$OUTPUT_FILE' with content from '$CORE_LOGIC_FILE'."
echo "Run './$OUTPUT_FILE' to set up Flutter worktrees."
