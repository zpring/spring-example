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

for candidateVersion in "$candidateVersions"; do
    echo "$candidateVersion"
    git show snapshot/$candidateVersion:README.adoc
done
