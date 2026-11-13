# review-checks.R ---------------------------------------------------------------
#
# Evidence for 02-methods-review: I reviewed the three analyses in
# dataset-overview.qmd and reran the parts I would have done differently.
# This script regenerates every number quoted in that review.
#
# Run:   Rscript group_project/review-checks.R
# Time:  about 5 minutes (four DESeq2 fits on 14,226 genes).
#
# Rules kept, as in the original scripts:
#   - raw counts into DESeq2, never CPM or logged values
#   - groupings (arm / route / ctype) all defined from the METADATA,
#     never from the count table being tested
#   - column order checked against metadata rows before every test

suppressPackageStartupMessages({
  library(here); library(dplyr); library(DESeq2); library(vegan); library(matrixStats)
})
source(here::here("R/count_tables.R"))

d    <- read_counts("group_b")
meta <- as.data.frame(d$metadata)
meta$arm   <- factor(meta$arm, levels = c("pill", "injectable", "ring"))
meta$route <- factor(ifelse(meta$arm == "ring", "local", "systemic"),
                     levels = c("systemic", "local"))
stopifnot(identical(colnames(d$genes), meta$sample_id),
          identical(colnames(d$species), meta$sample_id))
cat("Order check passed:", ncol(d$genes), "samples in both tables\n")

genes <- d$genes[rowSums(d$genes) >= 10, ]   # verified below: keeps all 14,226
sp    <- d$species
sym   <- setNames(d$gene_info$symbol, d$gene_info$ensembl_gene_id)

## ---- 1. Filters: does the >= 10 total-reads rule do anything? ----------------
cat("\n### 1. Gene filters\n")
cat("rowSums >= 10:                  ", sum(rowSums(d$genes) >= 10), "of", nrow(d$genes), "\n")
cat(">= 10 reads in >= 5 samples:   ", sum(rowSums(d$genes >= 10) >= 5), "\n")
cat(">= 10 reads in >= 9 samples:    ", sum(rowSums(d$genes >= 10) >= 9), "\n")
cat("\n### 1. Species filters\n")
cat("rowSums >= 10:                  ", sum(rowSums(sp) >= 10), "of", nrow(sp), "\n")
cat("present (> 0) in >= 5 samples:  ", sum(apply(sp > 0, 1, sum) >= 5), "\n")

## ---- 2. Shrinkage: raw vs shrunken log2FC, species (ring vs pill) -------------
spk  <- sp[rowSums(sp) >= 10, ]
ddsA <- DESeqDataSetFromMatrix(spk, meta, design = ~ rnaseq_batch + bv + arm)
ddsA <- DESeq(ddsA, quiet = TRUE)
res_rp <- results(ddsA, contrast = c("arm", "ring", "pill"), alpha = 0.05)
shr_rp <- lfcShrink(ddsA, contrast = c("arm", "ring", "pill"),
                    type = "normal", quiet = TRUE)
tsig <- data.frame(taxon = rownames(res_rp), padj = res_rp$padj,
                   lfc = res_rp$log2FoldChange,
                   shrLFC = shr_rp$log2FoldChange,
                   baseMean = res_rp$baseMean) |> filter(padj < 0.05)
spname <- d$taxonomy$species[match(tsig$taxon, d$taxonomy$taxon)]
top8_raw  <- tsig |> mutate(spp = spname) |> arrange(desc(abs(lfc)))    |> slice_head(n = 8)
top8_shr  <- tsig |> mutate(spp = spname) |> arrange(desc(abs(shrLFC))) |> slice_head(n = 8)
cat("\n### 2. Species: sig ring-vs-pill =", nrow(tsig),
    "(their report: 27)\n")
cat("\ntop 8 by |raw| LFC (their fig5 / table):\n")
print(top8_raw   |> select(spp, lfc, shrLFC, baseMean) |>
      mutate(across(-spp, ~ round(.x, 2))), row.names = FALSE)
cat("\ntop 8 by |shrunk| LFC (after lfcShrink):\n")
print(top8_shr   |> select(spp, lfc, shrLFC, baseMean) |>
      mutate(across(-spp, ~ round(.x, 2))), row.names = FALSE)
cat("overlap of the two lists:", length(intersect(top8_raw$taxon, top8_shr$taxon)), "of 8\n")

## ---- 3. Shrinkage: raw vs shrunken log2FC, genes (local vs systemic) ---------
ddsR <- DESeqDataSetFromMatrix(genes, meta,
                               design = ~ rnaseq_batch + bv + any_sti + route)
ddsR <- DESeq(ddsR, quiet = TRUE)
res_r <- results(ddsR, contrast = c("route", "local", "systemic"), alpha = 0.05)
shr_r <- lfcShrink(ddsR, contrast = c("route", "local", "systemic"),
                   type = "normal", quiet = TRUE)
gsig <- data.frame(ensembl_gene_id = rownames(res_r), padj = res_r$padj,
                   lfc = res_r$log2FoldChange, shrLFC = shr_r$log2FoldChange,
                   baseMean = res_r$baseMean) |> filter(padj < 0.05) |>
  mutate(symbol = sym[ensembl_gene_id])
g8_raw <- gsig |> arrange(desc(abs(lfc)))    |> slice_head(n = 8)
g8_shr <- gsig |> arrange(desc(abs(shrLFC))) |> slice_head(n = 8)
cat("\n### 3. Genes: sig local-vs-systemic =", nrow(gsig),
    "(their report: 66)\n")
cat("\ntop 8 by |raw| LFC (their fig8):\n")
print(g8_raw |> select(symbol, lfc, shrLFC, baseMean) |>
        mutate(across(-symbol, ~ round(.x, 2))), row.names = FALSE)
cat("\ntop 8 by |shrunk| LFC (after lfcShrink):\n")
print(g8_shr |> select(symbol, lfc, shrLFC, baseMean) |>
        mutate(across(-symbol, ~ round(.x, 2))), row.names = FALSE)
cat("overlap of the two lists:", length(intersect(g8_raw$ensembl_gene_id,
    g8_shr$ensembl_gene_id)), "of 8\n")

## ---- 4. Adjusted vs unadjusted models ---------------------------------------
res_rp_un <- results(DESeq(DESeqDataSetFromMatrix(spk, meta,
                       design = ~ rnaseq_batch + arm), quiet = TRUE),
                     contrast = c("arm", "ring", "pill"), alpha = 0.05)
res_r_un  <- results(DESeq(DESeqDataSetFromMatrix(genes, meta,
                       design = ~ rnaseq_batch + route), quiet = TRUE),
                     contrast = c("route", "local", "systemic"), alpha = 0.05)
cat("\n### 4. Adjusted vs unadjusted\n")
cat("SPECIES ring vs pill, ~ batch + arm (unadjusted):          ",
    sum(res_rp_un$padj < 0.05, na.rm = TRUE), "\n")
cat("SPECIES ring vs pill, ~ batch + bv + arm (their model):    ",
    sum(res_rp$padj < 0.05, na.rm = TRUE), "\n")
cat("GENES  local vs systemic, ~ batch + route (unadjusted):    ",
    sum(res_r_un$padj < 0.05, na.rm = TRUE), "\n")
cat("GENES  local vs systemic, ~ batch + bv + sti + route (theirs):",
    sum(res_r$padj < 0.05, na.rm = TRUE), "\n")

## ---- 5. The route collapse: are the two systemic arms interchangeable? ------
res_pi  <- results(ddsA, contrast = c("arm", "injectable", "pill"),  alpha = 0.05)
ddsA_g  <- DESeqDataSetFromMatrix(genes, meta,
                                  design = ~ rnaseq_batch + bv + any_sti + arm)
ddsA_g  <- DESeq(ddsA_g, quiet = TRUE)
res_pi_g <- results(ddsA_g, contrast = c("arm", "injectable", "pill"), alpha = 0.05)
cat("\n### 5. Systemic arms vs each other (route-collapse check)\n")
cat("SPECIES injectable vs pill sig:", sum(res_pi$padj < 0.05, na.rm = TRUE), "\n")
cat("GENES   injectable vs pill sig:", sum(res_pi_g$padj < 0.05, na.rm = TRUE), "\n")
cat("GENES   ring vs pill:", sum(results(ddsA_g, contrast = c("arm","ring","pill"),
    alpha = 0.05)$padj < 0.05, na.rm = TRUE),
    "; ring vs injectable:", sum(results(ddsA_g,
    contrast = c("arm","ring","injectable"), alpha = 0.05)$padj < 0.05,
    na.rm = TRUE), "\n")

## ---- 6. Q3 done formally: nested LRTs, both directions ----------------------
bc    <- vegdist(t(sp))
meta$ctype <- factor(cutree(hclust(bc, "ward.D2"), k = 3))   # their k = 3
cat("\n### 6. Cluster sizes (k = 3):\n"); print(table(meta$ctype))
dds_ct <- DESeq(DESeqDataSetFromMatrix(genes, meta,
                design = ~ rnaseq_batch + bv + any_sti + arm + ctype),
                test = "LRT", reduced = ~ rnaseq_batch + bv + any_sti + arm,
                quiet = TRUE)
cat("genes where CTYPE adds beyond ARM (padj<0.05):",
    sum(results(dds_ct, alpha = 0.05)$padj < 0.05, na.rm = TRUE), "\n")
dds_ar <- DESeq(DESeqDataSetFromMatrix(genes, meta,
                design = ~ rnaseq_batch + bv + any_sti + ctype + arm),
                test = "LRT", reduced = ~ rnaseq_batch + bv + any_sti + ctype,
                quiet = TRUE)
cat("genes where ARM adds beyond CTYPE (padj<0.05):",
    sum(results(dds_ar, alpha = 0.05)$padj < 0.05, na.rm = TRUE), "\n")

vsd  <- vst(DESeqDataSetFromMatrix(genes, meta, design = ~ 1), blind = TRUE)
topv <- head(order(rowVars(assay(vsd)), decreasing = TRUE), 2000)
euc  <- vegdist(t(assay(vsd)[topv, ]), method = "euclidean")
cat("\nmarginal PERMANOVA (by = 'margin'):\n")
print(adonis2(euc ~ ctype + arm, data = meta, permutations = 999, by = "margin"))

## ---- 7. Dispersion checks (betadisper) after every PERMANOVA -----------------
cat("\n### 7. betadisper: are the groups equally spread?\n")
bcs <- vegdist(t(sp))
for (v in c("arm", "bv")) {
  pt <- permutest(betadisper(bcs, meta[[v]]), permutations = 999)
  cat("microbiome Bray-Curtis, dispersion by", v, ": p =",
      pt$tab["Groups", "Pr(>F)"], "\n")
}
for (v in c("ctype", "route", "arm")) {
  pt <- permutest(betadisper(euc, droplevels(meta[[v]])), permutations = 999)
  cat("gene-expression Euclidean, dispersion by", v, ": p =",
      pt$tab["Groups", "Pr(>F)"], "\n")
}

cat("\nDONE. Compare these numbers with the tables in 02-methods-review.html.\n")