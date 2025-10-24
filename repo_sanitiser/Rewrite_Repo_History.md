# Detailed Step-by-Step Guide to Rewrite Repository History
## 0) Panic not. Prepare
* Work from a local machine you control.
* Do not attempt half-measures like a normal commit only, because the secret will remain in history.

## 1) Make a Backup
From the repo parent directory, run the following command to create a backup of your repository:
```bash
cp -r my-repo my-repo-backup
```
This preserves the dirty repo if you need to recover anything later.

## 2) Immediately Rotate / Revoke the Leaked Secret
* If it is an API token, key, password or similar, rotate it now at the provider console or revoke it.
* Example (Telegram): open BotFather in Telegram, select your bot, revoke old token and generate new one.
* If you cannot rotate immediately, disable the service or credentials until you can.
Why: anyone who grabbed the secret can use it even if you clean the repo later.

## 3) Clone a Fresh Copy to Operate On
`git-filter-repo` expects a fresh clone for safest operation:
```bash
cd ~/work
git clone git@github.com:<your>/<repo>.git repo-clean
cd repo-clean
```

## 4) Install the Tools
Preferred: `git-filter-repo`. Alternative: BFG Repo-Cleaner.
Install `git-filter-repo` (Debian/Ubuntu example):
```bash
sudo apt update
sudo apt install git-filter-repo -y
```
Or with pip if needed:
```bash
pip install git-filter-repo
```
If you prefer BFG:
```bash
# requires Java
sudo apt install openjdk-11-jre-headless -y
# download BFG jar from its site and use it as described in BFG docs
```

## 5) Replace the Secret in All History
Use `git-filter-repo` replace-text to replace the exact string with a safe placeholder:
```bash
git filter-repo --replace-text <(echo "SECRET_TO_REMOVE==>REPLACEMENT")
```
Example for your token:
```bash
git filter-repo --replace-text <(echo "https://api.telegram.org/botOLDTOKEN/getUpdates==>https://api.telegram.org/<TOKEN>/getUpdates")
```
Notes:
* Do not use `--path` unless you intentionally want to keep only that file. `--path` will remove other files from history.
* If `git-filter-repo` complains because the clone is not fresh, re-clone and try again, or add `--force` with caution.

## 6) Clean Current Working Tree Files
Search and replace in current files in case the secret still exists in the working tree:
```bash
# replace in a file
sed -i 's|OLD_SECRET|REPLACEMENT|g' path/to/file

# verify no matches remain
grep -R "part_of_secret_or_token" .
```

## 7) Verify the Secret is Gone from Commits
Check the specific commit or whole history:
```bash
# show file at a commit
git show <commit-ish>:path/to/file

# search commits that add/remove the string
git log -S "partial_or_full_secret" --source --all

# search across all object contents (fast check)
git grep "partial_or_full_secret" $(git rev-list --all)
```
If these return nothing, the secret has been removed.

## 8) Force-Push the Cleaned History to the Remote
Re-add or confirm your remote points where you want to push (SSH recommended):
```bash
git remote add origin git@github.com:<your>/<repo>.git   # if missing
git push --force --set-upstream origin main
```
Warning:
* Force-pushing rewrites remote history. Coordinate with any colleagues. All clones will need to be recloned or reset.

## 9) Update Working Copies and Deployments
On servers or other clones that have old history, reset them to the new remote:
```bash
# on the server or other machines with that repo
git fetch origin
git reset --hard origin/main
```
Local-only config files (for example `config.py`) that should not be in git must remain untracked and be kept out of future commits.

## 10) Rotate Secrets Again if Needed and Audit Access
* After cleaning, ensure the new token is in use and old token is invalid.
* Check logs for suspicious activity related to the leaked credential.
* If the leaked secret had broad access (e.g. cloud provider credentials), consider rotating other related credentials and reviewing IAM roles.

## 11) Prevent Future Leaks
* Add secrets to `.gitignore` or, better, keep them out of repo entirely and use environment variables, secret managers or config files not tracked. Example `.gitignore`:
```markdown
# local config
config.py
.env
```
* Use secret scanning: enable GitHub/Bitbucket secret scanning and alerting.
* Use pre-commit hooks such as pre-commit with detect-secrets or git-secrets to block commits containing secrets. Example quick install:
```bash
pip install detect-secrets pre-commit
detect-secrets-hook --register # or set up pre-commit config
```
* Add CI checks to fail when secrets are found in PRs.

## 12) Communication and Documentation
* Tell the team what happened and what was rotated.
* If the secret was customer-facing or sensitive, follow your organisation’s incident response process.
* Keep a short incident note: when, what, how it was revoked, and steps taken.

## Quick Command Summary (One-Shot Recipe)
Assuming you can rotate the secret first, then from a fresh clone:
```bash
# clone fresh
git clone git@github.com:<you>/<repo>.git repo-clean
cd repo-clean

# install (if not present)
pip install git-filter-repo

# replace secret in all history (edit the string)
git filter-repo --replace-text <(echo "OLD_SECRET==>REPLACEMENT")

# replace in working files and verify
sed -i 's|OLD_SECRET|REPLACEMENT|g' path/to/file
grep -R "part_of_old_secret" .   # should show nothing

# push cleaned history
git remote add origin git@github.com:<you>/<repo>.git   # if missing
git push --force --set-upstream origin main
```

## Final Notes and Good Practice
* Always rotate the secret first, before history rewrite, because the leak could already be exploited.
* Rewriting history is required to remove secrets from Git history, but it does not stop someone who already cloned the old repo. Assume compromise until rotated.
* Use SSH remotes for push/pull to avoid password leakage over plain HTTPS credentials.
* Keep this checklist handy in your team runbook.
