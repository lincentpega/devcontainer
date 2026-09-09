---
name: smeta
description: >-
  Builds a restaurant bill breakdown (смета, cost-split) from a receipt/check and a
  per-person order list, output as an Excel matrix. Use when the user gives a
  receipt (image or text) plus "who ate what" and asks to make a смета, split the
  bill, distribute dish costs per person, or reconcile who owes what.
compatibility: Requires Python 3.11+ and openpyxl.
metadata:
  domain: restaurant-bill-breakdown
  lang: ru
---

# Смета: restaurant receipt → per-person cost breakdown

Reusable recipe for turning a restaurant receipt and a list of who ordered what
into an Excel "смета" — a matrix of positions × people, with a per-person
subtotal, service charge, and total, all reconciling to the receipt.

## Inputs

1. **Receipt** — text or image. Per line: item name, quantity (`Кол-во`), line
   total (`Сумма`). Bottom lines: `Полная сумма` (subtotal), `Обслуживание N%`
   (service charge, e.g. `+12%`), `ИТОГО`.
2. **Person list** — ordered dishes per person. People with no dish detail are
   usually summarized as "остальное" (the rest). Shared/group items also land
   on that person unless told otherwise.

## Building the mapping (the hard part)

Reconcile so the **sum of all person-column amounts = the receipt subtotal** and
`Полная сумма + Обслуживание*N% = ИТОГО`.

- Compute unit price = line total ÷ quantity when quantity > 1.
- Assign every receipt line to the person(s) whose order matches it.
- Let total **units per item equal the number of people** assigned to that item.
  If fewer units exist than people (e.g. 2 tea pots for 6 drinkers, 1 loaf for 2),
  **split the line total evenly** across those people and adjust one person's
  share so the split sums exactly to the line total.
- Put every leftover/unclaimed line into the **"остальное" person**'s column.
- Dish-name aliases used on such receipts: see
  [references/dish-vocabulary.md](references/dish-vocabulary.md). Common ones:
  `двойное мясо`/`доп.гушт` = an extra-meat add-on for the osh it follows;
  `Махсус` = `Особый ош`; `туй ош` can mean `Туй оши порция` (full) or
  `Туй оши 0,7` (smaller) — disambiguate from the person's wording and price.

## Building the Excel

The example files in `assets/examples/` are the exact target format —
copy `assets/examples/Рони смета.xlsx` as the base or read its structure first.
Generate with a script like `scripts/build_smeta.py` (adapt the `people` and
`items` data). Format is the whole point; keep it:

- Row 1 header: `Позиция | Сумма | <person> ...`. Bold Arial, middle-aligned.
- One row per item. `Сумма` (col B) = `=SUM(C:H)` across person columns.
- Blank row, then:
  - `Полная сумма` — per person `=SUM(<col>2:<col><last>)`, B = `=SUM(B2:B<last>)`.
  - `Обслуживание N%` — per person = `CEILING(<col>full*N/100, 1)` (round up) or
    `<col>full*N/100` for exact; B = `=SUM(<service cells>)`.
  - `ИТОГО` — per person `=<col>full+<col>service`; B = `B<full>+B<service>`.
- Column widths ~ (A 30, B 16, people 11–13), row height 22.5, `freeze_panes = "A2"`.

## Validation

Print a person-summary table (sумма / +N% / ИТОГО). Confirm:
- Σ person **Полная сумма** = receipt `Полная сумма`.
- Σ person **service** and total **ИТОГО** match the receipt when using exact
  percentages. With per-person `CEILING((...) )` rounding-up the total can exceed
  the receipt by a few units (Σ of ceilings) — say so and offer exact-match if asked.

## Edge cases

- **"остальное" person** absorbs every unclaimed line (often a large share).
- **Shared single items** (tea, bread, salads to share) — split evenly, note it.
- **Отсутствующий человек** — the initial list may be missing someone (e.g.
  "а тут Владислава нет") — re-check the count of main dishes vs people; one
  extra osh/dish usually means a missing diner, not an overcharge.
- **Rounding** — offer round-up (CEILING), exact, or exact-with-difference
  absorbed by one person.
