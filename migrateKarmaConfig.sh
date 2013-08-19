#!/bin/sh
#
# Karma 0.10 config file migration script
# 
# Andrew Martin, 19/08/2013
# sublimino@gmail.com
#
## Usage: %SCRIPT_NAME% [options] path-to-karma-config
##
## Options:
##   -t, --test        Check if config file has been upgraded
##   -h, --help        Display this message
##

# helper functions
DIR=$(cd "$(dirname "$0")" && pwd)
THIS_SCRIPT="$DIR"/$(basename $0)

COLOUR_RED=$(tput setaf 1 2>/dev/null :-"")
COLOUR_RESET=$(tput sgr0 2>/dev/null :-"")

usage() {
    [ "$*" ] && echo "$THIS_SCRIPT: $*" && echo
    sed -n '/^##/,/^$/s/^## \{0,1\}//p' "$THIS_SCRIPT" | sed "s/%SCRIPT_NAME%/$(basename $THIS_SCRIPT)/g"
    exit 2
}

error() {
    set +o nounset
    [ "$*" ] && ERROR="$*" || ERROR="Unknown Error"
    tput bold 2>/dev/null
    echo "$THIS_SCRIPT: $COLOUR_RED$ERROR$COLOUR_RESET" && echo || echo
    exit 3
}

check_number_of_expected_arguments() {
    [[ $EXPECTED_NUM_ARGUMENTS != ${#ARGUMENTS[@]} ]] && {
        ARGUMENTS_STRING="argument"
        [[ $EXPECTED_NUM_ARGUMENTS > 1 ]] && ARGUMENTS_STRING="$ARGUMENTS_STRING"s
        usage "$EXPECTED_NUM_ARGUMENTS $ARGUMENTS_STRING expected, ${#ARGUMENTS[@]} found"
    }
    return 0
}

_isMac ()
{
    [[ "Darwin" = $(uname) ]] && return 0 || return 1
}


# user defaults
TEST_MIGRATION=0

# required defaults
EXPECTED_NUM_ARGUMENTS=1

# exit on error
set -o errexit
# error on unset variable
set -o nounset
# error on clobber
set -o noclobber

[[ $# = 0 && $EXPECTED_NUM_ARGUMENTS > 0 ]] && usage


while [ $# -gt 0 ]; do
  case $1 in
  (-h|--help) usage;;
  (-t|--test) TEST_MIGRATION=1;;
  (--) shift; break;;
  (-*) usage "$1: unknown option";;
  (*) ARGUMENTS+=($1);
  esac
  shift
done

check_number_of_expected_arguments


# main
FILENAME=${ARGUMENTS[0]}

# check to see if this config file's already been migrated
if grep "module.exports" "$FILENAME" >/dev/null; then 
    [[ $TEST_MIGRATION = 0 ]] && error "$FILENAME is already in Karma 0.10 RequireJS format"
    exit 1
else 
    [[ $TEST_MIGRATION = 1 ]] && exit 0
fi

echo "About to migrate $FILENAME"

mv "$FILENAME" "$FILENAME".old

echo "Backed up $FILENAME to $FILENAME.old"


# rewrite config file in subshell
(echo 'module.exports = function(config) {
  config.set({
' 
cat $FILENAME.old | sed 's#\([a-zA-Z]*\) = \(.*\)#\1: \2#g' | sed 's#;$#,#g' | sed 's#^#    #' 

echo '  });
};
') > $FILENAME


# move adapters into new 'adapters' property
ADAPTERS=$(grep -F 'files: [' "$FILENAME" -A 30 | sed '/"/d')
FRAMEWORKS=''

for ADAPTER in JASMINE MOCHA QUNIT; do 
    if echo $ADAPTERS | grep $ADAPTER >/dev/null; then 
        echo "Found adapter: $ADAPTER"
        _isMac && { sed -i '' "/$ADAPTER/d" $FILENAME; } || { sed "/$ADAPTER/d" $FILENAME -i; }
        ADAPTER=$(echo $ADAPTER | awk '{print tolower($0)}')
        FRAMEWORKS="'$ADAPTER',$FRAMEWORKS"
    fi
done

FRAMEWORKS=$(echo "    frameworks: [$FRAMEWORKS]," | sed "s#',\]#']#g")
awk "/basePath:/{print; print \"\n$FRAMEWORKS\"; next}1" $FILENAME > $FILENAME.awk
\mv $FILENAME.awk $FILENAME


# change LOG_INFO to config.LOG_INFO
_isMac && { sed -i '' 's#\(LOG_\)#config.\1#g' $FILENAME; } || { sed 's#\(LOG_\)#config.\1#g' $FILENAME -i; }


echo "Migrated $FILENAME"
exit 0
