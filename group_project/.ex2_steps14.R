# Exercise 2, Steps 1-4 — filters, grid, effect, log transform
library(tidyverse)
library(here)

data_dir <- "data/2-workshop2/instructional_dataset"
metadata <- read_csv(here(data_dir, "01_metadata.csv"), show_col_types = FALSE)
species  <- read_csv(here(data_dir, "02_microbiome_counts.csv"), show_col_types = FALSE)
genes    <- read_csv(here(data_dir, "04_rnaseq_counts.csv.gz"), show_col_types = FALSE)
taxonomy <- read_csv(here(data_dir, "03_microbiome_taxonomy.csv"), show_col_types = FALSE)

mat_of <- function(df) {
  m <- as.matrix(df[, -1]); rownames(m) <- df[[1]]; m
}
sp <- mat_of(species); gn <- mat_of(genes)

## ---- Step 1: prevalence and the filter curve -----------------------------
prev <- function(m) rowMeans(m > 0)
sp_prev <- prev(sp); gn_prev <- prev(gn)

cat("== Step 1: prevalence distribution ==\n")
cat("species: n_prev_ge_0.10 =", sum(sp_prev >= 0.10), "of", nrow(sp), "\n")
cat("species: median prevalence =", median(sp_prev),
    " min =", min(sp_prev), " max =", max(sp_prev), "\n")
cat("genes:   n_prev_ge_0.10 =", sum(gn_prev >= 0.10), "of", nrow(gn), "\n")
cat("genes:   median prevalence =", median(gn_prev), "\n")

# share of reads lost by the 10% prevalence rule
lost <- function(m, keep) {
  1 - sum(m[keep, ]) / sum(m)
}
sp_keep10 <- sp_prev >= 0.10
gn_keep10 <- gn_prev >= 0.10
cat("species 10%: kept", sum(sp_keep10), "lost", round(100*lost(sp, sp_keep10), 2), "% of reads\n")
cat("genes   10%: kept", sum(gn_keep10), "lost", round(100*lost(gn, gn_keep10), 3), "% of reads\n")

# filter curve for species
cat("\n== species filter curve ==\n")
for (c in seq(0, 0.9, by = 0.1)) {
  k <- sp_prev >= c
  cat(sprintf("prev >= %3.1f : kept %4d of 220, reads kept %6.2f%%\n",
              c, sum(k), 100 * sum(sp[k, ]) / sum(sp)))
}
cat("\n== genes filter curve ==\n")
for (c in seq(0, 0.9, by = 0.1)) {
  k <- gn_prev >= c
  cat(sprintf("prev >= %3.1f : kept %5d of 14226, reads kept %6.2f%%\n",
              c, sum(k), 100 * sum(gn[k, ]) / sum(gn)))
}

## ---- Step 2: grid of filters --------------------------------------------
# species: prevalence 5/10/25% x mean relative abundance 0 / 0.01% / 0.1%
sp_relprop <- sweep(sp, 2, colSums(sp), "/")   # proportion per sample
sp_mean_prop <- rowMeans(sp_relprop)           # mean relative abundance
cat("\n== species grid (rows: prevalence, cols: mean rel abundance) ==\n")
for (p in c(0.05, 0.10, 0.25)) {
  for (a in c(0, 0.0001, 0.001)) {
    k <- sp_prev >= p & sp_mean_prop >= a
    cat(sprintf("prev>=%4s mean>=%6s : kept %3d, reads kept %6.2f%%\n",
                p, a, sum(k), 100 * sum(sp[k, ]) / sum(sp)))
  }
}

# genes: mean CPM 1/5/10 x prevalence 0/50/90%
gn_cpm <- sweep(gn, 2, colSums(gn), "/") * 1e6
gn_mean_cpm <- rowMeans(gn_cpm)
cat("\n== genes grid (rows: mean CPM, cols: prevalence) ==\n")
for (c in c(1, 5, 10)) {
  for (p in c(0, 0.5, 0.9)) {
    k <- gn_mean_cpm >= c & gn_prev >= p
    cat(sprintf("cpm>=%3d prev>=%4s : kept %5d, counts kept %6.2f%%\n",
                c, p, sum(k), 100 * sum(gn[k, ]) / sum(gn)))
  }
}

## ---- Step 3: did the filter change anything? -----------------------------
eff <- function(m) {          # effective number of species
  p <- sweep(m, 2, colSums(m), "/")
  exp(-colSums(p * log(p), na.rm = TRUE))
}
sp_eff_before <- eff(sp)
sp_kept <- sp[sp_prev >= 0.10, ]
sp_eff_after <- eff(sp_kept)
det_before <- colSums(sp > 0); det_after <- colSums(sp_kept > 0)
cat("\n== Step 3: effect of species 10% filter ==\n")
cat("median effective features before:", round(median(sp_eff_before), 2),
    " after:", round(median(sp_eff_after), 2), "\n")
cat("cor(before, after) effective:", round(cor(sp_eff_before, sp_eff_after, method = "spearman"), 3), "\n")
cat("median features detected before:", median(det_before),
    " after:", median(det_after), "\n")
cat("cor(before, after) detected:", round(cor(det_before, det_after, method = "spearman"), 3), "\n")

## ---- Step 4: normalise, then log -----------------------------------------
cpm <- function(m) sweep(m, 2, colSums(m), "/") * 1e6
sp_cpm <- cpm(sp)
gn_cpm_all <- cpm(gn)
l2sp <- log2(sp_cpm + 1)
l2gn <- log2(gn_cpm_all + 1)

# pick one abundant species and one gene to show
sp_most_abund <- names(sort(sp_mean_prop, decreasing = TRUE))[1]
cat("\n== Step 4 ==\n")
cat("most abundant species:", sp_most_abund, "\n")
cat("species cpm range:", range(sp_cpm[sp_most_abund, ]), "\n")
cat("species log2(cpm+1) range:", range(l2sp[sp_most_abund, ]), "\n")

# a mid-abundance gene (mean cpm between 5 and 50) so the +1 matters
mid_genes <- names(which(gn_mean_cpm > 5 & gn_mean_cpm < 50))
g1 <- mid_genes[1]
cat("example gene:", g1, " mean cpm =", round(gn_mean_cpm[g1], 2), "\n")
cat("gene cpm range:", range(gn_cpm_all[g1, ]), "\n")
cat("gene log2(cpm+1) range:", range(l2gn[g1, ]), "\n")
cat("gene log2(cpm+0.5/1/10) quantiles (0.25,0.5,0.75, max):\n")
for (a in c(0.5, 1, 10)) {
  v <- log2(gn_cpm_all[g1, ] + a)
  cat(sprintf("  +%4.1f : quantiles %s, max %.2f\n", a,
              paste(round(quantile(v, c(.25, .5, .75)), 2), collapse = ", "),
              max(v)))
}
# zero-cell info for the gene
cat("gene zeros:", sum(gn_cpm_all[g1, ] == 0), "of", ncol(gn), "\n")

saveRDS(list(
  sp_prev = sp_prev, gn_prev = gn_prev, sp_mean_prop = sp_mean_prop,
  gn_mean_cpm = gn_mean_cpm, example_gene = g1,
  sp_most_abund = sp_most_abund
), here("ex2_step_cache.rds"))
cat("\nDONE steps 1-4\n")
