#!/bin/bash
set -euo pipefail

upstreamRepository="${1:?No upstream repository specified}"
upstreamBranch="${2:?No upstream branch specified}"

for remote in $(git remote); do
    git remote get-url "$remote" | grep ".*/${upstreamRepository}[\.git$|$]" &>/dev/null && upstreamRemote="$remote"
    git remote get-url "$remote" | grep ".*/${upstreamRepository}-commercial[\.git$|$]" &>/dev/null && snapshotRemote="$remote"
done

[[ -z "$upstreamRemote" ]] && { echo "Can't find remote for $upstreamRepository" >&2; exit 1; }
[[ -z "$snapshotRemote" ]] && { echo "Can't find snapshot remote for $repupstreamRepositoryository" >&2; exit 1; }

snapshotVersions=$(git for-each-ref --format='%(refname:lstrip=4)' "refs/remotes/$snapshotRemote/snapshot/*" | sort)
releaseVersions=$(git for-each-ref --format='%(refname:lstrip=4)' "refs/remotes/$snapshotRemote/release/*" | sort)
candidateVersions=$(comm -2 -3 <(echo "$snapshotVersions") <(echo "$releaseVersions"))

echo "$candidateVersions" | while IFS= read -r candidateVersion ; do
    localAheadCount=$(git rev-list --count "$commercialRemote/snapshot/$candidateVersion".."snapshot/$candidateVersion" 2> /dev/null)
    [[ "$localAheadCount" > 0 ]] && candidateBranch="snapshot/$candidateVersion" || candidateBranch="$commercialRemote/snapshot/$candidateVersion"
    tracking=$(git show "${candidateBranch}":.github/release-train-rebase-tracking 2>/dev/null)
    if grep -q "^${repository}/${branch}$" <<< "$tracking"; then
        echo "Rebasing snapshot branch $candidateVersion"
        directory=$(git worktree list --porcelain | grep -B 2 "branch refs/heads/snapshot/$candidateVersion" | head -n 1 | awk '{print $2}')
        [[ -z "$directory" ]] && directory=$(pwd)
        pushd "$directory" > /dev/null
            branch=$(git branch --show-current)
            git checkout -q snapshot/"$candidateVersion"
            git merge -q --ff-only "$candidateBranch"
            git checkout -q "$branch"
        popd > /dev/null
    fi
done

