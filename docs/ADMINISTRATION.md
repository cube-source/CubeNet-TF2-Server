# CubeNet TF2 Server Administration

## Overview

This document covers administration of the CubeNet TF2 server.

---

# SourceMod Administration

Administrative users are managed through:


sourcemod/configs/admins.cfg


Simple administrators may also be configured using:


sourcemod/configs/admins_simple.ini


---

# Bot Management

CubeNet uses custom bot management plugins.

## Bot Roster

Location:


sourcemod/configs/ss_bot_roster.cfg


The roster controls:

- Bot names
- Classes
- Difficulty
- Personality settings

---

# Plugin Management

Installed CubeNet plugins:

| Plugin | Purpose |
|---|---|
| SS Bot Manager | Persistent bot identities |
| SS AFK Bot | AFK player simulation |
| SS Bot Voices | Bot voice system |

---

# Troubleshooting

## Plugin Not Loading

Check:


tf/addons/sourcemod/logs/


Verify:


sm plugins list


---

## Recompile Plugins

Run:


./tools/compile_plugins.sh


Restart the server after updating plugins.
