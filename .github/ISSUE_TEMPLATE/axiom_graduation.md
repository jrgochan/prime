---
name: Axiom graduation
about: Propose graduating an axiom to a proved theorem
title: '[Graduation] '
labels: graduation, proofs
assignees: ''
---

## Axiom to Graduate

**Name**: `axiom_name_here`
**File**: `proofs/Cathedral/Path/To/File.lean:line`
**Current type signature**:
```lean
axiom axiom_name_here : ...
```

## Proposed Proof Strategy

How you plan to prove this axiom:

1. ...
2. ...
3. ...

## Dependencies

What mathematical facts or Lean infrastructure does this require?

- [ ] Available in Mathlib
- [ ] Requires new Mathlib contribution
- [ ] Requires numerical certification
- [ ] Requires PNT-level estimates

## Impact

Which proof paths does this axiom appear on?
- [ ] Crown path (direct BD reduction)
- [ ] Oracle bridge (GPU-certified)
- [ ] Alternative chain
- [ ] Physics interpretation
- [ ] Off-crown (no RH impact)

## Verification Plan

How will you verify the graduation is correct?

```bash
make verify    # Should show one fewer axiom
make audit     # Should show the axiom as graduated
```
