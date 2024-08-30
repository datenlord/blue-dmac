#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

BASH_PROFILE=$HOME/.bash_profile
if [ -f "$BASH_PROFILE" ]; then
    source $BASH_PROFILE
fi

TEST_DIR=`realpath ./test`
LOG_DIR=`realpath ./tmp`
ALL_LOG=$TEST_DIR/run.log

mkdir -p $LOG_DIR

make -j8 -f Makefile.test all TESTDIR=$TEST_DIR LOGDIR=$LOG_DIR
cat $LOG_DIR/*.log | tee $ALL_LOG

FAIL_KEYWORKS='Error\|ImmAssert'
grep -w $FAIL_KEYWORKS $LOG_DIR/*.log | cat
ERR_NUM=`grep -c -w $FAIL_KEYWORKS $ALL_LOG | cat`
if [ $ERR_NUM -gt 0 ]; then
    echo "FAIL"
    false
else
    echo "PASS"
fi
