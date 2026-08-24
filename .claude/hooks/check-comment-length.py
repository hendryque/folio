#!/usr/bin/env python3
"""PreToolUse hook: block edits that introduce comments longer than 3 lines.

Long comments usually narrate the WHAT; the limit forces them down to the WHY.
Reads the Edit/Write tool input as JSON on stdin; exit 2 blocks the edit and
feeds stderr back to the model.
"""
import json
import os
import sys

LIMIT = 3

LINE_MARKERS = {
    ".swift": ("//",),
    ".js": ("//",),
    ".ts": ("//",),
    ".css": (),          # block comments only
    ".yml": ("#",),
    ".yaml": ("#",),
    ".sh": ("#",),
    ".py": ("#",),
}


def longest_comment_run(text: str, markers: tuple) -> int:
    run = longest = 0
    in_block = False
    for raw in text.splitlines():
        line = raw.strip()
        if in_block:
            is_comment = True
            if "*/" in line:
                in_block = False
        elif line.startswith("/*"):
            is_comment = True
            in_block = "*/" not in line
        else:
            is_comment = any(line.startswith(m) for m in markers)
        run = run + 1 if is_comment else 0
        longest = max(longest, run)
    return longest


def main() -> int:
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input", {})
    ext = os.path.splitext(tool_input.get("file_path", ""))[1].lower()
    markers = LINE_MARKERS.get(ext)
    if markers is None:
        return 0  # not a policed file type (markdown, json, ...)

    text = tool_input.get("new_string") or tool_input.get("content") or ""
    longest = longest_comment_run(text, markers)
    if longest > LIMIT:
        print(
            f"Blocked: this edit contains a {longest}-line comment "
            f"(project limit: {LIMIT} lines). Rewrite it more concisely: "
            "keep only the WHY (the constraint or intent the code cannot "
            "express), drop the WHAT (anything readable from the code "
            "itself). Then retry the edit.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
