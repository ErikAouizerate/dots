# Command line cheatsheet

What each installed tool is for, and the few commands that cover most of the
usage. `--help` has the rest. The playbook installs all of them except `eza`
and `zoxide`, which are installed by hand.

## Look up and read

### tldr — examples instead of the manual

```sh
tldr tar                # a few examples for a command (also: tldr git log)
tldr -l | grep zip      # search the page names
tldr -p osx rsync       # another platform: linux, osx, windows, common...
tldr -L fr tar          # another language
tldr -m tar             # the page itself: they are plain markdown
tldr -u                 # refresh the cache (automatic once a week)
```

### bat — `cat` with colours and line numbers

```sh
bat file.py             # highlight, header, line numbers, pager
bat -p file.py          # plain, no decoration; -pp also skips the pager
bat -r 20:40 file.py    # a line range
bat --diff file.py      # only the lines that differ from the Git index
bat -l man -p           # force a syntax (here for MANPAGER)
```

Not a `cat` for scripts: it pages and decorates, so pass `--color=never
--decorations=never`, or use plain `cat`.

### tree — a directory as an indented tree

```sh
tree -L 2 -d                    # two levels, directories only
tree -I 'node_modules|.git'     # skip what is noise
tree -h --du -L 1               # human sizes, directory totals
```

### eza — `ls` with colours, icons and Git status

```sh
eza -l                          # long listing
eza -la --icons                 # hidden files, icons (needs a Nerd Font)
eza -l --git --group-directories-first
eza -T -L 2                     # tree, two levels
eza -l -s size -r               # sort by size, reversed
```

Not installed by the playbook: `dnf install eza`.

### htop — processes, live

```sh
htop                    # F3 search, F4 filter, F5 tree, F6 sort, F9 kill
htop -u "$USER"         # only my processes
htop -t                 # start in tree view
```

## Find

### ripgrep — search file contents

```sh
rg pattern                  # recursive, .gitignore-aware, no hidden, no binary
rg -i -w pattern            # case-insensitive, whole words (-F: no regex)
rg -t py -g '!vendor/**' pattern
rg -l pattern               # only the file names; -c counts per file
rg -C3 pattern              # three lines of context
rg -uu pattern              # hidden and gitignored files too
rg -l old | xargs sed -i 's/old/new/g'   # the rewrite `rg -r` does not do
```

### fd — find files by name

```sh
fd pattern              # by name, .gitignore-aware
fd -e rs -e toml        # by extension
fd -t f -t l            # type: f file, d dir, l link, x executable
fd -H -I                # hidden and ignored files
fd -d 2 -E node_modules # depth, exclusion
fd -x wc -l {}          # run a command per result (-X: once for all)
fd -e jpg -x convert {} {.}.png   # {.} is the path without extension
```

### fzf — an interactive filter for anything

```sh
fd -t f | fzf                   # pick a file (Ctrl-T does this anywhere)
git branch | fzf                # pick a branch
fd | fzf --preview 'bat {}'     # preview on the right
fzf -m                          # multi-select, Tab
```

`Ctrl-R`, `Ctrl-T` and `Alt-C` come from the oh-my-zsh `fzf` plugin enabled in
`~/.zshrc` (`fzf --zsh`).

### zoxide — `cd` that remembers

```sh
z dots                  # jump to the best match for "dots"
zi                      # same, but pick with fzf
z -                     # back to the previous directory
zoxide query -l         # what it knows (zoxide remove to forget one)
```

Configured in `~/.zshrc.local`, not in this repository:
`eval "$(zoxide init zsh)"`.

## Handle

### ouch — one command for every archive

```sh
ouch c a.txt b.txt out.tar.gz   # compress; format from the output extension
ouch d out.tar.gz               # decompress into ./out/ (unlike tar -xf)
ouch d out.tar.gz --here        # ... or into the current directory
ouch l out.zip                  # list the contents
ouch -y d out.zip               # take the default answer to every question
```

### jq — read and reshape JSON

```sh
jq . file.json                        # pretty-print
jq -r '.scripts.test' package.json    # raw string, no quotes
jq '.items[] | .name'                 # one value per item
jq '.items | map(select(.age > 30))'  # filter a list
curl -s "$url" | jq -r '.data.id'     # the usual way to read an API
jq --arg n "$USER" '{user: $n}'       # build an object with a shell value
```

### direnv — per-directory environment

```sh
echo 'export API_URL=http://localhost:8000' > .envrc
direnv allow            # trust this .envrc; loads on cd, unloads on leave
direnv deny             # untrust it
direnv prune            # forget the allow entries of deleted directories
```

```sh
# inside a .envrc
layout python           # venv in .direnv/, activated automatically
dotenv                  # load a .env file
PATH_add bin            # prepend ./bin to PATH
```

The hook is already in `~/.zshrc`.

### gitleaks — secrets in a repo

```sh
gitleaks git .                     # scan the whole history
gitleaks dir .                     # scan the working tree (uncommitted files)
gitleaks git --redact --log-opts="HEAD~5..HEAD"
gitleaks dir . -c .gitleaks.toml   # custom rules and allowlists
```

The `pre-push` hook (see `home/.config/git/hooks/pre-push`) runs it on every
push and blocks the push on a finding; `SKIP_SECURITY=1 git push` bypasses it.
