// ponytail — OpenCode V2 plugin (local port of the upstream V1 plugin).
//
// The upstream package ships a V1 plugin, which OpenCode V2 cannot load. This
// wrapper re-registers the same behavior through the V2 plugin API: the six
// /ponytail commands, the six skills, and the per-turn ruleset injection.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const require = createRequire(import.meta.url);

// The upstream package's exports map only exposes the V1 plugin entrypoint, so
// resolve that entry and derive the package root from it.
const pkgRoot = path.resolve(path.dirname(require.resolve('@dietrichgebert/ponytail')), '../..');
const { parseCommandFile } = require(path.join(pkgRoot, '.opencode', 'plugins', 'ponytail-frontmatter.cjs'));
const { getPonytailInstructions } = require(path.join(pkgRoot, 'hooks', 'ponytail-instructions.js'));
const { getDefaultMode, normalizePersistedMode } = require(path.join(pkgRoot, 'hooks', 'ponytail-config.js'));

// Same state file the V1 plugin used, so an existing mode carries over.
function statePath() {
  const configRoot = process.env.XDG_CONFIG_HOME || path.join(os.homedir(), '.config');
  return path.join(configRoot, 'opencode', '.ponytail-active');
}

function readMode() {
  try {
    return normalizePersistedMode(fs.readFileSync(statePath(), 'utf8').trim()) || getDefaultMode();
  } catch {
    return getDefaultMode();
  }
}

function writeMode(mode) {
  fs.mkdirSync(path.dirname(statePath()), { recursive: true });
  fs.writeFileSync(statePath(), mode);
}

function commandEntries() {
  const commandDir = path.join(pkgRoot, '.opencode', 'command');
  const entries = [];
  for (const file of fs.readdirSync(commandDir).filter((f) => f.endsWith('.md'))) {
    const name = path.basename(file, '.md');
    const parsed = parseCommandFile(path.join(commandDir, file));
    if (parsed) entries.push({ name, ...parsed });
  }
  return entries;
}

// Minimal YAML frontmatter reader for the fields ponytail skills use. Handles
// `key: value` and the `key: >` folded block scalars.
function frontmatterValue(frontmatter, key) {
  const lines = frontmatter.split(/\r?\n/);
  const start = lines.findIndex((line) => line.startsWith(`${key}:`));
  if (start === -1) return undefined;
  const inline = lines[start].slice(key.length + 1).trim();
  if (inline && !/^[>|]-?$/.test(inline)) return inline;
  const block = [];
  for (let i = start + 1; i < lines.length && /^\s+/.test(lines[i]); i++) {
    block.push(lines[i].trim());
  }
  return block.join(' ').trim() || undefined;
}

function skillEntries() {
  const skillsDir = path.join(pkgRoot, 'skills');
  const entries = [];
  for (const dir of fs.readdirSync(skillsDir)) {
    const skillPath = path.join(skillsDir, dir, 'SKILL.md');
    if (!fs.existsSync(skillPath)) continue;
    const raw = fs.readFileSync(skillPath, 'utf8');
    const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
    const frontmatter = match ? match[1] : '';
    const name = frontmatterValue(frontmatter, 'name') || dir;
    entries.push({
      id: name,
      name,
      description: frontmatterValue(frontmatter, 'description'),
      path: skillPath,
      content: (match ? match[2] : raw).trim(),
    });
  }
  return entries;
}

function commandArgs(name, text) {
  const trimmed = String(text ?? '').trim();
  const match = trimmed.match(new RegExp(`^/${name}\\s*([\\s\\S]*)$`));
  return match ? match[1].trim() : trimmed;
}

export default {
  id: 'ponytail',

  async setup(ctx) {
    await ctx.command.transform((editor) => {
      for (const entry of commandEntries()) {
        editor.add({
          name: entry.name,
          description: entry.description,
          execute: async ({ sessionID, prompt, delivery }) => {
            const args = commandArgs(entry.name, prompt?.text);
            if (entry.name === 'ponytail') {
              const mode = args ? normalizePersistedMode(args) : getDefaultMode();
              if (mode) writeMode(mode);
            }
            const text = entry.template.replaceAll('$ARGUMENTS', args);
            await ctx.session.prompt({ ...prompt, sessionID, text, delivery });
          },
        });
      }
    });

    await ctx.skill.transform((editor) => {
      for (const entry of skillEntries()) {
        editor.add(entry);
      }
    });

    await ctx.session.hook('context', (event) => {
      const mode = readMode();
      if (mode === 'off') return;
      const instructions = getPonytailInstructions(mode);
      if (instructions) {
        event.system.push({ type: 'text', text: instructions });
      }
    });
  },
};
