#!/bin/sh
# Walks the review-request steps offline, through the entry `main`, with rein
# step. Each walk must hold its text. A sabotage edits one guard and must make
# a walk fail, so the walk is known to test that guard.
# The patterns hold backticks and globs in single quotes on purpose.
# shellcheck disable=SC2016
root=${WALKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
pr=https://github.com/owner/repo/pull/9
fail=0
SHA=0123456789abcdef0123456789abcdef01234567
INFO='main.info={"repo":"owner/repo","title":"Fix the thing","jira":"none","author":"someone","teams":"@owner/core","reviewers":"none","sha":"0123456789abcdef0123456789abcdef01234567"}'
PLACE_YES='main.place={"workplace":true}'
PLACE_NO='main.place={"workplace":false}'
NOT_ASKED='main.guard={"already_asked":false,"asked_before":false,"reasked":false,"dismissed":false,"approved":false,"changed":"none","last_post":"none"}'
ASKED="main.guard={\"already_asked\":true,\"asked_before\":true,\"reasked\":false,\"dismissed\":false,\"approved\":false,\"changed\":\"none\",\"last_post\":\"🤖 Review requested in <#C123> (https://slack.example/p1) at $SHA\"}"
CHANGED='main.guard={"already_asked":false,"asked_before":true,"reasked":false,"dismissed":false,"approved":false,"changed":"2 commits: fix the retry","last_post":"🤖 Review requested in <#C123> (https://slack.example/p1) at 1111"}'
DISMISSED='main.guard={"already_asked":true,"asked_before":true,"reasked":false,"dismissed":true,"approved":false,"changed":"the earlier approval was dismissed","last_post":"🤖 Review requested in <#C123> (https://slack.example/p1) at 0123"}'
REASKED="main.guard={\"already_asked\":true,\"asked_before\":true,\"reasked\":true,\"dismissed\":true,\"approved\":false,\"changed\":\"the earlier approval was dismissed\",\"last_post\":\"🤖 Re-asked at $SHA in <#C123> (https://slack.example/p2): the earlier approval was dismissed\"}"
APPROVED='main.guard={"already_asked":false,"asked_before":true,"reasked":false,"dismissed":false,"approved":true,"changed":"none","last_post":"none"}'
FOUND_YES='find_and_post.found={"found":true,"channels":"review-room (C123)","groups":"@owner-core"}'
FOUND_NO='find_and_post.found={"found":false,"channels":"none","groups":"none"}'
POSTED_YES='find_and_post/post_and_record.posted={"posted":true,"links":"<#C123> (https://slack.example/p1)"}'
POSTED_NO='find_and_post/post_and_record.posted={"posted":false,"links":"none"}'
RECORDED='find_and_post/post_and_record.recorded={"recorded":true}'
REPLIED_YES='reply_and_record.replied={"replied":true,"link":"<#C123> (https://slack.example/p2)"}'
REPLIED_NO='reply_and_record.replied={"replied":false,"link":"none"}'
RE_RECORDED='reply_and_record.recorded={"recorded":true}'
FOUND_KEY='"key":"find_and_post.found"'
POSTED_KEY='"key":"find_and_post/post_and_record.posted"'
REPLY_KEY='"key":"reply_and_record.replied"'

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
expect "the workplace check runs after the read" '"key":"main.place"' \
  --answer "$INFO"
expect "the workplace check reads the owner's Slack channels" \
  'slack_search_channels for that owner name' --answer "$INFO"
expect "a personal repo returns not workplace" 'Return: not workplace' \
  --answer "$INFO" --answer "$PLACE_NO"
never "a personal repo never checks the guards" '"key":"main.guard"' \
  --answer "$INFO" --answer "$PLACE_NO"
expect "the guard runs after a workplace is found" '"key":"main.guard"' \
  --answer "$INFO" --answer "$PLACE_YES"
expect "an earlier request for this head returns already asked" \
  'already asked' --answer "$INFO" --answer "$PLACE_YES" --answer "$ASKED"
never "an earlier request for this head never searches Slack" \
  "$FOUND_KEY" --answer "$INFO" --answer "$PLACE_YES" --answer "$ASKED"
expect "a human approval after the push returns not needed" 'not needed' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$APPROVED"
never "a human approval never searches Slack" "$FOUND_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$APPROVED"
never "a human approval never re-asks in the thread" \
  'Reply once in the Slack thread' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$APPROVED"
expect "the guard checks the request for the head sha" \
  'names the head sha 0123' --answer "$INFO" --answer "$PLACE_YES"
expect "the guard counts only human approvals after the last push" \
  'submitted after the last commit' --answer "$INFO" --answer "$PLACE_YES"
expect "a head that changed since the request re-asks in the thread" \
  'Reply once in the Slack thread' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED"
expect "a dismissed approval re-asks in the thread" \
  'Reply once in the Slack thread' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$DISMISSED"
expect "the re-ask reply names the new head and the change in one line" \
  'ready for re-review' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED"
expect "the re-ask never posts a new top-level message" \
  'Post no new top-level message' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED"
expect "a re-ask at this head runs once per head" 'already re-asked' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$REASKED"
never "a re-ask at this head never replies again" "$REPLY_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$REASKED"
expect "a successful re-ask records it on the PR" 'Re-asked at 0123' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$CHANGED" \
  --answer "$REPLIED_YES"
expect "a successful re-ask returns re-asked" 'Return: re-asked' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$CHANGED" \
  --answer "$REPLIED_YES" --answer "$RE_RECORDED"
expect "a failed reply returns re-ask failed" 'Return: re-ask failed' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$CHANGED" \
  --answer "$REPLIED_NO"
never "a failed reply records nothing" 'Re-asked at 0123' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$CHANGED" \
  --answer "$REPLIED_NO"
expect "a PR with no request searches Slack for channels" "$FOUND_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED"
expect "the channel search runs at run time" \
  'not use any channel name from memory' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED"
expect "the channel search reads the last 30 days of messages" \
  'last 30 days' --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED"
expect "the channel search reads each topic and purpose" \
  'For each candidate, read its topic' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED"
expect "the channel search drops a channel that refuses review requests" \
  'requests do not belong there' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED"
expect "the channel search chooses one channel, or two at most" \
  'one channel, or two at most' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED"
expect "the channel search finds Slack user groups for the teams" \
  'Then find the Slack user groups for the teams' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED"
expect "the channel search never invents a user group handle" \
  'Never invent a handle' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED"
expect "no channel found returns no channel" 'Return: no channel' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$FOUND_NO"
never "no channel found posts nothing" "$POSTED_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$FOUND_NO"
expect "a found channel reaches the post" "$POSTED_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$FOUND_YES"
expect "the post matches the channel's usual phrasing" \
  'match the usual phrasing of' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$FOUND_YES"
expect "the post names reviewers only when past requests do" \
  'Mention the reviewers' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$FOUND_YES"
expect "the post names a user group only when past requests do" \
  'Mention the user group' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$FOUND_YES"
expect "a successful post records the request on the PR" \
  'Review requested in <#channel> (<permalink>) at 0123' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$FOUND_YES" --answer "$POSTED_YES"
expect "a successful post returns posted yes and the links" \
  'Return: posted yes' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$FOUND_YES" --answer "$POSTED_YES" \
  --answer "$RECORDED"
expect "a failed post returns posted no" 'Return: posted no' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$FOUND_YES" --answer "$POSTED_NO"
never "a failed post never records a request" 'Review requested in' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$FOUND_YES" --answer "$POSTED_NO"

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
