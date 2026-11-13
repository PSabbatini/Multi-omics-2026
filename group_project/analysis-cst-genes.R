# analysis-cst-genes.R ----------------------------------------------------------
#
# Question: group people by COMMUNITY TYPE (from the microbiome table), then
#           test their GENES. Does community type explain more host gene
#           expression than contraceptive method does?
#
# Workshop rule, kept: the group is defined from ONE table (species counts) and
# the OTHER table (genes) is what we test.
#
# Community type = clusters of similar vaginal microbiomes (classic "community
# state types", CST). Method = arm (pill / injectable / ring) and, for
# reference, route (local vs systemic, from analysis-genes-ring.R).
#
# Outputs: figures -> group_project/figures/  (fig9, fig10, fig11)
#          full DESeq2 LRT results -> group_project/results/
#          summary tables -> printed to console

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(vegan)
  library(DESeq2)
})

source(here::here("R/count_tables.R"))

fig_dir <- here::here("group_project", "figures")
res_dir <- here::here("group_project", "results")
dir.create(fig_dir, showWarnings = FALSE)
dir.create(res_dir, showWarnings = FALSE)

theme_set(theme_minimal(base_size = 13))

## ---- 1. Load and CHECK ORDER -------------------------------------------------
d     <- read_counts("group_b")
meta  <- d$metadata
sp    <- d$species
genes <- d$genes
stopifnot(identical(colnames(sp), meta$sample_id),
          identical(colnames(genes), meta$sample_id))
cat("Order check passed:", ncol(sp), "samples in both tables\n")
meta$arm <- factor(meta$arm, levels = c("pill", "injectable", "ring"))
meta$route <- factor(ifelse(meta$arm == "ring", "local", "systemic"),
                     levels = c("systemic", "local"))

## ---- 2. Define community types from the MICROBIOME table ---------------------
# Bray-Curtis distances between samples, Ward clustering, cut into k groups.
bc   <- vegdist(t(sp), method = "bray")
hc   <- hclust(bc, method = "ward.D2")
for (k in 2:5) {
  sil <- mean(cluster::silhouette(cutree(hc, k = k), bc)[, 3])
  cat("mean silhouette, k =", k, ":", signif(sil, 3), "\n")
}
k <- 3   # classic CST number: Lactobacillus-dominant, intermediate, diverse
ctype <- factor(cutree(hc, k = k), levels = 1:k, labels = paste0("C", 1:k))
meta$ctype <- ctype

# Name the clusters by their biology (rules, so a rerun gives the same names):
#   crispatus-dominant = highest mean L. crispatus share
#   diverse            = highest mean Shannon
#   iners-dominant     = whichever remains
tax <- d$taxonomy
genus_rel <- sweep(sp, 2, colSums(sp), "/")
genus_ids <- tax$Genus[match(rownames(sp), tax$taxon)]
genus_rel <- rowsum(genus_rel, group = genus_ids, reorder = TRUE)
sp_rel <- sweep(sp, 2, colSums(sp), "/")

crisp_share <- colMeans(sp_rel["lactobacillus_crispatus", , drop = FALSE])
charac <- data.frame(ctype = ctype, sample_id = meta$sample_id) |>
  left_join(data.frame(sample_id = colnames(sp),
                       shannon  = diversity(t(sp)),
                       crisp    = unname(crisp_share),
                       lac      = unname(genus_rel["Lactobacillus", ]),
                       gv       = unname(genus_rel["Gardnerella", ])),
            by = "sample_id") |>
  group_by(ctype) |> summarise(across(c(shannon, crisp, lac, gv), mean), n = n(), .groups = "drop")
crisp_dom <- charac$ctype[which.max(charac$crisp)]
diverse   <- charac$ctype[which.max(charac$shannon)]
iners_dom <- setdiff(charac$ctype, c(crisp_dom, diverse))
rename_map <- c(setNames(paste0(crisp_dom, "=Crispatus-dom"), crisp_dom),
                setNames(paste0(iners_dom, "=Iners-dom"),     iners_dom),
                setNames(paste0(diverse,   "=Diverse-BVlike"), diverse))
meta$ctype_lab <- factor(rename_map[as.character(ctype)],
                         levels = rename_map[charac$ctype])
cat("\n### Cluster character (means)\n\n")
print(as.data.frame(charac))
cat("\nCluster names:", paste(rename_map, collapse = "; "), "\n")

cat("\n### Community type x arm (n)\n\n")
print(table(arm = meta$arm, ctype = meta$ctype_lab))
cat("\n### Community type x bv (n)\n\n")
print(table(bv = meta$bv, ctype = meta$ctype_lab))
cat("\n### Community type x route: mean Lactobacillus share\n\n")
lac_vec <- unname(genus_rel["Lactobacillus", ])
names(lac_vec) <- colnames(sp)
print(meta |> group_by(ctype_lab) |>
        summarise(mean_lac_share = mean(lac_vec[sample_id]),
                  n = n(), .groups = "drop"))

## ---- 3. What each type looks like (composition figure) ------------------------
top_g <- names(sort(rowMeans(genus_rel), decreasing = TRUE))[1:9]
meta_ctype <- meta |> select(sample_id, ctype_lab)
comp <- as.data.frame(genus_rel[top_g, , drop = FALSE]) |>
  tibble::rownames_to_column("genus") |>
  pivot_longer(-genus, names_to = "sample_id", values_to = "relab") |>
  left_join(meta_ctype, by = "sample_id") |>
  bind_rows(
    data.frame(genus = "Other", sample_id = colnames(sp),
               relab = 1 - colSums(genus_rel[top_g, ])) |>
      left_join(meta_ctype, by = "sample_id")
  ) |>
  group_by(ctype_lab, genus) |> summarise(relab = mean(relab), .groups = "drop") |>
  mutate(genus = factor(genus, levels = c(rev(sort(top_g)), "Other")))

p10 <- ggplot(comp, aes(ctype_lab, relab, fill = genus)) +
  geom_col(position = "stack", colour = "white", linewidth = 0.1) +
  scale_fill_brewer(palette = "Paired") +
  labs(title = "Mean microbiome composition by community type",
       subtitle = "The types are defined FROM this table — this is their definition, not a test",
       y = "mean relative abundance", x = NULL, fill = NULL) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1),
        legend.text = element_text(face = "italic", size = 9),
        legend.key.height = grid::unit(9, "pt"))
ggsave(file.path(fig_dir, "fig10_composition_by_ctype.png"), p10,
       width = 8, height = 5, dpi = 150)

## ---- 4. Test the GENES: DESeq2 LRT, ctype vs arm ------------------------------
# LRT asks: does adding the grouping variable to the design fit the counts
# better, gene by gene? Same design otherwise, so the two comparisons are fair.
keep <- rowSums(genes) >= 10
cat("\nGenes tested:", sum(keep), "of", nrow(genes), "\n")

fit_lrt <- function(groupvar) {
  dds <- DESeqDataSetFromMatrix(countData = genes[keep, ],
                                colData = as.data.frame(meta),
                                design = as.formula(paste(
                                  "~ rnaseq_batch + bv + any_sti +", groupvar)))
  dds <- DESeq(dds, quiet = TRUE, test = "LRT",
               reduced = ~ rnaseq_batch + bv + any_sti)
  res <- results(dds, alpha = 0.05)
  as.data.frame(res) |> tibble::rownames_to_column("ensembl_gene_id")
}
res_arm   <- fit_lrt("arm")
res_ctype <- fit_lrt("ctype_lab")
info <- d$gene_info
res_ctype <- res_ctype |> left_join(info, by = "ensembl_gene_id")
write.csv(res_ctype, file.path(res_dir, "deseq2_lrt_ctype.csv"), row.names = FALSE)

sig_arm   <- sum(res_arm$padj < 0.05, na.rm = TRUE)
sig_ctype <- sum(res_ctype$padj < 0.05, na.rm = TRUE)
sig_route <- 66   # from analysis-genes-ring.R (Wald test, local vs systemic)
cat("\n### Genes significant at adjusted p < 0.05 (LRT)\n")
cat("arm (method):          ", sig_arm, "\n")
cat("community type:        ", sig_ctype, "\n")

top <- res_ctype |> filter(padj < 0.05) |> arrange(padj) |> slice_head(n = 12) |>
  mutate(across(baseMean, ~ signif(.x, 3)), log2FC = round(log2FoldChange, 2),
         padj = signif(padj, 2)) |>
  select(ensembl_gene_id, symbol, gene_name, log2FC, padj, baseMean)
cat("\nTop 12 community-type genes (by adjusted p; LRT has no single effect size,\n")
cat("the log2FC shown is the C1-vs-C3 coefficient; mean expression per type is\n")
cat("printed below):\n\n")
print(as.data.frame(top[, -1]), row.names = FALSE)

## ---- 5. VST values: for the PCA figure and mean-expression table -------------
# VST is a transform for PLOTTING/summaries only — the tests use raw counts.
vsd <- vst(DESeqDataSetFromMatrix(countData = genes[keep, ],
                                  colData = as.data.frame(meta),
                                  design = ~ 1), blind = TRUE)
cat("\n### Mean VST expression of the top 12 ctype genes, by community type\n\n")
mm <- assay(vsd)[top$ensembl_gene_id, , drop = FALSE]
mat <- t(apply(mm, 1, function(r) tapply(r, meta$ctype_lab, mean)))
rownames(mat) <- top$symbol
print(round(mat, 1))

## ---- 5. Variance explained: PERMANOVA on gene expression ----------------------
# VST (variance-stabilising) values, top 2000 most variable genes; euclidean
# distances; a permutation test for how much variance each grouping explains.
vsd  <- vst(DESeqDataSetFromMatrix(countData = genes[keep, ],
                                   colData = as.data.frame(meta),
                                   design = ~ 1), blind = TRUE)
topv <- head(order(matrixStats::rowVars(assay(vsd)), decreasing = TRUE), 2000)
euc  <- vegdist(t(assay(vsd)[topv, ]), method = "euclidean")
cat("\n### PERMANOVA on gene expression (VST top 2000 genes, 999 permutations)\n\n")
perm_ctype <- adonis2(euc ~ ctype_lab, data = as.data.frame(meta), permutations = 999)
perm_arm   <- adonis2(euc ~ arm,       data = as.data.frame(meta), permutations = 999)
perm_route <- adonis2(euc ~ route,     data = as.data.frame(meta), permutations = 999)
perm_full  <- adonis2(euc ~ ctype_lab + arm, data = as.data.frame(meta), permutations = 999)
cat("community type alone:\n"); print(perm_ctype)
cat("\narm (method) alone:\n"); print(perm_arm)
cat("\nroute alone:\n");          print(perm_route)
cat("\ntype + arm (does arm add anything beyond type?):\n"); print(perm_full)

## ---- 6. Figures ---------------------------------------------------------------
topv2 <- head(order(matrixStats::rowVars(assay(vsd)), decreasing = TRUE), 500)
pc   <- prcomp(t(assay(vsd)[topv2, ]), center = TRUE, scale. = FALSE)
pve  <- pc$sdev^2 / sum(pc$sdev^2) * 100
pcs  <- data.frame(sample_id = rownames(pc$x), PC1 = pc$x[, 1], PC2 = pc$x[, 2]) |>
  left_join(meta, by = "sample_id")

p9 <- ggplot(pcs, aes(PC1, PC2, colour = ctype_lab)) +
  geom_point(size = 2.6, alpha = 0.85) +
  stat_ellipse(linewidth = 0.6, linetype = 2) +
  labs(title = "Host gene expression by community type",
       subtitle = "Same PCA as the route analysis, now coloured by microbiome type",
       x = paste0("PC1 (", signif(pve[1], 2), "%)"),
       y = paste0("PC2 (", signif(pve[2], 2), "%)"),
       colour = NULL) +
  theme(legend.position = "bottom")
ggsave(file.path(fig_dir, "fig9_gene_pca_by_ctype.png"), p9, width = 7, height = 5, dpi = 150)

cmp <- data.frame(
  grouping = factor(c("community type", "arm (method)", "route (local vs systemic)"),
                    levels = c("community type", "arm (method)", "route (local vs systemic)")),
  genes = c(sig_ctype, sig_arm, sig_route))
p11 <- ggplot(cmp, aes(grouping, genes, fill = grouping)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = genes), vjust = -0.4, size = 4.2) +
  scale_fill_manual(values = c("#c26b3f", "#4a6fa5", "#4d8f6a")) +
  labs(title = "How many host genes differ, by grouping variable?",
       subtitle = "DESeq2, adjusted p < 0.05 (arm and type: LRT; route: Wald)",
       x = NULL, y = "number of significant genes") +
  ylim(0, max(cmp$genes) * 1.12)
ggsave(file.path(fig_dir, "fig11_sig_gene_counts.png"), p11, width = 7, height = 4.5, dpi = 150)

cat("\nDone. Figures in:", fig_dir, "\n")
