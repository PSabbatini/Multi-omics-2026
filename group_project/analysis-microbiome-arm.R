# analysis-microbiome-arm.R -----------------------------------------------------
#
# Question: does the vaginal microbiome differ by contraceptive arm
#           (pill / injectable / ring) in the Group B dataset?
#
# Outputs:  figures -> group_project/figures/
#           tables  -> printed to console as markdown, for the HTML write-up.
#
# Workshop rules respected:
#   - arm is defined from the METADATA, and the species table is what we test
#   - raw counts go into DESeq2 (no CPM, no log transform first)
#   - count matrix columns are checked against metadata rows before any test

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(ggplot2)
  library(vegan)
  library(DESeq2)
})

source(here::here("R/count_tables.R"))

fig_dir <- here::here("group_project", "figures")
dir.create(fig_dir, showWarnings = FALSE)

theme_set(theme_minimal(base_size = 13))
arm_cols <- c(pill = "#4a6fa5", injectable = "#c26b3f", ring = "#4d8f6a")

## ---- 1. Load and CHECK ORDER -------------------------------------------------
d    <- read_counts("group_b")
meta <- d$metadata
sp   <- d$species   # helper already reorders columns to metadata$sample_id

# Belt and braces: confirm explicitly (DESeq2 will not warn, it will just be wrong)
stopifnot(identical(colnames(sp), meta$sample_id))
cat("Order check passed:", ncol(sp), "samples, columns == metadata$sample_id\n")

meta$arm <- factor(meta$arm, levels = c("pill", "injectable", "ring"))
cat("\n### Group sizes\n\n")
print(as.data.frame(table(meta$arm, dnn = "arm")))

## ---- 2. Library sizes ---------------------------------------------------------
libs <- data.frame(sample_id = colnames(sp), libsize = colSums(sp)) |>
  left_join(meta, by = "sample_id")
cat("\nLibrary size summary (reads per sample):\n")
print(summary(libs$libsize))

p1 <- ggplot(libs, aes(arm, libsize / 1000, fill = arm)) +
  geom_boxplot(outlier.size = 0.8, alpha = 0.6) +
  geom_jitter(width = 0.15, size = 0.8, alpha = 0.5) +
  scale_fill_manual(values = arm_cols) +
  labs(title = "Sequencing depth (library size) by arm",
       y = "reads per sample (thousands)", x = NULL) +
  theme(legend.position = "none")
ggsave(file.path(fig_dir, "fig1_library_size.png"), p1,
       width = 6, height = 4, dpi = 150)

## ---- 3. Alpha diversity (Shannon) --------------------------------------------
# Shannon: how many species are present AND how evenly spread they are.
alpha <- data.frame(sample_id = colnames(sp), shannon = diversity(t(sp), index = "shannon")) |>
  left_join(meta, by = "sample_id")

kw <- kruskal.test(shannon ~ arm, data = alpha)
cat("\n### Alpha diversity (Shannon) by arm\n")
print(alpha |> group_by(arm) |> summarise(median = median(shannon),
                                          q1 = quantile(shannon, .25),
                                          q3 = quantile(shannon, .75), .groups = "drop"))
cat("\nKruskal-Wallis: chi-sq =", signif(kw$statistic, 3),
    "df =", kw$parameter, "p =", signif(kw$p.value, 3), "\n")
pw <- pairwise.wilcox.test(alpha$shannon, alpha$arm, p.adjust.method = "BH")
print(pw)

p2 <- ggplot(alpha, aes(arm, shannon, fill = arm)) +
  geom_boxplot(outlier.size = 0.8, alpha = 0.6) +
  geom_jitter(width = 0.15, size = 0.8, alpha = 0.5) +
  scale_fill_manual(values = arm_cols) +
  labs(title = "Alpha diversity (Shannon) by contraceptive arm",
       subtitle = paste0("Kruskal-Wallis p = ", signif(kw$p.value, 3)),
       y = "Shannon diversity", x = NULL) +
  theme(legend.position = "none")
ggsave(file.path(fig_dir, "fig2_shannon.png"), p2, width = 6, height = 4, dpi = 150)

## ---- 4. Composition: mean relative abundance of top genera -------------------
# Relative abundance only for the PLOT. (Both count tables are compositional:
# a lower share is not the same claim as "there was less of it".)
tax <- d$taxonomy
genus_rel <- sweep(sp, 2, colSums(sp), "/")        # share of each sample
# aggregate species rows up to Genus
genus_ids <- tax$Genus[match(rownames(sp), tax$taxon)]
genus_rel <- rowsum(genus_rel, group = genus_ids, reorder = TRUE)
top_g <- names(sort(rowMeans(genus_rel), decreasing = TRUE))[1:9]
meta_arms <- meta |> select(sample_id, arm)
comp <- as.data.frame(genus_rel[top_g, , drop = FALSE]) |>
  tibble::rownames_to_column("genus") |>
  tidyr::pivot_longer(-genus, names_to = "sample_id", values_to = "relab") |>
  left_join(meta_arms, by = "sample_id") |>
  bind_rows(
    data.frame(genus = "Other", sample_id = colnames(sp),
               relab = 1 - colSums(genus_rel[top_g, ])) |>
      left_join(meta_arms, by = "sample_id")
  ) |>
  group_by(arm, genus) |> summarise(relab = mean(relab), .groups = "drop") |>
  mutate(genus = factor(genus, levels = c(rev(sort(top_g)), "Other")))

p3 <- ggplot(comp, aes(arm, relab, fill = genus)) +
  geom_col(position = "stack", colour = "white", linewidth = 0.1) +
  scale_fill_brewer(palette = "Paired") +
  labs(title = "Mean composition by arm: top 9 genera",
       y = "mean relative abundance", x = NULL, fill = NULL) +
  theme(legend.text = element_text(face = "italic", size = 9),
        legend.key.height = grid::unit(9, "pt"))
ggsave(file.path(fig_dir, "fig3_composition.png"), p3, width = 8, height = 5, dpi = 150)

# Lactobacillus-dominance: share of samples >50% Lactobacillus, by arm
lac <- data.frame(sample_id = colnames(sp),
                  lac_share = genus_rel[rownames(genus_rel) == "Lactobacillus", ]) |>
  left_join(meta, by = "sample_id")
cat("\n### Lactobacillus-dominant samples (>50% of reads), by arm\n")
print(lac |> group_by(arm) |> summarise(n_dom = sum(lac_share > .5),
                                        n = n(), share = mean(lac_share > .5),
                                        mean_lac = mean(lac_share), .groups = "drop"))

## ---- 5. Beta diversity: Bray-Curtis PCoA + PERMANOVA -------------------------
# Bray-Curtis: how different each sample's whole community is from each other's.
bc <- vegdist(t(sp), method = "bray")
pcoa <- cmdscale(bc, k = 2, eig = TRUE, add = TRUE)
var_expl <- pcoa$eig[1:2] / sum(pcoa$eig[pcoa$eig > 0])
ord <- data.frame(sample_id = rownames(pcoa$points), MDS1 = pcoa$points[, 1],
                  MDS2 = pcoa$points[, 2]) |> left_join(meta, by = "sample_id")

p4 <- ggplot(ord, aes(MDS1, MDS2, colour = arm)) +
  geom_point(size = 2.2, alpha = 0.85) +
  stat_ellipse(linewidth = 0.6, linetype = 2) +
  scale_colour_manual(values = arm_cols) +
  labs(title = "Community composition (Bray-Curtis PCoA)",
       subtitle = "Each point = one participant's vaginal sample",
       x = paste0("PCoA 1 (", signif(100 * var_expl[1], 2), "%)"),
       y = paste0("PCoA 2 (", signif(100 * var_expl[2], 2), "%)"),
       colour = NULL) +
  theme(legend.position = "bottom")
ggsave(file.path(fig_dir, "fig4_pcoa.png"), p4, width = 7, height = 5, dpi = 150)

cat("\n### PERMANOVA (Bray-Curtis, 999 permutations)\n")
perm_full <- adonis2(bc ~ arm + bv + any_sti + rnaseq_batch, data = as.data.frame(meta),
                     permutations = 999)
print(perm_full)
perm_arm_alone <- adonis2(bc ~ arm, data = as.data.frame(meta), permutations = 999)
cat("\narm on its own:\n"); print(perm_arm_alone)

## ---- 6. DESeq2 differential abundance by arm ---------------------------------
# RAW counts in. Filter out species with almost no signal first.
keep <- rowSums(sp) >= 10
dds <- DESeqDataSetFromMatrix(countData = sp[keep, ], colData = meta,
                              design = ~ rnaseq_batch + bv + arm)
dds <- DESeq(dds, quiet = TRUE)
cat("\nDESeq2 design: ~ rnaseq_batch + bv + arm;", sum(keep),
    "of", nrow(sp), "species kept after minimal filtering\n")

contrasts <- list(
  injectable_vs_pill = c("arm", "injectable", "pill"),
  ring_vs_pill       = c("arm", "ring", "pill"),
  ring_vs_injectable = c("arm", "ring", "injectable")
)
tax_lookup <- tax |> select(taxon, Genus, species)

for (nm in names(contrasts)) {
  res <- results(dds, contrast = contrasts[[nm]], alpha = 0.05) |>
    as.data.frame() |>
    tibble::rownames_to_column("taxon") |>
    left_join(tax_lookup, by = "taxon") |>
    arrange(padj)
  cat("\n### DESeq2:", nm, "— significant species (padj < 0.05):",
      sum(res$padj < 0.05, na.rm = TRUE), "\n")
  top <- res |> filter(padj < 0.05) |> slice_head(n = 10) |>
    mutate(across(c(baseMean, lfcSE), ~ signif(.x, 3)),
           log2FC = round(log2FoldChange, 2),
           padj = signif(padj, 2)) |>
    select(taxon, Genus, log2FC, padj, baseMean)
  print(as.data.frame(top), row.names = FALSE)
  assign(paste0("res_", nm), res)

  # top-hit bar chart for the two main contrasts
  if (nm %in% c("injectable_vs_pill", "ring_vs_pill")) {
    top_plot <- res |> filter(padj < 0.05) |>
      mutate(label = ifelse(is.na(species), Genus, gsub(".*_", " ", species))) |>
      group_by(label) |> slice_max(abs(log2FoldChange), n = 1) |> ungroup() |>
      slice_max(abs(log2FoldChange), n = 8) |>
      ggplot(aes(log2FoldChange, reorder(label, log2FoldChange), fill = log2FoldChange > 0)) +
      geom_col(width = 0.7) +
      geom_vline(xintercept = 0, linewidth = 0.4) +
      scale_fill_manual(values = c("TRUE" = "#c26b3f", "FALSE" = "#4a6fa5"),
                        guide = "none") +
      labs(title = paste0("Most different species: ", gsub("_", " ", nm)),
           subtitle = "DESeq2, adjusted p < 0.05; positive = enriched in first arm of the pair",
           x = "log2 fold change", y = NULL) +
      theme(axis.text.y = element_text(face = "italic", size = 10))
    ggsave(file.path(fig_dir, paste0("fig5_deseq2_", nm, ".png")), top_plot,
           width = 7.5, height = 4.5, dpi = 150)
  }
}

cat("\nDone. Figures in:", fig_dir, "\n")
