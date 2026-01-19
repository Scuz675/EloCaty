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
