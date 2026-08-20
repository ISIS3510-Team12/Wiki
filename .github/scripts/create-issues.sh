#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/env.sh"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/validate.sh"
source "$SCRIPT_DIR/project.sh"
source "$SCRIPT_DIR/issue.sh"

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
