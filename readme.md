# My blog

This is the source of my site: https://iamwoz.com

# Local dev
Install:
- [Hugo](https://gohugo.io/) (currently using v0.111.3)
- (optional) [Spell Right VS Code plugin](https://github.com/bartosz-antosik/vscode-spellright)

```sh
# start a new post
./newpost.sh my_super_duper_post
# run local dev server (-D to show drafts)
hugo server -D
# or, run local dev server, accessible on the local network
hugo server -D --bind 0.0.0.0
```


# Publish to the web
```sh
# build content & put in public/
# publish.sh lists more steps like proof reading, lighthouse etc.
./publish.sh
# publish to web - simples!
git push
```


# todo
- amend netlify related posts
- include only links in rss
- make inline code like `this` prettier
- display tags
  - in post
  - in post list
  - page of all tags?
- light syntax highlighting for light mode
- how to find links to my posts?
- find dead links
- any SEO I should be doing?
- hello
