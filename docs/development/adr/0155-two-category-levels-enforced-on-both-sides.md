---
title: "The two-level category rule is enforced in the repository, on both the parent and the child side, and eligibility reads the stored parentUuid"
date: 2026-10-02
tags:
  - adr
description: "CategoryRepository.save refuses a parent that is itself a child and refuses giving a parent to a category that has children, so the two-level rule cannot be bypassed by the picker's quick-create path; eligibility is decided on the stored parentUuid rather than on tree depth, so a category promoted by an archived parent takes no children."
---

# 0155 — The two-level category rule is enforced in the repository, on both the parent and the child side, and eligibility reads the stored `parentUuid`

**Status:** Accepted, 2026-10-02

## Context
Ticket 051 caps the category tree at roots plus one child level. Three questions had to be settled to make that a rule rather than a form validation.

**Where it is enforced.** Structural invariants already live in the repository — unique sibling name, the delete guard — while the form owns input rules. Quick-create in the picker (ticket 026) writes straight through `CategoryRepository.save`, so a UI-only rule would leave exactly that path as the hole a third level slips through.

**Which side is checked.** The obvious half is the parent side: the chosen parent must not itself have a parent. The other half is the child side, and it violates the rule just as badly — moving a category that has children under a root produces depth three from below. The form disables its parent field in that case, but the form is not the enforcement point.

**What "is a root" means.** `buildCategoryTree` promotes a category whose parent is archived or absent to a root, so a child can *look* like a root on screen. Deciding eligibility on the rendered tree would allow a tree that is two levels on screen and three in the data, and restoring the archived parent would then produce exactly the forbidden depth.

## Decision
`CategoryRepository.save` throws `CategoryInvalid` when the chosen parent has a `parentUuid` of its own, **and** when the category being given a parent has children of its own. Archived categories count on both sides: the parent lookup ignores `archived`, and the children lookup returns archived children, so hiding a category never frees up a level. Parent eligibility in the form and the quick-create affordance in the picker are both decided on the **stored** `parentUuid`, not on tree depth.

## Consequences
- `ineligibleParents` is deleted. It computed "myself plus all descendants" to prevent cycles, and with two levels a cycle cannot exist; the form offers the roots minus itself instead.
- `_wouldCycle` is deleted for the same reason: once the parent must be a root, the ancestor walk can only ever be one step long, and the self-parent case is checked separately.
- A category promoted by an archived parent sits at root level but accepts no children — deliberate, and visible. It *is* not a root; its parent is merely hidden.
- `save` costs one extra query, but only when a parent is being set — never when a root is created.
- Existing deeper data is left alone; only new violations are refused. At the time of the decision no three-level data existed, so this costs nothing in practice.
- The picker search tests of ticket 038 lose their third level: the subtree and path rules are now exercised one level deep only.

## Evidence
- `lib/features/category/domain/category_repository.dart:183-195` — both refusals, with the note on archived children
- `lib/features/category/presentation/category_form_screen.dart:88-99` — roots minus self, and `hasChildren` disabling the field
- `lib/features/category/presentation/category_picker.dart:166` — the per-row `+` gated on the stored `parentUuid`
