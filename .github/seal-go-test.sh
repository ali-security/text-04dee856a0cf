#!/usr/bin/env bash
# Runs golang.org/x/text's test suite (`go test ./...`, README.md) verbosely
# into a log file, then prints a compact report: per-package results, one line
# per skipped test with the reason the test printed, and pass/fail/skip totals.
# Usage: seal-go-test.sh [test-filter]   (empty filter = full suite)
set -u

FILTER="${1:-}"
LOG="${RUNNER_TEMP:-/tmp}/go-test.log"
: > "$LOG"

rc=0
run() {
  echo "+ go test $*" >> "$LOG"
  if go test "$@" >> "$LOG" 2>&1; then :; else rc=$?; fi
}

if [ -n "$FILTER" ]; then
  run -count=1 -v $FILTER
else
  # Packages whose table/conformance tests fetch Unicode/CLDR data from
  # unicode.org; upstream gates them behind -long (internal/testtext/flag.go).
  LONG_PKGS="collate currency date internal/export/idna internal/export/unicode internal/number unicode/bidi unicode/norm unicode/runenames width"
  LONG_ARGS=""
  EXCL=""
  for p in $LONG_PKGS; do
    LONG_ARGS="$LONG_ARGS ./$p"
    EXCL="$EXCL golang.org/x/text/$p"
  done
  OTHER_PKGS=$(go list ./... | awk -v excl="$EXCL" '
    BEGIN { n = split(excl, e, " "); for (i = 1; i <= n; i++) skip[e[i]] = 1 }
    !($0 in skip) { print }')
  run -count=1 -v $OTHER_PKGS
  run -count=1 -v $LONG_ARGS -long
fi

awk '
  # go test -v streams t.Log/t.Skip output under the test currently named by
  # the last "=== RUN/CONT/NAME" line; subtest "--- SKIP" lines arrive later,
  # when the parent finishes, so remember the last message per test name.
  /^=== (RUN|CONT|NAME) / { cur=$3; next }
  /^=== / { next }
  /^\+ go test / { print; next }
  /^[ \t]*--- PASS: / { passed++; next }
  /^[ \t]*--- FAIL: / { failed++; print "FAILED TEST: " $3; next }
  /^[ \t]*--- SKIP: / {
    skipped++; np++; sname[np]=$3
    r=msg[$3]; sub(/^[ \t]+/, "", r)
    if (r == "") r="(t.SkipNow, no message)"
    sreason[np]=r; next
  }
  /^(ok|FAIL|\?)[ \t]/ {
    print
    for (i=1; i<=np; i++) skips[++ns]="SKIP\t" $2 "\t" sname[i] "\t" sreason[i]
    np=0; delete msg; next
  }
  /^(PASS|FAIL)$/ { next }
  cur != "" { msg[cur]=$0 }
  END {
    print ""
    print "==== skipped tests (" skipped+0 ") ===="
    for (i=1; i<=ns; i++) print skips[i]
    print ""
    printf "==== go test summary: tests passed=%d failed=%d skipped=%d ====\n", passed, failed, skipped
  }
' "$LOG"

if [ "$rc" -ne 0 ]; then
  echo "go test failed (exit $rc); full verbose log follows"
  cat "$LOG"
fi
exit $rc
