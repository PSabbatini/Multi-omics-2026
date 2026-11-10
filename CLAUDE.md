# Workshop Workspace — Data Science for Biology

This is my personal workspace for the Durban Data Science for Biology workshop
series. My AI assistant loads this file automatically so it knows how to help
me.

## About me

I am a **beginner** at coding. Please explain things simply, avoid jargon, and
when you do use a technical term, briefly say what it means.

I am a biologist. You can assume I understand the biology and the study design.
Do not explain what a gene or a bacterium is. Do explain what the code is doing.

## How this project is organized

- `notebooks/` — starter Quarto (`.qmd`) notebooks, a mix of plain-language text
  and runnable R code. `00-hello-r` checks the setup, and `02` to `05` go with
  the workshop's four coding modules.
- `data/2-workshop2/` — the three multiomics datasets.
- `R/count_tables.R` — a helper that loads a workshop dataset. See below.

## The multiomics datasets

Three datasets, each with the same six files and the same column names:

- `data/2-workshop2/instructional_dataset/` — a pregnancy cohort, 157
  participants at three visits, outcome term or preterm
- `data/2-workshop2/group_a_probiotic/` — a probiotic trial, before and after
- `data/2-workshop2/group_b_contraception/` — three contraceptive methods

Each folder has `01_metadata.csv`, `02_microbiome_counts.csv`,
`03_microbiome_taxonomy.csv`, `04_rnaseq_counts.csv.gz`,
`05_gene_annotation.csv` and `06_cytokines.csv`.

Both count tables are **features in rows, samples in columns**.

Load them with the helper rather than by hand:

```r
source(here::here("R/count_tables.R"))

d <- read_counts("instructional")   # or "group_a", "group_b"
d$metadata                          # one row per sample
d$species                           # 220 species x 471 samples
d$genes                             # 14,226 genes x 471 samples

# A phyloseq object for microViz, from EITHER table:
ps <- as_counts(table = "microbiome")
ps <- as_counts(table = "rnaseq")
```

The second one is the point of the week. microViz was written for microbiome
data, but `as_counts()` hands it the gene annotation as its feature-rank table,
so the same microViz pipeline works on human genes.

## Things to get right in this workshop

- **Raw counts go into DESeq2.** Never CPM, never logged. It does its own
  normalisation.
- **Check the order** of the count matrix columns against the sample table rows
  before any test. DESeq2 will not warn, it will just be wrong.
- **Do not define a group from one count table and then test that same table.**
  Define it from one and test the other.
- **Both count tables are compositional.** "Relative abundance went down" is not
  the same claim as "there was less of it".

## The group project

On Wednesday and Thursday I work on a group project in `group_project/`.

- Write each analysis as a Quarto document in `group_project/`, render it with
  `quarto render`, and tell me the path of the HTML file.
- End every document with a section called `## Choices made`. List each
  decision you made (method, distance, filter, threshold, transform, test,
  samples dropped), one line each: what you chose, and one alternative you did
  not choose.
- When I ask what a method means, explain it in a few plain sentences and give
  me a link to documentation or a paper I can read myself.

## Working with me

- When suggesting code, keep it short and explain what each part does.
- If something can be done more than one way, pick the simplest one.
- Feel free to suggest small experiments I can try to learn.
- **When I ask you to compute something, tell me how I could check it myself.**
  Every exercise this week ends by asking me to verify your work, so give me the
  number or the plot that would catch you being wrong.
- If you are unsure, say so instead of guessing. A confident wrong answer costs
  me more than "I don't know".
