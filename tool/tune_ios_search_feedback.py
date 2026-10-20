from pathlib import Path

path = Path('lib/product_search_v51.dart')
text = path.read_text(encoding='utf-8')
original = text

replacements = {
    "static const Duration _silenceAfterSpeech = Duration(milliseconds: 1200);":
        "static const Duration _silenceAfterSpeech = Duration(milliseconds: 800);",
    "static const Duration _noSpeechTimeout = Duration(seconds: 4);":
        "static const Duration _noSpeechTimeout = Duration(seconds: 3);",
    "static const Duration _maximumRecordingTime = Duration(seconds: 12);":
        "static const Duration _maximumRecordingTime = Duration(seconds: 7);",
    "    busy = true;\n    try {\n      final bytes = await image.readAsBytes();":
        "    busy = true;\n    onStateChanged?.call();\n    try {\n      final bytes = await image.readAsBytes();",
}

for old, new in replacements.items():
    if old not in text:
        raise SystemExit(f'Expected text not found:\n{old}')
    text = text.replace(old, new)

if text == original:
    raise SystemExit('No changes applied')

path.write_text(text, encoding='utf-8')
print('OK: iOS search feedback tuned')
print(' - voice silence after speech: 0.8s')
print(' - no-speech timeout: 3s')
print(' - maximum recording: 7s')
print(' - image scan now refreshes UI immediately when AI search starts')
