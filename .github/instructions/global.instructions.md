---
applyTo: "**"
---
- Start every task by reading `.github/copilot-instructions.md`; it captures the repo-wide workflow that CI expects.
- Before editing any service code, open the closest `AGENTS.md` (currently `front/AGENTS.md`, `guard/AGENTS.md`, and `public-api/v1alpha/AGENTS.md`) for authoritative layout, command, and style guidance.
- Run builds, tests, and linters through the make targets in the service directory so you inherit the shared root `Makefile` logic.
- Capture the commands you execute and cite them in your PR so reviewers can replay the same validation steps.
- Trust these instructions first and search the tree only when information here or in the service `AGENTS.md` files is missing or proven inaccurate.
