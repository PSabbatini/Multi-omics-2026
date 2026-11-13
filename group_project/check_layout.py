# Checks a pptx for (1) overlapping text/picture boxes and (2) text that
# likely overflows its box (estimated from font size and text length).
# Heuristic, not a renderer — but catches gross problems.
import sys
from pptx import Presentation
from pptx.util import Emu

EMU_IN = 914400
prs = Presentation(sys.argv[1] if len(sys.argv) > 1 else "Group-B-presentation.pptx")


def box(sh):
    return (sh.left / EMU_IN, sh.top / EMU_IN,
            (sh.left + sh.width) / EMU_IN, (sh.top + sh.height) / EMU_IN)


def overlap(a, b):
    ox = min(a[2], b[2]) - max(a[0], b[0])
    oy = min(a[3], b[3]) - max(a[1], b[1])
    return ox > 0.05 and oy > 0.05, ox, oy


def est_lines(text, width_in, size_pt, bold=False):
    if not text.strip():
        return 0
    # Calibri average glyph width ~0.50 em (0.53 for bold)
    char_w_pt = size_pt * (0.53 if bold else 0.50)
    chars_per_line = max(8, (width_in * 72) / char_w_pt)
    lines = 0
    for para in text.split("\n"):
        n = len(para)
        lines += max(1, -(-n // int(chars_per_line)))
    return lines


problems = 0
for idx, slide in enumerate(prs.slides, 1):
    shapes = []
    for sh in slide.shapes:
        if sh.left is None:
            continue
        kind = "text" if sh.has_text_frame and sh.text_frame.text.strip() else (
            "pic" if sh.shape_type == 13 else None)
        if sh.has_table:
            kind = "table"
        if kind:
            shapes.append((kind, sh, box(sh)))
    # overlap check
    for i in range(len(shapes)):
        for j in range(i + 1, len(shapes)):
            k1, s1, b1 = shapes[i]
            k2, s2, b2 = shapes[j]
            hit, ox, oy = overlap(b1, b2)
            if hit:
                problems += 1
                print(f"slide {idx}: OVERLAP {k1}'{s1.name}' x {k2}'{s2.name}' "
                      f"by {ox:.2f}x{oy:.2f} in  {b1} {b2}")
    # overflow check
    for kind, sh, b in shapes:
        if kind != "text":
            continue
        w_in = b[2] - b[0]
        h_in = b[3] - b[1]
        est_h = 0.0
        for p in sh.text_frame.paragraphs:
            txt = "".join(r.text for r in p.runs)
            if not txt:
                continue
            size = max((r.font.size.pt for r in p.runs if r.font.size), default=18)
            bold = any(r.font.bold for r in p.runs)
            n = est_lines(txt, w_in - 0.1, size, bold)
            est_h += n * size * 1.22 / 72 + 0.09   # line height + space_after
        if est_h > h_in + 0.15:
            problems += 1
            print(f"slide {idx}: TEXT OVERFLOW est {est_h:.2f}in > box {h_in:.2f}in "
                  f"(w={w_in:.1f}) first='{sh.text_frame.text[:60].strip()}'")

print("PROBLEMS:", problems if problems else "none found")
