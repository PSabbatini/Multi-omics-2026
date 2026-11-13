# analysis-genes-ring.R ---------------------------------------------------------
#
# Question: the ring acts locally at the vagina; pill and injectable act
#           systemically. Does the ring differ from the other two in HOST gene
#           expression (the RNA-seq table)?
#
# Grouping: route = "local" (ring, n=26) vs "systemic" (pill + injectable, n=67),
#           defined from the METADATA (arm) — the gene table is what we test.
#
# Outputs:  figures -> group_project/figures/
#           full DESeq2 result tables -> group_project/results/
#           summary tables -> printed to console as for the HTML write-up.

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(ggplot2)
  library(DESeq2)
})

source(here::here("R/count_tables.R"))

fig_dir <- here::here("group_project", "figures")
res_dir <- here::here("group_project", "results")
dir.create(fig_dir, showWarnings = FALSE)
dir.create(res_dir, showWarnings = FALSE)

theme_set(theme_minimal(base_size = 13))
route_cols <- c(local = "#4d8f6a", systemic = "#4a6fa5")

## ---- 1. Load and CHECK ORDER -------------------------------------------------
d     <- read_counts("group_b")
meta  <- d$metadata
genes <- d$genes   # 14,226 human genes x 93 samples, raw counts

stopifnot(identical(colnames(genes), meta$sample_id))
cat("Order check passed:", ncol(genes), "samples, columns == metadata$sample_id\n")

meta$route <- factor(ifelse(meta$arm == "ring", "local", "systemic"),
                     levels = c("systemic", "local"))
meta$arm <- factor(meta$arm, levels = c("pill", "injectable", "ring"))
cat("\n### Route groups (defined from metadata, not from the counts)\n\n")
print(table(arm = meta$arm, route = meta$route))

## ---- 2. Library sizes ---------------------------------------------------------
libs <- data.frame(sample_id = colnames(genes), libsize = colSums(genes)) |>
  left_join(meta, by = "sample_id")
cat("\nGene library size summary:\n")
print(summary(libs$libsize))

p1 <- ggplot(libs, aes(route, libsize / 1e6, fill = route)) +
  geom_boxplot(outlier.size = 0.8, alpha = 0.6) +
  geom_jitter(width = 0.15, size = 0.8, alpha = 0.5) +
  scale_fill_manual(values = route_cols) +
  labs(title = "RNA-seq depth (library size) by delivery route",
       y = "mapped reads per sample (millions)", x = NULL) +
  theme(legend.position = "none")
ggsave(file.path(fig_dir, "fig6_gene_libsize.png"), p1, width = 6, height = 4, dpi = 150)

## ---- 3. DESeq2: ring (local) vs pill+injectable (systemic) -------------------
# RAW counts in. Filter near-silent genes. Adjust for batch, BV and STI status
# so route differences are not confounded by them.
keep <- rowSums(genes) >= 10
cat("\nGenes kept after minimal filter (total reads >= 10):", sum(keep),
    "of", nrow(genes), "\n")
dds <- DESeqDataSetFromMatrix(countData = genes[keep, ], colData = as.data.frame(meta),
                              design = ~ rnaseq_batch + bv + any_sti + route)
dds <- DESeq(dds, quiet = TRUE)

res <- results(dds, contrast = c("route", "local", "systemic"), alpha = 0.05)
cat("\n### DESeq2: local (ring) vs systemic (pill + injectable)\n")
print(summary(res, alpha = 0.05))
res_df <- as.data.frame(res) |>
  tibble::rownames_to_column("ensembl_gene_id") |>
  left_join(d$gene_info, by = "ensembl_gene_id") |>
  mutate(log2FC = round(log2FoldChange, 2), padj = signif(padj, 2))
write.csv(res_df, file.path(res_dir, "deseq2_ring_local_vs_systemic.csv"),
          row.names = FALSE)
cat("\nFull results written to group_project/results/deseq2_ring_local_vs_systemic.csv\n")

sig <- res_df |> filter(padj < 0.05)
cat("\nSignificant genes (adjusted p < 0.05):", nrow(sig),
    "of", nrow(res_df), "tested\n")
cat("\nTop 10 UP in ring (local):\n\n")
up <- sig |> filter(log2FoldChange > 0) |> arrange(padj) |> slice_head(n = 10) |>
  select(symbol, gene_name, locus_group, log2FC, padj, baseMean) |>
  mutate(across(c(baseMean), ~ signif(.x, 3)))
print(as.data.frame(up), row.names = FALSE)
cat("\nTop 10 DOWN in ring (i.e. higher in systemic):\n\n")
down <- sig |> filter(log2FoldChange < 0) |> arrange(padj) |> slice_head(n = 10) |>
  select(symbol, gene_name, locus_group, log2FC, padj, baseMean) |>
  mutate(across(c(baseMean), ~ signif(.x, 3)))
print(as.data.frame(down), row.names = FALSE)

## ---- 4. Consistency: is the local signal driven by both systemic methods? ----
# If "local vs systemic" is real, ring should differ from pill AND from
# injectable in the same direction. arm needs its own model (it is not in the
# route design above).
dds_arm <- DESeqDataSetFromMatrix(countData = genes[keep, ], colData = as.data.frame(meta),
                                  design = ~ rnaseq_batch + bv + any_sti + arm)
dds_arm <- DESeq(dds_arm, quiet = TRUE)
res_rp <- results(dds_arm, contrast = c("arm", "ring", "pill"), alpha = 0.05)
res_ri <- results(dds_arm, contrast = c("arm", "ring", "injectable"), alpha = 0.05)
rp <- as.data.frame(res_rp) |> tibble::rownames_to_column("ensembl_gene_id") |>
  filter(padj < 0.05)
ri <- as.data.frame(res_ri) |> tibble::rownames_to_column("ensembl_gene_id") |>
  filter(padj < 0.05)
cat("\n### Consistency checks (adjusted p < 0.05)\n")
cat("ring vs pill:        ", nrow(rp), "significant genes\n")
cat("ring vs injectable:  ", nrow(ri), "significant genes\n")
same_dir <- intersect(rp$ensembl_gene_id, ri$ensembl_gene_id)
agree <- sum(sign(res_rp[same_dir, "log2FoldChange"]) ==
             sign(res_ri[same_dir, "log2FoldChange"]), na.rm = TRUE)
cat("significant in BOTH contrasts:", length(same_dir),
    "of which", agree, "point the same direction\n")

## ---- 5. PCA on variance-stabilised expression (visual overview) --------------
# VST is a transform for PLOTTING only — the test above used raw counts.
vsd  <- vst(dds, blind = FALSE)
topv <- head(order(rowVars(assay(vsd)), decreasing = TRUE), 500)
pc   <- prcomp(t(assay(vsd)[topv, ]), center = TRUE, scale. = FALSE)
pve  <- pc$sdev^2 / sum(pc$sdev^2) * 100
pcs  <- data.frame(sample_id = rownames(pc$x), PC1 = pc$x[, 1], PC2 = pc$x[, 2]) |>
  left_join(meta, by = "sample_id")

p2 <- ggplot(pcs, aes(PC1, PC2, colour = route, shape = arm)) +
  geom_point(size = 2.6, alpha = 0.85) +
  stat_ellipse(aes(colour = route), linewidth = 0.6, linetype = 2) +
  scale_colour_manual(values = route_cols) +
  scale_shape_manual(values = c(pill = 16, injectable = 17, ring = 15)) +
  labs(title = "Host gene expression (PCA, 500 most variable genes)",
       subtitle = "Solid = local (ring); circles/triangles = which systemic arm",
       x = paste0("PC1 (", signif(pve[1], 2), "%)"),
       y = paste0("PC2 (", signif(pve[2], 2), "%)"),
       colour = "route", shape = NULL) +
  theme(legend.position = "bottom")
ggsave(file.path(fig_dir, "fig7_gene_pca.png"), p2, width = 7, height = 5, dpi = 150)

# How much variance does route explain on PC1/PC2? (visual guide, not a test)
cat("\nMean PC1 value by route:\n")
print(pcs |> group_by(route) |> summarise(mean_PC1 = mean(PC1), .groups = "drop"))

## ---- 6. Top-gene figure --------------------------------------------------------
toplot <- sig |>
  group_by(symbol) |> slice_max(abs(log2FoldChange), n = 1) |> ungroup() |>
  mutate(dir = ifelse(log2FoldChange > 0, "up in ring", "up in systemic")) |>
  group_by(dir) |> slice_max(abs(log2FoldChange), n = 8) |> ungroup() |>
  ggplot(aes(log2FoldChange, reorder(symbol, log2FoldChange),
             fill = dir)) +
  geom_col(width = 0.7) +
  geom_vline(xintercept = 0, linewidth = 0.4) +
  scale_fill_manual(values = c("up in ring" = "#c26b3f",
                               "up in systemic" = "#4a6fa5")) +
  labs(title = "Most different genes: ring (local) vs systemic",
       subtitle = "DESeq2, adjusted p < 0.05; labels are gene symbols",
       x = "log2 fold change", y = NULL, fill = NULL) +
  theme(axis.text.y = element_text(face = "italic", size = 10),
        legend.position = "bottom")
ggsave(file.path(fig_dir, "fig8_gene_top_hits.png"), toplot,
       width = 7.5, height = 5.5, dpi = 150)

cat("\nDone. Figures in:", fig_dir, "\n")
