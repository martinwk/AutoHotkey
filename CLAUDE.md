# CLAUDE.md

## Deployment

After successfully testing a change, and in any case before/with every commit, run `copy_ahk_to_startup.bat` to deploy the scripts to the startup folder. Changes to the `.ahk` files in `lib/` only take effect after this runs — editing the repo alone does not update the running scripts.

## Documentation

Before every commit, update [README.md](README.md) to reflect the changes in that commit (new/changed hotkeys, behavior, files, or deployment steps). Keep it in sync with the code — don't let it drift.
