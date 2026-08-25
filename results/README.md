# Computational results

This directory contains the complete output of the systematic searches used
in [the accompanying paper](https://arxiv.org/abs/2608.02266).

For `q = 1`, FS₂ is tested directly on every relevant irreducible character.
For a prime power `q > 1`, the scan tests the characters α ⊠ λ of
G × C<sub>q²</sub>, where λ is faithful and α runs through the relevant
characters up to Galois conjugacy.

Each scan directory contains:

- `scan.csv`: one row per character table or SmallGroups identifier, including
  the number of failed characters and the computational metadata;
- `findings.csv`: one row per failed character. This file is absent for the
  CTblLib `q = 1` scan because that scan found no failures.

All scans used `findall = true`. The CTblLib scans exclude duplicate ordinary
character tables. The SmallGroups scans skip prime-power orders, since FS₂
holds for p-groups; the trivial group of order 1 is included.

## Inventory

| Scan | Rows in `scan.csv` | Failures |
| --- | ---: | ---: |
| CTblLib, `q = 1` | 2397 | 0 |
| CTblLib, `q = 2` | 2397 | 73 |
| CTblLib, `q = 3` | 2397 | 36 |
| CTblLib, `q = 4` | 2397 | 74 |
| CTblLib, `q = 5` | 2397 | 1 |
| SmallGroups, orders 1–189, `q = 3` | 1692 | 4 |
| SmallGroups, orders 1–567, `q = 1` | 34886 | 6 |
| SmallGroups, orders 1–567, `q = 2` | 34886 | 2 |

There are 34837 scanned groups of order strictly below 567 and 34886 scanned
groups through order 567. GAP's SmallGroups library contains 49 groups of
order 567.

## Provenance

The exact per-row metadata are part of every CSV file. The CTblLib scans were
run on 2026-08-10 using Julia 1.12.6, Oscar 1.9.0-DEV, GAP 4.16.0, CTblLib
1.3.11, and FS2 commit `428070c0f9ad`.

The SmallGroups scans were run on 2026-08-24 using Julia 1.12.6, Oscar 1.8.1,
GAP 4.16.1, SmallGrp 1.7.0, and FS2 commit `33ecdf228faa`. Because the installed
FS2 source tree did not contain Git metadata, the initially empty
`fs2_git_revision` column was restored after the computation by matching the
package tree recorded in the Julia environment to that commit. No computed
fields were changed.

The historical FS2 revisions can be installed directly, for example:

```julia
using Pkg
Pkg.add(url="https://github.com/ulthiel/FS2.jl", rev="33ecdf228faa")
```

The CSV files were checked for parseability, consecutive scan indices,
agreement between `scan_total` and the number of scan rows, and agreement
between `false_characters` and the corresponding rows in `findings.csv`.
