#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Required environment variables
# ============================================================

: "${REPOSITORY:?REPOSITORY is required}"
: "${PROJECT_OWNER:?PROJECT_OWNER is required}"
: "${PROJECT_NUMBER:?PROJECT_NUMBER is required}"

: "${ISSUE_PREFIX:?ISSUE_PREFIX is required}"
: "${ISSUE_TITLE:?ISSUE_TITLE is required}"
: "${ISSUE_DOCUMENTATION:?ISSUE_DOCUMENTATION is required}"
: "${REPETITIONS:?REPETITIONS is required}"

: "${SPRINT:?SPRINT is required}"
: "${MICRO_SPRINT:?MICRO_SPRINT is required}"

: "${TRIGGERED_BY:?TRIGGERED_BY is required}"

: "${ISSUE_TOKEN:?ISSUE_TOKEN is required}"
: "${PROJECT_TOKEN:?PROJECT_TOKEN is required}"

ASSIGN_TEAM="${ASSIGN_TEAM:-false}"

# ============================================================
# Team members
# ============================================================

TEAM_MEMBERS=(
  "valiwisdev"
)

# ============================================================
# Logging
# ============================================================

log() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}


# ============================================================
# Validation
# ============================================================

validate_issue_prefix() {
  case "$ISSUE_PREFIX" in
    MS1|MS2|MS3|MS4|Sprint1|Sprint2|Sprint3|Sprint4)
      ;;
    *)
      echo "Error: Invalid issue prefix '$ISSUE_PREFIX'."
      echo "Allowed prefixes:"
      echo "MS1, MS2, MS3, MS4, Sprint1, Sprint2, Sprint3, Sprint4"
      exit 1
      ;;
  esac
}


validate_repetitions() {
  if ! [[ "$REPETITIONS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: REPETITIONS must be a positive integer."
    exit 1
  fi
}


# ============================================================
# Get GitHub Project information
# ============================================================

get_project_information() {
  log "Getting GitHub Project information"

  PROJECT_DATA=$(
    GH_TOKEN="$PROJECT_TOKEN" gh api graphql \
      -f query='
        query($login: String!, $number: Int!) {
          organization(login: $login) {
            projectV2(number: $number) {
              id

              fields(first: 50) {
                nodes {
                  ... on ProjectV2IterationField {
                    id
                    name

                    configuration {
                      iterations {
                        id
                        title
                      }

                      completedIterations {
                        id
                        title
                      }
                    }
                  }
                }
              }
            }
          }
        }
      ' \
      -F login="$PROJECT_OWNER" \
      -F number="$PROJECT_NUMBER"
  )

  PROJECT_ID=$(
    echo "$PROJECT_DATA" |
      jq -r '.data.organization.projectV2.id'
  )

  SPRINT_FIELD_ID=$(
    echo "$PROJECT_DATA" |
      jq -r '
        .data.organization.projectV2.fields.nodes[]
        | select(.name == "Sprint")
        | .id
      '
  )

  SPRINT_ITERATION_ID=$(
    echo "$PROJECT_DATA" |
      jq -r \
        --arg sprint "$SPRINT" '
          .data.organization.projectV2.fields.nodes[]
          | select(.name == "Sprint")
          | (
              .configuration.iterations
              + .configuration.completedIterations
            )[]
          | select(.title == $sprint)
          | .id
        '
  )

  MICRO_SPRINT_FIELD_ID=$(
    echo "$PROJECT_DATA" |
      jq -r '
        .data.organization.projectV2.fields.nodes[]
        | select(.name == "Micro Sprint")
        | .id
      '
  )

  if [[ "$MICRO_SPRINT" != "None" ]]; then
    MICRO_SPRINT_ITERATION_ID=$(
      echo "$PROJECT_DATA" |
        jq -r \
          --arg micro "$MICRO_SPRINT" '
            .data.organization.projectV2.fields.nodes[]
            | select(.name == "Micro Sprint")
            | (
                .configuration.iterations
                + .configuration.completedIterations
              )[]
            | select(.title == $micro)
            | .id
          '
    )
  else
    MICRO_SPRINT_ITERATION_ID=""
  fi

  validate_project_information
}


validate_project_information() {
  if [[ -z "$PROJECT_ID" || "$PROJECT_ID" == "null" ]]; then
    echo "Error: Project '$PROJECT_NUMBER' was not found."
    exit 1
  fi

  if [[ -z "$SPRINT_FIELD_ID" || "$SPRINT_FIELD_ID" == "null" ]]; then
    echo "Error: Project field 'Sprint' was not found."
    exit 1
  fi

  if [[ -z "$SPRINT_ITERATION_ID" || "$SPRINT_ITERATION_ID" == "null" ]]; then
    echo "Error: Sprint '$SPRINT' was not found."
    exit 1
  fi

  if [[ "$MICRO_SPRINT" != "None" ]]; then
    if [[ -z "$MICRO_SPRINT_FIELD_ID" || "$MICRO_SPRINT_FIELD_ID" == "null" ]]; then
      echo "Error: Project field 'Micro Sprint' was not found."
      exit 1
    fi

    if [[ -z "$MICRO_SPRINT_ITERATION_ID" || "$MICRO_SPRINT_ITERATION_ID" == "null" ]]; then
      echo "Error: Micro Sprint '$MICRO_SPRINT' was not found."
      exit 1
    fi
  fi

  echo "Project ID: $PROJECT_ID"
  echo "Sprint: $SPRINT"
  echo "Micro Sprint: $MICRO_SPRINT"
}


# ============================================================
# Create issue
# ============================================================

create_issue() {
  local title="$1"
  local body="$2"

  local args=(
    --method POST
    "repos/$REPOSITORY/issues"
    -f "title=$title"
    -f "body=$body"
  )

  if [[ "$ASSIGN_TEAM" == "true" ]]; then
    echo "Assigning issue to all team members." >&2

    for member in "${TEAM_MEMBERS[@]}"; do
      args+=(-f "assignees[]=$member")
    done
  fi

  GH_TOKEN="$ISSUE_TOKEN" gh api "${args[@]}"
}

# ============================================================
# Add issue to GitHub Project
# ============================================================

add_issue_to_project() {
  local issue_node_id="$1"

  GH_TOKEN="$PROJECT_TOKEN" gh api graphql \
    -f query='
      mutation($projectId: ID!, $contentId: ID!) {
        addProjectV2ItemById(
          input: {
            projectId: $projectId
            contentId: $contentId
          }
        ) {
          item {
            id
          }
        }
      }
    ' \
    -F projectId="$PROJECT_ID" \
    -F contentId="$issue_node_id" \
    --jq '.data.addProjectV2ItemById.item.id'
}


# ============================================================
# Set iteration field
# ============================================================

set_iteration() {
  local item_id="$1"
  local field_id="$2"
  local iteration_id="$3"

  GH_TOKEN="$PROJECT_TOKEN" gh api graphql \
    -f query='
      mutation(
        $projectId: ID!,
        $itemId: ID!,
        $fieldId: ID!,
        $iterationId: String!
      ) {
        updateProjectV2ItemFieldValue(
          input: {
            projectId: $projectId
            itemId: $itemId
            fieldId: $fieldId
            value: {
              iterationId: $iterationId
            }
          }
        ) {
          projectV2Item {
            id
          }
        }
      }
    ' \
    -F projectId="$PROJECT_ID" \
    -F itemId="$item_id" \
    -F fieldId="$field_id" \
    -F iterationId="$iteration_id" \
    --silent
}


# ============================================================
# Configure project item
# ============================================================

configure_project_item() {
  local item_id="$1"

  echo "Setting Sprint: $SPRINT"

  set_iteration \
    "$item_id" \
    "$SPRINT_FIELD_ID" \
    "$SPRINT_ITERATION_ID"

  if [[ -n "$MICRO_SPRINT_ITERATION_ID" ]]; then
    echo "Setting Micro Sprint: $MICRO_SPRINT"

    set_iteration \
      "$item_id" \
      "$MICRO_SPRINT_FIELD_ID" \
      "$MICRO_SPRINT_ITERATION_ID"
  fi
}


# ============================================================
# Generate issue title
# ============================================================

generate_issue_title() {
  local index="$1"

  if (( REPETITIONS > 1 )); then
    echo "$ISSUE_PREFIX: $ISSUE_TITLE #$index"
  else
    echo "$ISSUE_PREFIX: $ISSUE_TITLE"
  fi
}


# ============================================================
# Generate issue body
# ============================================================

generate_issue_body() {
  cat <<EOF
$ISSUE_DOCUMENTATION

---

Created through GitHub Actions by @$TRIGGERED_BY
EOF
}


# ============================================================
# Main
# ============================================================

main() {
  validate_issue_prefix
  validate_repetitions
  get_project_information

  log "Creating documentation issues"

  for ((i = 1; i <= REPETITIONS; i++)); do
    title=$(generate_issue_title "$i")
    body=$(generate_issue_body)

    echo
    echo "Creating issue: $title"

    issue=$(create_issue "$title" "$body")

    issue_url=$(
      echo "$issue" |
        jq -r '.html_url'
    )

    issue_node_id=$(
      echo "$issue" |
        jq -r '.node_id'
    )

    echo "Created: $issue_url"

    item_id=$(add_issue_to_project "$issue_node_id")

    echo "Added to project."

    configure_project_item "$item_id"

    echo "Configured: $issue_url"
  done

  log "Done"

  echo "Created $REPETITIONS issue(s)."
}


main "$@"