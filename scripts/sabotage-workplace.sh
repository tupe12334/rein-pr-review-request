#!/bin/sh
# Invert the workplace guard in a copy of main.rein, so a personal repository
# is asked anyway, then check that a walk fails. A walk that still passes does
# not guard the rule that posts nothing outside a workplace.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/." "$tmp/" || exit 1
target=main.rein
sed 's/if (!place.workplace) {/if (place.workplace) {/' \
  "$root/$target" > "$tmp/$target" || exit 1
if cmp -s "$root/$target" "$tmp/$target"; then
  echo "sabotage did not apply: the workplace guard is not in $target"
  exit 1
fi
if ! (cd "$tmp" && rein check . > /dev/null 2>&1); then
  echo "sabotage is not valid rein: rein check fails on the copy"
  exit 1
fi
if (cd "$tmp" && WALKS_ROOT="$tmp" sh scripts/walks.sh) |
  grep -q '^FAIL: a personal repo returns not workplace'; then
  echo "sabotage fails as expected: the walk catches the personal repo post"
  exit 0
fi
echo "sabotage passed: the walks do not guard the workplace rule"
exit 1
