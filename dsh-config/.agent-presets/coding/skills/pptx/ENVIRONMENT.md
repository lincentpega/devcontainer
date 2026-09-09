# Shared runtime environment for this skill

The pptx skill's runtime dependencies are installed **once, machine-wide / in this
skill dir** — nothing is re-fetched per project. Verified 2026-09-07 with an
end-to-end smoke test: generate → validate → markitdown → PDF → slide images, all
passing.

## Python (venv inside this skill dir)

- Location: `.venv/` in this directory →
  `/Users/igorkrasniukov/.agents/skills/pptx/.venv`
- Packages: defusedxml 0.7.1 · lxml 6.1.3 · Pillow 12.3.0 ·
  markitdown 0.1.7 (installed with the `pptx` extra, brings python-pptx 1.0.2)
- Always invoke scripts with the venv interpreter, e.g.:
  `~/.agents/skills/pptx/.venv/bin/python ~/.agents/skills/pptx/scripts/office/validate.py deck.pptx`
- markitdown CLI: `~/.agents/skills/pptx/.venv/bin/markitdown deck.pptx`

## Node (node_modules inside this skill dir)

- Location: `node_modules/` in this directory
- Packages: pptxgenjs 4.0.1 · react · react-dom · react-icons · sharp
  (exact versions in `package.json` / `package-lock.json`)
- Node does **not** resolve global/neighbor dirs by default. When a generation
  script lives outside this dir, export NODE_PATH first:
  `export NODE_PATH=/Users/igorkrasniukov/.agents/skills/pptx/node_modules`
  then `require('pptxgenjs')` (and react/sharp) resolve from any cwd.
  Scripts run from inside this dir need no NODE_PATH.

## System binaries (Homebrew, machine-wide, one-time install)

- `soffice` → `/opt/homebrew/bin/soffice` (symlink to
  `/Applications/LibreOffice.app/Contents/MacOS/soffice`, LibreOffice 26.2.4.2).
  For conversions prefer the skill's `scripts/office/soffice.py` wrapper.
- `pdftoppm` (poppler 26.09.0) → `/opt/homebrew/bin/pdftoppm`,
  for rasterizing PDFs into slide images.

## Typical QA chain

1. Generate: `node gen.js` (with `NODE_PATH` exported)
2. Validate: `~/.agents/skills/pptx/.venv/bin/python ~/.agents/skills/pptx/scripts/office/validate.py out.pptx [--original template.pptx]`
3. Text check: `~/.agents/skills/pptx/.venv/bin/markitdown out.pptx`
4. PDF: `~/.agents/skills/pptx/.venv/bin/python ~/.agents/skills/pptx/scripts/office/soffice.py --headless --convert-to pdf out.pptx`
5. Images: `pdftoppm -jpeg -r 150 out.pdf slide` → inspect `slide-*.jpg`

## Maintenance

- Python deps: `~/.agents/skills/pptx/.venv/bin/pip install -U defusedxml lxml Pillow 'markitdown[pptx]'`
- Node deps: `cd ~/.agents/skills/pptx && npm update`

## Notes

- `SKILL.md` is unmodified upstream content from github.com/anthropics/skills
  (proprietary license — see `LICENSE.txt`).
- Smoke-test artifacts were kept at `/tmp/pptx-smoke/` (smoke.pptx, smoke.pdf,
  slide-*.jpg) for reference.
