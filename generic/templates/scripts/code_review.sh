#!/bin/bash
# Runs the Ollama `pi` code-review harness with the configured review model.
#
#   Model:  $CODE_REVIEW_MODEL if set, otherwise glm-5.2:cloud.
#   Prompt: optional first argument; defaults to the standard review prompt.
#
# The review text is written to stdout — the caller is responsible for saving it to
# docs/codereviews/. This script exists so the *invocation* is a plain path with no
# `${VAR:-default}` brace expansion, which the permission system cannot auto-approve.
#
# Override the model for a single run with a plain assignment prefix (also
# auto-approvable), e.g.:  CODE_REVIEW_MODEL=some-model scripts/code_review.sh
set -euo pipefail

MODEL="${CODE_REVIEW_MODEL:-glm-5.2:cloud}"
PROMPT="${1:-review this code and return your findings}"

exec ollama launch pi --model "$MODEL" -- -p "$PROMPT"
