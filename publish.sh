#!/bin/bash

# local dev
# - proof read
# - test on other browsers

# push branch
# - set draft to false
# - run this script
# - push to branch
# - goto https://github.com/uozuAho/blog -> current branch
# - click on the netlify build badge - this shows the branch deployment
# - run lighthouse
# - open with mobile browser
# - check percy: click the tick/cross in github -> click on Details of Percy
#   snapshot -> Run npx percy snapshot public -> click the percy link in the logs
# - read in feedly
# - check with original authors if using any content

# final steps
# - set the article date to today's date
# - merge to main
# - publish (run this script)
# - push
# - goto https://github.com/uozuAho/blog -> check percy

rm -rf public
hugo
# remove blog RSS feed (use home RSS feed)
# Hugo docs are unclear on how to do this.
rm public/blog/index.xml
