# Editing my Claude Code Buddy soul (name + personality)

I want your help giving my Claude Code companion a really good name and
personality. Read this whole thing before doing anything.

## Step 0: Ask for a screenshot of my `/buddy`

**Before drafting anything, ask me to paste a screenshot of my current
`/buddy` card.** The whole point is to make the personality specific to
my actual rolled bones. From the screenshot, extract:

- **Species** (snail, axolotl, dragon, etc.)
- **Rarity** (common / uncommon / rare / epic / legendary)
- **Eye character** (`·  ✦  ×  ◉  @  °`)
- **Hat** (none, crown, tophat, propeller, halo, wizard, beanie, tinyduck)
- **Shiny flag** (1% rare bonus, look for a `✨SHINY` or sparkle marker)
- **Stat profile**: DEBUGGING, PATIENCE, CHAOS, WISDOM, SNARK

For the stats, identify:

- The **highest** stat: this is the *primary*, the character's central trait.
- The **lowest** stat: this is the *secondary / dump*, the running gag and
  character flaw. It's often dramatically lower than the others (1, 25, or
  similar depending on rarity), so it stands out.
- The middle three: flavor.

If I haven't pasted a screenshot yet, **stop and ask for one** before
suggesting any names or blurbs.

## What's editable, what isn't

- **Soul** = `name`, `personality`, `hatchedAt`. Lives in `~/.claude.json`
  under the top-level `companion` key. This is what we're editing.
- **Bones** = species, rarity, eye, hat, shiny flag, the five stats. NOT
  in the config file. Bones are recomputed every render from a hash of
  `oauthAccount.accountUuid` plus a 15-character salt baked into the
  Claude Code binary.

If I want to change stats, species, rarity, eye, hat, or shiny, that's
`any-buddy`, not this. The soul edit and the bones swap are independent:
editing the soul never touches bones, and re-rolling bones with any-buddy
never touches the soul.

## How to write a persona the watcher LLM can actually use

The `personality` string isn't only for the `/buddy` card. It's also fed
to a **speech-bubble watcher** that comments in the corner of Claude Code
during conversations. That watcher reads the personality string each turn
and tries to act in character. The better the blurb, the funnier and more
specific the bubble.

**Checklist for a good personality blurb:**

1. **Reference at least one stat by literal number.** The watcher will
   call back to it. ("WISDOM dialed to 100 and PATIENCE at 25" gives the
   watcher a built-in running joke about impatient wisdom; the watcher
   later says things like "wait, your snark stat is *thirteen*?" because
   the number is sitting right there in the prompt.)
2. **Name the physical traits.** Species, hat, eye, shiny if applicable.
   The watcher needs to know what the character literally looks like.
3. **Lock in the primary stat as the central trait.** Make the highest
   stat the defining feature.
4. **Lock in the dump stat as the running gag.** The lowest stat is the
   most distinctive thing about the character. Lean into it. A wise
   character with low PATIENCE is more interesting than a generically
   wise character.
5. **2 to 4 sentences, roughly 50 to 100 words.** Long enough for the
   watcher to find hooks, short enough to remember.
6. **Third person, present tense.** "He knows the answer," not "I know."
7. **Set up at least one reusable joke hook**, a phrase or quirk the
   watcher can call back to without re-inventing.

**Workflow before writing:**

1. Read the screenshot. Identify primary, secondary, physical traits.
2. Ask me: *what general vibe do I want?* (wise mentor, chaotic gremlin,
   corporate middle manager, paranoid genius, cheerful menace, snobby
   academic, etc.) Don't skip this step. The screenshot tells you what
   the character looks like and what their stats are, but not what
   *voice* I want.
3. Ask if I have a name in mind. If yes, use it. If no, suggest 2 or 3
   names that fit the vibe + species + stats.
4. Draft 2 or 3 short personality options that hit the checklist, each
   in a slightly different tone. Let me pick.
5. Once I pick, do the safe edit below.

## Safe edit pattern

Always:

1. Back up.
2. Use `jq --arg` for string values (safe quoting handles quotes, dashes,
   anything weird in the personality string).
3. Write to a temp file then `mv` atomically. Never edit `~/.claude.json`
   in place.
4. Verify with a re-read.

```bash
# 1. backup
mkdir -p ~/.claude/backups
cp ~/.claude.json ~/.claude/backups/.claude.json.pre-soul-edit.$(date +%Y%m%d_%H%M%S)

# 2. edit (replace the two strings)
jq --arg name "NEW_NAME_HERE" \
   --arg p "NEW PERSONALITY BLURB HERE." \
   '.companion.name = $name | .companion.personality = $p' \
   ~/.claude.json > /tmp/claude.json.new \
   && mv /tmp/claude.json.new ~/.claude.json

# 3. verify
jq '.companion' ~/.claude.json
```

If I only want to change one field, drop the other from the jq filter.

## File layout (for reference)

```bash
jq '.companion' ~/.claude.json
```

returns:

```json
{
  "name": "Axalot",
  "personality": "...",
  "hatchedAt": 1775029382900
}
```

Leave `hatchedAt` alone. It's the original hatch timestamp and acts as
continuity if I ever swap names again.

## Critical: running-session clobber

A running `claude` process keeps `~/.claude.json` cached in memory and
periodically flushes the cache back to disk. You can see this happening:
new files keep appearing in `~/.claude/backups/.claude.json.backup.*`
during a session. If you edit the file mid-session, the edit may stick,
or may get overwritten when CC next flushes (usually within minutes).

In practice, the soul edit often does stick because the companion intro
template gets re-read from disk each turn. But it's not guaranteed.

Two options, tell me which I'm doing:

1. **Edit live (running CC).** Faster, but if it reverts I'll re-apply.
   Make the backup first either way.
2. **Edit while CC is fully closed.** Cleanest. Run `pkill -x claude`
   first, then edit, then I'll relaunch. Guaranteed to stick.

If I just say "do it," default to option 1: backup, edit, warn me about
the clobber risk in your reply, and tell me how to re-apply if it reverts.

## Verifying the change is live

After the edit, `jq '.companion' ~/.claude.json` should show the new
values. If I'm running Claude Code, run `/buddy` to confirm the card
shows the new name. The speech-bubble watcher in the corner will start
using the new personality on its next comment.

## Now wait for me

Don't do anything until I paste the `/buddy` screenshot. Then walk me
through the workflow: extract bones, ask for vibe, suggest names, draft
options, edit on approval.
