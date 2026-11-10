# Instructor smoke test. Not for participants.
#
# Runs the whole week's analysis once, in this container, on the shipped data,
# through the same helper the exercises use. If this passes, a participant can
# do Tuesday, Wednesday, Thursday and Friday.
#
# From the repository root, inside a Codespace or the built image:
#
#   Rscript .devcontainer/smoke-test.R
#
# Run it after any change to the Dockerfile, the datasets, or R/count_tables.R.
# It is deliberately strict: it stops on the first thing that is not true.
suppressPackageStartupMessages({
  library(tidyverse); library(here); library(microViz); library(phyloseq)
  library(DESeq2); library(fgsea); library(msigdbr); library(pROC); library(vegan)
})
source("R/count_tables.R")
ok <- function(...) cat("PASS ", sprintf(...), "\n")

# --- Module 2 -----------------------------------------------------------------
d <- read_counts("instructional")
stopifnot(nrow(d$metadata) == 471, nrow(d$species) == 220, nrow(d$genes) == 14226)
ok("read_counts: %d samples, %d species, %d genes", nrow(d$metadata), nrow(d$species), nrow(d$genes))

lacto <- intersect(d$taxonomy$taxon[!is.na(d$taxonomy$Genus) & d$taxonomy$Genus == "Lactobacillus"],
                   rownames(d$species))
lf <- colSums(d$species[lacto, ]) / colSums(d$species)
stopifnot(all(lf >= 0 & lf <= 1))
md <- d$metadata |> mutate(lacto_fraction = lf[sample_id],
                           community = if_else(lacto_fraction >= 0.5, "lactobacillus", "anaerobe"))
ok("Lactobacillus fraction in [0,1]; community split %s",
   paste(names(table(md$community)), table(md$community), collapse = " / "))

# --- Module 3 -----------------------------------------------------------------
ps <- as_counts(table = "microbiome")
p <- ps |> tax_transform("identity", rank = "species") |> dist_calc("bray") |>
  ord_calc("PCoA") |> ord_plot(colour = "outcome")
stopifnot(inherits(p, "ggplot"))
ok("microViz ordination on species: ok")

psg <- as_counts(table = "rnaseq", min_count = 10, min_samples = 100)
pg <- psg |> tax_transform("clr", rank = "symbol") |> dist_calc("euclidean") |>
  ord_calc("PCoA") |> ord_plot(colour = "outcome")
stopifnot(inherits(pg, "ggplot"))
ok("microViz ordination on %d genes: ok", ntaxa(psg))

perm <- ps |> tax_transform("identity", rank = "species") |> dist_calc("bray") |>
  dist_permanova(variables = "outcome", n_perms = 49, seed = 1) |> perm_get()
ok("PERMANOVA ran, outcome R2 = %.4f", as.data.frame(perm)$R2[1])

bp <- psg |> comp_barplot(tax_level = "symbol", n_taxa = 8)
ok("comp_barplot on genes: ok")

# --- Module 4 -----------------------------------------------------------------
w18 <- md |> filter(time_point == "week_18")
m <- d$genes[, w18$sample_id]
keep <- rowSums(m >= 10) >= ceiling(0.25 * ncol(m))
dds <- DESeqDataSetFromMatrix(m[keep, ], as.data.frame(w18), ~ community)
dds <- DESeq(dds, quiet = TRUE)
res <- results(dds, contrast = c("community", "anaerobe", "lactobacillus"))
n_sig <- sum(res$padj < 0.05, na.rm = TRUE)
stopifnot(n_sig > 1000)
ok("DESeq2 on genes: %d of %d significant", n_sig, sum(keep))

# --- Module 5 -----------------------------------------------------------------
hm <- msigdbr(species = "Homo sapiens", collection = "H")
sets <- split(hm$ensembl_gene, hm$gs_name)
st <- res$stat; names(st) <- rownames(res); st <- st[!is.na(st)]
g <- fgsea(sets, st, minSize = 15, maxSize = 500, nproc = 1) |> as_tibble() |> arrange(padj)
stopifnot(nrow(g) > 10)
ok("fgsea: %d sets tested, top = %s", nrow(g), g$pathway[1])

# --- Module 6 -----------------------------------------------------------------
pp <- md |> group_by(participant_id, outcome) |>
  summarise(micro = mean(1 - lacto_fraction), .groups = "drop") |>
  mutate(preterm = as.integer(outcome == "preterm"))
a <- auc(roc(pp$preterm, pp$micro, quiet = TRUE))
ok("pROC: microbiome-only AUC = %.2f", as.numeric(a))

# --- group datasets -----------------------------------------------------------
for (g2 in c("group_a", "group_b")) {
  dd <- read_counts(g2)
  ok("%s: %d samples, %d species, %d genes", g2, nrow(dd$metadata), nrow(dd$species), nrow(dd$genes))
  ps2 <- as_counts(g2, table = "rnaseq", min_count = 10, min_samples = 20)
  ok("%s: as_counts on genes gives %d features", g2, ntaxa(ps2))
}
cat("\nALL CHECKS PASSED\n")
