# Load necessary libraries
library(readr)     # read csv file
library(haven)     # read stata or .dta files
library(tidyverse) # All-rounder from data manipulation  
library(nnet) # multinom() build model
library(MASS) # for ginv()
library(broom)  # tidy functions for tidy output
library(lmtest) # LR test for model comparison
library(patchwork) # Greater editing in plots
library(scales)    # Adjustment of x-y axis in plots
library(sandwich)   # Cluster-robust SE
library(modelsummary) # publication table (equivalent to esttab)
library(ggalluvial)   # Sankey/Alluvial graph
library(ggh4x)
library(cowplot)

dataM <- read_dta("E:/4th year/Project/SVRS/SVRS_Data_Uncoded/final_merges/grand_merge_1723.dta")
# select only which may matter
Int_Mig_data <- dataM %>% 
  dplyr::select(SVRS,caseid,q11_sex,h8,schedule,migrated,bmdis,amdis,bmdiv,amdiv,bmarea,amarea,shift,economic,religion,relation,Educational_Level,occupation,reason,marry,age)
rm(dataM)


# Year-by-year percentage of flow.
Int_Mig_data %>% 
  filter(!is.na(shift)) %>% 
  reframe(
    counts = n(),
    R_R_count = sum(shift == 1, na.rm = TRUE),
    R_U_count = sum(shift == 2, na.rm = TRUE),
    U_R_count = sum(shift == 3, na.rm = TRUE),
    U_U_count = sum(shift == 4, na.rm = TRUE),
    .by = SVRS
  ) %>%
  mutate(
    R_R = paste0(R_R_count, " (", sprintf("%.2f", R_R_count / counts * 100), "%)"),
    R_U = paste0(R_U_count, " (", sprintf("%.2f", R_U_count / counts * 100), "%)"),
    U_R = paste0(U_R_count, " (", sprintf("%.2f", U_R_count / counts * 100), "%)"),
    U_U = paste0(U_U_count, " (", sprintf("%.2f", U_U_count / counts * 100), "%)"),
    Overall = paste0(counts, " (", sprintf("%.2f", counts / sum(counts) * 100), "%)")
  ) %>%
  dplyr::select(SVRS, R_R, R_U, U_R, U_U, Overall)




# Time-trend plot (facted)
# Prepare data with custom ranges for each transition type
plot_data <- Int_Mig_data %>% 
  filter(!is.na(shift)) %>% 
  reframe(
    counts = n(),
    R_R = sum(shift == 1, na.rm = TRUE) / counts * 100,
    R_U = sum(shift == 2, na.rm = TRUE) / counts * 100,
    U_R = sum(shift == 3, na.rm = TRUE) / counts * 100,
    U_U = sum(shift == 4, na.rm = TRUE) / counts * 100,
    .by = SVRS
  ) %>%
  pivot_longer(
    cols = c(R_R, R_U, U_R, U_U),
    names_to = "transition_type",
    values_to = "proportion"
  ) %>%
  mutate(
    transition_label = case_when(
      transition_type == "R_R" ~ "A: Rural-to-Rural",
      transition_type == "R_U" ~ "B: Rural-to-Urban",
      transition_type == "U_R" ~ "C: Urban-to-Rural",
      transition_type == "U_U" ~ "D: Urban-to-Urban"
    ),
    transition_label = factor(transition_label,
                              levels = c("A: Rural-to-Rural", "B: Rural-to-Urban",
                                         "C: Urban-to-Rural", "D: Urban-to-Urban"))
  )

# Define custom y-limits for each facet
y_limits <- list(
  "A: Rural-to-Rural" = c(15, 30),
  "B: Rural-to-Urban" = c(10, 20),
  "C: Urban-to-Rural" = c(0, 15),
  "D: Urban-to-Urban" = c(40, 60)
)

# Create plot with custom facet scales
fig2 <- ggplot(plot_data, aes(x = SVRS, y = proportion, group = 1)) +
  geom_line(size = 1.2, color = "#2c7bb6") +
  geom_point(
    size = 3.5, color = "#2c7bb6",
    fill = "white", shape = 21, stroke = 1.5
  ) +
  geom_vline(
    xintercept = 2020,
    linetype = "dashed",
    color = "red",
    size = 0.8
  ) +
  facet_wrap(
    ~ transition_label,
    ncol = 2,
    scales = "free_y",
    axes = "all_x",
    axis.labels = "all_x"
  ) +
  facetted_pos_scales(
    y = list(
      scale_y_continuous(limits = c(15, 30), breaks = seq(15, 30, 2.5)),
      scale_y_continuous(limits = c(10, 20), breaks = seq(10, 20, 2)),
      scale_y_continuous(limits = c(0, 15), breaks = seq(0, 15, 2.5)),
      scale_y_continuous(limits = c(40, 60), breaks = seq(40, 60, 2.5))
    )
  ) +
  labs(
    x = "Year",
    y = "Proportion (%)"
  ) +
  theme_bw() +
  theme(
    strip.text = element_text(face = "bold", size = 11, hjust = 0),
    axis.title = element_text(size = 12),
    axis.text = element_text(size = 10),
    strip.background = element_rect(fill = "gray90", color = "black"),
    panel.grid.minor = element_blank(),
    panel.spacing = unit(1.5, "lines")
  ) +
  scale_x_continuous(breaks = 2017:2023)

print(fig2)

# Save
ggsave("time_trend_plot.tiff", plot = fig2, device = "tiff", width = 7.5, height = 4.8, units = "in", dpi = 300, compression = "lzw")



# Create period variable and keep only migrants with complete data
alluvial_data <- Int_Mig_data %>% 
  filter(migrated == 1,
         !is.na(shift),
         !is.na(bmarea),
         !is.na(amarea)) %>% 
  mutate(
    period = case_when(
      SVRS <= 2019 ~ "Pre-COVID (2017–2019)",
      SVRS >= 2020 ~ "Post-COVID (2020–2023)"
    ),
    # Recode bmarea and amarea to readable labels
    origin = factor(bmarea,
                    levels = c(0, 1),
                    labels = c("Rural origin", "Urban origin")),
    destination = factor(amarea,
                         levels = c(0, 1),
                         labels = c("Rural destination", "Urban destination")),
    # Readable shift label for legend
    flow_type = factor(shift,
                       levels = c(1, 2, 3, 4),
                       labels = c("Rural → Rural",
                                  "Rural → Urban",
                                  "Urban → Rural",
                                  "Urban → Urban"))
  ) %>% 
  filter(!is.na(period))


# ============================================================
# COLLAPSE TO FLOW COUNTS PER PERIOD
# ============================================================
# ggalluvial needs counts (freq) not individual rows
flow_counts <- alluvial_data %>% 
  count(period, origin, destination, flow_type) %>% 
  group_by(period) %>% 
  mutate(
    # Convert to proportions within each period so the two
    # panels are visually comparable despite different N
    prop = n / sum(n)
  ) %>% 
  ungroup()

print(flow_counts)


# ============================================================
# DEFINE CONSISTENT COLOR PALETTE FOR FLOW TYPES
# ============================================================
flow_colors <- c(
  "Rural → Rural"  = "#4CAF50",   # green  — stable rural
  "Rural → Urban"  = "#2196F3",   # blue   — classic urbanization
  "Urban → Rural"  = "#b70088",   # purple — reverse migration (your key finding)
  "Urban → Urban"  = "#FF9800"    # orange — urban-to-urban
)


# ============================================================
# FUNCTION: BUILD ONE ALLUVIAL PANEL
# ============================================================
make_alluvial <- function(data, period_label) {
  
  data %>% 
    filter(period == period_label) %>% 
    ggplot(aes(axis1 = origin,
               axis2 = destination,
               y     = prop,
               fill  = flow_type)) +
    
    geom_alluvium(aes(fill = flow_type),
                  alpha = 0.75,
                  width = 1/4,
                  knot.pos = 0.4) +
    
    geom_stratum(width  = 1/4,
                 fill   = "grey92",
                 color  = "grey50",
                 linewidth = 0.3) +
    
    geom_text(stat  = "stratum",
              aes(label = after_stat(stratum)),
              size  = 3.2,
              fontface = "bold",
              color = "grey20",
              angle = 90) +
    
    scale_x_discrete(
      limits = c("Origin area", "Destination area"),
      expand = c(0.15, 0.15)
    ) +
    scale_y_continuous(
      labels = scales::percent_format(accuracy = 1)
    ) +
    scale_fill_manual(values = flow_colors, name = "Migration flow") +
    
    labs(
      title = period_label,
      x     = NULL,
      y     = NULL          # <- was "Share of migrants"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title       = element_text(face = "bold", hjust = 0.5, size = 13),
      legend.position  = "none",
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.text.x      = element_blank(),   # <- removes "Origin area"/"Destination area"
      axis.ticks.x     = element_blank(),
      axis.text.y      = element_text(size = 9),  # keeps the 0/25/50/75/100% labels,
      plot.margin = margin(2,2,2,2)
    )
}


# ============================================================
# BUILD BOTH PANELS
# ============================================================
p_pre  <- make_alluvial(flow_counts, "Pre-COVID (2017–2019)")
p_post <- make_alluvial(flow_counts, "Post-COVID (2020–2023)")


# ============================================================
# COMBINE WITH PATCHWORK + SHARED LEGEND
# ============================================================
library(patchwork)
# Extract legend from a temporary plot that has it turned on
legend_plot <- flow_counts %>% 
  ggplot(aes(axis1 = origin, axis2 = destination,
             y = prop, fill = flow_type)) +
  geom_alluvium(alpha = 0.75, width = 1/4) +
  scale_fill_manual(values = flow_colors, name = "Migration flow") +
  theme(legend.position = "bottom",
        legend.title    = element_text(face = "bold"))

shared_legend <- cowplot::get_legend(legend_plot)   # needs cowplot package

# Final combined figure
combined <- (p_pre | p_post) /
  cowplot::plot_grid(shared_legend) +
  plot_layout(heights = c(10, 1))

print(combined)

ggsave("alluvial_transition.tiff", plot = combined, device = "tiff", width = 7.5, height = 5.2, units = "in", dpi = 300, compression = "lzw")



# ============================================================
# DIVISION-LEVEL VERSION (bmdiv → amdiv)
# for a richer "who moved where" picture
# ============================================================

division_labels <- c(
  "10" = "Barisal",
  "20" = "Chittagong",
  "30" = "Dhaka",
  "40" = "Khulna",
  "45" = "Mymensingh",
  "50" = "Rajshahi",
  "55" = "Rangpur",
  "60" = "Sylhet"
)

div_counts <- Int_Mig_data %>% 
  filter(migrated == 1,
         !is.na(bmdiv),
         !is.na(amdiv)) %>% 
  mutate(
    period      = case_when(
      SVRS <= 2019 ~ "Pre-COVID (2017–2019)",
      SVRS >= 2020 ~ "Post-COVID (2020–2023)"
    ),
    origin_div  = factor(bmdiv,
                         levels = as.numeric(names(division_labels)),
                         labels = division_labels),
    dest_div    = factor(amdiv,
                         levels = as.numeric(names(division_labels)),
                         labels = division_labels)
  ) %>% 
  filter(!is.na(period)) %>% 
  count(period, origin_div, dest_div) %>% 
  group_by(period) %>% 
  mutate(prop = n / sum(n)) %>% 
  ungroup()

# Division-level palette (one color per origin division)
div_colors <- c(
  "Barisal"    = "#E53935",
  "Chittagong" = "#8E24AA",
  "Dhaka"      = "#1E88E5",
  "Khulna"     = "#00897B",
  "Mymensingh" = "#FFF200",
  "Rajshahi"   = "#C75300",
  "Rangpur"    = "#6D4C41",
  "Sylhet"     = "#546E7A"
)

make_div_alluvial <- function(data, period_label) {
  data %>% 
    filter(period == period_label) %>% 
    ggplot(aes(axis1 = origin_div,
               axis2 = dest_div,
               y     = prop,
               fill  = origin_div)) +
    geom_alluvium(alpha = 0.65, width = 1/5, knot.pos = 0.4) +
    geom_stratum(width = 1/5, fill = "grey92",
                 color = "grey50", linewidth = 0.3) +
    geom_text(stat = "stratum",
              aes(label = after_stat(stratum)),
              size = 2.8, color = "grey20", fontface = "bold") +                          
    scale_x_discrete(
      limits = c("Origin division", "Destination division"),
      expand = c(0.15, 0.15)
    ) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    scale_fill_manual(values = div_colors, name = "Origin division") +
    labs(title = period_label, x = NULL, y = NULL) +   # <- dropped "Share of migrants"
    theme_minimal(base_size = 11) +
    theme(
      plot.title       = element_text(face = "bold", hjust = 0.5, size = 13),
      legend.position  = "none",
      panel.grid       = element_blank(),
      axis.text.x      = element_blank(),              # <- dropped "Origin division"/"Destination division"
      axis.ticks.x     = element_blank()
    )
}

div_pre  <- make_div_alluvial(div_counts, "Pre-COVID (2017–2019)")
div_post <- make_div_alluvial(div_counts, "Post-COVID (2020–2023)")

div_combined <- (div_pre | div_post)   # <- dropped plot_annotation title/subtitle/caption

print(div_combined)

ggsave("alluvial_division.tiff", plot = div_combined, device = "tiff", width = 7.5, height = 5.2, units = "in", dpi = 300, compression = "lzw")




###########################################################

#   modelling #

###########################################################


## --- rebuild your modelling data (your code, unchanged) ---
multmodel <- Int_Mig_data %>%
  dplyr::select(caseid,
                shift,
                age,
                q11_sex,
                religion,
                relation,
                marry,
                Educational_Level,
                occupation,
                economic,
                reason,
                SVRS,
                h8,
                bmdiv)

multmodel <- na.omit(multmodel)

multmodel$shift <- as.factor(multmodel$shift)
multmodel <- multmodel %>%
  mutate(across(-c(shift, caseid), as.factor))

multmodel$clusterID <- as.numeric(sub("^\\S+\\s+(\\S+).*$", "\\1", multmodel$caseid))

## Reference category = 2 (Rural -> Urban)
multmodel <- multmodel %>%
  mutate(shift = relevel(factor(shift), ref = "2"))

## Full model
multinom_model <- nnet::multinom(
  shift ~ . - caseid - clusterID,
  data  = multmodel,
  maxit = 200,
  Hess  = TRUE
)



# 2. Robust vcov, clustered on PSU
vc <- vcovCL(multinom_model, cluster = ~clusterID)

# 3. Robust coeftest -> this IS the robust version, use it downstream
robust_ct <- coeftest(multinom_model, vcov. = vc)

# vc already computed and correct — this part worked
cf_mat <- coef(multinom_model)          # matrix: levels x terms

# Flatten the coefficient matrix to a named vector
est <- as.vector(t(cf_mat))
names(est) <- paste(rep(rownames(cf_mat), each = ncol(cf_mat)),
                    rep(colnames(cf_mat), times = nrow(cf_mat)),
                    sep = ":")

# --- Safety check before trusting anything downstream ---
setdiff(names(est), colnames(vc))   # should be character(0)
setdiff(colnames(vc), names(est))   # should be character(0)


est_alt <- as.vector(cf_mat)
names(est_alt) <- paste(rep(colnames(cf_mat), each = nrow(cf_mat)),
                        rep(rownames(cf_mat), times = ncol(cf_mat)), sep = ":")
setdiff(names(est_alt), colnames(vc))   # check 


cf_mat <- coef(multinom_model)
lvls   <- rownames(cf_mat)     # outcome levels, e.g. "1","3","4"
terms  <- colnames(cf_mat)     # predictor terms

candidates <- list(
  term_first  = as.vector(outer(terms, lvls, paste, sep = ":")),  # "(Intercept):1"
  level_first = as.vector(outer(lvls, terms, paste, sep = ":")),  # "1:(Intercept)"
  term_first_dot  = as.vector(outer(terms, lvls, paste, sep = ".")),
  level_first_dot = as.vector(outer(lvls, terms, paste, sep = "."))
)

for (nm in names(candidates)) {
  miss <- setdiff(candidates[[nm]], colnames(vc))
  cat(nm, "-> unmatched:", length(miss), "of", length(candidates[[nm]]), "\n")
}


cf_mat <- coef(multinom_model)
lvls   <- rownames(cf_mat)
terms  <- colnames(cf_mat)

est <- as.vector(cf_mat)                                     # NOT t(cf_mat) — same shape as outer()
names(est) <- as.vector(outer(lvls, terms, paste, sep = ":"))

# Reorder est to match vc's column order
est <- est[colnames(vc)]

# Naive (non-robust) SEs from the model's own vcov, same names, same reordering
naive_se <- sqrt(diag(vcov(multinom_model)))
naive_se <- naive_se[colnames(vc)]
naive_z  <- est / naive_se

# Compare a handful of these against broom's own naive output
check <- broom::tidy(multinom_model) %>%
  mutate(term_key = paste(y.level, gsub("`", "", term), sep = ":")) %>%
  filter(term_key %in% names(naive_z)[1:10])

data.frame(term = names(naive_z)[1:10], my_z = round(naive_z[1:10], 3))
check %>% mutate(broom_z = round(statistic, 3)) %>% select(term_key, broom_z)


# --- Robust SEs, matched and verified in previous step ---
se <- sqrt(diag(vc))
se <- se[names(est)]          # already in vc's order, this just guarantees it
z  <- est / se
p  <- 2 * pnorm(-abs(z))

# --- Build the full robust results table ---
robust_table <- tibble(
  y.level   = sub(":.*$", "", names(est)),
  term      = sub("^[^:]*:", "", names(est)),
  estimate  = est,
  std.error = se,
  statistic = z,
  p.value   = p,
  row.names = NULL
)

# --- Final display table: RRR, 95% CI, stars ---
tidy_robust <- robust_table %>%
  mutate(
    outcome = case_when(
      y.level == "1" ~ "Rural→Rural",
      y.level == "3" ~ "Urban→Rural",
      y.level == "4" ~ "Urban→Urban"
    ),
    RRR     = round(exp(estimate), 2),
    CI_low  = round(exp(estimate - 1.96 * std.error), 2),
    CI_high = round(exp(estimate + 1.96 * std.error), 2),
    p.value = round(p.value, 4),
    stars   = case_when(
      p.value < 0.01 ~ "***",
      p.value < 0.05 ~ "**",
      p.value < 0.1  ~ "*",
      TRUE           ~ ""
    )
  ) %>%
  select(outcome, term, RRR, CI_low, CI_high, p.value, stars)

print(tidy_robust, n = Inf, width = Inf)



#################################################


#-----------McFadden's R-square-----------------#

# Fit null model (intercept only)
null_model <- multinom(shift ~ 1, data = multmodel)

# Calculate McFadden's R²
ll_full <- logLik(multinom_model)
ll_null <- logLik(null_model)

r2_mcfadden <- 1 - (as.numeric(ll_full) / as.numeric(ll_null))
cat("McFadden's R² =", round(r2_mcfadden, 4), "\n")


