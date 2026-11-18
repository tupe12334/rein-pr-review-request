#!/bin/sh
# Invert the once-per-head re-ask guard in a copy of main.rein, so a head that
# was already re-asked is re-asked again, then check that a walk fails. A walk
# that still passes does not guard the one re-ask per head.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/." "$tmp/" || exit 1
target=main.rein
sed 's/if (guard.reasked) {/if (!guard.reasked) {/' \
  "$root/$target" > "$tmp/$target" || exit 1
if cmp -s "$root/$target" "$tmp/$target"; then
  echo "sabotage did not apply: the re-ask guard is not in $target"
  exit 1
fi
if ! (cd "$tmp" && rein check . > /dev/null 2>&1); then
  echo "sabotage is not valid rein: rein check fails on the copy"
  exit 1
fi
if (cd "$tmp" && WALKS_ROOT="$tmp" sh scripts/walks.sh) |
  grep -q '^FAIL: a head that was re-asked returns already re-asked'; then
  echo "sabotage fails as expected: the walk catches the repeated re-ask"
  exit 0
fi
echo "sabotage passed: the walks do not guard the once-per-head re-ask"
exit 1
