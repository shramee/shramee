#!/usr/bin/env bash
# Regenerates the SVG cards in this folder, including private contributions.
#
# The cards come from a local github-stats-extended server using your own
# GitHub token, so private data never goes through a public instance.
#
# 1. Start the server. It needs the top-langs date filter and byte stats from
#    stats-organization/github-stats-extended#746. Until it merges,
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
HIDE="go%20template,bibtex%20style,css,html,less,twig,scss,sass,stylus,markdown,dockerfile,makefile,shell,batchfile,powershell,smarty,blade,handlebars,ejs,hcl,nix,procfile,vue,yacc,roff,xslt,apacheconf,hack,javascript"

# 2022 to now: repos I own, plus repos in orgs I own (admin) that I've committed to. GitHub doesn't
# record who created a repo, so committing is the proxy. Public and private.
# The card can't filter by org, so every other repo it would see is excluded by name.
# The list is built here at run time, so private repo names never get committed.
# sotap is also excluded: it holds ~42 MB of generated TeX and swamps everything else.
# Needs the gh CLI, logged in as me.
exclude_list() {
  local admin_orgs
  admin_orgs=" $(gh api user/memberships/orgs --paginate --jq '.[] | select(.role == "admin") | .organization.login' | tr '\n' ' ') "
  local keep=() drop=()
  while IFS=$'\t' read -r owner name; do
    if [ "$owner" = "$USER_NAME" ]; then
      keep+=("$name")
    elif [[ "$admin_orgs" == *" $owner "* ]] &&
      gh api "repos/$owner/$name/contributors?per_page=100" --jq '.[].login' 2>/dev/null | grep -qx "$USER_NAME"; then
      keep+=("$name")
    else
      drop+=("$name")
    fi
  done < <(gh api graphql --paginate -f query='query($endCursor: String) { viewer {
      repositories(first: 100, after: $endCursor, isFork: false,
        ownerAffiliations: [OWNER, ORGANIZATION_MEMBER, COLLABORATOR]) {
        pageInfo { hasNextPage endCursor } nodes { name owner { login } } } } }' \
    --jq '.data.viewer.repositories.nodes[] | "\(.owner.login)\t\(.name)"')
  # exclude_repo matches names only: never exclude a name one of my kept repos also uses
  { echo sotap; printf '%s\n' "${drop[@]}" | grep -vxF -f <(printf '%s\n' "${keep[@]}"); } | sort -u | paste -sd, -
}
LANGS="$SERVER/api/top-langs?username=$USER_NAME&layout=compact&langs_count=8&role=OWNER,ORGANIZATION_MEMBER,COLLABORATOR&hide=$HIDE&$THEME"

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
fetch "$LANGS&exclude_repo=$(exclude_list)&pushed_after=2022&custom_title=Languages%202022%20to%20now" top-langs-2022-now.svg
# 2014 to 2021: default card settings (repos I own, no hidden languages), only the date range and look changed
fetch "$SERVER/api/top-langs?username=$USER_NAME&layout=compact&langs_count=8&$THEME&pushed_after=2014&pushed_before=2022&custom_title=Languages%202014%20to%202021" top-langs-2014-2021.svg
