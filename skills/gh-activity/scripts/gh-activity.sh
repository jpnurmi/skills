#!/usr/bin/env bash

function _date() { if command -v gdate &>/dev/null; then gdate "$@"; else date "$@"; fi; }

function _gh-activity-week-range() {
  local iso_week=$1 year week jan4 weekday monday sunday normalized

  if [[ ! "$iso_week" =~ ^([0-9]{4})-W([0-9]{2})$ ]]; then
    echo "gh-activity: invalid ISO week: $iso_week" >&2
    return 2
  fi

  year=${BASH_REMATCH[1]}
  week=${BASH_REMATCH[2]}
  if ((10#$week < 1 || 10#$week > 53)); then
    echo "gh-activity: invalid ISO week: $iso_week" >&2
    return 2
  fi

  jan4=$(_date -d "$year-01-04" --utc +%Y-%m-%d) || return
  weekday=$(_date -d "$jan4" --utc +%u) || return
  monday=$(_date -d "$jan4 - $((10#$weekday - 1)) days + $((10#$week - 1)) weeks" --utc +%Y-%m-%d) || return
  normalized=$(_date -d "$monday" --utc +%G-W%V) || return
  if [[ "$normalized" != "$iso_week" ]]; then
    echo "gh-activity: invalid ISO week: $iso_week" >&2
    return 2
  fi

  sunday=$(_date -d "$monday + 6 days" --utc +%Y-%m-%d) || return
  printf '%s %s\n' "$monday" "$sunday"
}

function _gh-activity-month-range() {
  local relative=$1 first last

  first=$(_date --utc +%Y-%m-01) || return
  if [[ "$relative" == last ]]; then
    first=$(_date -d "$first - 1 month" --utc +%Y-%m-%d) || return
  fi
  last=$(_date -d "$first + 1 month - 1 day" --utc +%Y-%m-%d) || return
  printf '%s %s\n' "$first" "$last"
}

function _gh-activity-prs() {
  local user=$1 from=$2 to=$3 query created activity from_date=${2%%T*} to_date=${3%%T*}

  query='query($q: String!, $endCursor: String) {
      search(query: $q, type: ISSUE, first: 100, after: $endCursor) {
        nodes {
          ... on PullRequest {
            title
            number
            url
            createdAt
            closedAt
            mergedAt
            state
            isDraft
            headRefName
            headRepository { nameWithOwner }
            timelineItems(last: 100, itemTypes: [HEAD_REF_FORCE_PUSHED_EVENT]) {
              nodes {
                ... on HeadRefForcePushedEvent {
                  createdAt
                  actor { login }
                  afterCommit { oid }
                }
              }
            }
            repository { nameWithOwner }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }'

  created=$(gh api graphql --paginate --slurp \
    -f query="$query" \
    -f q="is:pr author:$user created:$from_date..$to_date sort:created-desc") || return
  activity=$(gh api graphql --paginate --slurp \
    -f query="$query" \
    -f q="is:pr author:$user created:<=$to_date updated:>=$from_date sort:updated-desc") || return

  jq -s --arg user "$user" --arg from "$from" --arg to "$to" -c '
    .[0] as $created
    | .[1] as $activity
    | [$created[].data.search.nodes[], $activity[].data.search.nodes[]]
    | unique_by(.url)
    | . as $prs
    | {
      actions: [
        $prs[] as $pr
        | (
            if $pr.createdAt >= $from and $pr.createdAt <= $to then
              {label: (if $pr.isDraft then "OPENED DRAFT" else "OPENED" end), occurredAt: $pr.createdAt}
            else empty end,
            if $pr.mergedAt >= $from and $pr.mergedAt <= $to then
              {label: "MERGED", occurredAt: $pr.mergedAt}
            elif $pr.closedAt >= $from and $pr.closedAt <= $to then
              {label: "CLOSED", occurredAt: $pr.closedAt}
            else empty end,
            ($pr.timelineItems.nodes[]
              | select(.actor.login == $user)
              | {label: "UPDATED", occurredAt: .createdAt, sha: .afterCommit.oid})
          ) as $action
        | select($action.occurredAt >= $from and $action.occurredAt <= $to)
        | {
          repo: $pr.repository.nameWithOwner,
          key: "PR:\($pr.repository.nameWithOwner)#\($pr.number)",
          kind: "PR",
          label: $action.label,
          occurredAt: $action.occurredAt,
          title: $pr.title,
          number: $pr.number,
          artifactUrl: $pr.url,
          sha: $action.sha
        }
      ],
      heads: [
        $prs[]
        | select(.headRepository.nameWithOwner != null and .headRefName != null)
        | {
            repo: .repository.nameWithOwner,
            key: "PR:\(.repository.nameWithOwner)#\(.number)",
            headRepo: .headRepository.nameWithOwner,
            ref: .headRefName,
            createdAt,
            closedAt,
            number,
            title,
            artifactUrl: .url
          }
      ]
    }
  ' <<< "$created
$activity"
}

function _gh-activity-contributions() {
  local user=$1 from=$2 to=$3 response since until

  since=$(_date -d "$from - 1 day" --utc +%Y-%m-%d) || return
  until=${to%%T*}

  response=$(gh api graphql \
    -f query='query($from: DateTime!, $to: DateTime!) {
      viewer {
        contributionsCollection(from: $from, to: $to) {
          commitContributionsByRepository(maxRepositories: 100) {
            repository { nameWithOwner url }
            contributions(first: 100) { nodes { commitCount occurredAt } }
          }
          issueContributions(first: 100) {
            nodes {
              occurredAt
              issue { title number url repository { nameWithOwner } }
            }
          }
          pullRequestReviewContributions(first: 100) {
            nodes {
              occurredAt
              pullRequest { title number url repository { nameWithOwner } }
            }
          }
          repositoryContributions(first: 100) {
            nodes { occurredAt repository { nameWithOwner url } }
          }
        }
      }
    }' \
    -F from="$from" \
    -F to="$to") || return

  jq --arg user "$user" --arg since "$since" --arg until "$until" -c '
    .data.viewer.contributionsCollection as $activity
    | [
        $activity.commitContributionsByRepository[]
        | ([.contributions.nodes[].commitCount] | add // 0) as $count
        | select($count > 0)
        | {
            repo: .repository.nameWithOwner,
            key: "commits",
            label: "COMMITS",
            amount: $count,
            occurredAt: ([.contributions.nodes[].occurredAt] | max),
            url: "\(.repository.url)/commits?author=\($user)&since=\($since)&until=\($until)"
          }
      ]
      + [
          $activity.issueContributions.nodes[]
          | {
              repo: .issue.repository.nameWithOwner,
              key: "ISSUE:\(.issue.repository.nameWithOwner)#\(.issue.number)",
              kind: "ISSUE",
              label: "OPENED",
              occurredAt,
              title: .issue.title,
              number: .issue.number,
              artifactUrl: .issue.url
            }
        ]
      + [
          $activity.pullRequestReviewContributions.nodes[]
          | {
              repo: .pullRequest.repository.nameWithOwner,
              key: "PR:\(.pullRequest.repository.nameWithOwner)#\(.pullRequest.number)",
              kind: "PR",
              label: "REVIEWED",
              occurredAt,
              title: .pullRequest.title,
              number: .pullRequest.number,
              artifactUrl: .pullRequest.url
            }
        ]
      + [
          $activity.repositoryContributions.nodes[]
          | {
              repo: .repository.nameWithOwner,
              key: "repository-created:\(.repository.url)",
              label: "CREATED REPOSITORY",
              occurredAt,
              url: .repository.url
            }
        ]
  ' <<< "$response"
}

function _gh-activity-events() {
  local user=$1 from=$2 to=$3 heads=$4 prs=$5 response

  response=$(gh api --paginate --slurp "users/$user/events?per_page=100") || return

  jq -s --arg from "$from" --arg to "$to" -c '
    .[0] as $response
    | .[1] as $heads
    | .[2] as $prs
    | [$response[][]
      | select(.created_at >= $from and .created_at <= $to)
      | if .type == "IssueCommentEvent" then
          .payload.issue as $issue
          | {
              repo: .repo.name,
              key: "\(if $issue.pull_request then "PR" else "ISSUE" end):\(.repo.name)#\($issue.number)",
              kind: (if $issue.pull_request then "PR" else "ISSUE" end),
              label: "COMMENTED",
              occurredAt: .created_at,
              isComment: true,
              title: $issue.title,
              number: $issue.number,
              artifactUrl: $issue.html_url,
              actionUrl: .payload.comment.html_url
            }
        elif .type == "PullRequestReviewCommentEvent" then
          .payload.pull_request as $pr
          | {
              repo: .repo.name,
              key: "PR:\(.repo.name)#\($pr.number)",
              kind: "PR",
              label: "COMMENTED",
              occurredAt: .created_at,
              isComment: true,
              title: $pr.title,
              number: $pr.number,
              artifactUrl: $pr.html_url,
              actionUrl: .payload.comment.html_url
            }
        elif .type == "IssuesEvent" and .payload.action != "opened" then
          .payload.issue as $issue
          | {
              repo: .repo.name,
              key: "ISSUE:\(.repo.name)#\($issue.number)",
              kind: "ISSUE",
              label: (.payload.action | ascii_upcase),
              occurredAt: .created_at,
              title: $issue.title,
              number: $issue.number,
              artifactUrl: $issue.html_url
            }
        elif .type == "PushEvent" and (.payload.ref | startswith("refs/heads/")) then
          . as $event
          | (.payload.ref | sub("^refs/heads/"; "")) as $ref
          | $heads[]
          | select(.headRepo == $event.repo.name and .ref == $ref)
          | select(.createdAt <= $event.created_at and (.closedAt == null or .closedAt >= $event.created_at))
          | . as $pr
          | select(any($prs[]; .key == $pr.key and .sha == $event.payload.head) | not)
          | {
              repo: $pr.repo,
              key: $pr.key,
              kind: "PR",
              label: "UPDATED",
              occurredAt: $event.created_at,
              title: $pr.title,
              number: $pr.number,
              artifactUrl: $pr.artifactUrl
            }
        else
          empty
        end
    ]
  ' <<< "$response
$heads
$prs"
}

function _gh-activity-mentions() {
  local user=$1 from=$2 to=$3 response from_date=${2%%T*} to_date=${3%%T*}

  response=$(gh api graphql --paginate --slurp \
    -f query='query($q: String!, $endCursor: String) {
      search(query: $q, type: ISSUE, first: 100, after: $endCursor) {
        nodes {
          __typename
          ... on Issue {
            title
            number
            url
            repository { nameWithOwner }
            timelineItems(last: 100, itemTypes: [MENTIONED_EVENT]) {
              nodes {
                ... on MentionedEvent { createdAt actor { login } }
              }
            }
          }
          ... on PullRequest {
            title
            number
            url
            repository { nameWithOwner }
            timelineItems(last: 100, itemTypes: [MENTIONED_EVENT]) {
              nodes {
                ... on MentionedEvent { createdAt actor { login } }
              }
            }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }' \
    -f q="mentions:$user created:<=$to_date updated:>=$from_date sort:updated-desc") || return

  jq --arg user "$user" --arg from "$from" --arg to "$to" -c '
    [.[].data.search.nodes[] as $item
      | $item.timelineItems.nodes[]
      | select(.actor.login == $user)
      | select(.createdAt >= $from and .createdAt <= $to)
      | (if $item.__typename == "PullRequest" then "PR" else "ISSUE" end) as $kind
      | {
          repo: $item.repository.nameWithOwner,
          key: "\($kind):\($item.repository.nameWithOwner)#\($item.number)",
          kind: $kind,
          label: "MENTIONED IN",
          occurredAt: .createdAt,
          title: $item.title,
          number: $item.number,
          artifactUrl: $item.url
        }
    ]
  ' <<< "$response"
}

function _gh-activity-repos() (
  local repo pattern

  if (($# == 0)); then
    cat
    return
  fi

  shopt -s nocasematch
  while IFS= read -r repo; do
    for pattern in "$@"; do
      if [[ "$repo" == $pattern ]]; then
        printf '%s\n' "$repo"
        break
      fi
    done
  done
)

function gh-activity() {
  local from_arg to_arg week_arg week_range month_arg month_range year user from to begin end from_epoch to_epoch event_cutoff week month
  local pr_result prs heads contributions events mentions report pattern repos i missing key repo number metadata
  local -a args=() patterns=()

  while (($# > 0)); do
    case "$1" in
      --repo|--repo=*)
        if [[ "$1" == --repo ]]; then
          shift
          pattern=${1-}
        else
          pattern=${1#*=}
        fi
        if [[ -z "$pattern" || "$pattern" == -* ]]; then
          echo "gh-activity: --repo requires a repository pattern" >&2
          return 2
        fi
        patterns+=("$pattern")
        ;;
      *)
        args+=("$1")
        ;;
    esac
    shift
  done
  set -- "${args[@]}"

  case $# in
    0)
      from_arg=today
      to_arg=today
      ;;
    1)
      if [[ "$1" =~ ^[0-9]{4}-W[0-9]{2}$ ]]; then
        week_arg=$1
      elif [[ "$1" == "last week" || "$1" == "this week" ]]; then
        week_arg=$(_date -d "$1" --utc +%G-W%V) || return
      elif [[ "$1" == "last month" || "$1" == "this month" ]]; then
        month_arg=${1%% *}
      elif [[ "$1" =~ ^[0-9]+$ ]]; then
        from_arg="$1 days ago"
        to_arg=today
      elif [[ "$1" =~ ^[0-9]+[[:space:]]+(days?|weeks?)$ ]]; then
        from_arg="$1 ago"
        to_arg=today
      else
        from_arg="$1"
        to_arg="$1"
      fi
      ;;
    2)
      if [[ "$1" == week && "$2" =~ ^[0-9]{1,2}$ ]]; then
        year=$(_date --utc +%G) || return
        printf -v week_arg '%s-W%02d' "$year" "$((10#$2))"
      elif [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^(days?|weeks?)$ ]]; then
        from_arg="$1 $2 ago"
        to_arg=today
      elif [[ "$1" == last && "$2" == week ]]; then
        week_arg=$(_date -d "$1 $2" --utc +%G-W%V) || return
      elif [[ "$1" == this && "$2" == week ]]; then
        week_arg=$(_date -d "$1 $2" --utc +%G-W%V) || return
      elif [[ "$1" =~ ^(last|this)$ && "$2" == month ]]; then
        month_arg=$1
      elif [[ "$1" == last && "$2" == day ]]; then
        from_arg="$1 $2"
        to_arg=today
      else
        from_arg="$1"
        to_arg="$2"
      fi
      ;;
    3)
      if [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^(days?|weeks?)$ && "$3" == ago ]]; then
        from_arg="$1 $2 $3"
        to_arg=today
      else
        echo "usage: gh-activity [--repo <[owner/]repo-pattern>]... [<date> | <year>-W<week> | week <week> | <n> [days|weeks] [ago] | last <day|week|month> | this <week|month> | <from> <to>]" >&2
        return 2
      fi
      ;;
    *)
      echo "usage: gh-activity [--repo <[owner/]repo-pattern>]... [<date> | <year>-W<week> | week <week> | <n> [days|weeks] [ago] | last <day|week|month> | this <week|month> | <from> <to>]" >&2
      return 2
      ;;
  esac

  if [[ -n "$week_arg" ]]; then
    week_range=$(_gh-activity-week-range "$week_arg") || return
    read -r from_arg to_arg <<< "$week_range"
  fi
  if [[ -n "$month_arg" ]]; then
    month_range=$(_gh-activity-month-range "$month_arg") || return
    read -r from_arg to_arg <<< "$month_range"
  fi

  from=$(_date -d "$from_arg" --utc +%Y-%m-%dT00:00:00Z) || return
  to=$(_date -d "$to_arg" --utc +%Y-%m-%dT23:59:59Z) || return
  if [[ "$from" > "$to" ]]; then
    echo "gh-activity: start date must not be after end date" >&2
    return 2
  fi

  user=$(gh api user -q '.login') || return

  for i in "${!patterns[@]}"; do
    if [[ "${patterns[i]}" != */* ]]; then
      patterns[i]="$user/${patterns[i]}"
    fi
  done

  pr_result=$(_gh-activity-prs "$user" "$from" "$to") || return
  prs=$(jq -c '.actions' <<< "$pr_result") || return
  heads=$(jq -c '.heads' <<< "$pr_result") || return

  from_epoch=$(_date -d "$from" +%s) || return
  to_epoch=$(_date -d "$to" +%s) || return
  if ((to_epoch - from_epoch <= 31536000)); then
    if ! contributions=$(_gh-activity-contributions "$user" "$from" "$to"); then
      echo "gh-activity: contribution lookup failed; showing other activity" >&2
      contributions=[]
    fi
  else
    echo "gh-activity: contribution lookup is limited to one year; showing pull requests, mentions and recent events" >&2
    contributions=[]
  fi

  event_cutoff=$(_date -d "30 days ago" --utc +%Y-%m-%dT00:00:00Z) || return
  if [[ "$to" < "$event_cutoff" ]]; then
    events=[]
  elif ! events=$(_gh-activity-events "$user" "$from" "$to" "$heads" "$prs"); then
    echo "gh-activity: event lookup failed; showing other activity" >&2
    events=[]
  fi

  if ! mentions=$(_gh-activity-mentions "$user" "$from" "$to"); then
    echo "gh-activity: mention lookup failed; showing other activity" >&2
    mentions=[]
  fi

  repos=$(jq -sr 'add | map(.repo) | unique[]' <<< "$prs
$contributions
$events
$mentions") || return
  repos=$(_gh-activity-repos "${patterns[@]}" <<< "$repos") || return

  missing=$(jq -sr --arg repos "$repos" '
    ($repos | split("\n")) as $repos
    | add | group_by(.key)[]
    | select(.[0].kind != null)
    | select(.[0].repo as $repo | ($repos | index($repo)) != null)
    | select(all(.title == null) or all(.artifactUrl == null))
    | .[0] | [.key, .repo, .number] | @tsv
  ' <<< "$prs
$contributions
$events
$mentions") || return
  while IFS=$'\t' read -r key repo number; do
    [[ -n "$key" ]] || continue
    if metadata=$(gh api "repos/$repo/issues/$number" --jq '{title, html_url}'); then
      events=$(jq --arg key "$key" --argjson metadata "$metadata" -c '
        map(if .key == $key then
          .title = (.title // $metadata.title)
          | .artifactUrl = (.artifactUrl // $metadata.html_url)
        else . end)
      ' <<< "$events") || return
    else
      echo "gh-activity: metadata lookup failed for $repo#$number; showing available activity" >&2
    fi
  done <<< "$missing"

  report=$(jq -sr --arg repos "$repos" '
    ($repos | split("\n")) as $repos
    | add as $items
    | (reduce ($items[] | select(.title != null)) as $item
        ({}; .[$item.key] = $item.title)) as $titles
    | (reduce ($items[] | select(.artifactUrl != null)) as $item
        ({}; .[$item.key] = $item.artifactUrl)) as $urls
    | $items
    | map(
        if .kind != null then
          .title = (.title // $titles[.key] // "\(.kind) #\(.number)")
          | .artifactUrl = (.artifactUrl // $urls[.key] // (.actionUrl | split("#")[0]))
        else
          .
        end
      )
    | group_by(.repo)
    | map(
        select(
          .[0].repo as $repo
          | ($repos | index($repo)) != null
        )
        | . as $repoGroup
        | $repoGroup[0].repo as $repo
        | ($repoGroup
            | group_by(.key)
            | map(
                . as $group
                | if $group[0].label == "COMMITS" then
                    {
                      latestAt: ($group | map(.occurredAt) | max),
                      text: (
                        "- CREATED \($group[0].amount) "
                        + (if $group[0].amount == 1 then "COMMIT" else "COMMITS" end)
                        + ": \($group[0].url)"
                      )
                    }
                  elif $group[0].label == "CREATED REPOSITORY" then
                    {
                      latestAt: ($group | map(.occurredAt) | max),
                      text: "- CREATED REPOSITORY: \($group[0].url)"
                    }
                  else
                    ($group | map(select(.isComment == true)) | sort_by(.occurredAt)) as $comments
                    | ($group
                        | group_by(.label)
                        | map({
                            label: .[0].label,
                            count: length,
                            occurredAt: (map(.occurredAt) | min)
                          })
                        | sort_by(.occurredAt)
                      ) as $summary
                    | {
                        latestAt: ($group | map(.occurredAt) | max),
                        text: (
                          "- "
                          + if $summary | length > 0 then
                              ($summary | map(
                                .label + if .count > 1 then " (\(.count))" else "" end
                              ) | join(", ")) + " "
                            else "" end
                          + "\($group[0].kind) #\($group[0].number): \($group[0].title) "
                          + $group[0].artifactUrl
                        ),
                        comments: $comments
                      }
                  end
              )
            | sort_by(.latestAt)
            | reverse
          ) as $entries
        | {
            latestAt: ($entries | map(.latestAt) | max),
            text: (
              "\($repo)\n" + ($entries | map(
                .text
                + if ((.comments // []) | length) > 0 then
                    "\n" + (.comments | map("    - \(.actionUrl)") | join("\n"))
                  else "" end
              ) | join("\n")) + "\n"
            )
          }
      )
    | sort_by(.latestAt)
    | reverse
    | .[].text
  ' <<< "$prs
$contributions
$events
$mentions") || return

  begin=$(_date -d "$from" --utc "+%a %Y-%m-%d")
  end=$(_date -d "$to" --utc "+%a %Y-%m-%d")
  if [[ "$begin" == "$end" ]]; then
    echo -e "Activity ($begin)\n"
  elif ((to_epoch - from_epoch == 7 * 86400 - 1)) && [[ "$(_date -d "$from" --utc +%u)" == 1 ]]; then
    week=$(_date -d "$from" --utc +%-V) || return
    echo -e "Activity (Week $week: $begin - $end)\n"
  elif [[ -n "$month_arg" ]]; then
    month=$(_date -d "$from" --utc +%B) || return
    echo -e "Activity ($month: $begin - $end)\n"
  else
    echo -e "Activity ($begin - $end)\n"
  fi

  printf '%s\n' "$report"
}

gh-activity "$@"
