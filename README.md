# Internal Migration and COVID-19 in Bangladesh — Replication Code

Replication code for:

> **How COVID-19 altered the pattern of internal migration in Bangladesh: Evidence from SVRS 2017–2023**
> Md. Fahim Ashab Abir, Noor Jahan Akter
> Institute of Statistical Research and Training (ISRT), University of Dhaka

This repository contains the two scripts used to produce every table and figure reported in the manuscript, from raw Sample Vital Registration System (SVRS) schedules to the final multinomial logistic regression results.

---

## Repository contents

| File | Language | Purpose |
|---|---|---|
| `SVRS_data_wrangling.do` | Stata (v17 MP) | Cleans, merges, and appends the raw SVRS Population/Household (Schedule‑2) and Migration (Schedule‑7 & 8) files for 2017–2023 into a single analytic dataset. Constructs in‑migration/out‑migration records, harmonizes variables across years, applies the exclusions described in the manuscript (foreign migration; multiple same‑year moves), and writes the merged file used by the R script below. |
| `Multinomial_model_clean.R` | R (v4.5.2) | Reads the merged dataset and produces Table 1, Fig 2, Fig 3, Fig 4, and Table 2 (the multinomial logistic regression with PSU‑clustered robust standard errors) exactly as reported in the manuscript. |


---

## Data

The underlying SVRS microdata are collected and held by the **Bangladesh Bureau of Statistics (BBS)** and are not redistributed in this repository. They are available from BBS upon reasonable request; see the manuscript's Ethics statement and Data Availability Statement for details.

To run this pipeline yourself:

1. Obtain the raw SVRS Schedule‑2, Schedule‑7, and Schedule‑8 files for 2017–2023 from BBS.
2. Update the file paths at the top of `SVRS_data_wrangling.do` to point to your raw files.
3. Running the `.do` file will write the merged analytic dataset to `data/grand_merge_1723.dta`.
4. `Multinomial_model_clean.R` expects that file at `data/grand_merge_1723.dta` (edit `data_path` in the script if you use a different location).

No individual‑level data are included in this repository.

---

## Requirements

**Stata**
- Stata 17 (MP) or later
- No user‑written packages required beyond base Stata (confirm against your actual `.do` file and list any `ssc install` dependencies here if applicable)

**R** (tested on R 4.5.2)
```r
install.packages(c(
  "haven", "tidyverse", "nnet", "sandwich", "lmtest",
  "gt", "patchwork", "scales", "ggalluvial", "cowplot"
))
```

---

## What each script produces

**`SVRS_data_wrangling.do`**
- `data/grand_merge_1723.dta` — the pooled, cleaned analytic dataset (5,943,968 observations; 477,802 internal migrants)

**`Multinomial_model_clean.R`**
- Table 1 — annual distribution of migration types, 2017–2023 (printed to console)
- `Fig2.tif` — time-trend plot of the four transition types
- `Fig3.tif` — area-level (rural/urban) alluvial diagram, pre‑/post‑COVID
- `Fig4.tif` — division-level alluvial diagram, pre‑/post‑COVID
- `Table2_MNL_results.csv` — full multinomial logistic regression results (RRR, 95% CI, PSU-clustered p-values), matching Table 2 / S1 Table in the manuscript

---

## Variable coding

Full variable coding and recoding crosswalks (age groups, occupation, economic status, migration reason, etc.) are documented in **S1 File** of the published manuscript.



---

## Contact

Questions about the code should be directed to the corresponding author: mfabir@isrt.ac.bd
