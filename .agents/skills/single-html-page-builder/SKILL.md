---
name: single-html-page-builder
description: Build or update a single browser-ready index.html page from broad user requirements. Use when the task is a one-page HTML site, landing page, dashboard, portfolio, or similar single-file webpage that must stay in one index.html file and use html-builder plus hooks for validation.
---

# Single HTML Page Builder

## Purpose

Build one complete `index.html` page for the user’s topic and keep the work in a single file.

Use this skill when:

- the user wants a one-page website, landing page, dashboard, or showcase page
- the output must stay in a single `index.html`
- HTML, CSS, and optional JS must live in the same file
- the page should be browser-ready with no external CDN, npm, React, or Vue

## Workflow

1. Check the working environment first: OS, shell, repo root, `.codex/` structure, hooks config, existing `html-builder` agent, and whether `index.html` already exists and contains `<html>`, `<head>`, and `<body>`.
2. If `index.html` is missing or invalid, or if the `html-builder` agent is missing, stop and report `BLOCKED`.
3. Inspect the user’s topic, purpose, audience, and style. If the core request is ambiguous, ask 3 questions before editing.
4. Use the existing `html-builder` agent to create or update only `index.html`.
5. Keep all HTML, CSS, and optional JS inside that one file.
6. Rely on the existing PostToolUse and Stop hooks for validation and final test/commit behavior. Do not use `test-runner` for this skill.
7. If the user does not answer the questions, proceed with safe defaults and explicitly report any assumptions.

## Page Design Rules

- Use semantic HTML.
- Make the layout responsive for mobile, tablet, and desktop.
- Match the topic with real sections, not empty placeholder boxes.
- Include a nav, hero, core information section, a content section that fits the topic, a CTA or usage hint, and a footer.
- Add useful card, table, timeline, or summary layouts when they fit the topic.
- If the user provides an image reference, copy only the layout rhythm, spacing, density, and visual balance. Do not copy the image itself.

## Content Rules

- Prefer concrete, topic-specific content over generic filler.
- If a fact may change over time, label it as example data or unverified unless the user provided the data.
- Preserve any user-provided names, labels, or structure unless the user asks otherwise.
- Keep the change limited to `index.html`.

## Reporting

When finished, report briefly:

- the file path
- the main sections added
- how to open the page in a browser
- whether the PostToolUse hook validation ran
- whether the Stop hook auto commit ran or still needs confirmation
- whether `git push` was not run

