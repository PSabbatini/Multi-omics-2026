# Builds group_project/Group-B-presentation.pptx from the three Group B
# analyses (analysis-microbiome-arm.R, analysis-genes-ring.R,
# analysis-cst-genes.R) and the QC report.
#
# Run:  python3 make_presentation.py
# Re-run after re-running the R scripts to refresh numbers/figures.

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from PIL import Image
import os

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures")
OUT = os.path.join(HERE, "Group-B-presentation.pptx")

TITLE_C = RGBColor(0x1F, 0x3A, 0x5F)   # dark blue
ACCENT_C = RGBColor(0x4A, 0x6F, 0xA5)  # mid blue
BODY_C = RGBColor(0x30, 0x30, 0x30)
CAP_C = RGBColor(0x8A, 0x4A, 0x1F)     # burnt orange for "main finding"
ANS_C = RGBColor(0x2E, 0x6B, 0x3A)     # green for answer slides

SW, SH = Inches(13.333), Inches(7.5)

prs = Presentation()
prs.slide_width = SW
prs.slide_height = SH
BLANK = prs.slide_layouts[6]


def _rect(slide, x, y, w, h, color):
    from pptx.enum.shapes import MSO_SHAPE
    sh = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, x, y, w, h)
    sh.fill.solid()
    sh.fill.fore_color.rgb = color
    sh.line.fill.background()
    sh.shadow.inherit = False
    return sh


def _text(slide, x, y, w, h, runs, size=16, color=BODY_C, bold=False,
          italic=False, align=PP_ALIGN.LEFT, space_after=6, line=1.0):
    """runs = str, or list of (text, dict-overrides) paragraphs."""
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    if isinstance(runs, str):
        runs = [(runs, {})]
    for i, (txt, ov) in enumerate(runs):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = ov.get("align", align)
        p.space_after = Pt(ov.get("space_after", space_after))
        r = p.add_run()
        r.text = txt
        f = r.font
        f.size = Pt(ov.get("size", size))
        f.bold = ov.get("bold", bold)
        f.italic = ov.get("italic", italic)
        f.color.rgb = ov.get("color", color)
        f.name = "Calibri"
    return tb


def _pic(slide, path, x, y, max_w, max_h):
    """Place image centred in the box, preserving aspect ratio."""
    iw, ih = Image.open(path).size
    scale = min(max_w / iw, max_h / ih)
    w, h = int(iw * scale), int(ih * scale)
    left = int(x + (max_w - w) / 2)
    top = int(y + (max_h - h) / 2)
    return slide.shapes.add_picture(path, left, top, w, h)


def new_slide(title=None, kicker=None):
    s = prs.slides.add_slide(BLANK)
    _rect(s, 0, 0, SW, Inches(0.12), ACCENT_C)
    if title:
        _text(s, Inches(0.55), Inches(0.35), Inches(12.3), Inches(0.6),
              title, size=27, bold=True, color=TITLE_C)
    if kicker:
        _text(s, Inches(0.55), Inches(1.02), Inches(12.3), Inches(0.38),
              kicker, size=14, italic=True, color=ACCENT_C)
    return s


def bullets(slide, items, x, y, w, h, size=15):
    runs = []
    for it in items:
        if isinstance(it, tuple):          # (text, level)
            txt, lvl = it
        else:
            txt, lvl = it, 0
        runs.append((("•  " if lvl == 0 else "–  ") + txt,
                     {"size": size - lvl * 1.5, "space_after": 7}))
    _text(slide, x, y, w, h, runs)


def finding(slide, txt, y=Inches(6.55)):
    _rect(slide, Inches(0.55), y, Inches(0.09), Inches(0.62), CAP_C)
    _text(slide, Inches(0.78), y, Inches(12.0), Inches(0.72),
          [("Main finding:  " + txt, {"size": 14.5, "color": CAP_C,
                                      "italic": True})], space_after=0)


def table(slide, x, y, w, header, rows, col_widths=None, fsize=12.5):
    n_r, n_c = len(rows) + 1, len(header)
    shp = slide.shapes.add_table(n_r, n_c, x, y, w, Inches(0.35 * n_r))
    tbl = shp.table
    if col_widths:
        for j, cw in enumerate(col_widths):
            tbl.columns[j].width = Inches(cw)
    for j, htxt in enumerate(header):
        c = tbl.cell(0, j)
        c.text = htxt
        for p in c.text_frame.paragraphs:
            p.alignment = PP_ALIGN.LEFT
            for r in p.runs:
                r.font.size, r.font.bold = Pt(fsize), True
                r.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        c.fill.solid()
        c.fill.fore_color.rgb = TITLE_C
    for i, row in enumerate(rows, start=1):
        for j, val in enumerate(row):
            c = tbl.cell(i, j)
            c.text = str(val)
            for p in c.text_frame.paragraphs:
                for r in p.runs:
                    r.font.size = Pt(fsize)
                    r.font.color.rgb = BODY_C
    return tbl


def question_slide(q_no, question, what, methods):
    s = new_slide(f"Question {q_no} of 3", "One of three questions we asked of the Study B data")
    _rect(s, Inches(0.55), Inches(1.55), Inches(0.12), Inches(1.15), ACCENT_C)
    _text(s, Inches(0.85), Inches(1.55), Inches(11.9), Inches(1.2),
          question, size=24, bold=True, color=TITLE_C)
    _text(s, Inches(0.55), Inches(3.0), Inches(12.3), Inches(1.2),
          [("What this question means", {"size": 16, "bold": True, "color": ACCENT_C}),
           (what, {"size": 15})])
    _text(s, Inches(0.55), Inches(4.35), Inches(12.3), Inches(2.9),
          [("How we answered it (methods)", {"size": 16, "bold": True, "color": ACCENT_C})] +
          [(m, {"size": 14}) for m in methods])
    return s


def answer_slide(q_no, question, answer_lines):
    s = new_slide(f"Question {q_no} — the answer", question)
    _rect(s, Inches(0.55), Inches(1.75), Inches(0.12), Inches(4.4), ANS_C)
    runs = [(a, {"size": 20 if i == 0 else 17,
                 "bold": i == 0,
                 "color": ANS_C if i == 0 else BODY_C,
                 "space_after": 12})
            for i, a in enumerate(answer_lines)]
    _text(s, Inches(0.9), Inches(1.75), Inches(11.9), Inches(4.5), runs)
    return s


# ---------------------------------------------------------------- 1 title ---
s = prs.slides.add_slide(BLANK)
_rect(s, 0, 0, SW, SH, TITLE_C)
_rect(s, 0, Inches(4.62), SW, Inches(0.06), ACCENT_C)
_text(s, Inches(0.9), Inches(1.7), Inches(11.5), Inches(1.7),
      [("Contraceptive method and the vaginal environment",
        {"size": 40, "bold": True, "color": RGBColor(0xFF, 0xFF, 0xFF)})])
_text(s, Inches(0.9), Inches(3.55), Inches(11.5), Inches(0.8),
      "Group B project — the vaginal microbiome, host gene expression and community types in Study B",
      size=19, color=RGBColor(0xC9, 0xD8, 0xEC))
_text(s, Inches(0.9), Inches(4.9), Inches(11.5), Inches(1.6),
      [("93 participants · one vaginal sample each", {"size": 16}),
       ("Three contraceptive arms: pill (28) · injectable (39) · vaginal ring (26)", {"size": 16}),
       ("Data Science for Biology workshop — Workshop 2, multiomics group project", {"size": 13, "italic": True})],
      color=RGBColor(0xC9, 0xD8, 0xEC))

# ------------------------------------------------------------- 2 dataset ---
s = new_slide("The dataset: Study B (contraception)")
bullets(s, [
    "A cross-sectional study: one vaginal sample per person, at a single time point (93 participants)",
    "Three contraceptive arms — the main grouping variable, defined from the sample sheet:",
], Inches(0.55), Inches(1.25), Inches(5.4), Inches(1.5))
table(s, Inches(1.0), Inches(2.75), Inches(4.6),
      ["Arm (method)", "n"],
      [["Injectable (e.g. DMPA injection)", "39"],
       ["Pill (oral contraceptive)", "28"],
       ["Vaginal ring", "26"]], col_widths=[3.6, 1.0])
bullets(s, [
    "For every sample, three data layers:",
    ("Microbiome: 220 bacterial species × 93 samples (raw read counts)", 1),
    ("Host transcriptome: 14,226 human genes × 93 samples (RNA-seq, raw counts)", 1),
    ("Cytokines: 15 immune proteins per sample (not used in the three questions)", 1),
    "Clinical variables: BV status (51 negative / 39 positive / 3 intermediate), Nugent score, pH, any STI (48 of 93), RNA-seq batch (B1 / B2)",
], Inches(6.2), Inches(1.25), Inches(6.6), Inches(3.4))
bullets(s, [
    "Quality control first: sample sheet complete, tables aligned to it, counts integer with no gaps, batch not confounded with arm",
    "One flagged item: sample B006 has low microbiome depth (5,247 reads) — kept, but noted; cytokines missing for 2 samples",
    "Workshop rule kept throughout: raw counts into DESeq2, groups defined from one table and tested on the other",
], Inches(0.55), Inches(4.7), Inches(12.3), Inches(2.2), size=14)

# ------------------------------------------------------------- 3 roadmap ---
s = new_slide("Three questions, three analyses")
for i, (q, note) in enumerate([
    ("Does the vaginal microbiome differ between contraceptive methods?",
     "Species table · diversity, composition, ordination, DESeq2"),
    ("Does the ring — which acts locally — differ from systemic methods in host gene expression?",
     "Gene table · DESeq2, local vs systemic route"),
    ("Does the vaginal community type explain host gene expression better than contraceptive method does?",
     "Types defined from the microbiome · tested on genes · DESeq2 LRT + PERMANOVA"),
]):
    y = Inches(1.5 + i * 1.85)
    _rect(s, Inches(0.55), y, Inches(0.85), Inches(1.55), ACCENT_C)
    _text(s, Inches(0.55), y + Inches(0.35), Inches(0.85), Inches(0.8),
          f"Q{i+1}", size=30, bold=True, color=RGBColor(0xFF, 0xFF, 0xFF),
          align=PP_ALIGN.CENTER)
    _text(s, Inches(1.7), y + Inches(0.1), Inches(11.0), Inches(1.5),
          [(q, {"size": 18, "bold": True, "color": TITLE_C}),
           (note, {"size": 13.5, "italic": True, "color": ACCENT_C})])

# ============================================================ QUESTION 1 ===
question_slide(
    1,
    "Does the vaginal microbiome differ between the three contraceptive methods (pill, injectable, ring)?",
    "Different contraceptives expose the vagina to different hormones — oestrogen and progestin given "
    "orally, by injection, or released locally from a ring. If the hormonal environment shapes which "
    "bacteria thrive, the three arms should have different bacterial communities.",
    ["Groups defined from the METADATA (arm); the species count table is what we test.",
     "Alpha diversity: Shannon index per sample, compared with Kruskal–Wallis (a rank test for 3 groups).",
     "Composition: mean relative abundance of the top 9 genera per arm (plot only — shares, not amounts).",
     "Community structure: Bray–Curtis distances between samples, PCoA ordination, PERMANOVA test "
     "(999 permutations), adjusting for BV, STI and batch.",
     "Differential abundance: DESeq2 on RAW counts (design ~ batch + BV + arm), adjusted p < 0.05; "
     "110 of 220 species kept after minimal filtering."])

# Q1 results — diversity & composition
s = new_slide("Q1 · Results 1 — diversity and dominance",
              "Is there as much / the same kind of bacterial life in each arm?")
_pic(s, os.path.join(FIG, "fig2_shannon.png"), Inches(0.55), Inches(1.45), Inches(6.1), Inches(4.15))
_pic(s, os.path.join(FIG, "fig3_composition.png"), Inches(6.85), Inches(1.45), Inches(6.1), Inches(4.15))
bullets(s, [
    "Shannon medians: pill 0.90, injectable 1.74, ring 1.59 — Kruskal–Wallis p = 0.47 (no difference)",
    "Lactobacillus-dominant samples (>50% of reads): 61% of pill, 49% of injectable, 46% of ring users",
], Inches(0.55), Inches(5.8), Inches(12.3), Inches(0.65), size=13)
finding(s, "Diversity and overall dominance do not differ by method — every arm holds a mix of "
           "Lactobacillus-dominant and diverse communities.")

# Q1 results — structure
s = new_slide("Q1 · Results 2 — whole-community composition",
              "Do the communities as wholes shift between arms?")
_pic(s, os.path.join(FIG, "fig4_pcoa.png"), Inches(0.55), Inches(1.45), Inches(7.1), Inches(4.6))
table(s, Inches(8.0), Inches(1.75), Inches(4.9),
      ["PERMANOVA (Bray–Curtis)", "R²", "p"],
      [["Arm alone", "0.033", "0.112"],
       ["Arm + BV + STI + batch", "0.272", "0.001"]],
      col_widths=[2.9, 1.0, 1.0], fsize=13)
bullets(s, [
    "Each point is one participant's sample; dashed ellipses group arms",
    "Arms overlap heavily; BV status, not arm, drives the significant full model",
], Inches(8.0), Inches(3.6), Inches(4.9), Inches(1.6), size=13)
finding(s, "Method alone does not significantly explain overall community composition "
           "(R² = 0.033, p = 0.11) — 3% of the variation.")

# Q1 results — DESeq2
s = new_slide("Q1 · Results 3 — which species differ",
              "Species-level tests (DESeq2 on raw counts, adjusted p < 0.05)")
_pic(s, os.path.join(FIG, "fig5_deseq2_ring_vs_pill.png"), Inches(0.55), Inches(1.45), Inches(6.1), Inches(4.15))
_pic(s, os.path.join(FIG, "fig5_deseq2_injectable_vs_pill.png"), Inches(6.85), Inches(1.45), Inches(6.1), Inches(4.15))
bullets(s, [
    "Ring vs pill: 27 significant species — BV-associated anaerobes (Atopobium, Mobiluncus, Prevotella, Sneathia) higher in ring users",
    "Injectable vs pill: 6 significant species (incl. L. crispatus higher in injectable); ring vs injectable: 14",
], Inches(0.55), Inches(5.8), Inches(12.3), Inches(0.65), size=13)
finding(s, "Species-level differences exist — largest between ring and pill (27 species), and they "
           "point toward a more BV-like flora in ring users.")

answer_slide(
    1, "Does the vaginal microbiome differ between contraceptive methods?",
    ["Modestly, yes — at the species level, not in overall structure.",
     "Diversity (Shannon, p = 0.47) and whole-community composition (PERMANOVA R² = 0.033, p = 0.11) do not significantly differ by arm.",
     "But DESeq2 finds consistent species-level differences: 27 species between ring and pill, mostly BV-associated anaerobes higher in ring users.",
     "BV status is the stronger correlate of community composition in this dataset."])

# ============================================================ QUESTION 2 ===
question_slide(
    2,
    "Does the ring — which releases hormone locally at the vagina — differ from the systemic methods in host gene expression?",
    "The ring acts at the vaginal surface; the pill and injectable act through the bloodstream. If local "
    "hormone exposure changes the vaginal tissue itself, ring users should show a distinct pattern of "
    "host (human) gene expression in the RNA-seq data.",
    ["Route defined from the METADATA: local (ring, n = 26) vs systemic (pill + injectable, n = 67); "
     "the gene table is what we test.",
     "RNA-seq depth is even between routes (median ~12.9 M reads).",
     "DESeq2 on RAW counts, design ~ RNA-seq batch + BV + STI + route, adjusted p < 0.05.",
     "PCA on variance-stabilised values of the 500 most variable genes (a plot, not a test).",
     "Consistency check: separate ring-vs-pill and ring-vs-injectable models — a real local signal "
     "should point the same way against both."])

# Q2 results — PCA
s = new_slide("Q2 · Results 1 — the expression landscape",
              "Do ring users look different before any formal test?")
_pic(s, os.path.join(FIG, "fig7_gene_pca.png"), Inches(0.55), Inches(1.45), Inches(7.1), Inches(4.6))
bullets(s, [
    "Each point = one participant; solid = local (ring), circles/triangles = which systemic arm",
    "Mean PC1: ring (local) +4.6 vs systemic −1.8 — ring samples shift along PC1",
    "Separation is visible but partial: individuals overlap",
], Inches(8.0), Inches(1.75), Inches(4.9), Inches(2.6), size=13)
finding(s, "There is a visible route-related shift in host gene expression along PC1 — worth testing formally.")

# Q2 results — DE genes
s = new_slide("Q2 · Results 2 — which genes differ",
              "DESeq2, ring (local) vs pill + injectable (systemic), adjusted p < 0.05")
_pic(s, os.path.join(FIG, "fig8_gene_top_hits.png"), Inches(0.55), Inches(1.4), Inches(6.9), Inches(4.7))
bullets(s, [
    "66 of 14,226 tested genes significant: 40 up in ring, 26 down",
    "Up in ring: secretory & inflammatory genes — BPIFA1 (antimicrobial secretory protein, log2FC 5.8), SERPINA11, PTGS2 (prostaglandin synthase, log2FC 1.6)",
    "Down in ring (higher in systemic): epithelial keratinisation genes — TGM3 (−3.7), KPRP (−3.4), KRT1 (−2.3)",
], Inches(7.7), Inches(1.6), Inches(5.2), Inches(4.3), size=13.5)
finding(s, "A small but interpretable signature: more secretory/inflammatory activity and less "
           "epithelial keratinisation in ring users.")

# Q2 results — consistency
s = new_slide("Q2 · Results 3 — is the signal consistent?",
              "A real local-vs-systemic effect should hold against either systemic method")
table(s, Inches(0.9), Inches(1.8), Inches(11.5),
      ["Consistency check (adjusted p < 0.05)", "Result"],
      [["Ring vs pill — significant genes", "60"],
       ["Ring vs injectable — significant genes", "87"],
       ["Significant in BOTH contrasts", "11 of 14,226"],
       ["…of which point the same direction", "11 of 11 (100%)"]],
      col_widths=[7.5, 4.0], fsize=14)
finding(s, "The route signal is internally consistent: whichever systemic method the ring is compared "
           "against, the shared significant genes always point the same way.")

answer_slide(
    2, "Does the ring differ from systemic methods in host gene expression?",
    ["Yes — a small but coherent local-vs-systemic signature.",
     "66 of 14,226 genes differ (adjusted p < 0.05): secretory and inflammatory genes up in ring users, keratinisation genes down.",
     "The signal is consistent against both systemic methods (11 genes significant in both, all same direction).",
     "It is a modest effect — 0.5% of tested genes — but biologically interpretable: local hormone delivery appears to change the vaginal epithelial state."])

# ============================================================ QUESTION 3 ===
question_slide(
    3,
    "Does the vaginal community type explain host gene expression better than contraceptive method does?",
    "Vaginal microbiomes fall into a few recurring 'community state types' (CSTs) — classic examples "
    "are Lactobacillus-dominant vs diverse/BV-like. If the bacterial environment shapes the host "
    "tissue, women sharing a community type should share gene-expression patterns, possibly more "
    "than women sharing a contraceptive method.",
    ["Types defined from the MICROBIOME table: Bray–Curtis distances, Ward clustering; k = 3 chosen "
     "by mean silhouette (0.32, best of k = 2–5).",
     "Types named by biology: Crispatus-dominant, Iners-dominant, Diverse (BV-like).",
     "Workshop rule kept: types come from one table, the GENES are tested in the other.",
     "DESeq2 likelihood-ratio tests (LRT) with identical covariates — community type vs arm — so the "
     "two groupings are compared fairly.",
     "PERMANOVA on variance-stabilised values (top 2,000 genes) for how much variance each grouping explains."])

# Q3 results — types
s = new_slide("Q3 · Results 1 — three community types",
              "What the microbiome table looks like when clustered")
_pic(s, os.path.join(FIG, "fig10_composition_by_ctype.png"), Inches(0.55), Inches(1.45), Inches(6.9), Inches(4.5))
table(s, Inches(7.7), Inches(1.6), Inches(5.1),
      ["Community type", "n", "Lactobacillus share"],
      [["Crispatus-dominant", "21", "97%"],
       ["Iners-dominant", "24", "88%"],
       ["Diverse (BV-like)", "48", "16%"]],
      col_widths=[2.6, 0.9, 1.6], fsize=13)
bullets(s, [
    "The diverse type is largely BV-positive: 37 of its 48 members; nearly all BV-negative women are Lactobacillus-dominant",
], Inches(7.7), Inches(3.4), Inches(5.1), Inches(1.4), size=13)
finding(s, "The dataset splits into the classic CSTs, and the diverse/BV-like type tracks BV status "
           "almost perfectly — this is the type's definition, not a test.")

# Q3 results — genes
s = new_slide("Q3 · Results 2 — how many genes each grouping explains",
              "Same covariates, only the grouping differs (LRT; route: Wald test)")
_pic(s, os.path.join(FIG, "fig11_sig_gene_counts.png"), Inches(0.55), Inches(1.45), Inches(6.9), Inches(4.15))
_pic(s, os.path.join(FIG, "fig9_gene_pca_by_ctype.png"), Inches(7.7), Inches(1.45), Inches(5.1), Inches(4.15))
bullets(s, [
    "Community type: 93 significant genes; arm (method): 49; route (local vs systemic): 66",
    "Top community-type genes (EDN2, CCNG2, ARL4C) are highest in the Crispatus-dominant type",
], Inches(0.55), Inches(5.8), Inches(12.3), Inches(0.65), size=13)
finding(s, "Gene by gene, community type flags nearly twice as many genes as method (93 vs 49) — "
           "the bacterial environment looks like the better correlate.")

# Q3 results — variance
s = new_slide("Q3 · Results 3 — how much variance, formally",
              "PERMANOVA on host gene expression (VST, top 2,000 genes, 999 permutations)")
table(s, Inches(0.9), Inches(1.8), Inches(11.5),
      ["Grouping", "R²", "p-value", "Reading"],
      [["Community type", "0.020", "0.51", "not significant"],
       ["Arm (method)", "0.032", "0.059", "borderline"],
       ["Route (local vs systemic)", "0.022", "0.038", "significant"],
       ["Type + arm together", "0.054", "0.14", "adds nothing significant"]],
      col_widths=[3.6, 1.4, 1.6, 4.9], fsize=13.5)
finding(s, "Globally, neither grouping explains much expression variance (~2–3%); only route is "
           "significant, and the gene-count advantage of community type does not translate into "
           "more explained variance.")

answer_slide(
    3, "Does community type explain host gene expression better than method?",
    ["Mixed evidence — neither grouping dominates.",
     "Gene by gene, community type flags more genes than method (93 vs 49), but its global variance share is the smallest of the three groupings (R² = 0.02, p = 0.51).",
     "Community type largely mirrors BV status, so part of its signal is BV ecology rather than type itself.",
     "The only globally significant grouping is route (local vs systemic) — the same signal found in Question 2.",
     "Honest summary: both effects are small; local-vs-systemic delivery is the clearest host-expression correlate in this dataset."])

# ------------------------------------------------------------ conclusions ---
s = new_slide("Putting the three answers together",
              "What this dataset says, overall")
bullets(s, [
    "Contraceptive method leaves a modest footprint on the vaginal microbiome: no diversity difference, no significant global compositional shift, but consistent species-level differences — largest between ring and pill, pointing toward a more BV-like flora in ring users.",
    "How the hormone is delivered matters more than which method it is: the locally acting ring shows a small, internally consistent host transcriptional signature (secretory/inflammatory genes up, keratinisation genes down), and route is the only grouping with a significant global effect on gene expression.",
    "The bacterial environment (community type) is the strongest gene-level correlate in the gene-by-gene comparison — but it largely mirrors BV status, and neither type nor method explains more than ~3% of expression variance.",
    "Taken together: in this cross-sectional study, BV-like ecology and local-vs-systemic hormone delivery matter more for the vaginal environment than the specific contraceptive chosen.",
    "Not yet analysed: the cytokines layer (15 immune proteins; 2 samples lack values) — the natural next question is whether the ring's transcriptional signature shows up as measurable inflammation.",
], Inches(0.55), Inches(1.45), Inches(12.3), Inches(5.0), size=15.5)

# --------------------------------------------------------- choices made ---
s = new_slide("Choices made",
              "Each with the alternative we did not choose")
bullets(s, [
    "Community types: k = 3 Ward clusters on Bray–Curtis, chosen by mean silhouette (0.32) — alternative: k = 2–5 were computed and scored lower",
    "Route grouping: ring vs pill + injectable, defined from metadata — alternative: a three-arm gene model, run as the consistency check",
    "DESeq2 on raw counts with design ~ batch + BV (+ STI) — alternative: no covariates, which would confound route with batch",
    "Significance threshold: adjusted p < 0.05 (BH) — alternative: raw p < 0.05, far too permissive across 14,226 genes",
    "Minimal filter before testing: total reads ≥ 10 — alternative: stricter prevalence filter (would drop rare features)",
    "Low-depth sample B006 kept — alternative: dropped (would remove one ring sample from species analyses)",
    "VST transform used only for plots and ordination — alternative: testing VST values would violate the raw-counts rule",
    "Cytokines not analysed (sub-LLOD values; 2 samples all-NA) — deferred rather than forced into the tests",
], Inches(0.55), Inches(1.45), Inches(12.3), Inches(5.4), size=14)

# ------------------------------------------------------- speaker notes ---
# In slide order; each note starts with the transition from the previous slide.
NOTES = [
    # 1 title
    "Good morning, everyone, and thank you for coming. Today I am presenting our Group B project: "
    "how contraceptive method relates to the vaginal environment. We brought together three layers "
    "of information from the same 93 women — the vaginal microbiome, the expression of their own "
    "human genes, and their clinical details. Over the next few minutes I will show you the dataset, "
    "the three questions we asked of it, what we found for each one, and what the answers mean "
    "when you put them together.",
    # 2 dataset
    "Before any results, let me show you the data itself. This is Study B, a cross-sectional study — "
    "one vaginal sample per woman, at a single time point. The 93 participants use one of three "
    "contraceptive methods: the injectable, the pill, or the vaginal ring. That method is our main "
    "grouping variable, and it comes from the sample sheet — we never derive groups from the count "
    "data we are testing. For every sample we have three layers: bacterial species counts, human "
    "gene expression from RNA-seq, and fifteen cytokines — though the cytokines were not used in "
    "the three questions I will show you. We did quality control first: the tables align, the counts "
    "are complete, and the lab batch is not confounded with the method. One sample, B006, had low "
    "microbiome depth; we kept it but flagged it. With the data checked, here are the three "
    "questions we asked.",
    # 3 roadmap
    "Our three questions build on each other. First, the simplest one: does the vaginal microbiome "
    "itself differ between the methods? Second, we turn to the host: the ring is the only method "
    "that acts locally at the vagina, so do ring users show a different gene-expression profile? "
    "And third, we put the two data layers head-to-head: which explains host gene expression "
    "better — the bacterial community type, or the contraceptive method? Let us start with the "
    "microbiome.",
    # 4 Q1 question
    "Question one: does the vaginal microbiome differ between pill, injectable and ring users? "
    "The reasoning is that different methods expose the vagina to different hormone doses and "
    "routes, and the hormonal environment is known to shape which bacteria thrive. We defined the "
    "groups from the metadata and tested the species table. We looked at diversity with the Shannon "
    "index and a Kruskal–Wallis test, at composition with mean relative abundance plots, at whole "
    "communities with Bray–Curtis ordination and PERMANOVA adjusting for bacterial vaginosis, STIs "
    "and batch, and at individual species with DESeq2 on raw counts. First: is there the same kind "
    "and amount of bacterial life in each arm?",
    # 5 Q1 R1
    "Here diversity does not differ: the Shannon medians are 0.90 for pill, 1.74 for injectable and "
    "1.59 for ring, and the Kruskal–Wallis p-value is 0.47 — no significant difference. The "
    "composition panel on the right tells a similar story: Lactobacillus-dominant samples make up "
    "61 percent of pill users, 49 percent of injectable and 46 percent of ring users — a slight "
    "downward trend, but every arm contains a mix of Lactobacillus-dominant and diverse communities. "
    "So the amount of bacterial life is similar. But maybe the communities as wholes still differ — "
    "that is the next test.",
    # 6 Q1 R2
    "This ordination shows each woman's whole community as one point, positioned by how similar her "
    "bacteria are to everyone else's. The ellipses group the arms, and you can see they overlap "
    "heavily. Formally, contraceptive method alone explains only about three percent of the "
    "variation in community composition — R squared 0.033, p equal to 0.11, not significant. The "
    "full model on the right is significant, but that is driven by bacterial vaginosis status, not "
    "by the method. So whole communities do not shift by arm — but perhaps individual species do. "
    "That is the species-level test.",
    # 7 Q1 R3
    "And here the answer changes. Testing species one at a time with DESeq2, ring users differ from "
    "pill users in 27 species — the largest contrast — and the pattern is striking: BV-associated "
    "anaerobes like Atopobium, Mobiluncus, Prevotella and Sneathia are higher in ring users. "
    "Injectable versus pill shows only 6 significant species, and ring versus injectable 14. So "
    "species-level differences do exist, largest between ring and pill, pointing toward a more "
    "BV-like flora in ring users. Let me summarise question one.",
    # 8 Q1 answer
    "So: does the microbiome differ between methods? Modestly, yes — at the species level, not in "
    "overall structure. Diversity and whole-community composition show no significant differences, "
    "but DESeq2 finds consistent species-level differences, especially between ring and pill. And "
    "throughout, BV status is the stronger correlate of the microbiome than the method itself. "
    "That is the bacterial side. Now we turn the lens around to the host, and specifically to the "
    "ring — the only method that releases its hormone locally at the vagina rather than through "
    "the bloodstream.",
    # 9 Q2 question
    "Question two: does the ring differ from the systemic methods in host gene expression? If "
    "local hormone exposure changes the vaginal tissue itself, ring users should show a distinct "
    "expression pattern. We grouped women by delivery route — 26 local, 67 systemic — defined from "
    "the metadata, and tested the gene table with DESeq2 on raw counts, adjusting for batch, BV and "
    "STI. RNA-seq depth was even between the groups. Before any formal test, an important sanity "
    "check: does a difference show up in an unsupervised plot?",
    # 10 Q2 R1
    "It does. This is a principal component analysis of the 500 most variable genes — no group "
    "labels were used to build it. Ring users, the solid squares, shift along the first axis: their "
    "mean PC1 is plus 4.6 against minus 1.8 for the systemic methods. The separation is visible "
    "but partial — individuals still overlap. So there is a route-related signal worth testing "
    "formally. The obvious next question: which genes drive it?",
    # 11 Q2 R2
    "Of the 14,226 genes tested, 66 are significant at adjusted p below 0.05 — 40 higher in ring "
    "users, 26 lower. The chart shows the strongest hits. Up in the ring: secretory and "
    "inflammatory genes — BPIFA1, an antimicrobial secretory protein, with a log2 fold change of "
    "5.8; PTGS2, the prostaglandin synthase; SERPINA11. Down in the ring — that is, higher in "
    "systemic users — are keratinisation genes: TGM3, KPRP, KRT1. In plain terms: more secretory "
    "and inflammatory activity, less epithelial cornification, in ring users. A small but very "
    "interpretable signature. But one grouping choice could fool us here — the two systemic "
    "methods might differ from each other. So we ran a consistency check.",
    # 12 Q2 R3
    "If the local-versus-systemic signal is real, the ring should differ from pill AND from "
    "injectable in the same direction. It does: 60 significant genes against pill, 87 against "
    "injectable, and 11 genes are significant in both contrasts — every single one of them points "
    "the same way. The signal holds whichever systemic method we compare against. Here is the "
    "answer to question two.",
    # 13 Q2 answer
    "Yes — the ring leaves a small but coherent local-versus-systemic signature. Sixty-six genes "
    "differ: secretory and inflammatory genes up in ring users, keratinisation genes down. The "
    "signal is internally consistent against both systemic methods. And it is a modest effect — "
    "half a percent of tested genes — but biologically interpretable: local hormone delivery "
    "appears to change the state of the vaginal epithelium. We have now seen the microbiome differ "
    "modestly by method, and the host respond to local delivery. Our final question puts the two "
    "data layers head-to-head: which explains host expression better — the bacterial community "
    "type, or the method?",
    # 14 Q3 question
    "Question three. Vaginal microbiomes fall into a few recurring community state types — "
    "classically Lactobacillus-dominant versus diverse and BV-like. If the bacterial environment "
    "shapes the host tissue, women sharing a community type should share expression patterns, "
    "perhaps more than women sharing a method. We defined the types from the microbiome table — "
    "Bray–Curtis distances, Ward clustering, three clusters chosen because they scored best on the "
    "silhouette measure — and then tested the genes, respecting our workshop rule: the group comes "
    "from one table, the test happens on the other. To compare the two groupings fairly we used "
    "identical covariates and likelihood-ratio tests. First: what do these community types look "
    "like?",
    # 15 Q3 R1
    "The dataset splits into the three classic types: 21 women are Crispatus-dominant, with 97 "
    "percent Lactobacillus; 24 are Iners-dominant, 88 percent Lactobacillus; and 48 fall into a "
    "diverse, BV-like type with only 16 percent Lactobacillus. Notice how tightly that diverse type "
    "tracks BV status — 37 of its 48 members are BV-positive, while almost all BV-negative women "
    "are Lactobacillus-dominant. One caution: this panel is the type's definition, not a test. Now "
    "the head-to-head on the genes.",
    # 16 Q3 R2
    "Here is the gene count comparison, with everything else held equal. Community type flags 93 "
    "significant genes; contraceptive method, 49; route, 66. Gene by gene, community type looks "
    "like the stronger correlate — nearly twice as many genes as method — and the top hits, like "
    "EDN2 and CCNG2, are highest in the Crispatus-dominant type. But counting genes is only one "
    "view, and it can mislead: the formal question is how much variance each grouping actually "
    "explains.",
    # 17 Q3 R3
    "And here the picture changes. On the full expression profile, community type explains only "
    "two percent of the variance and is not significant — p equal to 0.51. Method explains three "
    "percent, borderline. The only globally significant grouping is route — the same local-versus-"
    "systemic signal from question two. And combining type and method adds nothing significant. So "
    "the gene-count advantage of community type does not translate into more explained variance. "
    "Let me give you the honest answer to question three.",
    # 18 Q3 answer
    "The evidence is mixed — neither grouping dominates. Community type flags more genes than "
    "method, 93 versus 49, but explains the least variance globally, and much of its signal is "
    "really BV ecology, since the diverse type mirrors BV status. The only globally significant "
    "grouping is route — the same signal we found in question two. Both effects are small; "
    "local-versus-systemic delivery is the clearest host-expression correlate in this dataset. "
    "Let me put all three answers on one page.",
    # 19 conclusions
    "Taken together, three messages. First: contraceptive method leaves a modest footprint on the "
    "vaginal microbiome — no diversity difference, no significant global shift, but consistent "
    "species-level differences, largest between ring and pill. Second: how the hormone is delivered "
    "matters more than which method it is — the locally acting ring shows a small, reproducible "
    "transcriptional signature, and route is the only grouping with a significant global effect on "
    "gene expression. Third: the bacterial community type is the strongest gene-by-gene correlate, "
    "but it largely mirrors BV status, and neither grouping explains more than about three percent "
    "of expression variance. In short: BV-like ecology and local hormone delivery matter more than "
    "the specific contraceptive chosen. The natural next step is the cytokine layer we have not "
    "yet analysed — does the ring's transcriptional signature show up as measurable inflammation? "
    "Finally, so you can judge how much to trust each number, here are the choices we made.",
    # 20 choices
    "A few decisions worth knowing about. We chose three community types by the silhouette score "
    "and tested alternatives. We used DESeq2 on raw counts with batch and BV as covariates, so "
    "route differences are not confounded. We required adjusted p below 0.05 across more than "
    "fourteen thousand genes. We kept the low-depth sample rather than dropping it. And we used "
    "the variance-stabilising transform only for plots, never for tests. Every alternative we did "
    "not choose is listed in the project reports. Thank you very much — I am happy to take "
    "questions.",
]
for slide, note in zip(prs.slides, NOTES):
    slide.notes_slide.notes_text_frame.text = note
assert len(NOTES) == len(prs.slides._sldIdLst), f"{len(NOTES)} notes for {len(prs.slides._sldIdLst)} slides"

prs.save(OUT)
print("Saved:", OUT, "—", len(prs.slides._sldIdLst), "slides, all with speaker notes")
