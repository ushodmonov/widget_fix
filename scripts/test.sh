#!/bin/bash
# Runs every check: the mod's manifests and tests, the receiver's tests, the WidgetFix package's
# analysis and tests, Tally's analysis and tests, and a release build of Tally with WidgetFix compiled
# out of it.
set -euo pipefail
cd "$(dirname "$0")/.."

claude plugin validate .
claude plugin validate mod
claude plugin test mod
node --test mod/tests/*.node.test.mjs

(cd packages/widget_fix && flutter analyze && flutter test)
(cd tally && flutter analyze && flutter test)

# In a release build kDebugMode is false and the compiler drops every line of WidgetFix.
(cd tally && flutter build web --release --no-pub >/dev/null)
if grep -q "What should Claude fix here" tally/build/web/main.dart.js; then
  echo "WidgetFix is in the release build" >&2
  exit 1
fi
echo "All checks passed."
