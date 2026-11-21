#!/usr/bin/env bash
#
# Change the Zonix portal admin's email and/or password, step by step.
# Wraps update_admin_login.js so nothing needs to be copied or pasted.
#
# Run from anywhere:
#   bash tool/change_admin_login.sh
#
# It finds the Firebase service-account key by itself, looking in this order:
#   1. $ZONIX_KEY (if you set it)
#   2. pit_shop/Firebase/*firebase-adminsdk*.json (next to this project)
#   3. ~/.zonix/*firebase-adminsdk*.json
#   4. ~/Downloads/*firebase-adminsdk*.json
# The key is never copied into the project and never committed.

set -euo pipefail

TOOL_DIR="$(cd "$(dirname "$0")" && pwd)"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }

bold "== Zonix admin login change =="
echo

# --- 1. Node.js -----------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  red "Node.js is not installed. Install it from https://nodejs.org and run this again."
  exit 1
fi

# --- 2. Service-account key -----------------------------------------------
KEY="${ZONIX_KEY:-}"
if [ -z "$KEY" ]; then
  for f in "$TOOL_DIR"/../../Firebase/*firebase-adminsdk*.json "$HOME"/.zonix/*firebase-adminsdk*.json "$HOME"/Downloads/*firebase-adminsdk*.json; do
    if [ -f "$f" ]; then KEY="$f"; break; fi
  done
fi
if [ -z "$KEY" ] || [ ! -f "$KEY" ]; then
  red "No Firebase service-account key found."
  echo "Get one: Firebase Console > Project settings > Service accounts >"
  echo "Generate new private key, and save it in ~/.zonix/ or ~/Downloads/."
  exit 1
fi
echo "Using key: $KEY"
echo

# --- 3. Dependencies (first run only) -------------------------------------
if [ ! -d "$TOOL_DIR/node_modules/firebase-admin" ]; then
  echo "Installing firebase-admin (first run only)..."
  (cd "$TOOL_DIR" && npm install --silent)
  echo
fi

# --- 4. What to change ----------------------------------------------------
read -r -p "Current admin email: " CURRENT_EMAIL
CURRENT_EMAIL="$(echo "$CURRENT_EMAIL" | tr -d '[:space:]')"
if [[ "$CURRENT_EMAIL" != *@* ]]; then
  red "That doesn't look like an email."
  exit 1
fi

echo
echo "What do you want to change?"
echo "  1) Password only"
echo "  2) Email only"
echo "  3) Both email and password"
read -r -p "Choose 1, 2 or 3: " CHOICE

ARGS=("$KEY" "$CURRENT_EMAIL")
NEW_EMAIL=""
case "$CHOICE" in
  1) ARGS+=(--password) ;;
  2|3)
    read -r -p "New email: " NEW_EMAIL
    NEW_EMAIL="$(echo "$NEW_EMAIL" | tr -d '[:space:]')"
    if [[ "$NEW_EMAIL" != *@* ]]; then
      red "That doesn't look like an email."
      exit 1
    fi
    ARGS+=(--email "$NEW_EMAIL")
    [ "$CHOICE" = "3" ] && ARGS+=(--password)
    ;;
  *) red "Please choose 1, 2 or 3."; exit 1 ;;
esac

# --- 5. Confirm -----------------------------------------------------------
echo
bold "About to update:"
echo "  Account:  $CURRENT_EMAIL"
[ -n "$NEW_EMAIL" ] && echo "  New email: $NEW_EMAIL"
[ "$CHOICE" != "2" ] && echo "  Password:  you'll type the new one next (hidden)"
read -r -p "Continue? (y/n): " OK
if [ "$OK" != "y" ] && [ "$OK" != "Y" ]; then
  echo "Cancelled. Nothing changed."
  exit 0
fi
echo

# --- 6. Run ---------------------------------------------------------------
cd "$TOOL_DIR"
if node update_admin_login.js "${ARGS[@]}"; then
  echo
  green "Done. Open the portal and sign in with the new details."
else
  echo
  red "Nothing was changed (see the message above)."
  exit 1
fi
