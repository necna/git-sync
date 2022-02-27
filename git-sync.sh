#!/bin/sh

set -e

SOURCE_REPO=$1
SOURCE_BRANCH=$2
DESTINATION_REPO=$3
DESTINATION_BRANCH=$4

if ! echo $SOURCE_REPO | grep -Eq ':|@|\.git\/?$'; then
  if [[ -n "$SSH_PRIVATE_KEY" || -n "$SOURCE_SSH_PRIVATE_KEY" ]]; then
    SOURCE_REPO="git@github.com:${SOURCE_REPO}.git"
    GIT_SSH_COMMAND="ssh -v"
  else
    SOURCE_REPO="https://github.com/${SOURCE_REPO}.git"
  fi
fi

if ! echo $DESTINATION_REPO | grep -Eq ':|@|\.git\/?$'; then
  if [[ -n "$SSH_PRIVATE_KEY" || -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
    DESTINATION_REPO="git@gitee.com:${DESTINATION_REPO}.git"
    GIT_SSH_COMMAND="ssh -v"
  else
    DESTINATION_REPO="https://gitee.com/${DESTINATION_REPO}.git"
  fi
fi

echo "SOURCE=$SOURCE_REPO:$SOURCE_BRANCH"
echo "DESTINATION=$DESTINATION_REPO:$DESTINATION_BRANCH"

mkdir -p /root/new_source && cd /root/new_source && git init

if [[ -n "$SOURCE_SSH_PRIVATE_KEY" ]]; then
  # Clone using source ssh key if provided
  git clone -c core.sshCommand="/usr/bin/ssh -i ~/.ssh/src_rsa" "$SOURCE_REPO" /root/source --origin master && cd /root/source
else
  git clone "$SOURCE_REPO" /root/source --origin master && cd /root/source
fi

git fast-export --signed-tags=strip --all | (cd /root/new_source && git fast-import)

# Pull all branches references down locally so subsequent commands can see them
# git fetch source '+refs/heads/*:refs/heads/*' --update-head-ok

# Print out all branches
# git --no-pager branch -a -vv

if [[ -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
  # Clone using source ssh key if provided
  git clone -c core.sshCommand="/usr/bin/ssh -i ~/.ssh/dst_rsa" "$DESTINATION_REPO" /root/dst --origin master && cd /root/dst
else
  git clone "$DESTINATION_REPO" /root/dst --origin master && cd /root/dst
fi

if [[ -n "$DESTINATION_SSH_PRIVATE_KEY" ]]; then
  # Push using destination ssh key if provided
  git config --local core.sshCommand "/usr/bin/ssh -i ~/.ssh/dst_rsa"
fi

git config user.name $USER_NAME
git config user.email $USER_EMAIL

rm -rf /root/dst/* && git add -A && git commit -m "deleted all files" && git push -f

# git push destination "${SOURCE_BRANCH}:${DESTINATION_BRANCH}" -f

cd /root/new_source
git config user.name $USER_NAME
git config user.email $USER_EMAIL
git remote add origin "$DESTINATION_REPO"
git push -f --set-upstream origin master
