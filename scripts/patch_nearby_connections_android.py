"""
Patches flutter_nearby_connections_plus Kotlin plugin to remove the v1
Flutter embedding (PluginRegistry.Registrar) which was removed in Flutter 3.x.
The plugin's FlutterPlugin (v2) implementation is correct and untouched.

Usage: python3 scripts/patch_nearby_connections_android.py <path-to-kt-file>
"""
import re
import sys

path = sys.argv[1]
with open(path) as f:
    content = f.read()

# Remove the Registrar import line.
content = "\n".join(
    line for line in content.split("\n")
    if "PluginRegistry.Registrar" not in line
)

# Remove the @JvmStatic registerWith method from the companion object.
# The function body has no nested braces so [^}]* is safe.
content = re.sub(
    r"\n\n\s+@JvmStatic\n\s+fun registerWith\([^)]*\) \{[^}]*\}",
    "",
    content,
)

with open(path, "w") as f:
    f.write(content)

print(f"Patched: {path}")
