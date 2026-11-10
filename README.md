# Data Science for Biology — Workshop Environment

This is the participant environment for the Durban Data Science for Biology
workshop series. It runs entirely in **GitHub Codespaces**, so there is nothing
to install on your computer. You only need a web browser and a free GitHub
account.

This copy is for **Multiomics, microbiome and host gene expression**, Nairobi,
9 to 13 November 2026.

## Getting started

1. Click the green **"Use this template"** button (top right) →
   **"Create a new repository"** to make your own copy.
2. On *your copy*, add your OpenRouter API key as a Codespaces secret named
   `OPENROUTER_API_KEY` (your GitHub **Settings → Codespaces → Secrets**, and
   give the secret access to your new repository).
3. On your copy, click **"Code" → "Codespaces" → "Create codespace on main"**.
4. When the codespace finishes building, open `notebooks/00-hello-r.qmd` and
   run the code cell. Do this **before Tuesday morning**, because the container
   takes several minutes to build the first time.
5. Open the terminal and type `pi` to start Pi, your AI coding assistant.

Full step-by-step walkthrough:
[Get Started page on the workshop website](https://elsherbini.github.io/data-science-for-biology/materials/2-workshop2/getting-started.html).

## What's inside

- `.devcontainer/` — defines the Codespace: R, the tidyverse, Quarto, the
  Bioconductor and microViz packages, and the Pi coding agent.
- `notebooks/` — starter Quarto (`.qmd`) notebooks. `00-hello-r` checks your
  setup, and `02-count-table-anatomy` through `05-enrichment` go with the four
  coding modules.
- `group_project/` — where your group project work goes. Its `README.md` has
  the prompts to start with.
- `data/2-workshop2/` — the three datasets.
- `R/count_tables.R` — loads a dataset, and builds the phyloseq object that lets
  microViz work on either count table.
- `CLAUDE.md` — context about you that your AI assistant reads automatically
  so it can help you better.

## The multiomics datasets

> [!IMPORTANT]
> These data are **constructed**. Every count in both tables is real sequencing
> output from a real sample, but the study around them, the visit labels and the
> birth outcomes, was built for this workshop. Analyse them properly, and do not
> cite the results.

Three datasets share one file layout, so your code moves between them with one
line changed:

```r
source(here::here("R/count_tables.R"))
d <- read_counts("instructional")   # or "group_a", "group_b"
```

## About the AI assistant

Pi is billed through your own OpenRouter account. It starts on
`z-ai/glm-5.3-flash`, which is cheap and fast, and good enough for most of
what you'll do. When it gets stuck, step up to the stronger `z-ai/glm-5.3`
with the `/model` command (or `Ctrl+L`) and notice the difference in speed,
quality, and cost. Your spending is on your
[OpenRouter activity page](https://openrouter.ai/activity).
