import re
import random
import base64

# Load your Lua script from a file
with open("original_script.lua", "r", encoding="utf-8") as f:
    lua_code = f.read()

# Generate random variable names
def random_var(length=6):
    return ''.join(random.choices("abcdefghijklmnopqrstuvwxyz", k=length))

# Find all local variable declarations
pattern = r"\blocal\s+([A-Za-z_][A-Za-z0-9_]*)"
variables = set(re.findall(pattern, lua_code))

# Ignore standard keywords
ignore = {"true", "false", "nil"}
obf_map = {var: random_var() for var in variables if var not in ignore}

# Replace variable names
def obfuscate_vars(code, var_map):
    for original, obf in sorted(var_map.items(), key=lambda x: -len(x[0])):
        code = re.sub(rf'\b{original}\b', obf, code)
    return code

obfuscated_code = obfuscate_vars(lua_code, obf_map)

# Optionally encode strings (base64 for non-URLs)
def encode_strings(code):
    def replacer(match):
        s = match.group(1)
        if len(s) > 4 and not s.lower().startswith("https"):
            encoded = base64.b64encode(s.encode()).decode()
            return f'HttpService:Base64Decode("{encoded}")'
        return f'"{s}"'
    return re.sub(r'"([^"]+)"', replacer, code)

# Add HttpService line if Base64Decode is used
encoded = encode_strings(obfuscated_code)
if "HttpService:Base64Decode" in encoded:
    preface = 'local HttpService = game:GetService("HttpService")\n'
    obfuscated_code = preface + encoded
else:
    obfuscated_code = encoded

# Save to a new file
with open("obfuscated_script.lua", "w", encoding="utf-8") as f:
    f.write(obfuscated_code)

print("✅ Obfuscation complete. Output saved to obfuscated_script.lua.")
