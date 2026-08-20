#!/usr/bin/env bash

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

                  ... on ProjectV2SingleSelectField {
                    id
                    name

                    options {
                      id
                      name
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

  PRIORITY_FIELD_ID=$(
    echo "$PROJECT_DATA" |
      jq -r '
        .data.organization.projectV2.fields.nodes[]
        | select(.name == "Priority")
        | .id
      '
  )

  PRIORITY_OPTION_ID=$(
    echo "$PROJECT_DATA" |
      jq -r \
        --arg priority "$PRIORITY" '
          .data.organization.projectV2.fields.nodes[]
          | select(.name == "Priority")
          | .options[]
          | select(.name == $priority)
          | .id
        '
  )

  validate_project_information
}

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

set_single_select() {
  local item_id="$1"
  local field_id="$2"
  local option_id="$3"

  GH_TOKEN="$PROJECT_TOKEN" gh api graphql \
    -f query='
      mutation(
        $projectId: ID!,
        $itemId: ID!,
        $fieldId: ID!,
        $optionId: String!
      ) {
        updateProjectV2ItemFieldValue(
          input: {
            projectId: $projectId
            itemId: $itemId
            fieldId: $fieldId
            value: {
              singleSelectOptionId: $optionId
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
    -F optionId="$option_id" \
    --silent
}

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

  echo "Setting Priority: $PRIORITY"

  set_single_select \
    "$item_id" \
    "$PRIORITY_FIELD_ID" \
    "$PRIORITY_OPTION_ID"
}
