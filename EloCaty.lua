-- EloCaty (Vanilla 1.12/1.18-style) – Smart Cat Rotation + Prowl + OOC Buffs (fixed)
-- Author: Skazz @ Tel'Abim
-- Macro: /script EloCaty:Rota()

EloCaty = EloCaty or {}

--------------------------------------------------
-- CONFIG
--------------------------------------------------
EloCaty.cfg = {
  biteCP = 3,
  biteMinEnergy = 60,

  useProwl = true,
  rakeOnce = true,

  -- Self buffs (ONLY out of combat AND not prowled)
  useSelfBuffs = true,
  useMark = true,
  useThorns = true,

  -- Rip behavior (once per target)
  ripOnlyOnTough = true,
  toughHP = 1800,
  toughLevelDiff = 2,

  poolEnergy = true,
  shredFallback = true,

  useTigersFury = true,
  tfMinEnergy = 60,

  clearErrors = true,
}

--------------------------------------------------
-- STATE
--------------------------------------------------
EloCaty.state = EloCaty.state or {
  lastTargetSig = nil,
  ripped = false,

  tfSpellIndex = nil,

  lastEnergy = 0,
}

--------------------------------------------------
-- ENERGY TRACKING (lightweight)
--------------------------------------------------
local energyFrame = CreateFrame("Frame", "EloCatyEnergyFrame", UIParent)
energyFrame:RegisterEvent("UNIT_ENERGY")
energyFrame:SetScript("OnEvent", function()
  EloCaty.state.lastEnergy = UnitMana("player") or 0
end)

local function ShouldPool(cost)
  if not EloCaty.cfg.poolEnergy then return false end
  return (UnitMana("player") or 0) < cost
end

--------------------------------------------------
-- TOOLTIP SCANNING (BUFFS/DEBUFFS) – rank-agnostic prefix match
--------------------------------------------------
local tip = CreateFrame("GameTooltip", "EloCatyTip", UIParent, "GameTooltipTemplate")

local function HasAuraPrefix(unit, baseName, isDebuff)
  local n = string.len(baseName)
  for i = 1, 16 do
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    if isDebuff then
      tip:SetUnitDebuff(unit, i)
    else
      tip:SetUnitBuff(unit, i)
    end
    local text = EloCatyTipTextLeft1 and EloCatyTipTextLeft1:GetText() or nil
    tip:Hide()
    if not text then break end
    if text == baseName or string.sub(text, 1, n) == baseName then
      return true
    end
  end
  return false
end

--------------------------------------------------
-- HELPERS
--------------------------------------------------
local function StartAttack()
  for i = 1, 172 do
    if IsAttackAction(i) then
      if not IsCurrentAction(i) then
        UseAction(i)
      end
      break
    end
  end
end

local function EnsureCatForm()
  local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
  if n <= 0 then return true end

  for i = 1, n do
    local _, name, active = GetShapeshiftFormInfo(i)
    if name == "Cat Form" then
      if not active then
        CastShapeshiftForm(i)
        return false
      end
      return true
    end
  end
  return true
end

local function DropShapeshift()
  local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
  for i = 1, n do
    local _, _, active = GetShapeshiftFormInfo(i)
    if active then
      CastShapeshiftForm(i)
      return
    end
  end
end

local function IsTough()
  local c = UnitClassification and UnitClassification("target") or "normal"
  if c == "elite" or c == "rareelite" or c == "worldboss" then return true end

  local hpmax = UnitHealthMax and UnitHealthMax("target") or 0
  if hpmax >= (EloCaty.cfg.toughHP or 1800) then return true end

  local tl = UnitLevel("target")
  local pl = UnitLevel("player")
  if tl and pl and tl >= (pl + (EloCaty.cfg.toughLevelDiff or 2)) then return true end

  return false
end

--------------------------------------------------
-- SPELLBOOK LOOKUP (RANK SAFE) FOR COOLDOWNS
--------------------------------------------------
local function FindSpellIndex(base)
  for i = 1, 300 do
    local name = GetSpellName(i, "spell")
    if not name then break end
    if string.sub(name, 1, string.len(base)) == base then
      return i
    end
  end
  return nil
end

local function SpellReady(base)
  if base == "Tiger's Fury" then
    if not EloCaty.state.tfSpellIndex then
      EloCaty.state.tfSpellIndex = FindSpellIndex("Tiger's Fury")
    end
    local idx = EloCaty.state.tfSpellIndex
    if not idx then return false end
    local s, d = GetSpellCooldown(idx, "spell")
    return (s == 0 and d == 0)
  end
  return false
end

--------------------------------------------------
-- MAIN ROTATION
--------------------------------------------------
function EloCaty:Rota()
  local hasTarget = UnitExists("target") and not UnitIsDead("target")
  local canAttack = hasTarget and UnitCanAttack and UnitCanAttack("player", "target")

  local prowled = HasAuraPrefix("player", "Prowl", false)
  local inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or false

  -- OUT OF COMBAT BUFFS (only when NOT prowled). Requires caster form.
  if EloCaty.cfg.useSelfBuffs and (not inCombat) and (not prowled) then
    local needMark = EloCaty.cfg.useMark and (not HasAuraPrefix("player", "Mark of the Wild", false))
    local needThorns = EloCaty.cfg.useThorns and (not HasAuraPrefix("player", "Thorns", false))

    if needMark or needThorns then
      if GetShapeshiftForm and GetShapeshiftForm() ~= 0 then
        DropShapeshift()
        if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
        return
      end

      if needMark then
        CastSpellByName("Mark of the Wild")
        if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
        return
      end
      if needThorns then
        CastSpellByName("Thorns")
        if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
        return
      end
    end
  end

  -- Ensure Cat Form for prowl/rotation
  if not EnsureCatForm() then
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    return
  end

  prowled = HasAuraPrefix("player", "Prowl", false)

  -- OUT OF COMBAT PROWL: only when we don't have a valid attack target
  if EloCaty.cfg.useProwl and (not canAttack) then
    if not prowled then
      CastSpellByName("Prowl")
      if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
      return
    end
  end

  -- If no valid target, stop here
  if not canAttack then
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    return
  end

  -- Target signature
  local sig = (UnitName("target") or "?") .. ":" .. (UnitLevel("target") or 0) .. ":" .. (UnitHealthMax("target") or 0)
  if sig ~= EloCaty.state.lastTargetSig then
    EloCaty.state.lastTargetSig = sig
    EloCaty.state.ripped = false
  end

  local cp = GetComboPoints() or 0
  local energy = UnitMana("player") or 0

  local rakeUp = HasAuraPrefix("target", "Rake", true)
  local ripUp  = HasAuraPrefix("target", "Rip", true)
  local tfUp   = HasAuraPrefix("player", "Tiger's Fury", false)
  prowled      = HasAuraPrefix("player", "Prowl", false)

  -- PROWL OPEN: While prowled, try Rake BEFORE starting auto attack.
  if prowled and EloCaty.cfg.rakeOnce and cp == 0 and (not rakeUp) then
    if not ShouldPool(35) then
      CastSpellByName("Rake")
    end
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    return
  end

  -- Now start auto-attack (after opener chance)
  StartAttack()

  -- Tiger's Fury
  if EloCaty.cfg.useTigersFury
     and (not tfUp)
     and energy >= (EloCaty.cfg.tfMinEnergy or 60)
     and SpellReady("Tiger's Fury") then
    CastSpellByName("Tiger's Fury")
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    return
  end

  -- Bite (pooled to minimum energy)
  if cp >= (EloCaty.cfg.biteCP or 3) then
    if energy >= (EloCaty.cfg.biteMinEnergy or 60) then
      CastSpellByName("Ferocious Bite")
    end
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    return
  end

  -- Rip once per target (tough mobs only)
  if cp >= 1 and (not EloCaty.state.ripped) and (not ripUp) then
    if (not EloCaty.cfg.ripOnlyOnTough) or IsTough() then
      if not ShouldPool(30) then
        CastSpellByName("Rip")
        EloCaty.state.ripped = true
      end
    else
      EloCaty.state.ripped = true
    end
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    return
  end

  -- Builder
  if not ShouldPool(40) then
    if EloCaty.cfg.shredFallback then
      CastSpellByName("Shred")
    end
    CastSpellByName("Claw")
  end

  if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
end
