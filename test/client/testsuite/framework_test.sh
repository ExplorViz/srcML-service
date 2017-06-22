##
# framework_test.sh
#
# Test framework for cli testing
#
# * Always source this file before any test cli commands are given
#   source $(dirname "$0")/framework_test.sh
#
# * Perform cli command
#
# * Call function check to verify the command, e.g.,
#   check 3<<- 'STDOUT'
#     <unit/>
#     STDOUT
#
# * Optionally also specify expected stderr of command, e.g.,
#   check 3<<- 'STDOUT' 4<<- 'STDERR'
#     <unit/>
#     STDOUT
#     STDERR
#
# * If a comparison pipe is not open, then it assumes blank
#   I.e., the following check assumes that both stdout and stderr are empty
#   check
#
# * Instead of pipe 3 being the expected contents of stdout of the command, it can be file, i.e.
#   check foo.xml
#
# * Multiple tests of cli command followed by call to function check
#   can be made

# current revision number, replaced in expected output strings
export REVISION=0.9.5

# construct a temporary directory name based on the test name (without the .sh)
TEMPDIR=./tmp/$(basename $0 .sh)

# remove old TEMPDIR, and create new fresh one
rm -fR $TEMPDIR
mkdir -p $TEMPDIR
cd $TEMPDIR

# make sure to find the srcml executable
export PATH=.:$PATH

echo "$SRC2SRCML"

if [ -z "$SRC2SRCML" ]; then
    SRC2SRCML='/usr/local/bin/srcml'
fi

if [ -z "$SRCML2SRC" ]; then
    SRCML2SRC='/usr/local/bin/srcml'
fi

if [ -z "$SRCML"]; then
    SRCML='/usr/local/bin/srcml'
fi

function src2srcml () {
    $SRC2SRCML "$@"
}

function srcml2src () {
    $SRCML2SRC "$@"
}

function srcml () {
    $SRCML "$@"
}

# always exit when a command exits with a non-zero status
set -e

# turn history on so we can output the command issued
# note that the fc command accesses the history
set -o history
HISTIGNORE=check:\#
HISTSIZE=2
HISTFILESIZE=0

# output the first entry in the history file, without numbers
firsthistoryentry() {
    fc -l -n -1
}

CAPTURE_STDOUT=true
CAPTURE_STDERR=true

# variable $1 is set to the contents of stdin
define() {

    # read stdin into variable $1
    IFS= read -r -d '' $1 || true
 
    # replace any mention of REVISION with the revision number,
    eval $1=\${$1//REVISION/${REVISION}}
}

# variable $1 is set to the contents of file $2
readfile() { ${1}="$(< $2)"; }

# file with name $1 is created from the contents of string variable $2
# created files are recorded so that cleanup can occur
createfile() {
    # make directory paths as needed
    mkdir -p $(dirname $1)

    # add contents to file
    echo -ne "${2}" > ${1}
}

rmfile() { rm -f ${1}; }

# capture stdout and stderr
capture_output() {
    [ "$CAPTURE_STDOUT" = true ] && exec 3>&1 1>$STDOUT
    [ "$CAPTURE_STDERR" = true ] && exec 4>&2 2>$STDERR
}

# uncapture stdout and stderr
uncapture_output() {
    [ "$CAPTURE_STDOUT" = true ] && exec 1>&3
    [ "$CAPTURE_STDERR" = true ] && exec 2>&4
}

message() {
    # return stdout and stderr to standard streams
    uncapture_output

    # trace the command
    echo "$1" >&2

    capture_output

    true
}

# output filenames for capturing stdout and stderr from the command
base=$(basename $0 .sh)
typeset STDERR=.stderr_$base
typeset STDOUT=.stdout_$base

# save stdout and stderr to our files
capture_output

##
# checks the result of a command
#
# If stdout is not specified, it is assumed to be empty
# If stderr is not specified, it is assumed to be empty
check() {

    # return stdout and stderr to standard streams
    uncapture_output

    # trace the command
    firsthistoryentry

    # check <filename> stdoutstr stderrstr
    if [ $# -ge 3 ]; then

        diff $1 <(echo -n "$2")
        diff $STDERR <(echo -n "$3")

    # check <filename> stdoutstr
    # note: empty string reports as a valid file
    elif [ $# -ge 2 ] && [ "$1" != "" ] && [ -e "$1" ]; then

        diff $1 <(echo -n "$2")
        [ ! -s $STDERR ]

    # check stdoutstr stderrstr
    elif [ $# -ge 2 ]; then

        diff $STDOUT <(echo -n "$1")
        diff $STDERR <(echo -n "$2")

    # check <filename>
    elif [ $# -ge 1 ] && [ "$1" != "" ] && [ -e "$1" ]; then
        diff $STDOUT $1
        [ ! -s $STDERR ]

    # check stdoutstr
    elif [ $# -ge 1 ]; then

        diff $STDOUT <(echo -n "$1")
        [ ! -s $STDERR ]

    else
        # check that the captured stdout is empty
        [ ! -s $STDOUT ]
        [ ! -s $STDERR ]
    fi

    # return to capturing stdout and stderr
    capture_output

    true
}

##
# checks the result of a command to verify that it is empty
#   $1 (optional) file of expected stdout
#   $2 (optional) file of expected stderr
#   $STDOUT - filename of captured stdout
#   $STDERR - filename of captured stderr
#
check_null() {

    # return stdout and stderr to standard streams
    uncapture_output

    # trace the command
    firsthistoryentry

    # verify expected stderr to the captured stdout

    # check that the captured stdout is empty
    [ ! -s $STDOUT ]

    # check that the captured stderr is empty
    [ ! -s $STDERR ]

    # # return to capturing stdout and stderr
    capture_output

    true
}

##
# checks the exit status of a command
#   $1 expected return value
#
# NOTE: Requires the following in test file header:
#   set +e
check_exit() {

    local exit_status=$?

    # return stdout and stderr to standard streams
    uncapture_output

    # trace the command
    firsthistoryentry

    # verify expected stderr to the captured stdout
    if [ $exit_status -ne $1 ]; then
        exit 8
    fi

    # return to capturing stdout and stderr
    capture_output

    true
}

# Check the validity of the xml
# Currently only checks for well-formed xml, not DTD validity
xmlcheck() {

    if [ "${1:0:1}" != "<" ]; then
        xmllint --noout ${1}
    else
        echo "${1}" | xmllint --noout /dev/stdin
    fi;

    true
}
