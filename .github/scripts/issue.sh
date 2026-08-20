#!/usr/bin/env bash

create_issue() {
  local title="$1"
  local body="$2"

  local args=(
    --method POST
    "repos/$REPOSITORY/issues"
    -f "title=$title"
    -f "body=$body"
  )

  case "$ASSIGNMENT_MODE" in
    none)
      ;;

    team)
      echo "Assigning issue to all team members." >&2

      for member in "${TEAM_MEMBERS[@]}"; do
        args+=(-f "assignees[]=$member")
      done
      ;;

    random)
      random_member="${TEAM_MEMBERS[RANDOM % ${#TEAM_MEMBERS[@]}]}"

      echo "Randomly selected team member: @$random_member" >&2

      args+=(-f "assignees[]=$random_member")
      ;;

    *)
      echo "Error: Invalid assignment mode '$ASSIGNMENT_MODE'." >&2
      echo "Allowed modes: none, team, random" >&2
      exit 1
      ;;
  esac

  GH_TOKEN="$ISSUE_TOKEN" gh api "${args[@]}"
}

generate_issue_title() {
  local index="$1"

  if (( REPETITIONS > 1 )); then
    echo "$ISSUE_PREFIX: $ISSUE_TITLE #$index"
  else
    echo "$ISSUE_PREFIX: $ISSUE_TITLE"
  fi
}

generate_issue_body() {
  cat <<EOF
$ISSUE_DOCUMENTATION

---

Created through GitHub Actions by @$TRIGGERED_BY
EOF
}
