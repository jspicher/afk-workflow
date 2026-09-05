# Resolve declared IDs without guessing from titles or loose prose.
def clean: sub("^`";"") | sub("`$";"") | sub("\\.md$";"");
def resolve($ticket; $edge; $all):
  ($edge|clean) as $ref |
  [$all[] | select(
    .id == $ref or
    (.id == ($ticket.feature + "/" + $ref)) or
    (.id == ($ref|sub("^\\.\\./";"")|sub("^\\./";"")|sub("/issues/";"/"))) or
    (.local_id? == $ref and .feature == $ticket.feature)
  ) | .id] | unique;
. as $all |
map(. as $ticket |
  .resolved = [.deps[] | resolve($ticket; .; $all) | if length==1 then .[0] else "!unresolved" end] |
  .runnable = (.status == "ready-for-agent" and .kind == "AFK" and
    ([.resolved[] as $id | any($all[]; .id == $id and .status == "done")] | all))
)
