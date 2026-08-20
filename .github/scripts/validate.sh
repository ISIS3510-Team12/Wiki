#!/usr/bin/env bash

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

  if [[ -z "$PRIORITY_FIELD_ID" || "$PRIORITY_FIELD_ID" == "null" ]]; then
    echo "Error: Project field 'Priority' was not found."
    exit 1
  fi

  if [[ -z "$PRIORITY_OPTION_ID" || "$PRIORITY_OPTION_ID" == "null" ]]; then
    echo "Error: Priority option '$PRIORITY' was not found."
    exit 1
  fi

  echo "Project ID: $PROJECT_ID"
  echo "Sprint: $SPRINT"
  echo "Micro Sprint: $MICRO_SPRINT"
  echo "Priority: $PRIORITY"
}
