from pathlib import Path

path = Path('.github/workflows/ios-build-current.yml')
text = path.read_text(encoding='utf-8')

old = '''      # =====================================================
      # 11. PREPARE FLUTTER BUILD CONFIGURATION
      # Build number follows the GitHub run number offset and must stay above the latest App Store build.
      # =====================================================
      - name: Prepare Flutter iOS configuration
        run: |
          BUILD_NUMBER=$((GITHUB_RUN_NUMBER + 20))
          if [ "$BUILD_NUMBER" -le 60 ]; then
            BUILD_NUMBER=61
          fi

          echo "BUILD_NUMBER=$BUILD_NUMBER" >> "$GITHUB_ENV"
          echo "Using App Store build number: $BUILD_NUMBER"

          flutter build ios \\
            --release \\
            --config-only \\
            --build-name="1.1.1" \\
            --build-number="$BUILD_NUMBER"
'''

new = '''      # =====================================================
      # 11. PREPARE FLUTTER BUILD CONFIGURATION
      # Use the exact marketing version and build number from pubspec.yaml.
      # =====================================================
      - name: Prepare Flutter iOS configuration
        run: |
          set -e

          VERSION_LINE=$(awk '/^version:/ {print $2; exit}' pubspec.yaml)
          BUILD_NAME="${VERSION_LINE%%+*}"
          BUILD_NUMBER="${VERSION_LINE##*+}"

          if [ -z "$VERSION_LINE" ] || [ "$BUILD_NAME" = "$VERSION_LINE" ] || [ -z "$BUILD_NUMBER" ]; then
            echo "ERROR: pubspec.yaml version must use x.y.z+build format"
            exit 1
          fi

          echo "BUILD_NAME=$BUILD_NAME" >> "$GITHUB_ENV"
          echo "BUILD_NUMBER=$BUILD_NUMBER" >> "$GITHUB_ENV"
          echo "Using App Store version: $BUILD_NAME ($BUILD_NUMBER)"

          flutter build ios \\
            --release \\
            --config-only \\
            --build-name="$BUILD_NAME" \\
            --build-number="$BUILD_NUMBER"
'''

if old not in text:
    raise SystemExit('Expected old iOS build configuration block was not found')

text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('OK: ios-build-current.yml now uses version/build from pubspec.yaml')
