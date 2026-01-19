# EloCaty – Vanilla Smart Cat Rotation

**Author:** Skazz  
**Realm:** Tel'Abim  

EloCaty is a one-button helper addon for Vanilla-era WoW clients.

## Features
### Out of Combat
- Applies **Mark of the Wild** if missing
- Applies **Thorns** if missing
- Shifts to **Cat Form**
- Enters **Prowl** when you don't have an attackable target

### Opener
- While **Prowled**, opens with **Rake** (attempts before auto-attack)

### Combat
- Uses **Tiger's Fury** when off cooldown (rank-agnostic spellbook lookup)
- Builds combo points with **Shred → Claw fallback**
- Uses **Rip once per target** (tough mobs only by default)
- Uses **Ferocious Bite at 3+ CP**, pooled to **60 energy**

## Install
Extract the `EloCaty` folder into:
```
World of Warcraft/Interface/AddOns/
```
You should have:
```
Interface/AddOns/EloCaty/EloCaty.toc
Interface/AddOns/EloCaty/EloCaty.lua
```

## Macro
Create a macro:
```lua
/script EloCaty:Rota()
```

## Publish on GitHub
### A) Website upload (no git)
1. Create a repo on GitHub named `EloCaty` (Public).
2. In the repo, click **Add file → Upload files**.
3. Upload `EloCaty.toc`, `EloCaty.lua`, and `README.md` (from inside the EloCaty folder).
4. Commit.
5. Optional: **Releases → Draft a new release**, tag `v1.0`, attach your zip, publish.

### B) Using git (best for updates)
1. Install Git (Windows): https://git-scm.com/downloads
2. Put the files in a folder named `EloCaty`.
3. In that folder, run:
```bash
git init
git add .
git commit -m "EloCaty v1.0"
```
4. Create a GitHub repo named `EloCaty`.
5. Add remote + push:
```bash
git branch -M main
git remote add origin https://github.com/<YOUR_USERNAME>/EloCaty.git
git push -u origin main
```
6. For updates:
```bash
git add .
git commit -m "Update"
git push
```
