# pr-review-request

A [Rein](https://github.com/tupe12334/rein) program. It asks a human for a review of a pull request on Slack. In a workplace, it finds the channels that take review requests and the user groups of the reviewers at run time. It posts one line per PR in each channel, and records the request on the PR. When the head changes or an approval is dismissed, it replies in the same Slack thread.

## Install

```sh
rein install -g github:tupe12334/rein-pr-review-request#v0.2.0
```

## Use

A caller awaits the program with the link of the pull request. The `const` needs a doc comment above it:

```text
/** Ask a human for a review on Slack, if no request exists for this head. */
const asked: string = await @pr-review-request/main(pr=<pull request link>);
```

- `pr`: the link of the pull request.

The answer is one line: `not workplace`, `not needed`, `already asked`, `already re-asked`, `re-asked`, `no channel`, `posted yes` or `posted no`, with the links of each post.

## Flow

1. The PR is read: repo, title, Jira key, author, CODEOWNERS teams, requested reviewers and the head sha (`read_pr.rein`).
2. The workplace is checked (`check_workplace.rein`). The owner of the repo must name a channel in a Slack workspace that the account can read. A personal repo gets `not workplace`. Nothing is posted.
3. The guards are checked (`check_guards.rein`). A human approval after the last push gives `not needed`. A re-ask that already names this head gives `already re-asked`. A request at an earlier head, or a dismissed approval, sends the PR to step 4. A request that names this head gives `already asked`. Nothing is posted in these cases.
4. A re-ask replies in the thread of the last request (`reply_and_record.rein`). The reply is `🤖 New head <sha>: <what changed>, ready for re-review`. It is not a new top-level message. The re-ask is then recorded on the PR as `🤖 Re-asked at <sha> in <#channel> (<permalink>): <what changed>`.
5. A new request finds the channels and user groups at run time (`find_and_post/find_channels.rein`). The search reads the last 30 days of review requests and the channels named for review, PRs, the repo or the CODEOWNERS team. It reads each topic and purpose, and drops a channel that says review requests do not belong there. It chooses one channel, or two at most. It also finds the user groups (`@team` handles) of the CODEOWNERS teams and of the reviewers' team. When none is found, the answer is `no channel` and nothing is posted.
6. Each channel gets one line for the PR, in its usual phrasing (`find_and_post/post_and_record/post_request.rein`). Reviewers, a team handle or a user group are named only when that channel's past requests name them.
7. Each post is recorded as a comment on the PR: `🤖 Review requested in <#channel> (<permalink>) at <sha>` (`find_and_post/post_and_record/record_request.rein`).

## Outward action

The Slack posts and replies reach other people. The program posts only when a caller awaits it, and pr-handling is the caller. It acts at most once per head: the guards in step 3 read the comments that steps 4 and 7 write.

## Accepted risks

- The channel choice is an agent answer. A wrong channel gets one wrong post. The post names the PR, so the owner can delete it.
- The workplace test is an agent answer. It reads the channel names and topics. A wrong answer posts to a workplace, or skips one.
- The user groups come from Slack search results. A handle that the search does not show is not named.
- A reply or a post that succeeds, followed by a failed record comment, leaves no comment for the guard. The next run for the same head asks again. The answer says `a record comment failed`.
- The guards, the channel rules and the workplace rule are prompt text. The walks check the text of each rule, not the answers.

## Develop

Run `git config core.hooksPath .githooks` once. Pushes then run `rein check .`, `scripts/walks.sh` and `shellcheck`. `scripts/walks.sh` walks the entry offline with fixed answers and checks each text. It also checks the line length, the function length and the absence of `==`. `scripts/sabotage-guard.sh` inverts the already-asked guard in a copy and checks that a walk fails. `scripts/sabotage-no-channel.sh` posts when no channel is found, in a copy, and checks that a walk fails. `scripts/sabotage-workplace.sh` asks a personal repo, in a copy, and checks that a walk fails.

## License

MIT
