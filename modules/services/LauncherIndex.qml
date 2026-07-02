pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // entries: [{ kind: "app"|"cmd", name, exec, icon, desktopId }]
    property var entries: []
    property bool ready: false

    // Reactive map: desktopId → entry. Used by TaskbarService for icon/name lookup.
    readonly property var byDesktopId: {
        const map = {}
        for (const e of root.entries) {
            if (e.desktopId) map[e.desktopId] = e
        }
        return map
    }

    signal updated()

    function refresh(): void {
        indexProc.running = true
    }

    // Very small fuzzy scorer: subsequence match with contiguous bonus.
    // Returns -1 if not match, else positive score.
    function fuzzyScore(query, text): int {
        if (!query) return 1
        const q = String(query).toLowerCase().trim()
        const s = String(text).toLowerCase()
        if (!q.length) return 1

        let qi = 0
        let score = 0
        let run = 0

        for (let si = 0; si < s.length && qi < q.length; si++) {
            if (s[si] === q[qi]) {
                qi++
                run++
                score += 5 + Math.min(10, run * 2)
            } else {
                run = 0
            }
        }

        if (qi < q.length) return -1

        // Prefer prefix-ish matches
        if (s.startsWith(q)) score += 30
        // Prefer shorter names when equal
        score += Math.max(0, 20 - s.length)

        return score
    }

    function search(query, maxResults): var {
        const q = String(query || "")
        const limit = Math.max(1, Number(maxResults || 60))

        if (!root.ready) return []
        if (!q.trim().length) {
            return root.entries.slice(0, Math.min(limit, root.entries.length))
        }

        const scored = []
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i]
            const s = root.fuzzyScore(q, e.name)
            if (s >= 0) scored.push({ score: s, entry: e })
        }

        scored.sort((a, b) => b.score - a.score)
        return scored.slice(0, limit).map(x => x.entry)
    }

    Component.onCompleted: refresh()

    Process {
        id: indexProc

        // Use a heredoc so we don't fight quoting.
        command: ["sh", "-lc", "python3 - <<'PY'\n" +
            "import os, json, stat, configparser\n" +
            "from pathlib import Path\n" +
            "\n" +
            "def norm_exec(exec_line: str) -> str:\n" +
            "    if not exec_line: return ''\n" +
            "    # remove desktop placeholders\n" +
            "    for token in ['%u','%U','%f','%F','%i','%c','%k','%d','%D','%n','%N','%v','%m']:\n" +
            "        exec_line = exec_line.replace(token, '')\n" +
            "    return ' '.join(exec_line.split())\n" +
            "\n" +
            "def desktop_dirs():\n" +
            "    dirs = []\n" +
            "    home = Path(os.path.expanduser('~'))\n" +
            "    dirs.append(home / '.local/share/applications')\n" +
            "    xdg = os.environ.get('XDG_DATA_DIRS', '')\n" +
            "    for d in [p for p in xdg.split(':') if p]:\n" +
            "        dirs.append(Path(d) / 'applications')\n" +
            "    # Common fallbacks\n" +
            "    for d in ['/usr/local/share/applications','/usr/share/applications','/run/current-system/sw/share/applications']:\n" +
            "        dirs.append(Path(d))\n" +
            "    # Dedupe\n" +
            "    seen = set(); out = []\n" +
            "    for p in dirs:\n" +
            "        ps = str(p)\n" +
            "        if ps in seen: continue\n" +
            "        seen.add(ps)\n" +
            "        out.append(p)\n" +
            "    return out\n" +
            "\n" +
            "def load_apps():\n" +
            "    apps = {}\n" +
            "    for base in desktop_dirs():\n" +
            "        try:\n" +
            "            if not base.is_dir():\n" +
            "                continue\n" +
            "            for file in base.glob('*.desktop'):\n" +
            "                desktop_id = file.stem\n" +
            "                cp = configparser.ConfigParser(interpolation=None)\n" +
            "                try:\n" +
            "                    cp.read(file, encoding='utf-8', errors='ignore')\n" +
            "                except TypeError:\n" +
            "                    cp.read(file)\n" +
            "                if 'Desktop Entry' not in cp: continue\n" +
            "                de = cp['Desktop Entry']\n" +
            "                if de.get('Type', 'Application') != 'Application': continue\n" +
            "                if de.get('NoDisplay', 'false').lower() == 'true': continue\n" +
            "                if de.get('Hidden', 'false').lower() == 'true': continue\n" +
            "                name = de.get('Name','').strip()\n" +
            "                if not name: continue\n" +
            "                exec_line = norm_exec(de.get('Exec','').strip())\n" +
            "                if not exec_line: continue\n" +
            "                icon = de.get('Icon','').strip()\n" +
            "                apps[desktop_id] = {\n" +
            "                    'kind':'app', 'name':name, 'exec':exec_line, 'icon':icon, 'desktopId':desktop_id\n" +
            "                }\n" +
            "        except Exception:\n" +
            "            continue\n" +
            "    return list(apps.values())\n" +
            "\n" +
            "def load_cmds(limit=6000):\n" +
            "    out = {}\n" +
            "    path = os.environ.get('PATH','')\n" +
            "    for d in [p for p in path.split(':') if p]:\n" +
            "        try:\n" +
            "            dp = Path(d)\n" +
            "            if not dp.is_dir():\n" +
            "                continue\n" +
            "            for child in dp.iterdir():\n" +
            "                if len(out) >= limit: break\n" +
            "                try:\n" +
            "                    st = child.stat()\n" +
            "                except Exception:\n" +
            "                    continue\n" +
            "                if not stat.S_ISREG(st.st_mode):\n" +
            "                    continue\n" +
            "                if not (st.st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)):\n" +
            "                    continue\n" +
            "                name = child.name\n" +
            "                if name not in out:\n" +
            "                    out[name] = { 'kind':'cmd', 'name':name, 'exec':name, 'icon':'', 'desktopId':'' }\n" +
            "        except Exception:\n" +
            "            continue\n" +
            "    return list(out.values())\n" +
            "\n" +
            "apps = load_apps()\n" +
            "cmds = load_cmds()\n" +
            "entries = apps + cmds\n" +
            "print(json.dumps(entries, ensure_ascii=False))\n" +
            "PY"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(this.text)
                    if (!Array.isArray(arr)) throw new Error("index not an array")
                    root.entries = arr
                    root.ready = true
                    root.updated()
                } catch (e) {
                    console.error("windows-bar: LauncherIndex parse failed:", e)
                    root.entries = []
                    root.ready = false
                    root.updated()
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: LauncherIndex stderr:", msg)
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.ready = false
                root.updated()
            }
        }
    }
}
