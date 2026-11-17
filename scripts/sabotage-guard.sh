#!/bin/sh
# Invert the already-asked guard in a copy of main.rein, so a head that was
# already asked is asked again, then check that a walk fails. A walk that
# still passes does not guard the one request per head.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/." "$tmp/" || exit 1
target=main.rein
sed 's/if (guard.already_asked) {/if (!guard.already_asked) {/' \
  "$root/$target" > "$tmp/$target" || exit 1
if cmp -s "$root/$target" "$tmp/$target"; then
  echo "sabotage did not apply: the already-asked guard is not in $target"
  exit 1
fi
if ! (cd "$tmp" && rein check . > /dev/null 2>&1); then
  echo "sabotage is not valid rein: rein check fails on the copy"
  exit 1
fi
if (cd "$tmp" && WALKS_ROOT="$tmp" sh scripts/walks.sh) |
  grep -q '^FAIL: an earlier request for this head returns already asked'; then
  echo "sabotage fails as expected: the walk catches the removed guard"
  exit 0
fi
echo "sabotage passed: the walks do not guard the one request per head"
exit 1
