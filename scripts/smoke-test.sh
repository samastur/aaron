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
  mkdir -p $work/support/Profiles
  sed "s|\$FIXTURES|$FIXTURES|g" $SMOKE/config.json > $work/support/Profiles/Default.json
  # Extra profiles for a scenario: App/SmokeTests/<name>.profiles/*.json
  for profile in $SMOKE/$name.profiles/*.json(N); do
    sed "s|\$FIXTURES|$FIXTURES|g" $profile > $work/support/Profiles/${profile:t}
  done
  document=$SMOKE/story.md
  [[ -f $SMOKE/$name.md ]] && document=$SMOKE/$name.md
  cp $document $work/
  # Extra files for a scenario: App/SmokeTests/<name>.files/*
  [[ -d $SMOKE/$name.files ]] && cp -R $SMOKE/$name.files/. $work/
  AARON_SUPPORT_DIR=$work/support WORK=$work AARON_DEBUG_SCRIPT=$SMOKE/$name.json AARON_SNAPSHOT_DIR=$work/out \
    timeout 120 $APP $work/${document:t} -ApplePersistenceIgnoreState YES > $work/app.log 2>&1
  if [[ -f $work/out/result.txt ]] && [[ $(head -1 $work/out/result.txt) == PASS ]]; then
    print "PASS  $name"
    rm -rf $work
  elif [[ -f $work/out/result.txt ]] && [[ $(head -1 $work/out/result.txt) == SKIP ]]; then
    print "SKIP  $name  ($(sed -n 2p $work/out/result.txt))"
    rm -rf $work
  else
    print "FAIL  $name  (output in $work)"
    [[ -f $work/out/result.txt ]] && sed 's/^/      /' $work/out/result.txt || print "      no result (timed out or crashed)"
    failed=1
  fi
done
exit $failed
