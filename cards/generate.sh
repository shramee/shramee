#!/usr/bin/env bash
# Regenerates the SVG cards in this folder, including private contributions.
#
# The cards come from a local github-stats-extended server using your own
# GitHub token, so private data never goes through a public instance.
#
# 1. Start the server. It needs the top-langs date filter and byte stats from
#    stats-organization/github-stats-extended#746 and #747. Until they merge,
#    use the branch on my fork:
#      git clone -b feat/top-langs-stats-format-both https://github.com/shramee/github-readme-stats github-stats-extended
#      cd github-stats-extended && pnpm install && pnpm --filter ./packages/core build
#      cd apps/backend && PAT_1="$(gh auth token)" node express.js
#    The token needs the `repo` scope to see private repositories.
# 2. Run this script from the repo root: ./cards/generate.sh
# 3. Commit the updated SVGs.
set -euo pipefail

SERVER="${SERVER:-http://localhost:9000}"
USER_NAME="shramee"
OUT="$(dirname "$0")"

# follow the viewer's light or dark GitHub theme
THEME="theme_light=light_github&theme_dark=github_dark&hide_border=true"

# markup, styling and config languages, Hack (only a few bytes), and JavaScript
HIDE="css,html,less,twig,scss,sass,stylus,markdown,dockerfile,makefile,shell,batchfile,powershell,smarty,blade,handlebars,ejs,hcl,nix,procfile,vue,yacc,roff,xslt,apacheconf,hack,javascript"

# every repo I own, belong to through an org, or collaborate on, public and private.
# stats_format=both shows the percentage and the size in bytes (GitHub doesn't expose line counts).
# sotap is excluded: it holds ~42 MB of generated TeX and swamps everything else.
LANGS="$SERVER/api/top-langs?username=$USER_NAME&layout=compact&langs_count=8&stats_format=both&card_width=450&role=OWNER,ORGANIZATION_MEMBER,COLLABORATOR&exclude_repo=sotap&hide=$HIDE&$THEME"

fetch() {
  curl -sSf "$1" -o "$OUT/$2"
  if grep -q "Something went wrong" "$OUT/$2"; then
    echo "error card returned for $2" >&2
    exit 1
  fi
  echo "wrote $2"
}

fetch "$SERVER/api?username=$USER_NAME&include_all_commits=true&show_icons=true&$THEME" stats.svg
# repos are grouped by their last push date
fetch "$LANGS&pushed_after=2022&custom_title=Languages%202022%20to%20now" top-langs-2022-now.svg
fetch "$LANGS&pushed_after=2014&pushed_before=2022&custom_title=Languages%202014%20to%202021" top-langs-2014-2021.svg
