import unicodedata, json

skip_names = ("CJK UNIFIED IDEOGRAPH", "CJK COMPATIBILITY IDEOGRAPH")
skip_categories = {"Cf", "Zs", "Zl", "Zp", "Mn", "Mc", "Me"}

out = []
dropped_invisible = 0
for cp in range(0x20, 0x110000):
    if 0xD800 <= cp <= 0xDFFF:
        continue

    ch = chr(cp)
    try:
        name = unicodedata.name(ch)
    except ValueError:
        continue

    if any(s in name for s in skip_names):
        continue

    if unicodedata.category(ch) in skip_categories:
        dropped_invisible += 1
        continue

    k = name.lower() + " u+%04x" % cp

    out.append({"e": ch, "k": k})

data = json.dumps(out, ensure_ascii=False, separators=(",", ":"))
print(
    len(out),
    "entries,",
    len(data.encode("utf-8")),
    "bytes; dropped",
    dropped_invisible,
    "invisible/combining chars",
)
with open("unicode.json", "w", encoding="utf-8") as f:
    f.write(data)
