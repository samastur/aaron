#!/bin/zsh
# Runs the smoke test scenarios in App/SmokeTests against a Debug build of
# the app. Needs no UI automation permissions. Usage:
#   scripts/smoke-test.sh [scenario ...]     (default: all)
set -u
ROOT=${0:A:h:h}
SMOKE=$ROOT/App/SmokeTests
FIXTURES=$ROOT/App/UITests/Fixtures
APP=$ROOT/build/DerivedData/Build/Products/Debug/Aaron.app/Contents/MacOS/Aaron

if [[ ${SKIP_BUILD:-0} != 1 ]]; then
  (cd $ROOT/App && xcodegen generate -q && xcodebuild -project Aaron.xcodeproj -scheme Aaron \
    -configuration Debug -derivedDataPath $ROOT/build/DerivedData build -quiet) || exit 1
fi

scenarios=("$@")
if (( ${#scenarios} == 0 )); then
  scenarios=(${SMOKE}/*.json(:t:r))
  scenarios=(${scenarios:#config})
fi

failed=0
for name in $scenarios; do
  work=$(mktemp -d -t aaron-smoke)
  sed "s|\$FIXTURES|$FIXTURES|g" $SMOKE/config.json > $work/config.json
  document=$SMOKE/story.md
  [[ -f $SMOKE/$name.md ]] && document=$SMOKE/$name.md
  cp $document $work/
  AARON_CONFIG_PATH=$work/config.json AARON_DEBUG_SCRIPT=$SMOKE/$name.json AARON_SNAPSHOT_DIR=$work/out \
    timeout 120 $APP $work/${document:t} -ApplePersistenceIgnoreState YES > $work/app.log 2>&1
  if [[ -f $work/out/result.txt ]] && [[ $(head -1 $work/out/result.txt) == PASS ]]; then
    print "PASS  $name"
    rm -rf $work
  else
    print "FAIL  $name  (output in $work)"
    [[ -f $work/out/result.txt ]] && sed 's/^/      /' $work/out/result.txt || print "      no result (timed out or crashed)"
    failed=1
  fi
done
exit $failed
