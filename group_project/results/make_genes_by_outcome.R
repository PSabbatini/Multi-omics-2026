# Rebuild data/genes_by_outcome.csv, the prerequisite for notebook 05.
# Same recipe as notebook 04, Exercise 2, step 5:
#   week 18 samples, genes with >= 10 counts in >= a quarter of samples,
#   DESeq2 on raw counts, ~ outcome, contrast preterm vs term.

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
  library(DESeq2)
})

source(here("R/count_tables.R"))
d <- read_counts("instructional")

# Week 18 only
meta <- d$metadata |> filter(time_point == "week_18")
counts <- d$genes[, meta$sample_id, drop = FALSE]

# Gene filter: at least 10 counts in at least a quarter of the samples
keep <- rowSums(counts >= 10) >= ncol(counts) / 4
counts <- counts[keep, , drop = FALSE]
cat("samples:", ncol(counts), " genes tested:", nrow(counts), "\n")

# Check column order matches metadata rows before any test
stopifnot(identical(colnames(counts), meta$sample_id))

dds <- DESeqDataSetFromMatrix(
  countData = counts,
  colData   = as.data.frame(meta),
  design    = ~ outcome
)
dds <- dds[rowSums(counts(dds)) > 0, ]
dds$outcome <- relevel(dds$outcome, ref = "term")
dds <- DESeq(dds)
res <- as.data.frame(results(dds, contrast = c("outcome", "preterm", "term")))

info <- d$gene_info |> select(ensembl_gene_id, symbol, gene_name)

out <- res |>
  rownames_to_column("feature") |>
  left_join(info, by = c("feature" = "ensembl_gene_id")) |>
  select(feature, baseMean, log2FoldChange, lfcSE, stat, pvalue, padj,
         symbol, gene_name)

write_csv(out, here("data", "genes_by_outcome.csv"))
cat("significant at padj < 0.05:", sum(out$padj < 0.05, na.rm = TRUE), "\n")
cat("of those, log2FC > 0 (higher in preterm):",
    sum(out$padj < 0.05 & out$log2FoldChange > 0, na.rm = TRUE), "\n")
cat("of those, log2FC < 0 (lower in preterm):",
    sum(out$padj < 0.05 & out$log2FoldChange < 0, na.rm = TRUE), "\n")
