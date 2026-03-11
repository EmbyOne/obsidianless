# obsidianless

Run Obsidian's official CLI on a headless Linux server — no monitor, no Obsidian Sync subscription.

## The Problem

Obsidian's [CLI](https://help.obsidian.md/cli) is powerful — 80+ commands for reading, writing, searching, and managing your vault from the terminal. But to enable it, you need to click a toggle in **Settings → General → Advanced → Command line interface**.

On a headless server, you can't open Settings. Nobody online had a clean solution.

## The Solution

The Settings toggle writes a single key to `~/.config/obsidian/obsidian.json`:

```json
{
  "cli": true
}
```

Not `"cliEnabled"`. Not `"enableCli"`. Just `"cli"`.

Found by reverse-engineering `obsidian.asar` — the Electron main process checks `D.cli` where `D` is the parsed config file. The IPC handler for the toggle is literally:

```javascript
s.ipcMain.on("cli", (e, n) => {
  n === true && !D.cli
    ? (D.cli = true, t.emit("cli", true), _())
    : n === false && D.cli && (delete D.cli, t.emit("cli", false), _())
})
```

Pre-inject the config before starting the container. Done.

## Quick Start

### 1. Clone this repo

```bash
git clone https://github.com/lucastraba/obsidianless.git
cd obsidianless
```

### 2. Configure your vault

Edit `obsidian.json` to point to your vault's mount path:

```json
{
  "vaults": {
    "my-vault": {
      "path": "/vault/MyVault",
      "ts": 1710000000000,
      "open": true
    }
  },
  "cli": true
}
```

> The vault ID key (`"my-vault"`) can be any string. The `path` must match where you mount it in Docker.

### 3. Build and run

```bash
docker build -t obsidianless .

docker run -d --name obsidian \
  -v /path/to/your/vault:/vault/MyVault \
  -v ./config:/home/obsidian/.config/obsidian \
  obsidianless
```

### 4. Use the CLI

```bash
# Direct usage
docker exec -e DISPLAY=:99 obsidian \
  /opt/obsidian/obsidian --no-sandbox version

# Or use the wrapper (add to .bashrc)
ob() {
  docker exec -e DISPLAY=:99 obsidian \
    /opt/obsidian/obsidian --no-sandbox "$@" 2>&1 \
    | grep -v "ERROR:dbus/bus.cc"
}

ob version          # 1.12.4
ob vault            # vault info
ob search query="meeting notes" limit=5
ob read path="Journal/2026-03-11.md"
ob tasks todo
ob daily:append content="- Called the dentist"
```

## CLI Commands

<details>
<summary><strong>Full command reference (80+ commands)</strong></summary>

### Files
| Command | Description |
|---------|-------------|
| `read path="note.md"` | Read file contents |
| `create name="Note" content="..."` | Create a file |
| `append path="note.md" content="text"` | Append to file |
| `prepend path="note.md" content="text"` | Prepend to file |
| `delete path="note.md"` | Delete a file |
| `move path="old.md" to="new.md"` | Move/rename |
| `files folder="Journal/"` | List files |
| `folders` | List folders |

### Search
| Command | Description |
|---------|-------------|
| `search query="text" limit=10` | Full-text search |
| `search:context query="text"` | Search with line context |

### Structure
| Command | Description |
|---------|-------------|
| `tags counts sort=count` | List tags with counts |
| `backlinks file="Note"` | List backlinks |
| `links file="Note"` | List outgoing links |
| `orphans` | Files with no incoming links |

### Tasks
| Command | Description |
|---------|-------------|
| `tasks todo` | List incomplete tasks |
| `tasks done` | List completed tasks |
| `task path="note.md" line=5 toggle` | Toggle a task |

### Daily Notes
| Command | Description |
|---------|-------------|
| `daily:read` | Read today's daily note |
| `daily:append content="text"` | Append to daily note |
| `daily:prepend content="text"` | Prepend to daily note |
| `daily:path` | Get daily note path |

### Properties (Frontmatter)
| Command | Description |
|---------|-------------|
| `properties path="note.md"` | List properties |
| `property:set name="key" value="val" path="note.md"` | Set property |
| `property:read name="key" path="note.md"` | Read property |

### Plugins
| Command | Description |
|---------|-------------|
| `plugins` | List installed plugins |
| `plugin:enable id="plugin-id"` | Enable a plugin |
| `plugin:install id="plugin-id"` | Install from community |

### Vault
| Command | Description |
|---------|-------------|
| `vault` | Vault info (name, path, files, size) |
| `version` | Obsidian version |
| `help` | Full command list |

### Developer
| Command | Description |
|---------|-------------|
| `eval code="..."` | Execute JavaScript |
| `dev:screenshot path="shot.png"` | Take a screenshot |
| `dev:console` | Show console messages |

</details>

## How It Works

```
┌─────────────────────────────────────────┐
│  Docker Container                       │
│                                         │
│  Xvfb :99         (virtual display)     │
│    └── Obsidian    (Electron app)       │
│          └── CLI   (enabled via config) │
│                                         │
│  Volume mounts:                         │
│    /vault/...      ← your vault files   │
│    ~/.config/...   ← obsidian.json      │
└─────────────────────────────────────────┘
```

1. **Xvfb** provides a virtual framebuffer — Obsidian thinks it has a display
2. **Obsidian** starts normally, loads the vault, indexes everything
3. **`obsidian.json`** has `"cli": true` pre-set, so CLI commands work immediately
4. **CLI commands** run as separate Obsidian processes that communicate with the running instance

## FAQ

**Do I need an Obsidian Sync subscription?**
No. This runs the free desktop app. If you *have* Sync, it'll work in the container too.

**Do I need a Catalyst license?**
Yes — the CLI is a [Catalyst](https://obsidian.md/pricing) perk ($25 one-time). This setup just lets you *enable* it without a GUI. It doesn't bypass the license.

**What about `obsidian-headless` (the npm package)?**
That's a separate product for Obsidian Sync users — it syncs vaults without the desktop app. This project runs the actual desktop app headlessly, giving you the full CLI.

**Are the dbus errors a problem?**
No. The container has no system bus, but Obsidian runs fine without it. The wrapper function filters them out.

**Can I use this for AI agents?**
Yes — that's exactly what I built it for. The CLI gives you wikilink-aware search, backlink resolution, and frontmatter operations that plain file access doesn't.

**Will my plugins work?**
Yes. Community plugins in your vault's `.obsidian/` folder load normally.

## Config Path by OS

If you're not using Docker and just want to enable CLI on a headless machine:

| OS | Config path |
|----|-------------|
| Linux | `~/.config/obsidian/obsidian.json` |
| macOS | `~/Library/Application Support/obsidian/obsidian.json` |
| Windows | `%APPDATA%/obsidian/obsidian.json` |

Add `"cli": true` to the JSON. That's it.

## License

MIT

## Credits

Built by reverse-engineering Obsidian's Electron source at 3 AM. The things you do for your vault.
