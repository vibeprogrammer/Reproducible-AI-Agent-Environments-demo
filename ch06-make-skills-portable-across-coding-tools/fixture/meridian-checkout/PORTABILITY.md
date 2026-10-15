# Portability checklist for meridian-checkout

Applies to every skill, instruction, prompt, agent and hook this repository
declares or depends on. Tested with APM v0.33.0; the compatibility matrix
from the last verified run lives in the demo's evidence folder
(`evidence/ch06-make-skills-portable-across-coding-tools/compatibility-matrix.md`).

1. Shared knowledge goes in a skill (`SKILL.md` per the Agent Skills
   specification). Paths inside it are relative to the skill folder.
2. Portable files never name a tool-specific path, tool name or command.
   Tool-specific notes live in their own package, restricted with
   `target:` in that package or `targets:` on the dependency.
3. Do not rely on a file-scoped instruction (`applyTo`) for a rule that
   must always hold; the skill carries the money rules too.
4. Every target in `apm.yml` has a row in the matrix. A primitive the matrix
   shows as `-` for a target does not exist for that tool; say so in the
   pull request rather than assume it.
5. Targets without an MCP client make `apm install` exit 1 when MCP servers
   are declared. Do not add such a target to `targets:` without deciding
   how to handle that.
6. After `apm compile`, read the generated `AGENTS.md`: on v0.33.0 it
   includes every installed dependency's instructions, including
   tool-specific ones.
7. "APM deploys" is not "the tool reads it". Mark runtime behaviour
   unverified unless someone ran the tool.
