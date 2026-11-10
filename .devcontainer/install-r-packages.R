# R packages for the Data Science for Biology workshops.
#
# Run once while the container image is built, so a Codespace starts with
# everything already present. Keep it in the Dockerfile rather than in
# setup.sh: a Dockerfile layer is cached and prebuilt, a postCreate command
# runs again for every participant and every rebuild.

options(
  # Posit's Ubuntu noble binaries, already the default for CRAN in this image.
  Ncpus = max(1L, parallel::detectCores()),
  # microViz is not on CRAN.
  repos = c(davidbarnett = "https://david-barnett.r-universe.dev",
            getOption("repos"))
)

# Extras not in the base image: here for file paths, palmerpenguins for
# notebook 00, and table and plotting helpers group projects reach for.
extras <- c(
  "here", "janitor", "gt", "palmerpenguins", "ggbeeswarm",
  "gtsummary", "ggpubr", "patchwork", "broom.helpers"
)

# Count tables, ordination, differential testing, enrichment.
multiomics <- c(
  "vegan",                 # distances, PERMANOVA
  "msigdbr",               # Hallmark gene sets (human Hallmark ships with it)
  "pROC",                  # ROC curves and AUC for the Friday discussion
  "corrplot",              # correlation heatmaps for the group projects
  "bioc::DESeq2",          # differential testing on both count tables
  "bioc::phyloseq",        # the container microViz expects
  "bioc::microbiome",      # microViz dependency
  "bioc::ComplexHeatmap",  # microViz dependency
  "bioc::fgsea",           # set enrichment on a ranked list
  "microViz"               # the pipeline the whole week uses
)

# pak resolves CRAN, Bioconductor and r-universe in one pass and will not
# reinstall what the base image already has.
pak::pkg_install(c(extras, multiomics), ask = FALSE)
