#!/bin/sh
# Walks the review-request steps offline, through the entry `main`, with rein
# step. Each walk must hold its text. A sabotage edits one guard and must make
# a walk fail, so the walk is known to test that guard.
# The patterns hold backticks and globs in single quotes on purpose.
# shellcheck disable=SC2016
root=${WALKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
pr=https://github.com/owner/repo/pull/9
fail=0
INFO='main.info={"repo":"owner/repo","title":"Fix the thing","jira":"none","author":"someone","teams":"@owner/core","reviewers":"none","sha":"0123456789abcdef0123456789abcdef01234567"}'
NOT_ASKED='main.guard={"already_asked":false,"approved":false}'
ASKED='main.guard={"already_asked":true,"approved":false}'
APPROVED='main.guard={"already_asked":false,"approved":true}'
FOUND_YES='main.found={"found":true,"channels":"review-room (C123)"}'
FOUND_NO='main.found={"found":false,"channels":"none"}'
POSTED_YES='post_and_record.posted={"posted":true,"links":"<#C123> (https://slack.example/p1)"}'
POSTED_NO='post_and_record.posted={"posted":false,"links":"none"}'
RECORDED='post_and_record.recorded={"recorded":true}'

# joined: one output line per step, so a walk greps a single line.
joined() { tr '\n' ' '; }

# $1 name, $2 fixed text the output must hold, $3... rein answers.
expect() {
  name=$1 want=$2
  shift 2
  status=0
  out=$(rein step --root "$root" --entry main --json --input pr="$pr" \
    "$@" 2>&1) || status=$?
  if [ "$status" -ne 0 ] && [ "$status" -ne 3 ]; then
    echo "FAIL: $name (rein exit $status)"
    echo "$out"
    fail=1
  elif printf '%s\n' "$out" | joined | grep -Fq -- "$want"; then
    echo "ok: $name"
  else
    echo "FAIL: $name"
    echo "$out"
    fail=1
  fi
}

# $1 name, $2 fixed text that must not appear, $3... rein answers.
never() {
  name=$1 bad=$2
  shift 2
  status=0
  out=$(rein step --root "$root" --entry main --json --input pr="$pr" \
    "$@" 2>&1) || status=$?
  if [ "$status" -ne 0 ] && [ "$status" -ne 3 ]; then
    echo "FAIL: $name (rein exit $status)"
    echo "$out"
    fail=1
  elif printf '%s\n' "$out" | joined | grep -Fq -- "$bad"; then
    echo "FAIL: $name"
    echo "$out"
    fail=1
  else
    echo "ok: $name"
  fi
}

expect "the PR is read first" '"key":"main.info"'
expect "the read asks for the Jira key, the author, teams and head sha" \
  'Answer jira: the Jira key'
expect "the guard runs after the read" '"key":"main.guard"' --answer "$INFO"
expect "an earlier request for this head returns already asked" \
  'already asked' --answer "$INFO" --answer "$ASKED"
never "an earlier request for this head never searches Slack" \
  '"key":"main.found"' --answer "$INFO" --answer "$ASKED"
expect "a human approval after the push returns not needed" 'not needed' \
  --answer "$INFO" --answer "$APPROVED"
never "a human approval never searches Slack" '"key":"main.found"' \
  --answer "$INFO" --answer "$APPROVED"
expect "the guard checks the request for the head sha" \
  'names the head sha 0123' --answer "$INFO"
expect "the guard counts only human approvals after the last push" \
  'submitted after the last commit' --answer "$INFO"
expect "the channel search runs at run time" \
  'not use any channel name from memory' --answer "$INFO" \
  --answer "$NOT_ASKED"
expect "the channel search reads the last 30 days of messages" \
  'last 30 days' --answer "$INFO" --answer "$NOT_ASKED"
expect "the channel search reads each topic and purpose" \
  'For each candidate, read its topic' --answer "$INFO" \
  --answer "$NOT_ASKED"
expect "the channel search drops a channel that refuses review requests" \
  'requests do not belong there' --answer "$INFO" --answer "$NOT_ASKED"
expect "the channel search chooses one channel, or two at most" \
  'one channel, or two at most' --answer "$INFO" --answer "$NOT_ASKED"
expect "no channel found returns no channel" 'Return: no channel' \
  --answer "$INFO" --answer "$NOT_ASKED" --answer "$FOUND_NO"
never "no channel found posts nothing" '"key":"post_and_record.posted"' \
  --answer "$INFO" --answer "$NOT_ASKED" --answer "$FOUND_NO"
expect "a found channel reaches the post" '"key":"post_and_record.posted"' \
  --answer "$INFO" --answer "$NOT_ASKED" --answer "$FOUND_YES"
expect "the post matches the channel's usual phrasing" \
  'match the usual phrasing of' --answer "$INFO" --answer "$NOT_ASKED" \
  --answer "$FOUND_YES"
expect "the post names reviewers only when past requests do" \
  'Mention the reviewers' --answer "$INFO" --answer "$NOT_ASKED" \
  --answer "$FOUND_YES"
expect "a successful post records the request on the PR" \
  'Review requested in <#channel> (<permalink>) at 0123' \
  --answer "$INFO" --answer "$NOT_ASKED" --answer "$FOUND_YES" \
  --answer "$POSTED_YES"
expect "a successful post returns posted yes and the links" \
  'Return: posted yes' --answer "$INFO" --answer "$NOT_ASKED" \
  --answer "$FOUND_YES" --answer "$POSTED_YES" --answer "$RECORDED"
expect "a failed post returns posted no" 'Return: posted no' \
  --answer "$INFO" --answer "$NOT_ASKED" --answer "$FOUND_YES" \
  --answer "$POSTED_NO"
never "a failed post never records a request" 'Review requested in' \
  --answer "$INFO" --answer "$NOT_ASKED" --answer "$FOUND_YES" \
  --answer "$POSTED_NO"

# style: lines of 80 columns or fewer, functions of 40 lines or fewer, no ==
# shellcheck disable=SC2016 # the awk programs read $0, not the shell
long=$(find "$root" -name '*.rein' -type f -exec env LC_ALL=en_US.UTF-8 awk \
  'length($0) > 80 { print FILENAME": "FNR }' {} +)
too_long=$(find "$root" -name '*.rein' -type f -exec awk \
  '/^export default/ { start = FNR; in_fn = 1 }
  in_fn && /^}/ { if (FNR - start + 1 > 40) print FILENAME": "start; in_fn = 0 }' \
  {} +)
eqs=$(find "$root" -name '*.rein' -type f -exec grep -n '==' {} +)
if [ -z "$long$too_long$eqs" ]; then
  echo "ok: style: lines, function length and no =="
else
  echo "FAIL: style: $long $too_long $eqs"
  fail=1
fi
exit $fail
