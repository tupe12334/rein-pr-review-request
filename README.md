# pr-review-request

A [Rein](https://github.com/tupe12334/rein) program. It asks a human for a review of a pull request on Slack, in a workplace only. It posts to the review channel of the owner's team, names that team's Slack user group, and records each request on the PR.

## Install

```sh
rein install -g github:tupe12334/rein-pr-review-request#v0.1.0
```

## Use

A caller awaits the program with the link of the pull request. The `const` needs a doc comment above it:

```text
/** Ask a human for a review on Slack, if no request exists for this head. */
const asked: string = await @pr-review-request/main(pr=<pull request link>);
```

- `pr`: the link of the pull request.

The answer is one line: `not workplace`, `already asked`, `not needed`, `already re-asked`, `re-asked`, `re-ask failed`, `no team`, `no channel`, `posted yes`, or `posted no`, with the links of each post.

## Flow

1. The PR is read: repo, title, Jira key, parent story, author, base branch, whether its `reviewDecision` is APPROVED, the CODEOWNERS team of each changed file, read from the base branch, and the head sha (`read_pr.rein`).
2. A repo whose owner field is not exactly `guiddeco` answers `not workplace` and posts nothing (`check_workplace.rein`). A repo named `guidde-tools` under another owner is not a workplace.
3. An APPROVED `reviewDecision` answers `not needed`. GitHub folds the required code-owner approvals into that value, so no other team is asked then.
4. The guards are checked (`check_guards.rein`):
   - A head that already has a `🤖 Review requested in` comment, and that names a team with `for <team>`, is asked for its next required team (step 8). When no team is left, the answer is `already asked`.
   - A head that changed, or an approval that was dismissed, after a request is re-asked in the Slack thread of the first request (`reask_team.rein`, `reask_team/reply_and_record.rein`). The reply is `🤖 New head <sha>: <change>, ready for re-review`. Each head is re-asked once. A re-ask first checks the next required team of the new head. When that team has no channel, the re-ask is not recorded and the PR gets a `🤖 No channel for <team>` comment. When its post fails, nothing is recorded and no reply is sent, so the next run retries.
5. The review team is the Jira Team Name of the ticket. When the ticket has none, it is the team of the author, from the `*-prs` channels the author posts in (`ask_team/find_team.rein`). No team answers `no team`.
6. A first request posts only the review team's channel, found at run time (`ask_team/find_and_post/find_channel.rein`). It is named `team-<team>-prs` or `<team>-prs`. Its purpose is read, and its Slack user group is the `<!subteam^…>` mention of its past posts. No channel or group is written in the program. A missing channel answers `no channel` and posts nothing.
7. The PRs are batched by story (`ask_team/find_and_post/find_story.rein`). Each open PR of the same Jira story gets one message, which lists its PRs, when it has the same review team, no request at any head, and no other team required. A PR with no story gets one message for itself.
8. A later run asks the next required team, one team per run (`ask_other.rein`). The other team is required only when a ruleset rule has `require_code_owner_review` true, a changed file is owned by that team in CODEOWNERS, and the review team does not own that file (`ask_team/check_other_team.rein`). The first required team with no request at this head is asked. Its post names the reason. A missing channel is named on the PR with `🤖 No channel for <team>` and is not recorded as asked. A post that fails records nothing.
9. Each post is recorded on each PR as a comment, keyed by the team and the head: `🤖 Review requested in <#channel> (<permalink>) at <sha> for <team>` (`ask_team/find_and_post/post_and_record/record_request.rein`).

## Outward action

The Slack post and the thread reply reach other people. The program posts only when a caller awaits it, and pr-handling is the caller. It posts at most once per head and team: the guards in step 4 read the comments that the posts write.

## Accepted risks

- The team, the other-team rule and the channel choice are agent answers. Only one team is asked per run, so a second required team waits for the next run. A wrong answer gets one wrong post. The post names the PR, so the owner can delete it.
- A post that succeeds, followed by a failed record comment, leaves no comment for the guard. The next run for the same head posts again. The answer says `a record comment failed`.
- A story batch counts a PR as waiting when it has no approval and no request for its head. A PR that another run asks at the same moment can appear in two batches.
- The guards, the team rules and the channel rules are prompt text. The walks check the text of each rule, not the answers.

## Known limits

v0.2.0 asks one required other team per head, so a head that needs two other teams asks only the first (tupe12334/rein-pr-review-request#2). Four open warnings are tracked in tupe12334/rein-pr-review-request#3.

## Develop

Run `git config core.hooksPath .githooks` once. Pushes then run `rein check .`, `scripts/walks.sh` and `shellcheck`. `scripts/walks.sh` walks the entry offline with fixed answers and checks each text. It also checks the line length, the function length and the absence of `==`. The sabotage scripts invert one guard in a copy and check that a walk fails:

- `scripts/sabotage-workplace.sh`: a personal repo is asked.
- `scripts/sabotage-guard.sh`: a head that was asked is asked again.
- `scripts/sabotage-no-channel.sh`: a PR with no owner channel is posted.
- `scripts/sabotage-other-team.sh`: the other team is asked when it is not required.

## License

MIT
