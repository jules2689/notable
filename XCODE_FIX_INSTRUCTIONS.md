# Fix Monaco Editor Duplicate Files Error

## Problem
Xcode is trying to copy Monaco Editor files multiple times, causing build errors like:
```
Multiple commands produce '.../abap.js'
```

## Solution (Choose One)

### Option 1: Build Script (Recommended)

This approach copies the Monaco folder during build, avoiding duplicate file references.

1. **Remove Monaco from Xcode:**
   - In Xcode, find `monaco-editor` in the project navigator
   - Select it and press Delete
   - Choose **"Remove Reference"** (NOT "Move to Trash")

2. **Add Build Script:**
   - Select your project in the navigator
   - Select your target (NotesApp)
   - Go to **Build Phases** tab
   - Click **+** → **New Run Script Phase**
   - Name it "Copy Monaco Editor"
   - Add this script:
   ```bash
   cp -R "${SRCROOT}/Resources/monaco-editor" "${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources/"
   ```
   - **IMPORTANT:** Drag this script phase to be BEFORE "Copy Bundle Resources"
   - Uncheck "For install builds only"

3. **Clean and Rebuild:**
   - Product → Clean Build Folder (Cmd+Shift+K)
   - Product → Build (Cmd+B)

### Option 2: Folder Reference

This treats the entire folder as a single resource.

1. **Remove Monaco from Xcode:**
   - In Xcode, find `monaco-editor` in the project navigator
   - Select it and press Delete
   - Choose **"Remove Reference"** (NOT "Move to Trash")

2. **Re-add as Folder Reference:**
   - Right-click the `Resources` folder in Xcode
   - Select **"Add Files to [Project Name]..."**
   - Navigate to and select the `monaco-editor` folder
   - **CRITICAL:** Select **"Create folder references"** (blue folder icon)
   - **DO NOT** check "Copy items if needed"
   - Make sure your target is selected
   - Click **Add**

3. **Verify in Build Phases:**
   - Go to **Build Phases** → **Copy Bundle Resources**
   - You should see `monaco-editor` listed ONCE as a folder (blue icon)
   - If you see individual files, remove them and try again

4. **Clean and Rebuild:**
   - Product → Clean Build Folder (Cmd+Shift+K)
   - Product → Build (Cmd+B)

## Why This Happens

When you add a folder with many files to Xcode and choose "Create groups" (yellow folder), Xcode adds each file individually to the build phases. This causes duplicate build commands when the same file appears multiple times.

Using a build script or folder reference treats the entire folder as a single unit, avoiding duplicates.

## Verification

After fixing, you should see:
- No duplicate file errors in build
- `monaco-editor` folder appears in your app bundle at runtime
- Code blocks work with Monaco Editor

