#!/bin/bash

is_git_repo() {
    git rev-parse --show-toplevel > /dev/null 2>&1
    result=$?
    if test $result != 0; then
        >&2 echo 'Not a git repo!'
        exit $result
  fi
}

is_git_repo

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -c| --commits)
    COMMITS="$2"
    shift
    ;;
    *)
    # unknown option
    ;;
esac
shift
done

die () {
    echo >&2 `basename $0`: $*
    exit 1
}

tmpfile=$(mktemp gitblah-XXXX)
[ -f "$tmpfile" ] || die "could not get tmpfile=[$tmpfile]"
trap "rm -f $tmpfile" EXIT


datefmt=%cI

if [ -n "${COMMITS+set}" ];
then git log -n $COMMITS --pretty=format:"$datefmt | %H | %s" > $tmpfile;
else git log --pretty=format:"$datefmt | %H | %s" > $tmpfile;
fi

printf '\n' >> $tmpfile

${VISUAL:-${EDITOR:-vi}} $tmpfile


ENVFILTER=""
while read commit; do
    IFS="|" read date hash message <<< "$commit"
    if [ "$datefmt" == "%cI" ]
    then
        DATE_NO_SPACE="$(echo "${date}" | tr -d '[[:space:]]')"
    else
        DATE_NO_SPACE="$(echo "${date}")"
    fi
    
    # echo $date
    # echo $hash
    # echo $message
    
    COMMIT_ENV=$(cat <<-END
if [ \$GIT_COMMIT = $hash ];
        then
            export GIT_AUTHOR_DATE="$DATE_NO_SPACE"
            export GIT_COMMITTER_DATE="$DATE_NO_SPACE";
        fi;
END
)
    # printf '%s\n' "$COMMIT_ENV"
    ENVFILTER="$ENVFILTER$COMMIT_ENV"
done < $tmpfile

# echo $ENVFILTER
# echo "the command to be executed: "
# echo "git filter-branch -f --env-filter '$ENVFILTER' -- --all"

export FILTER_BRANCH_SQUELCH_WARNING=1
git filter-branch -f --env-filter "$ENVFILTER" -- --all

if [ $? = 0 ] ; then
    echo "Git commit dates updated. Run 'git push -f BRANCH_NAME' to push your changes."
else
    echo "Git redate failed. Please make sure you run this on a clean working directory."
fi
