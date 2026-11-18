#!/bin/sh
# Invert the other-team guard in a copy of ask_team/find_and_post.rein, so a
# PR whose other team is not required is asked of that team anyway, then
# check that a walk fails. A walk that still passes does not guard the rule
# that the other team is asked only when its approval is required.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/." "$tmp/" || exit 1
target=ask_team/find_and_post.rein
sed 's/  if (!required) {/  if (required) {/' \
  "$root/$target" > "$tmp/$target" || exit 1
if cmp -s "$root/$target" "$tmp/$target"; then
  echo "sabotage did not apply: the other-team guard is not in $target"
  exit 1
fi
if ! (cd "$tmp" && rein check . > /dev/null 2>&1); then
  echo "sabotage is not valid rein: rein check fails on the copy"
  exit 1
fi
if (cd "$tmp" && WALKS_ROOT="$tmp" sh scripts/walks.sh) |
  grep -q '^FAIL: an other team not required is never asked'; then
  echo "sabotage fails as expected: the walk catches the extra team channel"
  exit 0
fi
echo "sabotage passed: the walks do not guard the other-team rule"
exit 1
