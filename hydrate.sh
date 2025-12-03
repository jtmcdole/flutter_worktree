#!/bin/bash
set -e

# --- Bash Script Hydration ---
CORE_LOGIC_FILE_SH="core_logic.sh"
TEMPLATE_FILE_SH="setup_flutter.template.sh"
OUTPUT_FILE_SH="setup_flutter.sh"

if [ ! -f "$CORE_LOGIC_FILE_SH" ]; then
    echo "❌ Error: '$CORE_LOGIC_FILE_SH' not found. Aborting bash hydration."
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE_SH" ]; then
    echo "❌ Error: '$TEMPLATE_FILE_SH' not found. Aborting bash hydration."
    exit 1
fi

# Base64 encode the bash core logic
PAYLOAD_SH=$(base64 -w 0 "$CORE_LOGIC_FILE_SH")

# Use sed to replace the placeholder in the bash template
sed "s|REPLACE_ME|$PAYLOAD_SH|" "$TEMPLATE_FILE_SH" > "$OUTPUT_FILE_SH"

chmod +x "$OUTPUT_FILE_SH"

echo "✅ Successfully hydrated '$OUTPUT_FILE_SH' with content from '$CORE_LOGIC_FILE_SH'."

# --- PowerShell Script Hydration ---
CORE_LOGIC_FILE_PS="core_logic.ps1"
TEMPLATE_FILE_PS="setup_flutter.template.ps1"
OUTPUT_FILE_PS="setup_flutter.ps1"

if [ ! -f "$CORE_LOGIC_FILE_PS" ]; then
    echo "❌ Error: '$CORE_LOGIC_FILE_PS' not found. Aborting PowerShell hydration."
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE_PS" ]; then
    echo "❌ Error: '$TEMPLATE_FILE_PS' not found. Aborting PowerShell hydration."
    exit 1
fi

# Base64 encode the PowerShell core logic
PAYLOAD_PS=$(base64 -w 0 "$CORE_LOGIC_FILE_PS")

# Use sed to replace the placeholder in the PowerShell template
sed "s|REPLACE_ME|$PAYLOAD_PS|" "$TEMPLATE_FILE_PS" > "$OUTPUT_FILE_PS"

echo "✅ Successfully hydrated '$OUTPUT_FILE_PS' with content from '$CORE_LOGIC_FILE_PS'."
echo ""
echo "All hydration complete."
echo "Run './$OUTPUT_FILE_SH' for bash setup, or '.\$OUTPUT_FILE_PS' (from PowerShell) for PowerShell setup."