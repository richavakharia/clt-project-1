# How Fast Does Normal Happen? Stress-Testing the Central Limit Theorem

**Math 167R, Project 1** · Richa Vakharia · San José State University

People often say that once a sample has 30 observations, the sample mean is approximately normal. I used Monte Carlo simulation in R to test that rule on 8 populations: 5 ordinary ones and 3 that each break one CLT assumption. For each population I simulated **B = 10,000 samples** at **27 sample sizes from n = 1 to n = 500**, then measured how close the distribution of sample means was to normal.

**Short answer: no, the number is not 30.** It depends on the population. The smallest n that worked ranged from 1 to 300, and for one population (the Cauchy) no n works at all.

## Results

| Population | CLT assumption | Smallest n judged normal | Normal at n = 30? | What controlled it |
|---|---|---|---|---|
| Standard Normal | All met (control) | **1** | Yes | Already normal at every n |
| Six-Sided Die | All met | **10** | Yes | Symmetric; only light tails + discreteness |
| Life/Death (age at death) | All met | **12** | Yes | Bimodal but bounded; mild left skew |
| Exponential (λ = 1) | All met | **70** | No | Skewness 2/√n; theory predicted 64 |
| Binomial (5, 0.10) | All met | **80** | No | Skewness fine by ~30, discreteness held it back |
| Non-identical Bernoulli (basketball) | Identical distribution fails | **125** | No | Same pace as an i.i.d. 70% shooter, so discreteness, not fatigue |
| Dependent Machine Failure | Independence fails | **300** | No | Slow convergence, and σ/√n is ~15% too big |
| Cauchy | Finite variance fails | **Never** | No | Spread of the mean never shrinks (IQR stays at 2) |

All the detailed numbers (skewness, kurtosis, Q-Q correlation, SE ratios) are in [`09_summary.html`](09_summary.html) and the individual analysis files.

## My "normal enough" standard

I call the sampling distribution approximately normal at a given n when **all three** hold:

1. |skewness| < 0.25
2. |excess kurtosis| < 0.50
3. Q-Q correlation > 0.998 (how straight the normal Q-Q plot is)

and they **keep holding for every larger n** I tested. The cutoffs are about 10 times the Monte Carlo noise at B = 10,000, so random noise alone won't trip them. I also looked at histograms, Q-Q plots, Shapiro-Wilk p-values, and simulated vs. theoretical standard errors. I didn't use Shapiro-Wilk as a deciding rule, because with 5,000 values it flags even tiny, unimportant departures. It even rejected the actual normal population at 2 sample sizes.

## Key takeaways

- **Skewness is the best predictor.** For i.i.d. data the skewness of x̄ is g₁/√n, so a rough rule is n ≳ (g₁ / 0.25)². That predicted the exponential (64 vs. 70 found) and age-at-death (12 vs. 12) almost exactly.
- **Discreteness matters too**, and moment-based theory doesn't capture it. The binomial and basketball cases passed on skewness long before their Q-Q plots stopped looking like staircases.
- **"The SE formula works" and "the shape is normal" are different things.** σ/√n was within ~2% for every i.i.d. finite-variance population, even at n = 1.
- **Heavy tails can break the CLT completely.** Averaging 500 Cauchy values gives the same spread as 1.
- **Dependence breaks the SE formula.** The machine-failure times are negatively correlated, so the real SE is about 15% *smaller* than σ/√n.
- **Non-identical distributions barely mattered** here, as long as no single observation dominates.
- A weird-looking population isn't necessarily a hard one: the bimodal age-at-death distribution converged faster than the smooth exponential.

## Repository layout

| File | What it is |
|---|---|
| `R/clt_helpers.R` | All reusable functions: simulation engine, diagnostics, plots, my cutoffs |
| `01_normal.qmd` to `08_age_at_death.qmd` | One analysis per population |
| `09_summary.qmd` | Cross-population comparison and final conclusions |
| `*.html` | Rendered versions of each file (self-contained, open in any browser) |
| `results/` | Saved results each analysis writes for the summary to read |
| `ai_prompts.md` | Record of my AI prompts, follow-ups, and how I checked the code |

Each analysis answers the same questions: what the population looks like, what I predicted, which n values I tried, theory vs. simulation, my chosen n, and what surprised me.

## How to reproduce

Requirements: R (4.x), Quarto, and the `knitr` and `rmarkdown` packages. No other packages are needed.

```bash
git clone <this repo>
cd <this repo>
quarto render
```

`quarto render` runs the files in order (01 → 09), so the summary is built last from the saved results. The full render takes about 2 minutes.

**Seeds:** every experiment calls `set.seed(student_id + n)` right before it runs, with `student_id = 2418` (the last four digits of my student ID). Each sample size gets its own seed so different n values don't reuse the same random numbers. I found that problem with the Cauchy; see `05_cauchy.qmd`. In `03_exponential.qmd` I reran the whole exponential study with a different seed: the exact numbers changed (chosen n went from 70 to 60), but the conclusion didn't.

## Limitations

- My cutoffs are a judgment call. A stricter skewness cutoff would push the skewed populations to bigger n, but the ranking wouldn't change.
- My n grid has gaps (for example 60, 70, 80), so a true cutoff could fall between grid points.
- The Q-Q correlation penalizes discrete distributions. Someone could reasonably call the binomial "normal enough" at a smaller n than I did.
