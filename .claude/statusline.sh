#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')

# --- Sandbox: read settings hierarchy (low → high priority) ---
sandbox=""
for f in \
    ~/.claude/settings.json \
    "${project_dir:+$project_dir/.claude/settings.json}" \
    "${project_dir:+$project_dir/.claude/settings.local.json}" \
    /etc/claude-code/managed-settings.json; do
    [ -z "$f" ] && continue
    val=$(jq -r '.sandbox.enabled // empty' "$f" 2>/dev/null)
    [ "$val" = "true" ] && sandbox="ON"
    [ "$val" = "false" ] && sandbox="OFF"
done
sandbox_from_settings="$sandbox"

# --- Sandbox: check transcript for in-session /sandbox toggle ---
# Match only actual command stdout (string content), not tool results (array content).
# String content: "content":"<local-command-stdout>..."  Array content: "content":[...]
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
    last_stdout=$(tail -200 "$transcript" 2>/dev/null \
        | grep '"content":"<local-command-stdout>' \
        | grep 'Sandbox' | tail -1 || true)
    if [ -n "$last_stdout" ]; then
        if echo "$last_stdout" | grep -q 'Sandbox enabled'; then
            sandbox="ON"
        elif echo "$last_stdout" | grep -q 'Sandbox disabled'; then
            sandbox="OFF"
        fi
    fi
fi

# --- Build output ---
# Context bar
if [ -n "$used" ]; then
    u=${used%.*}; f=$((u/5)); e=$((20-f))
    bar="["; for((i=0;i<f;i++)); do bar+="█"; done
    for((i=0;i<e;i++)); do bar+="░"; done
    bar+=" ${used}%]"
    echo -n "$model $bar"
else
    echo -n "$model"
fi

# Sandbox indicator
[ -n "$sandbox" ] && echo -n " | Sandbox: $sandbox"

# Safety net
safety_net=$(bunx cc-safety-net --statusline 2>/dev/null || true)
[ -n "$safety_net" ] && echo -n " | $safety_net"

echo
