import { test, before } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

let plugin;
let tmpRoot;

before(async () => {
  tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ponytail-plugin-'));
  process.env.XDG_CONFIG_HOME = tmpRoot;
  plugin = (await import('../index.js')).default;
});

function makeCtx() {
  const commands = [];
  const skills = [];
  const hooks = {};
  const prompts = [];
  return {
    command: {
      transform: async (cb) => {
        cb({ add: (command) => commands.push(command) });
      },
    },
    skill: {
      transform: async (cb) => {
        cb({ add: (skill) => skills.push(skill) });
      },
    },
    session: {
      hook: async (kind, cb) => {
        hooks[kind] = cb;
      },
      prompt: async (input) => {
        prompts.push(input);
      },
    },
    commands,
    skills,
    hooks,
    prompts,
  };
}

async function setup() {
  const ctx = makeCtx();
  await plugin.setup(ctx);
  return ctx;
}

test('registers the six skills with their SKILL.md content', async () => {
  const ctx = await setup();
  const ids = ctx.skills.map((s) => s.id).sort();
  assert.deepEqual(ids, [
    'ponytail',
    'ponytail-audit',
    'ponytail-debt',
    'ponytail-gain',
    'ponytail-help',
    'ponytail-review',
  ]);
  for (const skill of ctx.skills) {
    assert.ok(skill.path.endsWith('SKILL.md'), `${skill.id} points at a SKILL.md`);
    assert.ok(skill.content.length > 0, `${skill.id} has content`);
    assert.ok(skill.description, `${skill.id} has a description`);
  }
});

test('registers the six ponytail commands', async () => {
  const ctx = await setup();
  const names = ctx.commands.map((c) => c.name).sort();
  assert.deepEqual(names, [
    'ponytail',
    'ponytail-audit',
    'ponytail-debt',
    'ponytail-gain',
    'ponytail-help',
    'ponytail-review',
  ]);
  for (const command of ctx.commands) {
    assert.equal(typeof command.execute, 'function', `${command.name} has an executor`);
    assert.ok(command.description, `${command.name} has a description`);
  }
});

test('injects the ruleset into the system prompt', async () => {
  const ctx = await setup();
  const event = { system: [] };
  await ctx.hooks.context(event);
  assert.equal(event.system.length, 1);
  assert.equal(event.system[0].type, 'text');
  assert.match(event.system[0].text, /PONYTAIL MODE ACTIVE/);
  assert.match(event.system[0].text, /level: full/);
});

test('stays silent when the mode is off', async () => {
  fs.mkdirSync(path.join(tmpRoot, 'opencode'), { recursive: true });
  fs.writeFileSync(path.join(tmpRoot, 'opencode', '.ponytail-active'), 'off');
  const ctx = await setup();
  const event = { system: [] };
  await ctx.hooks.context(event);
  assert.equal(event.system.length, 0);
});

test('switches mode and submits the command prompt', async () => {
  const ctx = await setup();
  const command = ctx.commands.find((c) => c.name === 'ponytail');
  await command.execute({ sessionID: 'ses_test', prompt: { text: '/ponytail lite' }, delivery: 'async' });
  assert.equal(
    fs.readFileSync(path.join(tmpRoot, 'opencode', '.ponytail-active'), 'utf8'),
    'lite',
  );
  assert.equal(ctx.prompts.length, 1);
  assert.equal(ctx.prompts[0].sessionID, 'ses_test');
  assert.equal(ctx.prompts[0].delivery, 'async');
  assert.match(ctx.prompts[0].text, /lite/);
});

test('other commands submit their template', async () => {
  const ctx = await setup();
  const command = ctx.commands.find((c) => c.name === 'ponytail-review');
  await command.execute({ sessionID: 'ses_review', prompt: { text: '/ponytail-review' }, delivery: 'async' });
  assert.equal(ctx.prompts.length, 1);
  assert.equal(ctx.prompts[0].sessionID, 'ses_review');
  assert.match(ctx.prompts[0].text, /Review the current code changes for over-engineering/);
});
