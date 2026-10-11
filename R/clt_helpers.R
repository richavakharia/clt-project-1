# =============================================================================
# clt_helpers.R
# Reusable functions for CLT Project 1 (Math 167R)
# Every analysis file runs source("R/clt_helpers.R") at the top.
# Only base R is used (plus knitr::kable for tables) so anyone can reproduce it.
# =============================================================================

# ---- Project-wide settings ---------------------------------------------------

student_id <- 2418   # last four digits of my student ID, used as the seed
B          <- 10000  # number of Monte Carlo repetitions (NOT the sample size)

# Sample sizes to sweep through. Dense at the small end, where the shape
# changes fastest, and sparser at the large end.
n_grid <- c(1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 35, 40, 45, 50,
            60, 70, 80, 90, 100, 125, 150, 200, 300, 500)

# ---- My "normal enough" standard ---------------------------------------------
# A sampling distribution counts as approximately normal at a given n when
# ALL THREE of these hold:
#   1. |skewness|        < 0.25
#   2. |excess kurtosis| < 0.50
#   3. Q-Q correlation   > 0.998
# And the chosen n is the smallest n where the rule passes AND keeps passing
# for every larger n I tested (so one lucky run cannot pick the answer).
#
# Why these numbers: with B = 10,000 the Monte Carlo noise in skewness is
# about sqrt(6/B) = 0.024 and in excess kurtosis about sqrt(24/B) = 0.049,
# so the cutoffs are about 10 times bigger than the noise. A skewness of 0.25
# is the point where a histogram starts to look visibly lopsided to me.
skew_cut <- 0.25
kurt_cut <- 0.50
qq_cut   <- 0.998

# ---- Descriptive statistics --------------------------------------------------

# Sample skewness: average cubed z-score. 0 for any symmetric distribution.
skewness <- function(x) {
  z <- (x - mean(x)) / sd(x)
  mean(z^3)
}

# Excess kurtosis: average 4th-power z-score minus 3. 0 for a normal.
# Positive means heavier tails than normal, negative means lighter tails.
excess_kurtosis <- function(x) {
  z <- (x - mean(x)) / sd(x)
  mean(z^4) - 3
}

# Q-Q correlation: one number that measures how straight the normal Q-Q plot
# is. It is the correlation between the sorted data and the normal quantiles
# that qqnorm() puts on the x-axis. A perfectly straight Q-Q plot gives 1.
qq_correlation <- function(x) {
  theoretical <- qnorm(ppoints(length(x)))
  cor(sort(x), theoretical)
}

# Q-Q distance: the average gap (in standard deviations) between the points
# on the Q-Q plot and the qqline(). This answers the class question
# "can I find a number for the difference between the two lines?"
qq_distance <- function(x) {
  q  <- qqnorm(x, plot.it = FALSE)
  # qqline() draws the line through the 1st and 3rd quartiles
  yq <- quantile(x, c(0.25, 0.75))
  xq <- qnorm(c(0.25, 0.75))
  slope     <- diff(yq) / diff(xq)
  intercept <- yq[1] - slope * xq[1]
  mean(abs(q$y - (intercept + slope * q$x))) / sd(x)
}

# ---- Theory-based prediction -------------------------------------------------
# For i.i.d. data with population skewness g1 and excess kurtosis g2,
# the mean of n observations has
#     skewness        = g1 / sqrt(n)
#     excess kurtosis = g2 / n
# So I can PREDICT the n where my cutoffs are crossed before simulating:
#     g1 / sqrt(n) < skew_cut   ->  n > (g1 / skew_cut)^2
#     g2 / n       < kurt_cut   ->  n > |g2| / kurt_cut
predicted_n <- function(g1, g2) {
  n_skew <- ceiling((abs(g1) / skew_cut)^2)
  n_kurt <- ceiling(abs(g2) / kurt_cut)
  data.frame(from_skewness = n_skew, from_kurtosis = n_kurt,
             prediction = max(1, n_skew, n_kurt))
}

# ---- Monte Carlo engine ------------------------------------------------------

# Simulate B sample means for one sample size n.
#   gen  = a function(k) that returns k random draws from the population
# All n * B draws are generated at once and put in a matrix with one sample
# per column, then apply() takes the mean of each column.
# (This is the same as replicate(B, mean(gen(n))) but much faster.)
simulate_means <- function(gen, n, B, seed = student_id + n) {
  set.seed(seed)   # seed right before each experiment (student_id + n, see README)
  samples <- matrix(gen(n * B), nrow = n, ncol = B)
  apply(samples, 2, mean)
}

# Summarize one set of simulated sample means against theory.
#   mu, sigma = theoretical population mean and SD (use NA if they don't exist)
summarize_means <- function(means, n, mu = NA, sigma = NA) {
  theo_se <- sigma / sqrt(n)
  sk  <- skewness(means)
  ku  <- excess_kurtosis(means)
  qqr <- qq_correlation(means)
  # Shapiro-Wilk only accepts up to 5000 values, so test the first 5000.
  # With this many values it rejects even tiny departures, so I treat it as
  # supporting evidence only.
  sw_p <- if (sd(means) > 0) shapiro.test(means[1:5000])$p.value else NA
  data.frame(
    n          = n,
    sim_mean   = mean(means),
    theo_mean  = mu,
    sim_se     = sd(means),
    theo_se    = theo_se,
    se_ratio   = sd(means) / theo_se,
    skewness   = sk,
    ex_kurt    = ku,
    qq_cor     = qqr,
    qq_dist    = qq_distance(means),
    shapiro_p  = sw_p,
    normal_enough = abs(sk) < skew_cut & abs(ku) < kurt_cut & qqr > qq_cut
  )
}

# Run the whole sweep over many n values.
#   sim_fun = a function(n) that returns B sample means for sample size n
# Returns a list: the summary table and the raw means for every n.
run_sweep <- function(sim_fun, ns = n_grid, mu = NA, sigma = NA,
                      se_fun = NULL, mu_fun = NULL) {
  all_means <- list()
  rows <- list()
  for (n in ns) {
    m <- sim_fun(n)
    all_means[[as.character(n)]] <- m
    # some processes (basketball) have a mean/SD that depends on n
    mu_n    <- if (is.null(mu_fun)) mu else mu_fun(n)
    sigma_n <- if (is.null(se_fun)) sigma else se_fun(n) * sqrt(n)  # se_fun gives the SE directly
    rows[[length(rows) + 1]] <- summarize_means(m, n, mu_n, sigma_n)
  }
  list(table = do.call(rbind, rows), means = all_means)
}

# Smallest n that passes my rule AND every larger tested n also passes.
# Returns NA if there isn't one.
chosen_n <- function(tab) {
  ok <- tab$normal_enough
  for (i in seq_along(ok)) {
    if (all(ok[i:length(ok)])) return(tab$n[i])
  }
  NA
}

# ---- Plotting ----------------------------------------------------------------

# Population picture: histogram of a big sample from the population.
plot_population <- function(gen, main, discrete = FALSE, xlim = NULL,
                            seed = student_id, ...) {
  set.seed(seed)
  x <- gen(100000)
  if (discrete) {
    tab <- table(x) / length(x)
    plot(tab, lwd = 8, col = "steelblue", main = main,
         xlab = "Value", ylab = "Proportion", ...)
  } else {
    if (!is.null(xlim)) x <- x[x >= xlim[1] & x <= xlim[2]]  # zoom in
    hist(x, breaks = 80, freq = FALSE, col = "lightsteelblue",
         border = "white", main = main, xlab = "Value", ...)
  }
}

# Histogram of sample means with the CLT normal curve on top, plus Q-Q plot.
# One row per n value.
plot_sampling <- function(sweep, ns_to_show, mu = NA, sigma = NA,
                          se_fun = NULL, mu_fun = NULL, trim = NULL) {
  old <- par(mfrow = c(length(ns_to_show), 2), mar = c(4, 4, 2.5, 1))
  on.exit(par(old))
  for (n in ns_to_show) {
    m <- sweep$means[[as.character(n)]]
    shown <- m
    # for heavy tails, zoom in on the middle so the picture isn't one spike
    if (!is.null(trim)) {
      lim <- quantile(m, c(trim, 1 - trim))
      shown <- m[m >= lim[1] & m <= lim[2]]
    }
    hist(shown, breaks = 50, freq = FALSE, col = "lightsteelblue",
         border = "white", main = paste0("Sample means, n = ", n),
         xlab = "Sample mean")
    mu_n <- if (is.null(mu_fun)) mu else mu_fun(n)
    se_n <- if (is.null(se_fun)) sigma / sqrt(n) else se_fun(n)
    if (!is.na(mu_n) && !is.na(se_n)) {
      curve(dnorm(x, mu_n, se_n), add = TRUE, col = "firebrick", lwd = 2)
    }
    qqnorm(m, main = paste0("Normal Q-Q, n = ", n), pch = 20, cex = 0.4,
           col = rgb(0.27, 0.51, 0.71, 0.4))
    qqline(m, col = "firebrick", lwd = 2)
  }
}

# Skewness, kurtosis and Q-Q correlation as n grows, with my cutoffs drawn in.
plot_convergence <- function(tab, main = "") {
  old <- par(mfrow = c(1, 3), mar = c(4, 4, 3, 1))
  on.exit(par(old))
  plot(tab$n, tab$skewness, log = "x", type = "b", pch = 19,
       xlab = "n (log scale)", ylab = "Skewness", main = "Skewness")
  abline(h = c(-skew_cut, skew_cut), col = "firebrick", lty = 2)
  abline(h = 0, col = "gray50")
  plot(tab$n, tab$ex_kurt, log = "x", type = "b", pch = 19,
       xlab = "n (log scale)", ylab = "Excess kurtosis", main = "Excess kurtosis")
  abline(h = c(-kurt_cut, kurt_cut), col = "firebrick", lty = 2)
  abline(h = 0, col = "gray50")
  plot(tab$n, tab$qq_cor, log = "x", type = "b", pch = 19,
       xlab = "n (log scale)", ylab = "Q-Q correlation", main = "Q-Q correlation")
  abline(h = qq_cut, col = "firebrick", lty = 2)
  mtext(main, outer = TRUE, line = -1.2, font = 2)
}

# Nicely formatted results table
show_table <- function(tab) {
  out <- tab
  num <- sapply(out, is.numeric)
  out[num] <- lapply(out[num], function(col) signif(col, 4))
  out$shapiro_p <- format.pval(tab$shapiro_p, digits = 2, eps = 1e-4)
  knitr::kable(out, row.names = FALSE)
}

# Save results so 09_summary.qmd can build the cross-distribution table
save_results <- function(name, tab, n_star, note) {
  dir.create("results", showWarnings = FALSE)
  saveRDS(list(name = name, table = tab, n_star = n_star, note = note),
          file.path("results", paste0(gsub("[^a-z0-9]+", "_", tolower(name)), ".rds")))
}
