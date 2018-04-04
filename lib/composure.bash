# composure - by erichs
# light-hearted functions for intuitive shell programming

# install: source this script in your ~/.profile or ~/.${SHELL}rc script

# latest source available at http://git.io/composure
# known to work on bash, zsh, and ksh93

# 'plumbing' functions

stdlib_composure_keywords ()
{
    echo "about author example group param version"
}

stdlib_letterpress ()
{
    typeset rightcol="$1" leftcol="${2:- }"

    if [ -z "$rightcol" ]; then
        return
    fi

    printf "%-20s%s\n" "$leftcol" "$rightcol"
}

stdlib_transcribe ()
{
    typeset func=$1
    typeset file=$2
    typeset operation="$3"

    if git --version >/dev/null 2>&1; then
        if [ -d ~/.composure ]; then
            (
                cd ~/.composure
                if git rev-parse 2>/dev/null; then
                    if [ ! -f $file ]; then
                        printf "%s\n" "Oops! Couldn't find $file to version it for you..."
                        return
                    fi
                    cp $file ~/.composure/$func.inc
                    git add --all .
                    git commit -m "$operation $func"
                fi
            )
        else
            if [ "$USE_COMPOSURE_REPO" = "0" ]; then
                return  # if you say so...
            fi
            printf "%s\n" "I see you don't have a ~/.composure repo..."
            typeset input
            typeset valid=0
            while [ $valid != 1 ]; do
                printf "\n%s" 'would you like to create one? y/n: '
                read input
                case $input in
                    y|yes|Y|Yes|YES)
                        (
                            echo 'creating git repository for your functions...'
                            mkdir ~/.composure
                            cd ~/.composure
                            git init
                            echo "composure stores your function definitions here" > README.txt
                            git add README.txt
                            git commit -m 'initial commit'
                        )
                        # if at first you don't succeed...
                        stdlib_transcribe "$func" "$file" "$operation"
                        valid=1
                        ;;
                    n|no|N|No|NO)
                        printf "%s\n" "ok. add 'export USE_COMPOSURE_REPO=0' to your startup script to disable this message."
                        valid=1
                    ;;
                    *)
                        printf "%s\n" "sorry, didn't get that..."
                    ;;
                esac
            done
       fi
    fi
}

stdlib_typeset_functions ()
{
    # unfortunately, there does not seem to be a easy, portable way to list just the
    # names of the defined shell functions...

    # first, determine our shell:
    typeset shell
    if [ -n "$SHELL" ]; then
        shell=$(basename $SHELL)  # we assume this is set correctly!
    else
        # we'll have to try harder
        # here's a hack I modified from a StackOverflow post:
        # we loop over the ps listing for the current process ($$), and print the last column (CMD)
        # stripping any leading hyphens bash sometimes throws in there
        typeset x ans
        typeset this=$(for x in $(ps -p $$); do ans=$x; done; printf "%s\n" $ans | sed 's/^-*//')
        typeset shell=$(basename $this)  # e.g. /bin/bash => bash
    fi
    case "$shell" in
        bash)
            typeset -F | awk '{print $3}'
            ;;
        *)
            # trim everything following '()' in ksh
            typeset +f | sed 's/().*$//'
            ;;
    esac
}


# bootstrap metadata keywords for porcelain functions
for f in $(stdlib_composure_keywords)
do
    eval "$f() { :; }"
done
unset f


# 'porcelain' functions

stdlib_cite ()
{
    about creates one or more meta keywords for use in your functions
    param one or more keywords
    example '$ stdlib_cite url username'
    example '$ url http://somewhere.com'
    example '$ username alice'
    group stdlib_composure

    # this is the storage half of the 'metadata' system:
    # we create dynamic metadata keywords with function wrappers around
    # the NOP command, ':'

    # anything following a keyword will get parsed as a positional
    # parameter, but stay resident in the ENV. As opposed to shell
    # comments, '#', which do not get parsed and are not available
    # at runtime.

    # a BIG caveat--your metadata must be roughly parsable: do not use
    # contractions, and consider single or double quoting if it contains
    # non-alphanumeric characters

    if [ -z "$1" ]; then
        printf '%s\n' 'missing parameter(s)'
        stdlib_reference stdlib_cite
        return
    fi

    typeset keyword
    for keyword in $*; do
        eval "$keyword() { :; }"
    done
}

stdlib_draft ()
{
    about wraps command from history into a new function, default is last command
    param 1: name to give function
    param 2: optional history line number
    example '$ ls'
    example '$ stdlib_draft list'
    example '$ stdlib_draft newfunc 1120  # wraps command at history line 1120 in newfunc()'
    group stdlib_composure

    typeset func=$1
    typeset num=$2
    typeset cmd

    if [ -z "$func" ]; then
        printf '%s\n' 'missing parameter(s)'
        stdlib_reference stdlib_draft
        return
    fi

    # aliases bind tighter than function names, disallow them
    if [ -n "$(LANG=C type -t $func 2>/dev/null | grep 'alias')" ]; then
        printf '%s\n' "sorry, $(type -a $func). please choose another name."
        return
    fi

    if [ -z "$num" ]; then
        # parse last command from fc output
        # some versions of 'fix command, fc' need corrective lenses...
        typeset myopic=$(fc -ln -1 | grep stdlib_draft)
        typeset lines=1
        if [ -n "$myopic" ]; then
            lines=2
        fi
        cmd=$(fc -ln -$lines | head -1 | sed 's/^[[:blank:]]*//')
    else
        # parse command from history line number
        cmd=$(eval "history | grep '^[[:blank:]]*$num' | head -1" | sed 's/^[[:blank:][:digit:]]*//')
    fi
    eval "$func() { $cmd; }"
    typeset file=$(mktemp -t stdlib_draft.XXXX)
    typeset -f $func > $file
    stdlib_transcribe $func $file stdlib_draft
    rm $file 2>/dev/null
}

stdlib_glossary ()
{
    about displays help summary for all functions, or summary for a group of functions
    param 1: optional, group name
    example '$ stdlib_glossary'
    example '$ stdlib_glossary misc'
    group stdlib_composure

    typeset targetgroup=${1:-}

    for func in $(stdlib_typeset_functions); do
        if [ -n "$targetgroup" ]; then
            typeset group="$(typeset -f $func | stdlib_metafor group)"
            if [ "$group" != "$targetgroup" ]; then
                continue  # skip non-matching groups, if specified
            fi
        fi
        typeset about="$(typeset -f $func | stdlib_metafor about)"
        stdlib_letterpress "$about" $func
    done
}

stdlib_metafor ()
{
    about prints function metadata associated with keyword
    param 1: meta keyword
    example '$ typeset -f stdlib_glossary | stdlib_metafor example'
    group stdlib_composure

    typeset keyword=$1

    if [ -z "$keyword" ]; then
        printf '%s\n' 'missing parameter(s)'
        stdlib_reference stdlib_metafor
        return
    fi

    # this sed-fu is the retrieval half of the 'metadata' system:
    # 'grep' for the metadata keyword, and then parse/filter the matching line

    # grep keyword # strip trailing '|"|; # ignore thru keyword and leading '|"
    sed -n "/$keyword / s/['\";]*$//;s/^[ 	]*$keyword ['\"]*\([^([].*\)*$/\1/p"
}

stdlib_reference ()
{
    about displays apidoc help for a specific function
    param 1: function name
    example '$ stdlib_reference stdlib_revise'
    group stdlib_composure

    typeset func=$1
    if [ -z "$func" ]; then
        printf '%s\n' 'missing parameter(s)'
        stdlib_reference stdlib_reference
        return
    fi

    typeset line

    typeset about="$(typeset -f $func | stdlib_metafor about)"
    stdlib_letterpress "$about" $func

    typeset author="$(typeset -f $func | stdlib_metafor author)"
    if [ -n "$author" ]; then
        stdlib_letterpress "$author" 'author:'
    fi

    typeset version="$(typeset -f $func | stdlib_metafor version)"
    if [ -n "$version" ]; then
        stdlib_letterpress "$version" 'version:'
    fi

    if [ -n "$(typeset -f $func | stdlib_metafor param)" ]; then
        printf "parameters:\n"
        typeset -f $func | stdlib_metafor param | while read line
        do
            stdlib_letterpress "$line"
        done
    fi

    if [ -n "$(typeset -f $func | stdlib_metafor example)" ]; then
        printf "examples:\n"
        typeset -f $func | stdlib_metafor example | while read line
        do
            stdlib_letterpress "$line"
        done
    fi
}

stdlib_revise ()
{
    about loads function into editor for revision
    param 1: name of function
    example '$ stdlib_revise myfunction'
    group stdlib_composure

    typeset func=$1
    typeset temp=$(mktemp -t stdlib_revise.XXXX)

    if [ -z "$func" ]; then
        printf '%s\n' 'missing parameter(s)'
        stdlib_reference stdlib_revise
        return
    fi

    # populate tempfile...
    if [ -f ~/.composure/$func.inc ]; then
        # ...with contents of latest git revision...
        cat ~/.composure/$func.inc >> $temp
    else
        # ...or from ENV if not previously versioned
        typeset -f $func >> $temp
    fi

    if [ -z "$EDITOR" ]
    then
      typeset EDITOR=vi
    fi

    $EDITOR $temp
    . $temp  # source edited file

    stdlib_transcribe $func $temp stdlib_revise
    rm $temp
}

stdlib_write ()
{
    about stdlib_writes one or more composed function definitions to stdout
    param one or more function names
    example '$ stdlib_write finddown foo'
    example '$ stdlib_write finddown'
    group stdlib_composure

    if [ -z "$1" ]; then
        printf '%s\n' 'missing parameter(s)'
        stdlib_reference stdlib_write
        return
    fi

# bootstrap metadata
cat <<END
for f in $(stdlib_composure_keywords)
do
    eval "\$f() { :; }"
done
unset f
END

    # include stdlib_cite() to enable custom keywords
    typeset -f stdlib_cite $*
}

: <<EOF
License: The MIT License

Copyright © 2012 Erich Smith

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be included in all copies
or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
EOF
