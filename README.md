# eji4h_bash_aliases
This repository use for share personal alias and startup init in unix command line. It's support for macOS and Windows (WSL2).

## How to use
1. Clone or download this repository to some place.
2. Add call .bash_aliases in bash_profile or bashrc.
Example
```
. ~/eji4h_bash_aliases/.bash_aliases
```
3. If you use adb with install in Windows, Please change your adb path in android_sdk_aliases file.

## Command list

android_sdk_aliases
- adb

flutter_aliases
- flutter

gcloud_aliases
- gc="gcloud"

gh_complete
- gh

git_aliases
- gs="git status"
- ga="git add"
- gcm="git commit"
- gd="git diff"
- gdc="git diff --cached"
- gf="git fetch"
- gl="git log --graph --all --decorate"
- gch="git checkout"
- gcht="git checkout --theirs"
- gcho="git checkout --ours"
- gcl="git clean"
- gpl="git pull"
- gps="git push"
- grs="git reset"
- grv="git revert"
- gss="git stash"
- gssa="git stash apply"
- gsmuir="git submodule update --init --recursive"
- gsmu="git submodule update"
- gpso="git push --set-upstream origin"

kubectl_aliases
- kc="kubectl"

windows_shortcut_aliases
- open="explorer.exe"
- pbcopy="clip.exe"

yarn_path
- yarn
