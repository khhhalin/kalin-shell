#!/usr/bin/env python3
"""Calendar backend for Quickshell. Talks to Google Calendar via gcalcli."""

import json
import subprocess
import sys
from datetime import datetime


def _run(cmd, timeout=30):
    try:
        out = subprocess.check_output(cmd, text=True, timeout=timeout, stderr=subprocess.STDOUT)
        return {"ok": True, "output": out}
    except subprocess.CalledProcessError as e:
        return {"ok": False, "error": (e.output or "").strip() or "gcalcli failed"}
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "gcalcli timed out"}


def fetch_month(year, month):
    start = datetime(year, month, 1)
    end = datetime(year + 1, 1, 1) if month == 12 else datetime(year, month + 1, 1)

    start_str = start.strftime("%Y-%m-%d")
    end_str = end.strftime("%Y-%m-%d")

    result = _run(["gcalcli", "agenda", "--tsv", start_str, end_str])
    if not result["ok"]:
        print(json.dumps({"error": result["error"]}), flush=True)
        return

    events = []
    for line in result["output"].strip().split("\n"):
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 6:
            continue
        start_date, start_time, end_date, end_time, link, title = parts[:6]
        events.append({
            "startDate": start_date,
            "startTime": start_time,
            "endDate": end_date,
            "endTime": end_time,
            "title": title,
        })

    print(json.dumps({"events": events}), flush=True)


def add_event(text):
    result = _run(["gcalcli", "quick", text])
    if result["ok"]:
        print(json.dumps({"ok": True}), flush=True)
    else:
        print(json.dumps({"error": result["error"]}), flush=True)


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "missing command"}), flush=True)
        return
    cmd = sys.argv[1]
    if cmd == "fetch" and len(sys.argv) == 4:
        fetch_month(int(sys.argv[2]), int(sys.argv[3]))
    elif cmd == "add" and len(sys.argv) == 3:
        add_event(sys.argv[2])
    else:
        print(json.dumps({"error": "bad arguments"}), flush=True)


if __name__ == "__main__":
    main()
