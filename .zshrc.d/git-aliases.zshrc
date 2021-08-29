# ----------------------
# Git Aliases
# ----------------------
alias g='git'
alias ga='git add'
alias gaa='git add .'
alias gaaa='git add --all'
alias gau='git add --update'
alias gb='git branch'
alias gbd='git branch --delete '
alias gc='git commit'
alias gcm='git commit --message'
alias gcf='git commit --fixup'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gcom='git checkout master'
alias gcos='git checkout staging'
alias gcod='git checkout develop'
alias gd='git diff'
alias gda='git diff HEAD'
alias gi='git init'
alias glg='git log --graph --oneline --decorate --all'
alias gld='git log --pretty=format:"%h %ad %s" --date=short --all'
alias gm='git merge --no-ff'
alias gma='git merge --abort'
alias gmc='git merge --continue'
alias gp='git pull'
alias gpr='git pull --rebase'
alias gr='git rebase'
alias gs='git status'
alias gss='git status --short'
alias gst='git stash'
alias gsta='git stash apply'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash save'
alias grv='git remote --verbose'
alias gsp='find . -maxdepth 1 -mindepth 1 -type d -exec sh -c "(echo {} && cd {} && git status --porcelain && echo)" \;'
alias gsqauto='/usr/share/git-core/templates/bin/squash.sh'

alias gac='git pull && git add --all && echo $([[ -f $(git rev-parse --show-toplevel)/.autocommit ]] && cat $(git rev-parse --show-toplevel)/.autocommit || echo "auto commit") | git commit -a -F - && git push origin main'
alias gacdi2e='git pull di2e master && git add --all && echo $([[ -f $(git rev-parse --show-toplevel)/.autocommit ]] && cat $(git rev-parse --show-toplevel)/.autocommit || echo "auto commit") | git commit -a -F - && git push di2e main'
alias pushit="~/project/~robert.winter/repo-template/git/git-cmd.sh"
alias gsync="~/project/~robert.winter/repo-template/gitcompare.sh"

#alias g1st="echo \"# $(git rev-parse --show-toplevel | awk '{n=split($0,a,'"'/'"''); print a[n]}')\">README.md && git add --all && git commit -am \"initial\" && git push origin master"
# Clone repo in /tmp, strip out auto commits, generate a new commit, force push, then create pull request
# git log --pretty=format:"%h %s" --since=12.weeks | grep -o 'auto commit' | wc -l
# git reset --soft HEAD~$(git log --pretty=format:"%h %s" --since=12.weeks | grep -o 'auto commit' | wc -l)
# git commit -F- <<EOF
# feat(container): Create a Nexus3 RHEL container.
#
# Ansiblize from sonatype/docker-nexus3.
#
# #AMDAP-43
# EOF
# git push --force origin master

# After pull request merge, delete forked repo, copy local fork to save area, 
# When need to do new work, create a fork without fork syncing and clone the fork
