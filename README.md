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

The answer is one line: `not workplace`, `already asked`, `not needed`, `already re-asked`, `re-asked`, `no team`, `no channel`, `posted yes`, or `posted no`, with the links of each post.

## Flow

1. The PR is read: repo, title, Jira key, parent story, author, base branch, the CODEOWNERS team of each changed file, and the head sha (`read_pr.rein`).
2. A personal repo answers `not workplace` and posts nothing (`check_workplace.rein`). A workplace is an owner with a Slack channel in a workspace the account can read.
3. The guards are checked (`check_guards.rein`):
   - A human approval after the last push answers `not needed`.
   - A head that already has a `🤖 Review requested in` comment answers `already asked`.
   - A head that changed, or an approval that was dismissed, after a request is re-asked in the Slack thread of the first request (`reply_and_record.rein`). The reply is `🤖 New head <sha>: <change>, ready for re-review`. Each head is re-asked once. The re-ask is recorded on the PR as `🤖 Re-asked at <sha> in <#channel> (<permalink>): <change>`.
4. The review team is the Jira Team Name of the ticket. When the ticket has none, it is the team of the author, from the `*-prs` channels the author posts in (`ask_team/find_team.rein`). No team answers `no team`.
5. The other team is asked only when its approval is required to merge (`ask_team/check_other_team.rein`). Three things must hold: a ruleset rule has `require_code_owner_review` true, a changed file is owned by that team in CODEOWNERS, and the review team does not own that file. Then the reason is named in the post.
6. The channel of the review team is found at run time (`ask_team/find_and_post/find_channel.rein`). It is named `team-<team>-prs` or `<team>-prs`. Its purpose is read, and its Slack user group is the `<!subteam^…>` mention of its past posts. No channel or group is written in the program. When the other team is required, its channel is found the same way. A missing channel answers `no channel` and posts nothing.
7. The PRs are batched by story (`ask_team/find_and_post/find_story.rein`). Each open PR of the same Jira story that waits for review gets one message, which lists its PRs. A PR with no story gets one message for itself.
8. Each post is recorded on each PR as a comment: `🤖 Review requested in <#channel> (<permalink>) at <sha>` (`ask_team/find_and_post/post_and_record/record_request.rein`).

## Outward action

The Slack post and the thread reply reach other people. The program posts only when a caller awaits it, and pr-handling is the caller. It posts at most once per head: the guards in step 3 read the comments that steps 3 and 8 write.

## Accepted risks

- The team, the other-team rule and the channel choice are agent answers. A wrong answer gets one wrong post. The post names the PR, so the owner can delete it.
- A post that succeeds, followed by a failed record comment, leaves no comment for the guard. The next run for the same head posts again. The answer says `a record comment failed`.
- A story batch counts a PR as waiting when it has no approval and no request for its head. A PR that another run asks at the same moment can appear in two batches.
- The guards, the team rules and the channel rules are prompt text. The walks check the text of each rule, not the answers.

## Develop

Run `git config core.hooksPath .githooks` once. Pushes then run `rein check .`, `scripts/walks.sh` and `shellcheck`. `scripts/walks.sh` walks the entry offline with fixed answers and checks each text. It also checks the line length, the function length and the absence of `==`. The sabotage scripts invert one guard in a copy and check that a walk fails:

- `scripts/sabotage-workplace.sh`: a personal repo is asked.
- `scripts/sabotage-guard.sh`: a head that was asked is asked again.
- `scripts/sabotage-no-channel.sh`: a PR with no owner channel is posted.
- `scripts/sabotage-other-team.sh`: the other team is asked when it is not required.

## License

MIT
