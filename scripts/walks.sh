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
INFO='main.info={"repo":"owner/repo","title":"Fix the thing","jira":"ABC-1","story":"ABC-9","author":"someone","base":"main","owners":"src/a.ts: @owner/platform; src/b.ts: @owner/create-team","sha":"0123456789abcdef0123456789abcdef01234567"}'
PLACE_YES='main.place={"workplace":true}'
PLACE_NO='main.place={"workplace":false}'
NOT_ASKED='main.guard={"already_asked":false,"asked_before":false,"reasked":false,"dismissed":false,"approved":false,"changed":"none","thread":"none","last_post":"none"}'
ASKED="main.guard={\"already_asked\":true,\"asked_before\":true,\"reasked\":false,\"dismissed\":false,\"approved\":false,\"changed\":\"none\",\"thread\":\"none\",\"last_post\":\"🤖 Review requested in <#C123> (https://slack.example/p1) at $SHA\"}"
CHANGED='main.guard={"already_asked":false,"asked_before":true,"reasked":false,"dismissed":false,"approved":false,"changed":"2 commits: fix the retry","thread":"🤖 Review requested in <#C123> (https://slack.example/p1) at 0123","last_post":"🤖 Review requested in <#C123> (https://slack.example/p1) at 1111"}'
DISMISSED='main.guard={"already_asked":true,"asked_before":true,"reasked":false,"dismissed":true,"approved":false,"changed":"the earlier approval was dismissed","thread":"🤖 Review requested in <#C123> (https://slack.example/p1) at 0123","last_post":"🤖 Review requested in <#C123> (https://slack.example/p1) at 0123"}'
REASKED="main.guard={\"already_asked\":true,\"asked_before\":true,\"reasked\":true,\"dismissed\":true,\"approved\":false,\"changed\":\"the earlier approval was dismissed\",\"thread\":\"none\",\"last_post\":\"🤖 Re-asked at $SHA in <#C123> (https://slack.example/p2): the earlier approval was dismissed\"}"
APPROVED='main.guard={"already_asked":false,"asked_before":true,"reasked":false,"dismissed":false,"approved":true,"changed":"none","thread":"none","last_post":"none"}'
TEAM_YES='ask_team.team={"found":true,"team":"platform"}'
TEAM_NO='ask_team.team={"found":false,"team":"none"}'
OTHER_NO='ask_team.other={"required":false,"other":"none","reason":"none"}'
OTHER_YES='ask_team.other={"required":true,"other":"create-team","reason":"code-owner review by @owner/create-team is required for src/b.ts"}'
BATCH='ask_team/find_and_post.batch={"prs":"https://github.com/owner/repo/pull/9 0123;https://github.com/owner/repo/pull/10 aaaa","label":"ABC-9 Story"}'
OWN_YES='ask_team/find_and_post.own={"found":true,"channel":"team-platform-prs (C123)","group":"<!subteam^S1>"}'
OWN_NO='ask_team/find_and_post.own={"found":false,"channel":"none","group":"none"}'
EXTRA_YES='ask_team/find_and_post.extra={"found":true,"channel":"team-create-team-prs (C456)","group":"<!subteam^S2>"}'
EXTRA_NO='ask_team/find_and_post.extra={"found":false,"channel":"none","group":"none"}'
POSTED_YES='ask_team/find_and_post/post_and_record.posted={"posted":true,"links":"<#C123> (https://slack.example/p1)"}'
POSTED_NO='ask_team/find_and_post/post_and_record.posted={"posted":false,"links":"none"}'
RECORDED='ask_team/find_and_post/post_and_record.recorded={"recorded":true}'
REPLIED_YES='reask_team/reply_and_record.replied={"replied":true,"link":"<#C123> (https://slack.example/p2)"}'
REPLIED_NO='reask_team/reply_and_record.replied={"replied":false,"link":"none"}'
RT_TEAM='reask_team.team={"found":true,"team":"platform"}'
RT_OTHER_NO='reask_team.other={"required":false,"other":"none","reason":"none"}'
RT_OTHER_YES='reask_team.other={"required":true,"other":"create-team","reason":"code-owner review by create-team is required for src/b.ts"}'
RT_EXTRA_YES='reask_team.extra={"found":true,"channel":"team-create-team-prs (C456)","group":"<!subteam^S2>"}'
RT_POSTED_YES='reask_team.posted={"posted":true,"links":"<#C456> (https://slack.example/p3)"}'
RT_OTHER_KEY='"key":"reask_team.other"'
RT_EXTRA_KEY='"key":"reask_team.extra"'
RE_RECORDED='reask_team/reply_and_record.recorded={"recorded":true}'
TEAM_KEY='"key":"ask_team.team"'
OWN_KEY='"key":"ask_team/find_and_post.own"'
EXTRA_KEY='"key":"ask_team/find_and_post.extra"'
POSTED_KEY='"key":"ask_team/find_and_post/post_and_record.posted"'
REPLY_KEY='"key":"reask_team/reply_and_record.replied"'

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
expect "the read asks for the Jira key, the story, owners and head sha" \
  'Answer story: the Jira key of'
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
never "an earlier request for this head never finds a team" "$TEAM_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$ASKED"
expect "a human approval after the push returns not needed" 'not needed' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$APPROVED"
never "a human approval never finds a team" "$TEAM_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$APPROVED"
never "a human approval never re-asks in the thread" \
  'Reply once in the Slack thread' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$APPROVED"
expect "the guard checks the request for the head sha" \
  'names the head sha 0123' --answer "$INFO" --answer "$PLACE_YES"
expect "the guard counts only human approvals after the last push" \
  'was submitted' --answer "$INFO" --answer "$PLACE_YES"
expect "a head that changed since the request re-asks in the thread" \
  'Reply once in the Slack thread' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO"
expect "a dismissed approval re-asks in the thread" \
  'Reply once in the Slack thread' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$DISMISSED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO"
expect "the re-ask reply names the new head and the change in one line" \
  'ready for re-review' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO"
expect "the re-ask never posts a new top-level message" \
  'Post no new top-level message' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO"
expect "a re-ask at this head runs once per head" 'already re-asked' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$REASKED"
never "a re-ask at this head never replies again" "$REPLY_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$REASKED"
expect "the guard reads a dismissal only after the last request" \
  'was submitted after the last comment that last_post' --answer "$INFO" \
  --answer "$PLACE_YES"
expect "the re-ask reply names the first request thread text" \
  'of each first request' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO"
expect "a successful re-ask records it on the PR" 'Re-asked at 0123' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO" \
  --answer "$REPLIED_YES"
expect "a successful re-ask returns re-asked" 'Return: re-asked' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO" \
  --answer "$REPLIED_YES" --answer "$RE_RECORDED"
expect "a failed reply returns re-ask failed" 'Return: re-ask failed' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO" \
  --answer "$REPLIED_NO"
never "a failed reply records nothing" 'Re-asked at 0123' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO" \
  --answer "$REPLIED_NO"
expect "a new request finds the review team" "$TEAM_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED"
expect "the team comes from the Jira Team Name first" \
  'its Team Name field' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED"
expect "without a Jira team, the team comes from the author's channels" \
  'the Slack channels named' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED"
expect "no team found returns no team" 'Return: no team' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_NO"
expect "a found team checks whether another team must approve" \
  '"key":"ask_team.other"' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$TEAM_YES"
expect "the other-team check needs a code-owner rule" \
  'require_code_owner_review true' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$TEAM_YES"
expect "the other-team check counts a file only when the team does not own it" \
  'does not own it, so the approval of platform' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES"
expect "the review team channel is searched at run time" \
  'Do not use any channel name from memory' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES" \
  --answer "$OTHER_NO"
expect "the channel names follow the team-platform-prs pattern" \
  'team-platform-prs or platform-prs' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$TEAM_YES" --answer "$OTHER_NO"
expect "the channel's group comes from a past post mention" \
  'the <!subteam^ID> mention' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$TEAM_YES" --answer "$OTHER_NO"
expect "the group is never invented" 'Never invent a group' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES" \
  --answer "$OTHER_NO"
expect "a required other team is asked only after the owner's channel" \
  "$EXTRA_KEY" --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_YES" --answer "$OWN_YES" \
  --answer "$BATCH"
never "an other team not required is never asked" "$EXTRA_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO" --answer "$OWN_YES" \
  --answer "$BATCH"
expect "no owner channel returns no channel" 'Return: no channel' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO" --answer "$OWN_NO"
never "no owner channel posts nothing" "$POSTED_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO" --answer "$OWN_NO" \
  --answer "$BATCH"
expect "the owner's channel is found before any post" "$OWN_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO"
expect "a found owner channel looks for the PRs of its story" \
  'List the pull requests to ask in one message' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES" \
  --answer "$OTHER_NO" --answer "$OWN_YES"
expect "a found owner channel reaches the post" "$POSTED_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO" --answer "$OWN_YES" \
  --answer "$BATCH"
expect "a story posts one message that lists its PRs" 'needs reviews:' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO" --answer "$OWN_YES" \
  --answer "$BATCH"
expect "the post mentions the team's user group" \
  'mention the user group of that channel' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES" \
  --answer "$OTHER_NO" --answer "$OWN_YES" --answer "$BATCH"
expect "a required other team names the reason in the post" \
  'code-owner review by @owner/create-team is required' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES" \
  --answer "$OTHER_YES" --answer "$OWN_YES" --answer "$BATCH" \
  --answer "$EXTRA_YES"
expect "a required other team is searched by its bare name" \
  'team-create-team-prs or create-team-prs' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES" \
  --answer "$OTHER_YES" --answer "$OWN_YES" --answer "$BATCH"
expect "the other team is named without its org" 'without the org' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES"
expect "a story keeps only siblings with no request at any head" \
  'at any head, and' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$TEAM_YES" --answer "$OTHER_NO" \
  --answer "$OWN_YES"
expect "a story keeps only siblings of the same review team" \
  'Jira Team Name is the same team as platform' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES" \
  --answer "$OTHER_NO" --answer "$OWN_YES"
expect "a required other team with no channel posts nothing" \
  'Return: no channel for create-team' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$NOT_ASKED" --answer "$TEAM_YES" \
  --answer "$OTHER_YES" --answer "$OWN_YES" --answer "$BATCH" \
  --answer "$EXTRA_NO"
never "a required other team with no channel never posts" "$POSTED_KEY" \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_YES" --answer "$OWN_YES" \
  --answer "$BATCH" --answer "$EXTRA_NO"
expect "a successful post records the request on each PR" \
  'Review requested in <#channel> (<permalink>) at <sha>' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO" --answer "$OWN_YES" \
  --answer "$BATCH" --answer "$POSTED_YES"
expect "a successful post returns posted yes and the links" \
  'Return: posted yes' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$NOT_ASKED" --answer "$TEAM_YES" --answer "$OTHER_NO" \
  --answer "$OWN_YES" --answer "$BATCH" --answer "$POSTED_YES" \
  --answer "$RECORDED"
expect "a failed post returns posted no" 'Return: posted no' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO" --answer "$OWN_YES" \
  --answer "$BATCH" --answer "$POSTED_NO"
never "a failed post never records a request" 'Review requested in <#channel>' \
  --answer "$INFO" --answer "$PLACE_YES" --answer "$NOT_ASKED" \
  --answer "$TEAM_YES" --answer "$OTHER_NO" --answer "$OWN_YES" \
  --answer "$BATCH" --answer "$POSTED_NO"

expect "a re-ask checks whether the new head needs another team" \
  "$RT_OTHER_KEY" --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED" --answer "$RT_TEAM"
expect "a re-ask asks a required other team in its own channel" \
  'team-create-team-prs or create-team-prs' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$CHANGED" --answer "$RT_TEAM" \
  --answer "$RT_OTHER_YES"
expect "a re-ask names the reason in the other team's post" \
  'code-owner review by create-team is required' --answer "$INFO" \
  --answer "$PLACE_YES" --answer "$CHANGED" --answer "$RT_TEAM" \
  --answer "$RT_OTHER_YES" --answer "$RT_EXTRA_YES"
never "a re-ask with no other team required never posts to one" \
  "$RT_EXTRA_KEY" --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_NO"
expect "a re-ask still replies in the thread after the other team is asked" \
  'ready for re-review' --answer "$INFO" --answer "$PLACE_YES" \
  --answer "$CHANGED" --answer "$RT_TEAM" --answer "$RT_OTHER_YES" \
  --answer "$RT_EXTRA_YES" --answer "$RT_POSTED_YES"

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
