# Jujutsu VCS Skill

An agent skill for [Jujutsu (`jj`)](https://docs.jj-vcs.dev/). It teaches coding agents to use `jj` instead of Git in Jujutsu repositories, even when both tools share a working copy.

The [skill](skills/jujutsu-vcs/SKILL.md) covers day-to-day commands and workflows for stacked changes, history edits, and conflict resolution. Install `jj` separately.

## Install

### Pi

```sh
pi install git:github.com/dljsjr/jujutsu-vcs-skill
```

### Claude Code

```sh
claude plugin marketplace add dljsjr/jujutsu-vcs-skill
claude plugin install jujutsu-vcs@jujutsu-vcs-skill
```

### Skills CLI

```sh
npx skills add dljsjr/jujutsu-vcs-skill --skill jujutsu-vcs
```

## License

[MIT](LICENSE)
