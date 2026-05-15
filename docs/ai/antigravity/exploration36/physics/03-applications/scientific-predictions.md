# Scientific Predictions

## Domain-by-Domain Analysis of Cathedral Framework Predictions

Each section applies the three Cathedral insights to a specific scientific domain. Predictions are marked with testability ratings:
- 🟢 **Immediately testable** (public data, standard tools, < 1 week)
- 🟡 **Testable with effort** (specialized data/tools, 1-4 weeks)
- 🔴 **Long-term / speculative** (requires new experiments or currently untestable)

---

## 1. Molecular Biology

### Protein Folding (Insight B — Ward Identity) 🟢

**Prediction**: For natively folded proteins in the PDB (>100 residues), the Ward Health Index of the Cα contact map (using even/odd residue parity) will be WHI > 0.90 for at least 90% of structures. For known amyloid-forming sequences, WHI < 0.75 for at least 70%.

**Rationale**: A well-folded protein has balanced interactions between even and odd residues — the contact map exhibits Ward-like cancellation. Misfolded aggregates break this balance because they form repetitive β-sheet stacking (same-parity contacts dominate).

**Data source**: Protein Data Bank (PDB), publicly available.  
**Tools**: BioPython + NumPy. Estimated time: 2 days.

### Gene Expression (Insight A — Percolation) 🟢

**Prediction**: In bulk RNA-seq data from healthy human tissue (GTEx v8), the fraction of protein-coding genes with detectable expression (TPM > 1) will be 0.59 ± 0.03 across tissue types, centered near 6/π² ≈ 0.608.

**Rationale**: The expressed genome is the full genome filtered by the epigenetic state (Insight C). The fraction that "passes" should match the squarefree density if gene regulatory networks exhibit arithmetic-like exclusion.

**Data source**: GTEx Portal (public).  
**Tools**: R or Python. Estimated time: 1 day.

### Codon Redundancy (Insight A — Percolation) 🟡

**Prediction**: The wobble-position redundancy of the genetic code places the information content near a critical threshold — the fraction of codons where the third position carries information should be near 1 − 6/π² ≈ 39.2%.

**Rationale**: The genetic code is a "compression" of the amino acid space. The redundancy fraction should match the "non-squarefree" fraction if the code optimizes robustness vs. information.

**Data source**: Standard genetic code table. Tools: Direct computation.

---

## 2. Developmental Biology

### Gastrulation Timing (Insight A — Percolation) 🟡

**Prediction**: Gastrulation occurs when the fraction of cells that have received a fate-determining signal crosses 60 ± 5% of the total cell population.

**Rationale**: Gastrulation is the developmental percolation event — the first moment when differentiated cells form a connected majority. The Cathedral predicts this threshold matches 6/π².

**Data source**: Published scRNA-seq datasets (Pijuan-Sala et al. 2019, Nature).  
**Tools**: Seurat/Scanpy. Estimated time: 3-5 days.

### Developmental Pathologies (Insight B — Ward + Triple Interaction) 🔴

**Prediction**: Three distinct developmental pathologies map to breaking different vertices of the Triangle of Criticality:
- Break A (differentiation timing): Twinning or developmental arrest
- Break B (inter/intra-layer signaling balance): Organ malformation
- Break C (epigenetic projection failure): Teratoma formation

---

## 3. Neuroscience

### EEG Hemispheric Balance (Insight B — Ward Identity) 🟡

**Prediction**: The Ward Health Index of EEG coherence matrices (alpha band, left/right hemisphere parity) discriminates healthy controls from unilateral stroke patients with AUC > 0.75.

**Rationale**: Unilateral brain damage breaks the left-right Ward balance. The WHI should be high for healthy subjects (balanced inter-hemispheric coherence) and low for lateralized pathology.

**Data source**: Temple University Hospital EEG Corpus (public, ~25,000 recordings).  
**Tools**: MNE-Python. Estimated time: 1-2 weeks.

### Neural Coding (Insight A — Percolation) 🔴

**Prediction**: The long-term active fraction of cortical neurons approaches 6/π² ≈ 60.8%. Neurons that fire in too many contexts ("non-squarefree" — overloaded) are functionally silenced by inhibitory circuits (neural Pauli exclusion).

### Binding Problem (Insight C — Projection) 🔴

**Prediction**: Conscious experience is the projection of the full neural state onto the "coherent" subspace — the squarefree projection of neural activity. Only unique feature combinations survive to awareness.

---

## 4. Ecology

### Trophic Balance (Insight B — Ward Identity) 🟡

**Prediction**: In well-documented food webs, WHI (computed with producer/consumer parity) > 0.85 for stable ecosystems and < 0.70 for ecosystems undergoing regime shift.

**Rationale**: Stable ecosystems have balanced intra-trophic competition and inter-trophic predation. When the balance breaks (cod collapse, coral bleaching), the Ward current increases.

**Data source**: Ecological Network Database (published food web matrices).  
**Tools**: R + network analysis packages. Estimated time: 3-5 days.

### Biodiversity (Insight A — Percolation) 🟡

**Prediction**: Stable ecosystems have ~60.8% "functionally unique" species (those with no ecological equivalent). The remaining ~39.2% are redundant (parasites, commensals with overlapping niches).

**Data source**: Published food web analyses with functional trait data.

---

## 5. Climate Science

### Carbon Cycle (Triple Interaction) 🔴

**Prediction**: Climate stability requires three simultaneous conditions:
1. Active carbon-cycling surface fraction ≈ 60.8% (A)
2. Source-sink Ward balance |W| ≈ 0 (B)
3. Stable atmospheric filter (C)

Breaking any one destabilizes the others. Current climate change breaks C (atmospheric CO₂ changes the projection filter), which cascades to B (sources exceed sinks) and eventually A.

---

## 6. Economics and Finance

### Market Correlation (Insight A — Percolation) 🟢

**Prediction**: For the S&P 500, the fraction of stocks with positive correlation to the equal-weighted index has a long-run mean of 0.61 ± 0.04 (using 252-day rolling windows, 2000-2025). During crashes (VIX > 40), this fraction exceeds 0.85. During stability (VIX < 15), it approaches 0.608.

**Data source**: Yahoo Finance / CRSP daily prices.  
**Tools**: Python + pandas. Estimated time: 1 day.

### Market Equilibrium (Insight B — Ward) 🟡

**Prediction**: Market equilibrium ↔ |W| ≈ 0 when the bilinear form is the transaction matrix and parity is buyer/seller. The Ward current measures "market inefficiency."

---

## 7. Information Theory

### Lossy Compression (Insight C — Projection) 🟢

**Prediction**: The optimal JPEG quality factor (maximizing SSIM/filesize) corresponds to retaining ~60.8% of DCT coefficients for natural images.

**Rationale**: Lossy compression IS the projection principle: compressed = full × perceptual filter. The optimal retention fraction should match the squarefree density if perceptual importance follows a Möbius-like distribution.

**Data source**: Kodak image test suite (public, 24 images).  
**Tools**: Python + Pillow + scikit-image. Estimated time: 2 hours.

### Channel Capacity (Insight B — Ward) 🔴

**Prediction**: The capacity-achieving distribution for a binary-symmetric channel minimizes the Ward current of the channel transition matrix.

---

## 8. Condensed Matter Physics

### Topological Insulators (Triple Interaction) 🟡

**Prediction**: The fraction of the Brillouin zone occupied by topologically non-trivial states at the gap-closing transition is within 10% of 6/π² ≈ 0.608.

**Rationale**: The topological insulator's structure matches the Cathedral exactly:
- ℤ/2 grading = spin parity
- Ward cancellation = time-reversal protection
- Bulk-boundary projection = μ² filter

The Gram matrix eigenvalue statistics should match topological insulator surface state statistics.

**Data source**: Materials Project DFT band structures.  
**Tools**: Materials Project API + Python. Estimated time: 3-5 days.

---

## 9. Population Genetics

### Speciation (Triple Interaction) 🔴

**Prediction**: Speciation events show correlated threshold-crossing in three measures:
1. Hybrid frequency falls below 60.8% (A — reproductive isolation percolates)
2. Ward current in hybrids becomes large (B — epistatic incompatibility)
3. Developmental projection diverges (C — different epigenetic landscapes)

**Test system**: Ring species (e.g., Ensatina salamanders) where genetic distance varies continuously.

---

## 10. Linguistics

### Vocabulary Structure (Insight A — Percolation) 🟡

**Prediction**: In well-edited text, about 60.8% of word tokens carry unambiguous meaning. The remaining 39.2% are structurally redundant or semantically ambiguous.

**Data source**: Word-sense disambiguation corpora (SemCor, OntoNotes).

### Syntactic Balance (Insight B — Ward) 🔴

**Prediction**: Good writing has balanced subject-predicate Ward structure: |W| ≈ 0. Languages that deviate from this balance evolve faster (are less stable over time).

---

## Quick-Start: The Fastest Three Tests

| # | Prediction | Time | Data | Impact |
|---|---|---|---|---|
| 1 | JPEG compression ratio ≈ 60.8% | **2 hours** | Kodak suite (free) | Medium |
| 2 | GTEx gene expression ≈ 60.8% | **1 day** | GTEx portal (free) | High |
| 3 | S&P 500 correlation fraction | **1 day** | Yahoo Finance (free) | High |

If any two of these three hold, the Cathedral's structural principle has empirical support across three unrelated domains. If none hold, the numerical coincidences are likely domain-specific.

---

*Twenty predictions across ten domains. Five are testable this week. Start with the JPEG test — it takes two hours and costs nothing.*
