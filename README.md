# pr-review-request

A [Rein](https://github.com/tupe12334/rein) program. It asks a human for a review of a pull request on Slack. It finds the channels that take review requests at run time, posts one line per PR in each channel, and records the request on the PR.

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

The answer is one line: `already asked`, `not needed`, `no channel`, or `posted yes` or `posted no`, with the links of each post.

## Flow

1. The PR is read: repo, title, Jira key, author, CODEOWNERS teams, requested reviewers and the head sha (`read_pr.rein`).
2. Two guards are checked (`check_guards.rein`). When this head already has a `🤖 Review requested in` comment, the answer is `already asked`. When a human approved the PR after the last push, the answer is `not needed`. Nothing is posted in either case.
3. The channels are found at run time (`find_channels.rein`). The search reads the last 30 days of review requests and the channels named for review, PRs, the repo or the CODEOWNERS team. It reads each topic and purpose, and drops a channel that says review requests do not belong there. It chooses one channel, or two at most. When none is found, the answer is `no channel` and nothing is posted.
4. Each channel gets one line for the PR, in its usual phrasing (`post_and_record/post_request.rein`). Reviewers or a team handle are named only when that channel's past requests name them.
5. Each post is recorded as a comment on the PR: `🤖 Review requested in <#channel> (<permalink>) at <sha>` (`post_and_record/record_request.rein`).

## Outward action

The Slack post reaches other people. The program posts only when a caller awaits it, and pr-handling is the caller. It posts at most once per head: the guard in step 2 reads the comment that step 5 writes.

## Accepted risks

- The channel choice is an agent answer. A wrong channel gets one wrong post. The post names the PR, so the owner can delete it.
- A post that succeeds, followed by a failed record comment, leaves no comment for the guard. The next run for the same head posts again. The answer says `a record comment failed`.
- The guards and the channel rules are prompt text. The walks check the text of each rule, not the answers.

## Develop

Run `git config core.hooksPath .githooks` once. Pushes then run `rein check .`, `scripts/walks.sh` and `shellcheck`. `scripts/walks.sh` walks the entry offline with fixed answers and checks each text. It also checks the line length, the function length and the absence of `==`. `scripts/sabotage-guard.sh` inverts the already-asked guard in a copy and checks that a walk fails. `scripts/sabotage-no-channel.sh` posts when no channel is found, in a copy, and checks that a walk fails.

## License

MIT
