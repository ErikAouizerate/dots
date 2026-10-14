# ponytail — local OpenCode V2 plugin

Local port of the [`@dietrichgebert/ponytail`](https://www.npmjs.com/package/@dietrichgebert/ponytail)
plugin. The upstream package still ships a V1 plugin, which OpenCode V2 refuses
to load, so this wrapper re-registers the same behavior through the V2 plugin
API:

- `/ponytail <lite|full|ultra|off>` persists the level to
  `~/.config/opencode/.ponytail-active` and submits the command prompt.
- The other five `/ponytail-*` commands submit their upstream templates.
- The six upstream skills are registered from `skills/*/SKILL.md`.
- Every model request gets the ruleset injected via the shared upstream
  instruction builder; mode `off` disables it.

## Layout

| Path | Purpose |
|------|---------|
| `index.js` | The V2 plugin wrapper. |
| `test/plugin.test.mjs` | Behavior tests with a fake plugin context (`npm test`). |
| `node_modules/@dietrichgebert/ponytail` | Upstream code (hooks, skills, commands). |

## Update upstream

```sh
cd ~/.config/opencode/plugins/ponytail
npm update @dietrichgebert/ponytail
opencode service restart
```

Once the upstream package ships V2 support, switch back with
`opencode plugin add @dietrichgebert/ponytail` and delete this directory.

## Disable

Add `-ponytail` to `plugins` in `~/.config/opencode/opencode.json`, or remove
this directory. The mode file persists until deleted.
