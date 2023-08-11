file = first(google_font_files["abrilfatface"]) # bad checksum
file = first(google_font_files["anekbangla"]) # weird lookup type
file = font_file("juliamono")
file = font_file("jet-brains-mono")
file = first(google_font_files["robotoflex"])
file = first(google_font_files["notoserifgujarati"])

@time data = OpenTypeData(file);
@time font = OpenTypeFont(data);

glyphs = [font[c] for c in "AVAEE"]
offsets = glyph_offsets(font.gpos, glyphs, "latn", "AZE ", Set{String}())

rules = OpenType.positioning_rules(font.gpos, OpenType.positioning_features(font.gpos, "latn", "AZE ", Set{String}()))

r = first(rules)
r1 = first(r.rule_impls)

gid = 0x0df2

font.glyphs[gid + 1]

# ---

ENV["JULIA_DEBUG"] = "OpenType"
file = google_font_files["alegreya"][1]
OpenTypeData(file);
OpenTypeFont(file);
