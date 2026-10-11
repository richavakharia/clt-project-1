# AI Use Log: MATH 167R Project 1

I used Claude (Anthropic) for this project. This file records the important prompts, what came back, what I checked, and what got fixed. The professor's guidance asked for evidence of iteration and validation, so I focused on the places where something was wrong or needed a second look.


---

## 1. Main Prompts I used

**Uploads:** I uploaded the project brief, the student guidance `.qmd`, the class notes on the CLT and distributions, and the three extra-credit handouts.


**Prompts:**
1. wait what’s the difference between n and B? they both feel like sample size to me
2. why does the CLT need finite variance? like what actually breaks with the cauchy
3. can you explain independent vs identically distributed with a real example of each one failing
4. ok so i’m thinking i’ll call it normal if skewness is under 0.25 and the qq plot looks pretty straight. is that a reasonable way to do it or am i missing something
5. what sample sizes should i actually test? should they be closer together at the small end?
6. before i run anything, what n would you guess for the exponential? show me how you got it
7. can you write a function that simulates the sample means for just one population and one n? and explain what each line does bc i need to understand it
8. ok that works. now how do i loop it over a bunch of n values and save the skewness and kurtosis each time
9. is there a way to turn a qq plot into one number? i want something i can actually compare across n
10. my mean for the dependent process came out to 1.67 but i thought it’d be 1. did i mess up the code or is that actually right?
11. how do i know my skewness function is calculating it correctly
12. my cauchy skewness is stuck at 99.9 for basically every n, that seems weird. what could be causing it
13. shapiro-wilk keeps saying not normal even when the histogram looks totally fine. why does it do that
14. why does the binomial need a bigger n than its skewness says it should?
15. i changed the seed and my answer went from 70 to 60. is that bad?
16. which parts of this code would be hardest for me to explain? walk me through those

`
**AI follow-up questions and my answers:**

- What are the last four digits of my ID for the seed? → **2418**
- What is the scope of this project? →**all 5 required populations plus all 3 extra-credit ones**
- How should I structure this? → **one `.qmd` per population plus a summary, matching the brief's "separate analysis file for each population"**
- What output do you want? → **code plus a drafted write up that I write in my own words**

**Additional things I checked myself:** that the population list matched the 9/22 update (Uniform, Poisson, and Binomial Large were dropped) and that the parameters matched the table: Exp(λ = 1), Binomial(5, 0.10), Cauchy(0, 1), die values 1 to 6.

---

## 2. Iteration: the same seed for every n caused a fake Cauchy result

**What happened:** the first version called `set.seed(2418)` before *every* sample size. In the first test run the Cauchy's skewness was almost exactly **99.9 at every n from 20 to 150**, which looked weird to me.

**Diagnosis:** with the same seed, every n starts from the same random number stream. One gigantic Cauchy value early in the stream lands in some sample at *every* n, so the results for different n weren't independent experiments. The exponential and binomial tables also looked smoother than real noise would.

**Fix:** changed the seed to `set.seed(student_id + n)`. That's still fully reproducible, and still set right before each experiment, but each n gets its own random numbers. After the fix, the Cauchy skewness jumps around randomly like it should, and the IQR of the means stays at 2.

**A question I have: ** does using `student_id + n` still count as "using the last four digits of my student ID"? I think yes, since it's derived from them and documented in the README. 

---

## 3. Iteration: `plot_population()` crashed when rendering

**What happened:** the first render of `01_normal.qmd` failed inside `hist()` with a `plot.window` error.

**Diagnosis:** the helper passed `xlim = NULL` straight to `hist()`, and `hist()` doesn't accept a `NULL` xlim.

**Fix:** zoom in by filtering the data to the `xlim` range only when an `xlim` is given, and otherwise don't pass it at all.

---

## 4. Checking the "normal enough" cutoffs against noise

**Question I asked:** how do I know my cutoffs aren't just picking up Monte Carlo noise?

**Answer / check:** with B = 10,000, the standard error of a skewness estimate is about √(6/B) ≈ 0.024 and for kurtosis about √(24/B) ≈ 0.049. The cutoffs (0.25 and 0.50) are about 10 times bigger. For the Q-Q correlation, I simulated 200 sets of 10,000 truly normal values: the 1st percentile of the Q-Q correlation was 0.9998, so a 0.998 cutoff won't reject real normal data by accident.

**Validation:** the Standard Normal control case passes at every n, so the rule doesn't produce false alarms.

---

## 5. Checking that Shapiro-Wilk shouldn't be the deciding rule

**Observation:** Shapiro-Wilk rejected the *normal* population at 2 of 27 sample sizes and the die at 21 of 27, even when the histograms looked clearly bell-shaped.

**Reasoning:** with 5,000 values the test can detect tiny departures that don't matter in practice. For the die, it's detecting that the sample mean is *discrete*. So I kept it as supporting evidence only. (Also, `shapiro.test()` only accepts up to 5,000 values, which is why the code tests the first 5,000 means.)

---

## 6. Dependent process: the long-run mean isn't 1

**What happened:** I expected the mean operating time to be 1/λ₀ = 1. The simulation gave about 1.67.

**Check:** I verified with a separate long run of 1,000,000 failures (a different method from the main simulation) and got the same answer. The reason: when the previous time is short the rate drops a lot (as low as e^(-1.25) ≈ 0.29), so short runs get followed by long ones more strongly than long runs get followed by short ones.

**Design choice:** added a **burn-in** of 100 steps before each sample, so every sample starts from the long-run behavior and not from the same fixed starting point.

**SE check:** predicted the SE ratio from the autocorrelations, using 1 + 2Σρₖ, and got 0.851. The simulation gave about 0.85. Two independent methods agree.

---

## 7. Basketball: extending the 20-shot model to other n

**Question:** the handout uses exactly 20 shots. How do I vary n?

**Decision:** for n shots, the probabilities still go from 0.9 down to 0.5 using `seq(0.9, 0.5, length.out = n)`, so the fatigue curve is the same and just gets more shots along it. I started at n = 2 because `seq()` with one value gives 0.9 and not an average of 0.7.

**Validation:** added an i.i.d. Bernoulli(0.7) comparison to separate the effect of "non-identical" from "discrete." Both reached my standard at the same n.

---

## 8. What I'd prompt differently next time

Asking for the seed strategy up front and asking the AI to flag which results it had verified vs. assumed. Asking for more predictions from AI before running code so I could question its methods more and figure out the most optimal method to code the first time instead of lots of editing and reiterating. 

