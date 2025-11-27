#!/bin/bash
# Script to download and set up Monaco Editor for local use

MONACO_VERSION="0.45.0"
RESOURCES_DIR="Resources"
MONACO_DIR="$RESOURCES_DIR/monaco-editor"

echo "Downloading Monaco Editor v$MONACO_VERSION..."

# Create directory
mkdir -p "$MONACO_DIR"

# Download Monaco Editor
cd "$MONACO_DIR"
curl -L "https://registry.npmjs.org/monaco-editor/-/monaco-editor-${MONACO_VERSION}.tgz" -o monaco-editor.tgz

# Extract
tar -xzf monaco-editor.tgz

# Move files to correct location
if [ -d "package" ]; then
    mv package/* .
    rm -rf package
fi

# Clean up
rm -f monaco-editor.tgz

echo "Monaco Editor downloaded to $MONACO_DIR"
echo "Structure should be: $MONACO_DIR/min/vs/loader.js"
echo ""
echo "✓ Setup complete! Monaco Editor is ready to use."
echo "Make sure to add the monaco-editor folder to your Xcode project"
echo "and include it in 'Copy Bundle Resources' in Build Phases."
