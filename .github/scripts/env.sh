#!/usr/bin/env bash

: "${REPOSITORY:?REPOSITORY is required}"
: "${PROJECT_OWNER:?PROJECT_OWNER is required}"
: "${PROJECT_NUMBER:?PROJECT_NUMBER is required}"

: "${ISSUE_PREFIX:?ISSUE_PREFIX is required}"
: "${ISSUE_TITLE:?ISSUE_TITLE is required}"
: "${REPETITIONS:?REPETITIONS is required}"

: "${SPRINT:?SPRINT is required}"
: "${MICRO_SPRINT:?MICRO_SPRINT is required}"
: "${PRIORITY:?PRIORITY is required}"

: "${TRIGGERED_BY:?TRIGGERED_BY is required}"

: "${ISSUE_TOKEN:?ISSUE_TOKEN is required}"
: "${PROJECT_TOKEN:?PROJECT_TOKEN is required}"

ASSIGNMENT_MODE="${ASSIGNMENT_MODE:-none}"

TEAM_MEMBERS=(
  "valiwisdev"
)
