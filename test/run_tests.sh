#!/bin/sh

# To make output dates deterministic
export TZ='Europe/Rome'

OPT_CREATE_PGSQL=yes # create/prepare the postgresql test database
OPT_CREATE_REDIS=yes # create/prepare the redis test databases
OPT_DROP_PGSQL=yes   # drop the postgreql test environment
OPT_DROP_REDIS=yes   # drop the redis test environment

cd $(dirname $0)
BASEDIR=$(pwd)
cd -

REDIS_PORT=`node -e "console.log(require('${BASEDIR}/../config/environments/test.js').redis_port)"`
export REDIS_PORT
echo "REDIS_PORT: [${REDIS_PORT}]"

cleanup() {
  if test x"$OPT_DROP" = xyes; then
    if test x"$PID_REDIS" = x; then
      PID_REDIS=$(cat ${BASEDIR}/redis.pid)
      if test x"$PID_REDIS" = x; then
        echo "Could not find a test redis pid to kill it"
        return;
      fi
    fi
    echo "Cleaning up"
    kill ${PID_REDIS}
  fi
}

cleanup_and_exit() {
	cleanup
	exit
}

die() {
	msg=$1
	echo "${msg}" >&2
	cleanup
	exit 1
}

trap 'cleanup_and_exit' 1 2 3 5 9 13

while [ -n "$1" ]; do
        if test "$1" = "--nodrop"; then
                OPT_DROP_REDIS=no
                OPT_DROP_PGSQL=no
                shift
                continue
        elif test "$1" = "--nodrop-pg"; then
                OPT_DROP_PGSQL=no
                shift
                continue
        elif test "$1" = "--nodrop-redis"; then
                OPT_DROP_REDIS=no
                shift
                continue
        elif test "$1" = "--nocreate"; then
                OPT_CREATE_REDIS=no
                OPT_CREATE_PGSQL=no
                shift
                continue
        elif test "$1" = "--nocreate-pg"; then
                OPT_CREATE_PGSQL=no
                shift
                continue
        elif test "$1" = "--nocreate-redis"; then
                OPT_CREATE_REDIS=no
                shift
                continue
        else
                break
        fi
done

if [ -z "$1" ]; then
        echo "Usage: $0 [<options>] <test> [<test>]" >&2
        echo "Options:" >&2
        echo " --nocreate         do not create the test environment on start" >&2
        echo " --nocreate-pg      do not create the pgsql test environment" >&2
        echo " --nocreate-redis   do not create the redis test environment" >&2
        echo " --nodrop           do not drop the test environment on exit" >&2
        echo " --nodrop-pg        do not drop the pgsql test environment" >&2
        echo " --nodrop-redis     do not drop the redis test environment" >&2
        exit 1
fi

TESTS=$@

if test x"$OPT_CREATE_REDIS" = xyes; then
  echo "Starting redis on port ${REDIS_PORT}"
  echo "port ${REDIS_PORT}" | redis-server - > ${BASEDIR}/test.log &
  PID_REDIS=$!
  echo ${PID_REDIS} > ${BASEDIR}/redis.pid
fi

PREPARE_DB_OPTS=
if test x"$OPT_CREATE_PGSQL" != xyes; then
  PREPARE_DB_OPTS="$PREPARE_DB_OPTS --skip-pg"
fi
if test x"$OPT_CREATE_REDIS" != xyes; then
  PREPARE_DB_OPTS="$PREPARE_DB_OPTS --skip-redis"
fi

echo "Preparing the environment"
cd ${BASEDIR}
sh prepare_db.sh ${PREPARE_DB_OPTS} || die "database preparation failure"
cd -

PATH=node_modules/.bin/:$PATH

echo
echo "Environment:"
echo
echo "  ogr2ogr version: "`ogr2ogr --version`
echo

echo "Running tests"
mocha -t 5000 -u tdd ${TESTS}
ret=$?

cleanup || exit 1

exit $ret
