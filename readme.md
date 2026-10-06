<div align="center">

![CP2077 Journal State Tracer](images/Mod_Post_Head.png)

# CP2077 Journal State Tracer

**A standalone, read-only CET utility for tracing Cyberpunk 2077 journal state changes during gameplay.**

![Cyberpunk 2077 2.31](https://img.shields.io/badge/Cyberpunk%202077-2.31-00e5ff?style=for-the-badge)
![CET](https://img.shields.io/badge/CET-Required-fcee0a?style=for-the-badge)
![Read Only](https://img.shields.io/badge/Read%20Only-Yes-fcee0a?style=for-the-badge)
![Lua](https://img.shields.io/badge/Lua-100%25-fcee0a?style=for-the-badge)

</div>

---

CP2077 Journal State Tracer reads Cyberpunk 2077's live `JournalManager` through Cyber Engine Tweaks, captures the journal state at the beginning and end of a trace, and reports the entries whose state changed.

Instead of dumping the entire journal, the tracer is designed to isolate a specific gameplay sequence. Start a trace, perform the action, dialogue choice, objective, quest step, or other sequence you want to investigate, then stop the trace.

The utility compares the two snapshots and produces a timestamped JSON report containing the journal entries that changed between START and STOP.

This makes it useful for quest research, branching-path analysis, mod development, testing, debugging, and identifying internal journal states that are not obvious from the player-facing quest log.

During extended testing on Cyberpunk 2077 2.31, a single 65-minute Nomad/prologue trace captured 159 journal state changes.

---

## Features

- Captures a baseline `JournalManager` snapshot when START TRACE is pressed
- Captures a second snapshot when STOP TRACE is pressed
- Compares the two snapshots and reports journal entries whose state changed
- Detects Active, Succeeded, and Failed journal states
- Records internal journal paths
- Records journal entry IDs
- Records 32-bit journal entry hashes
- Records in-game journal timestamps
- Scans both `quests` and `ep1/quests` journal roots
- Displays captured changes directly in the CET interface
- Provides a detailed view for individual results
- Exports results to formatted JSON
- Uses timestamped report filenames
- Supports multiple independent traces during the same game session
- RESET TRACER clears the completed trace from memory without deleting previous reports
- Read-only
- Does not modify quests, progression, journal states, or save data

---

## Installation

Place the `CP2077 Journal State Tracer` folder into:

```text
Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods
```

The folder should contain:

```text
init.lua
```

---

## Usage

Launch Cyberpunk 2077 and allow Cyber Engine Tweaks to initialize.

Load into a playable game session.

Open the CET overlay and use:

```text
START TRACE
```

Perform the action or sequence you want to investigate.

When finished, press:

```text
STOP TRACE
```

The tracer captures the final journal state, compares it with the baseline, and displays the detected changes on the RESULTS page.

A timestamped JSON report is also generated:

```text
StateTrace_YYYYMMDD_HHMMSS.json
```

Example:

```text
StateTrace_20261006_000554.json
```

Each changed journal entry can include:

```text
id
path
hash
state
gameTime
```

Example:

```text
path: quests/main_quest/prologue/q001_01_victor/megabuilding/talk_jackie
state: Succeeded
hash: 760615170
id: talk_jackie
gameTime: 5d 11:06:21
```

After a completed trace, use:

```text
RESET TRACER
```

to return the utility to READY and begin another independent trace without reloading CET.

Previously generated JSON reports are not deleted.

---

## What the Tracer Reports

This utility reports changes in Cyberpunk 2077's internal journal state as exposed through CET's `JournalManager`.

The journal contains more than the quests and objectives visible in the player-facing quest log. It can include parent entries, nested objectives, descriptions, branches, internal records, and other state-bearing entries.

A changed entry may become:

- Active
- Succeeded
- Failed

A `Failed` journal entry does not necessarily mean the overall quest failed.

For example, during testing of The Rescue, taking an aggressive route caused the internal entry:

```text
wait_for_the_scavengers_to_finish
```

to become:

```text
Failed
```

while the quest itself continued normally.

The tracer intentionally reports that internal state change rather than trying to reinterpret or hide it.

Because the tool compares the journal at START and STOP, it reports endpoint state differences. It does not hook or record every intermediate transition that may occur between those two snapshots.

---

## Requirements

- Cyberpunk 2077
- Cyber Engine Tweaks

---

## Compatibility

CP2077 Journal State Tracer reads the game's live `JournalManager` rather than relying on a hardcoded list of quests or journal entries.

The utility scans both:

```text
quests
ep1/quests
```

This allows it to inspect journal entries exposed by both the base-game and Phantom Liberty journal trees.

Tested with Cyberpunk 2077 2.31.

---

## Output Safety

This utility is read-only.

It does not:

- Complete quests
- Fail quests
- Activate objectives
- Change journal states
- Change quest facts
- Modify progression
- Modify inventory
- Modify save data

It only captures journal state at the beginning and end of a trace, compares the two snapshots, and writes the detected changes to a JSON report.

---


Developed as a standalone Cyberpunk 2077 research and mod-development utility.

**Version 1.6**
