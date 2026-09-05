#!/usr/bin/env bash

load_tickets() {
  local file item id feature json status label states number deps tmp
  : > "$RUN/tickets.ndjson"
  if [[ "$TRACKER" == local ]]; then
    local files=() eligible selected matches=$'\n'
    if [[ -n ${ISSUES_GLOB:-} ]]; then
      # compgen expands the explicit user glob without eval or word splitting.
      while IFS= read -r selected; do
        [[ -f "$selected" ]] || continue
        matches+="$(absolute "$(dirname "$selected")")/$(basename "$selected")"$'\n'
      done < <(compgen -G "$ISSUES_GLOB" || true)
    fi
    if [[ -d "$ROOT/backlog" ]]; then
      while IFS= read -r -d '' file; do files+=("$file"); done < <(find "$ROOT/backlog" -type f -path '*/issues/*.md' -print0)
    fi
    for file in "${files[@]}"; do
      [[ -f "$file" && ! -L "$file" ]] || fail "Ticket must be a regular non-symlink file: $file"
      file="$(absolute "$(dirname "$file")")/$(basename "$file")"
      eligible=true
      if [[ -n ${ISSUES_GLOB:-} && "$matches" != *$'\n'"$file"$'\n'* ]]; then eligible=false; fi
      [[ "$file" == "$ROOT/backlog/"* ]] || fail "Ticket outside configured backlog: $file"
      feature=$(basename "$(dirname "$(dirname "$file")")")
      id="$feature/$(basename "$file" .md)"
      item=$(parse_ticket "$file" "$id") || fail "Ambiguous/unsupported ticket metadata: $file"
      jq -e '.status!="ready-for-agent" or .blockers_declared' <<< "$item" >/dev/null || fail "Ready ticket needs an explicit blocker declaration: $file"
      jq -c --arg feature "$feature" --argjson eligible "$eligible" '. + {feature:$feature,eligible:$eligible}' <<< "$item" >> "$RUN/tickets.ndjson"
    done
  else
    json=$(gh api --paginate "repos/$GH_REPO/issues?state=all&per_page=100" | jq -s 'add | map(select(has("pull_request")|not))') || fail 'Unable to load GitHub issues.'
    while IFS= read -r item; do
      number=$(jq -r .number <<< "$item"); status=''; states=0
      if [[ $(jq -r .state <<< "$item") == closed ]]; then
        status=$(jq -r 'if .state_reason == "completed" then "done" else "wontfix" end' <<< "$item")
      else
        for label in needs-triage needs-info ready-for-agent ready-for-human wontfix; do
          if jq -e --arg state_label "$(label_for "$label")" 'any(.labels[]; .name == $state_label)' <<< "$item" >/dev/null; then
            status=$label; states=$((states+1))
          fi
        done
        [[ $states -le 1 ]] || fail "Conflicting state labels on GitHub #$number"
        status=${status:-needs-triage}
      fi
      deps=$(gh api --paginate "repos/$GH_REPO/issues/$number/dependencies/blocked_by?per_page=100" | jq -s --arg repo "$GH_REPO" 'add | map((if (.repository_url // "") == ("https://api.github.com/repos/"+$repo) then "" else (.repository_url // "unknown-repository") end) + "#" + (.number|tostring))') || fail "Cannot read blockers for #$number"
      tmp="$RUN/github-body.md"
      jq -r '.body // ""' <<< "$item" > "$tmp"
      # Controller progress comments remain on the tracker, but do not change the
      # human decision snapshot used for idempotent completion reconciliation.
      gh api --paginate "repos/$GH_REPO/issues/$number/comments?per_page=100" | jq -rs 'add | map(select((.body // "" | startswith("[afk-run:"))|not) | .body) | join("\n\n")' >> "$tmp" || fail "Cannot read human comments for #$number"
      # Hosted state is authoritative; strip any stale local-style status lines.
      sed '/^\(\*\*\)\?Status:/d' "$tmp" > "$RUN/github-ticket.md"
      printf '\nStatus: %s\n' "$status" >> "$RUN/github-ticket.md"
      local original_format=$FORMAT
      FORMAT=markdown
      local parsed
      parsed=$(parse_ticket "$RUN/github-ticket.md" "#$number") || fail "Invalid GitHub ticket #$number"
      FORMAT=$original_format
      jq -c --argjson deps "$deps" --argjson number "$number" --arg status "$status" \
        '. + {feature:"github",number:$number,status:$status} | .deps = ((.deps + $deps)|unique) | del(.path)' <<< "$parsed" >> "$RUN/tickets.ndjson"
    done < <(jq -c '.[]' <<< "$json")
  fi
  jq -s -e 'group_by(.id) | all(.[]; length == 1)' "$RUN/tickets.ndjson" >/dev/null || fail 'Duplicate ticket IDs.'
  jq -s -f "$RUNTIME/lib/graph.jq" "$RUN/tickets.ndjson" > "$RUN/tickets.json" || fail 'Cannot resolve ticket graph.'
}

select_ticket() {
  # Stable ordering within the established priority classes.
  jq '[.[] | select(.runnable and .eligible!=false)] | sort_by(
    if (.body|test("critical.*bug|bug.*critical";"i")) then 0
    elif (.body|test("infrastructure";"i")) then 1
    elif (.body|test("tracer bullet";"i")) then 2
    elif (.body|test("refactor";"i")) then 4 else 3 end, .id) | .[0] // empty' "$RUN/tickets.json" > "$RUN/selected.json"
}

# Re-read all dependencies and the exact ticket immediately before a terminal action.
assert_ticket_current() {
  local task=$1
  load_tickets
  jq -e --slurpfile original "$task" '
    any(.[]; .id==$original[0].id and .runnable and
      .body==$original[0].body and .deps==$original[0].deps and
      .kind==$original[0].kind and .approved==$original[0].approved)
  ' "$RUN/tickets.json" >/dev/null || fail 'Ticket readiness, content or dependencies changed. Preserving work for human reconciliation.'
}

check_gate() {
  jq -e '.checks | type == "array" and length > 0 and all(.[]; type == "array" and length > 0 and all(.[]; type == "string" and length > 0))' "$CONFIG" >/dev/null || fail 'Configure checks as a nonempty array of command argument arrays.'
  local command_json arg
  while IFS= read -r command_json; do
    local argv=()
    while IFS= read -r -d '' arg; do argv+=("$arg"); done < <(jq -j '.[] | ., "\u0000"' <<< "$command_json")
    printf 'Gate: %s\n' "$command_json"
    printf 'Command: %s\n' "$command_json" >> "$TICKET_RUN/checks.log"
    if "${argv[@]}" >> "$TICKET_RUN/checks.log" 2>&1; then
      printf 'Result: PASS (exit 0)\n' >> "$TICKET_RUN/checks.log"
    else
      local code=$?
      printf 'Result: FAIL (exit %s)\n' "$code" >> "$TICKET_RUN/checks.log"
      return 1
    fi
  done < <(jq -c '.checks[]' "$CONFIG")
}
