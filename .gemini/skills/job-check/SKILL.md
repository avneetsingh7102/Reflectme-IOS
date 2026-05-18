---
name: job-check
description: Automatically evaluates a job link or text against my location rules and generates a tailored cover letter.
use: When the user provides a job description or URL to review.
---

# Execution Steps
1. Use your built-in web fetch tool to read the contents of the provided job URL (or read the pasted text).
2. Apply the strict location filter from my `GEMINI.md` file.
3. If it fails the location check, stop and explain why.
4. If it passes, look at my resume details and draft a high-impact cover letter directly in the terminal output.