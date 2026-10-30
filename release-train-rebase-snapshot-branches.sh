#!/bin/bash
repository="${1:?No repository specified}"
branch="${2:?No branch specified}"

for remote in $(git remote); do
    git remote get-url "$remote" | grep ".*/${repository}[\.git$|$]" &>/dev/null && repositoryRemote="$remote"
    git remote get-url "$remote" | grep ".*/${repository}-commercial[\.git$|$]" &>/dev/null && commercialRemote="$remote"
done

[[ -z "$repositoryRemote" ]] && { echo "Can't find remote for $repository" >&2; exit 1; }
[[ -z "$repositoryRemote" ]] && { echo "Can't find commercial remote for $repository" >&2; exit 1; }

snapshotVersions=$(git for-each-ref --format='%(refname:lstrip=4)' "refs/remotes/$commercialRemote/snapshot/*" | sort)
releaseVersions=$(git for-each-ref --format='%(refname:lstrip=4)' "refs/remotes/$commercialRemote/release/*" | sort)
candidateVersions=$(comm -2 -3 <(echo "$snapshotVersions") <(echo "$releaseVersions"))

echo "$candidateVersions" | while IFS= read -r candidateVersion ; do
    localAheadCount=$(git rev-list --count "$commercialRemote/snapshot/$candidateVersion".."snapshot/$candidateVersion" 2>/dev/null)
    [[ "$localAheadCount" > 0 ]] && candidateBranch="snapshot/$candidateVersion" || candidateBranch="$commercialRemote/snapshot/$candidateVersion"
    tracking=$(git show "${candidateBranch}":.github/release-train-rebase-tracking 2>/dev/null)
    if grep -q "^${repository}/${branch}$" <<< "$tracking"; then
        echo "Rebasing snapshot branch $candidateVersion"
        

    fi
done

