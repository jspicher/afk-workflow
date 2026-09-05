# Extract only declared metadata. Unsupported YAML constructs fail closed.
function trim(s) {gsub(/^[ \t]+|[ \t\r]+$/, "", s); return s}
function scalar(s) {s=trim(s); if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s=substr(s,2,length(s)-2); return s}
function dep(s) {
  s=trim(s); sub(/^[-*][ \t]+/,"",s); gsub(/`/,"",s)
  if (s ~ /^None([ .(]|$)/ || s=="[]" || s=="") return
  if (s ~ /^\[[^]]+\]\([^)]+\)$/) {sub(/^.*\]\(/,"",s); sub(/\)$/, "",s)}
  print "dep\t" scalar(s)
}
BEGIN {front=0; block=0; seams=0; statuses=0; declarations=0}
{sub(/\r$/, "")}
format=="fos-yaml" && NR==1 && $0=="---" {front=1; next}
format=="fos-yaml" && front && $0=="---" {front=0; next}
format=="fos-yaml" && front {
  if (/^status:/) {s=$0; sub(/^status:/,"",s); print "status\t" scalar(s); statuses++; block=0}
  else if (/^type:/) {s=$0; sub(/^type:/,"",s); print "kind\t" scalar(s); block=0}
  else if (/^id:/) {s=$0; sub(/^id:/,"",s); print "local_id\t" scalar(s); block=0}
  else if (/^depends_on:/) {
    declarations++
    s=$0; sub(/^depends_on:/,"",s); s=trim(s); block=1
    if(s ~ /^\[.*\]$/) {s=substr(s,2,length(s)-2); n=split(s,a,","); for(i=1;i<=n;i++) dep(a[i]); block=0}
    else if(s!="") exit 2
  }
  else if(block && /^[ \t]*-/) {s=$0; sub(/^[ \t]*/,"",s); dep(s)}
  else if(/^[^ \t]/) block=0
  next
}
format=="markdown" && /^(\*\*)?Status:(\*\*)?[ \t]/ {
  s=$0; gsub(/\*\*/,"",s); sub(/^Status:[ \t]*/,"",s); print "status\t" trim(s); statuses++
}
format=="markdown" && /^(\*\*)?Type:(\*\*)?[ \t]/ {
  s=$0; gsub(/\*\*/,"",s); sub(/^Type:[ \t]*/,"",s); print "kind\t" trim(s)
}
/^## / {block=($0=="## Blocked by" && format=="markdown"); if(block) declarations++; seams=($0=="## Approved test seams"); next}
format=="markdown" && block && NF {dep($0)}
seams && /^Approval: approved$/ {print "approved\ttrue"}
END {if(statuses!=1 || declarations>1 || front) exit 2; print "blockers_declared\t" (declarations==1 ? "true" : "false")}
