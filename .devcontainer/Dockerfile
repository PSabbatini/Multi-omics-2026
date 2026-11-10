FROM ghcr.io/rocker-org/devcontainer/tidyverse:4.5

# igraph, which phyloseq depends on, needs libglpk at run time and it is not in
# the base image. Everything else the R packages need is already here.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libglpk40 \
 && rm -rf /var/lib/apt/lists/*

# R packages for the workshop. See install-r-packages.R for what and why.
COPY install-r-packages.R /tmp/install-r-packages.R
RUN Rscript /tmp/install-r-packages.R && rm /tmp/install-r-packages.R

# Fail the image build rather than the workshop. If a package is missing, this
# layer errors here instead of in front of sixty people on Tuesday morning.
RUN R -q -e 'for (p in c("tidyverse", "here", "janitor", "gtsummary", "ggpubr", "patchwork", "vegan", "msigdbr", "pROC", "corrplot", "DESeq2", "phyloseq", "microbiome", "ComplexHeatmap", "fgsea", "microViz")) { suppressPackageStartupMessages(library(p, character.only = TRUE)); cat("ok  ", p, "\n") }'
