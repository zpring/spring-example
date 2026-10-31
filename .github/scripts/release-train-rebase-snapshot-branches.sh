#!/bin/bash
set -euox pipefail
{
ossRepository="${1:?No repository specified}"
ossBranch="${2:?No branch specified}"
commercialRepository=${ossRepository}-commercial

git remote -v

ossRemote=""
commercialRemote=""
for remote in $(git remote); do
    git remote get-url "${remote}" 
    git remote get-url "${remote}" | grep -E ".*/${ossRepository}(\.git|)$" &>/dev/null && ossRemote="${remote}"
    git remote get-url "${remote}" | grep -E ".*/${commercialRepository}(\.git|)$" &>/dev/null && commercialRemote="${remote}"
done

[[ -z "${ossRemote}" ]] && { echo "Can't find OSS remote for ${ossRepository}" >&2; exit 1; }
[[ -z "${commercialRemote}" ]] && { echo "Can't find commercial remote for ${commercialRepository}" >&2; exit 1; }

snapshotVersions=$(git for-each-ref --format='%(refname:lstrip=4)' "refs/remotes/${commercialRemote}/snapshot/*" | sort)
releaseVersions=$(git for-each-ref --format='%(refname:lstrip=4)' "refs/remotes/${commercialRemote}/release/*" | sort)
candidateVersions=$(comm -2 -3 <(echo "${snapshotVersions}") <(echo "${releaseVersions}"))

rebasedBranches=""
while IFS= read -r version ; do
    tracking=$(git show "${commercialRemote}/snapshot/${version}":.github/release-train-rebase-tracking 2>/dev/null || true)
    if grep -q "^${ossRepository}/${ossBranch}$" <<< "${tracking}"; then
        echo "Rebasing snapshot branch ${version}"
        directory=$(git worktree list --porcelain | grep -B 2 "branch refs/heads/snapshot/${version}" | head -n 1 | awk '{print $2}')
        [[ -z "${directory}" ]] && directory=$(pwd)
        pushd "${directory}" > /dev/null
            originalBranch=$(git branch --show-current)
            git checkout -q snapshot/"${version}"
            git merge -q --ff-only  "${commercialRemote}/snapshot/${version}"
            git rebase -q "${ossRemote}/${ossBranch}"
            rebasedBranches="${rebasedBranches:+$rebasedBranches }snapshot/${version}"
            git checkout -q "${originalBranch}"
        popd > /dev/null
    fi
done <<< "${candidateVersions}"

if [[ -n "${rebasedBranches}" ]]; then
    git push -q --atomic --force-with-lease --force-if-includes "${commercialRemote}" "${rebasedBranches}"
fi
exit
}

# https://github.com/spring-projects/spring-boot/blob/main/.github/actions/send-notification/action.yml
# https://github.com/spring-io/spring-github-workflows/blob/main/.github/actions/spring-failure-to-gchat/action.yml
# https://github.com/spring-projects/spring-aot-smoke-tests/blob/ci/.github/actions/send-notification/action.yml

