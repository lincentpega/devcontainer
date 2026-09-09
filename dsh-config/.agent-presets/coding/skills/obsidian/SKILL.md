---
name: obsidian
description: >
  Context and writing rules for the user's Obsidian vault.
  Use when the user asks to read notes, search the vault, or write a note.
  Triggers on: "write to vault", "in obsidian", "in inbox", "new note",
  "note to self", "find in vault", "запиши в vault", or any request
  referencing the Obsidian vault.
user-invocable: true
argument-hint: [what to write or find]
---

# Obsidian vault

## Location and permissions

- Vault: `/Users/igorkrasniukov/Documents/SocialTech Vault`
- **Writable only inside `<vault>/Inbox/`.** Everything else is out of scope and will prompt on each file.
- Reads work anywhere in the vault (Read/Grep/Glob, no prompts).

## Creating a new note

- Path: `<vault>/Inbox/<title>.md`
- Title = short summary of the content, no date prefix (Obsidian tracks creation time).
- Do not create subfolders inside Inbox unless explicitly asked.

## Writing style — notes are always in English

- **English only**, regardless of the language the user used to ask.
- **Get to the point.** No preambles ("Here's a note about..."), no closing summaries, no "hope this helps".
- **No emoji** in note content.
- **Writing style.** Professional and concise. Don't undermine cignificance of edge-cases and pitfalls, although, try to stay as concise as possible.

## Reading the vault

- Topic search → Grep across the entire vault.
- Wikilinks / tags / backlinks have no built-in semantic support — only raw text search. If Obsidian-native graph semantics are needed, ask the user before wiring up MCP.

## Don't

- Do not edit notes outside Inbox without an explicit request.
- Do not reorganize the vault structure.
- Do not translate existing Russian notes unless asked.
