#!/bin/bash

# Helpers ----------------------------------------------------------------------
function assert {
  if [[ "$1" =~ "$2" ]]
  then
    printf "\033[0;32m*\033[0m"
  else
    printf "\033[0;31mx \033[0m $1 =~ $2\n"
  fi
}
function assert_not {
  if [[ "$1" =~ "$2" ]]
  then
    printf "\033[0;31mx \033[0m !($1 =~ $2)\n"
  else
    printf "\033[0;32m*\033[0m"
  fi
}
function silent {
  # eval "$1" # DEBUG
  eval "$1 > /dev/null 2> /dev/null"
}
function green {
  printf "\033[0;32m$1\033[0m\n"
}
function red {
  printf "\033[0;31m$1\033[0m\n"
}
function current_branch {
  printf $(git symbolic-ref HEAD 2> /dev/null | sed 's#refs/heads\/\(.*\)#\1#')
}
function setup {
  if ! [[ "$(pwd)" =~ /ora-cli-bash$ ]]
  then
    red "$(pwd) is not the root"
    exit
  fi

  rm -rf ./test
  mkdir test
  mkdir test/server
  silent '(cd test/server && git init --bare)'
  silent 'git clone test/server test/client'
  cd test/client
  silent 'touch test.txt'
  silent 'git add -A'
  silent 'git commit -m "add test.txt"'
  silent 'git push origin master'

  silent 'git checkout -b develop'
  silent 'git push origin develop'
  silent 'git checkout -b staging'
  silent 'git push origin staging'

  silent 'git checkout develop'
}

# new_branch -------------------------------------------------------------------
# Fail on dirty develop branch
$(setup)
cd test/client
silent 'touch test2.txt'
silent '../../ora new_branch branch1'
assert $(current_branch) 'develop' # Fail: dirty develop
cd ../..

# Success with pulling develop
$(setup)
cd test/client
silent 'touch test2.txt'
silent 'git add -A'
silent 'git commit -m "add test2.txt"'
silent 'git push origin develop'
silent 'git reset HEAD~ --hard'
silent '../../ora new_branch branch1'
assert $(current_branch) 'branch1'
assert "$(ls)" 'test2.txt'
cd ../..

# Stash dirty
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent 'touch test2.txt'
silent '../../ora new_branch branch2'
assert $(current_branch) 'branch2'
assert "$(git status)" 'nothing to commit'
silent '../../ora checkout branch1'
assert "$(git status)" 'test2.txt'
cd ../..

# checkout ---------------------------------------------------------------------
# Success with dirty
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent 'touch test2.txt'
silent '../../ora checkout develop'
assert $(current_branch) 'develop'
assert "$(git status)" 'nothing to commit'
silent '../../ora checkout branch1'
assert "$(git status)" 'test2.txt'
cd ../..

# push -------------------------------------------------------------------------
# Success with merging parent branch (develop)
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent 'touch test2.txt'
silent 'git add -A'
silent 'git commit -m "add text2.txt"'
silent 'git checkout develop'
silent 'touch test3.txt'
silent 'git add -A'
silent 'git commit -m "add text3.txt"'
silent 'git push origin develop'
silent 'git checkout branch1'
silent '../../ora push'
assert "$(ls)" 'test2.txt'
assert "$(git push origin branch1 2>&1)" 'Everything up-to-date'
cd ../..

# delete -------------------------------------------------------------------------
# Success
$(setup)
cd test/client
silent 'git checkout -b branch1'
silent 'git push origin branch1'
silent '../../ora delete branch1'
assert $(current_branch) 'develop'
assert_not $(git branch) 'branch1'
assert "$(git pull origin branch1 2>&1)" 'fatal:'
cd ../..

# Not allow to delete develop/master
$(setup)
cd test/client
silent '../../ora delete master'
assert $(current_branch) 'develop'
silent '../../ora delete staging'
assert $(current_branch) 'develop'
silent '../../ora delete develop'
assert $(current_branch) 'develop'
cd ../..

# Keep dirty changes to current branch
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent '../../ora new_branch branch2'
silent 'touch test2.txt'
silent '../../ora delete branch1'
assert "$(git status)" 'nothing to commit'
silent '../../ora checkout branch2'
assert "$(ls)" 'test2.txt'
cd ../..


# staging ----------------------------------------------------------------------
# merge the current branch
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent 'touch test2.txt'
silent 'git add -A'
silent 'git commit -m "add test2.txt"'
silent '../../ora staging'
silent 'git checkout staging'
assert "$(ls)" 'test2.txt'
assert "$(git push origin staging 2>&1)" 'Everything up-to-date'
cd ../..

# keep dirty
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent 'touch test2.txt'
silent 'git add -A'
silent 'git commit -m "add test2.txt"'
silent 'touch test3.txt'
silent '../../ora staging'
assert "$(git status)" 'test3.txt'
silent 'rm test3.txt'
silent 'git checkout staging'
assert "$(ls)" 'test2.txt'
cd ../..

# master -----------------------------------------------------------------------
# merge the current branch
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent 'touch test2.txt'
silent 'git add -A'
silent 'git commit -m "add test2.txt"'
silent 'git checkout develop'
silent 'touch test3.txt'
silent 'git add -A'
silent 'git commit -m "add test3.txt"'
silent 'git checkout branch1'
silent '../../ora master v1.1.1.1'
assert $(current_branch) 'branch1'
silent 'git checkout master'
assert "$(ls)" 'test2.txt'
assert "$(ls)" 'test3.txt'
assert "$(git push origin master 2>&1)" 'Everything up-to-date'
silent 'git checkout develop'
assert "$(ls)" 'test2.txt'
assert "$(git push origin develop 2>&1)" 'Everything up-to-date'
cd ../..

# keep dirty
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent 'touch test2.txt'
silent 'git add -A'
silent 'git commit -m "add test2.txt"'
silent 'touch test3.txt'
silent '../../ora master v1.1.1.1'
assert "$(git status)" 'test3.txt'
silent 'rm test3.txt'
silent 'git checkout master'
assert "$(ls)" 'test2.txt'
cd ../..

# Fail on conflict
$(setup)
cd test/client
silent '../../ora new_branch branch1'
silent '(echo "test" > test2.txt)'
silent 'git add -A'
silent 'git commit -m "add test2.txt from branch1"'
silent 'git checkout develop'
silent '(echo "test2" > test2.txt)'
silent 'git add -A'
silent 'git commit -m "add test2.txt from develop"'
silent 'git checkout branch1'
silent '../../ora master v1.1.1.1'
assert $(current_branch) 'develop'
assert "$(git status)" 'conflict'
cd ../..

# Set tag
$(setup)
cd test/client
silent 'git checkout master'
silent 'git tag -a "v2.1.1.20" -m "tag1"'
silent 'git tag -a "v2.1.2.1" -m "tag2"'
silent '../../ora new_branch branch1'
silent '(echo "test" > test2.txt)'
silent 'git add -A'
silent 'git commit -m "add test2.txt"'
silent '../../ora master " "'
assert "$(git tag)" 'v2.1.2.2'
cd ../..

# Set custom tag
$(setup)
cd test/client
silent 'git checkout master'
silent 'git tag -a "v2.1.1.20" -m "tag1"'
silent 'git tag -a "v2.1.2.1" -m "tag2"'
silent '../../ora new_branch branch1'
silent '(echo "test" > test2.txt)'
silent 'git add -A'
silent 'git commit -m "add test2.txt"'
silent '../../ora master v2.1.2.4'
assert "$(git tag)" 'v2.1.2.4'
cd ../..

# Set tag message
$(setup)
cd test/client
silent 'git checkout master'
silent 'git tag -a "v2.1.1.2" -m "tag1"'
silent '../../ora new_branch branch1'
silent '../../ora new_branch branch2'
silent 'touch text2.txt'
silent 'git add -A'
silent 'git commit -m "add test2.txt"'
silent 'git checkout branch1'
silent 'touch test3.txt'
silent 'git add -A'
silent 'git commit -m "add test3.txt"'
silent 'git merge branch2 > /dev/null'
silent 'git commit --amend -m "12dd181 Merge pull request #1234 from ora-cli/branch2"'

silent 'git checkout branch2'
silent 'touch text4.txt'
silent 'git add -A'
silent 'git commit -m "add test4.txt"'
silent 'git checkout branch1'
silent 'touch test5.txt'
silent 'git add -A'
silent 'git commit -m "add test5.txt"'
silent 'git merge branch2 > /dev/null'
silent 'git commit --amend -m "12dd181 Merge pull request #5678 from ora-cli/branch3"'

silent '../../ora master v2.1.2.4'
assert "$(git tag -n)" "5678 ora-cli/branch3\n1234 ora-cli/branch2"
cd ../..

echo
