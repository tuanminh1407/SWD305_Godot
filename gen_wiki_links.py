import hashlib

def get_wikimedia_url(filename):
    # Wikimedia replaces spaces with underscores
    filename = filename.replace(' ', '_')
    md5 = hashlib.md5(filename.encode('utf-8')).hexdigest()
    hash1 = md5[0]
    hash2 = md5[:2]
    return f"https://upload.wikimedia.org/wikipedia/commons/{hash1}/{hash2}/{filename}"

files = [
    "Vi-Hà Nội-bắc.ogg",
    "Vi-saigon-Sài Gòn.ogg",
    "Vi-saigon-mẹ.ogg",
    "Vi-hanoi-mẹ.ogg"
]

for f in files:
    print(f"{f} -> {get_wikimedia_url(f)}")
