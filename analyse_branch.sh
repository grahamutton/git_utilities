#!/bin/bash

analyse_branch() {
    # Usage
    #
    # Called via bash from within a git repo
    # analyse_branch [<feature_branch>] [<upstream_branch>]...
    #
    # ...or as a git alias
    # git analyse [<feature_branch>] [<upstream_branch>]...
    #
    # This git alias syntax assumes an git alias has been configured like:
    # analyse = !bash --login -c 'analyse_branch -g "$@"'
    # ...and that this function will be loaded via .bash_profile or similar
    #
    # Parameters:
    # <feature_branch> is the name of the branch to analyse in relation to <upstream_branch>s
    # <upstream_branch> is each upstream branch to relate <feature_branch> to
    #
    # If no params passed* then feature_branch will default to HEAD
    # if no upstream_branch params passed then defaults to "master"
    # * when invoking via git alias (see below), at least 1 parameter is required to avoid errors
    #
    # Usage examples shown:
    # > analyse_branch fix_some_important_issue
    # > git <alias_name> fix_some_important_issue
    # would analyse branch fix_some_important_issue in relation to master
    #
    # analyse_branch fix_some_important_issue master qa
    # would analyse branch fix_some_important_issue in relation to master and qa
    #
    # analyse_branch
    # would analyse the current branch in relation to master


    # we need to cope with being called directly by bash but also from a git alias.
    # When being invoked via git alias, the first argument gets set to $0 and so
    # is not present in $@ (which contains $1 $2...)
    # Therefore when invoked from git we reset $@ to include $0 at the beginning.
    # We can determine this function was invoked by a git alias by it passing the
    # -g option
    while getopts "g" opt; do
        case $opt in
            g)
                shift
                set -- $0 "$@"
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                ;;
        esac
    done


    : git branch
    # Formatting vars
    f_bold=$(tput bold)
    f_und=$(tput smul)
    f_normal=$(tput sgr0)
    f_col1=$(tput setf 1)
    f_col2=$(tput setf 2)
    f_col3=$(tput setf 3)
    f_col4=$(tput setf 4)

    feature_br=${1:-HEAD}

    if [ $# -gt 1 ]; then
      shift
      upsteam_brs=$@
    else
      # @TODO bring in defaults from uncommitted config file
      upsteam_brs="master"
    fi

    if [ $feature_br = "HEAD" ]; then
        feature_br=$(git symbolic-ref --short HEAD)
    fi

    # Check that feature branch is not included in upstream branches as this will cause an error
    for branch in $upsteam_brs; do
        if [ "$branch" = "$feature_br" ]; then
            echo "Cannot proceed with branch [$branch] both as the feature branch and an upstream branch"
            exit 1;
        fi
    done


    git_initial_fork_point () {
        # thanks to http://stackoverflow.com/a/4991675/14162
        diff -u <(git rev-list --first-parent "${1:-master}") <(git rev-list --first-parent "${2:-HEAD}") | sed -ne "s/^ //p" | head -1
    }

    echo -e "${f_bold}Analysis of branch: ${f_und}${feature_br}${f_normal}\n"

    for upstream_br in $upsteam_brs; do
        initial_fork_point=$(git rev-parse --short $(git_initial_fork_point $upstream_br $feature_br))
        time_ago_to_initial_fork=$(git log -n1 $initial_fork_point --format="%ar")
        distance_to_intial_fork_point=$(git rev-list $feature_br ^$initial_fork_point --count)

        merge_base=$(git rev-parse --short $(git merge-base $upstream_br $feature_br))
        time_ago_to_merge_base=$(git log -n1 $merge_base --format="%ar")
        distance_to_merge_base_from_feature_br=$(git rev-list --first-parent $feature_br ^$merge_base --count)
        distance_to_merge_base_from_upstream_br=$(git rev-list --first-parent $upstream_br ^$merge_base --count)

        if [ -z "$shortest_distance" ] || [ "$distance_to_intial_fork_point" -lt "$shortest_distance" ]; then
          shortest_distance=$distance_to_intial_fork_point
          branch_with_most_recent_initial_fork=$upstream_br
        fi

        echo -e "${f_col1}$feature_br in relation to ${f_und}$upstream_br${f_normal}"
        echo -e "Was forked from an ancestor of $upstream_br ${f_col4}$distance_to_intial_fork_point commits ago${f_normal} at ${f_col2}$initial_fork_point${f_normal} (${f_col3}${time_ago_to_initial_fork})${f_normal}"
        echo -e "Has most recent common ancestor (merge-base) with $upstream_br ${f_col3}${time_ago_to_merge_base}${f_normal} at ${f_col2}${merge_base}${f_normal}"
        echo -e "Distance to merge-base from ${feature_br} is ${f_col4}${distance_to_merge_base_from_feature_br} commits${f_normal}"
        echo -e "Distance to merge-base from ${upstream_br}${f_normal} is ${f_col4}${distance_to_merge_base_from_upstream_br} commits${f_normal}"
        echo -e "\n";
    done

    echo "Based on intial fork points from branches [$upsteam_brs], looks like $feature_br was forked from ${f_col2}${branch_with_most_recent_initial_fork}${f_normal}"
}
