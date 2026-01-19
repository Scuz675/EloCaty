-- EloCaty (Vanilla 1.12 / 1.18-style) – Smart Cat Rotation + Next-Action Icon
-- Author: Skazz @ Tel'Abim
-- Macro: /script EloCaty:Rota()
--
-- Slash commands:
--   /elocaty icon           -> toggle icon on/off
--   /elocaty icon 40        -> set icon size (pixels)
--   /elocaty lock           -> lock icon (disable dragging)
--   /elocaty unlock         -> unlock icon (enable dragging)
--   /elocaty help           -> show help

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
-- UI SETTINGS (icon)
--------------------------------------------------
EloCaty.ui = EloCaty.ui or {
  enabled = true,
  size = 32,
  locked = false,
  frame = nil,
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
-- SPELLBOOK LOOKUP (RANK SAFE) FOR COOLDOWNS + ICONS
--------------------------------------------------
local function FindSpellIndexPrefix(base)
  for i = 1, 300 do
    local name = GetSpellName(i, "spell")
    if not name then break end
    if name == base or string.sub(name, 1, string.len(base)) == base then
      return i
    end
  end
  return nil
end

local function SpellReady(base)
  if base == "Tiger's Fury" then
    if not EloCaty.state.tfSpellIndex then
      EloCaty.state.tfSpellIndex = FindSpellIndexPrefix("Tiger's Fury")
    end
    local idx = EloCaty.state.tfSpellIndex
    if not idx then return false end
    local s, d = GetSpellCooldown(idx, "spell")
    return (s == 0 and d == 0)
  end
  return false
end

local function SpellTextureByBase(base)
  local idx = FindSpellIndexPrefix(base)
  if idx and GetSpellTexture then
    local tex = GetSpellTexture(idx, "spell")
    if tex then return tex end
  end

  -- Fallbacks (if spell not found or API weirdness)
  local fallback = {
    ["Mark of the Wild"] = "Interface\\Icons\\Spell_Nature_Regeneration",
    ["Thorns"]           = "Interface\\Icons\\Spell_Nature_Thorns",
    ["Cat Form"]         = "Interface\\Icons\\Ability_Druid_CatForm",
    ["Prowl"]            = "Interface\\Icons\\Ability_Druid_SupriseAttack",
    ["Rake"]             = "Interface\\Icons\\Ability_Druid_Disembowel",
    ["Tiger's Fury"]     = "Interface\\Icons\\Ability_Mount_JungleTiger",
    ["Ferocious Bite"]   = "Interface\\Icons\\Ability_Druid_FerociousBite",
    ["Rip"]              = "Interface\\Icons\\Ability_GhoulFrenzy",
    ["Shred"]            = "Interface\\Icons\\Spell_Shadow_VampiricAura",
    ["Claw"]             = "Interface\\Icons\\Ability_Druid_Rake",
  }
  return fallback[base]
end

--------------------------------------------------
-- NEXT ACTION ICON FRAME
--------------------------------------------------
local function ApplyLockState()
  local f = EloCaty.ui.frame
  if not f then return end
  if EloCaty.ui.locked then
    f:EnableMouse(false)
  else
    f:EnableMouse(true)
  end
end

local function SetIconSize(px)
  px = tonumber(px)
  if not px or px < 12 then px = 12 end
  if px > 128 then px = 128 end
  EloCaty.ui.size = px
  if EloCaty.ui.frame then
    EloCaty.ui.frame:SetWidth(px)
    EloCaty.ui.frame:SetHeight(px)
  end
end

local function EnsureIconFrame()
  if EloCaty.ui.frame then return end

  local f = CreateFrame("Button", "EloCatyNextSpell", UIParent)
  f:SetFrameStrata("TOOLTIP")
  f:SetFrameLevel(1000)
  f:SetWidth(EloCaty.ui.size)
  f:SetHeight(EloCaty.ui.size)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() if not EloCaty.ui.locked then f:StartMoving() end end)
  f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(f)
  t:SetTexture("Interface\\Icons\\Ability_Druid_CatForm")
  f.tex = t

  local b = CreateFrame("Frame", nil, f)
  b:SetAllPoints(f)
  b:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })

  EloCaty.ui.frame = f
  ApplyLockState()
end

-- Pure “advisor” logic; does NOT cast anything.
function EloCaty:GetNextSpell()
  if not EloCaty.ui.enabled then return nil end

  local hasTarget = UnitExists("target") and not UnitIsDead("target")
  local canAttack = hasTarget and UnitCanAttack and UnitCanAttack("player", "target")
  local prowled   = HasAuraPrefix("player", "Prowl", false)
  local inCombat  = (UnitAffectingCombat and UnitAffectingCombat("player")) or false

  -- Out of combat buffs (only when NOT prowled)
  if EloCaty.cfg.useSelfBuffs and (not inCombat) and (not prowled) then
    if EloCaty.cfg.useMark and (not HasAuraPrefix("player", "Mark of the Wild", false)) then
      return "Mark of the Wild"
    end
    if EloCaty.cfg.useThorns and (not HasAuraPrefix("player", "Thorns", false)) then
      return "Thorns"
    end
  end

  -- If not shifted at all, suggest Cat Form
  if GetShapeshiftForm and GetShapeshiftForm() == 0 then
    return "Cat Form"
  end

  -- Prowl when no attackable target
  if EloCaty.cfg.useProwl and (not canAttack) then
    if not prowled then return "Prowl" end
    return nil
  end

  if not canAttack then return nil end

  local cp     = GetComboPoints() or 0
  local energy = UnitMana("player") or 0

  local rakeUp = HasAuraPrefix("target", "Rake", true)
  local ripUp  = HasAuraPrefix("target", "Rip", true)
  local tfUp   = HasAuraPrefix("player", "Tiger's Fury", false)

  -- Prowl opener
  if prowled and EloCaty.cfg.rakeOnce and cp == 0 and (not rakeUp) then
    return "Rake"
  end

  -- Tiger's Fury
  if EloCaty.cfg.useTigersFury
     and (not tfUp)
     and energy >= (EloCaty.cfg.tfMinEnergy or 60)
     and SpellReady("Tiger's Fury") then
    return "Tiger's Fury"
  end

  -- Bite (show Bite even while pooling)
  if cp >= (EloCaty.cfg.biteCP or 3) then
    return "Ferocious Bite"
  end

  -- Rip (once per target, tough only by default)
  if cp >= 1 and (not EloCaty.state.ripped) and (not ripUp) then
    if (not EloCaty.cfg.ripOnlyOnTough) or IsTough() then
      return "Rip"
    end
  end

-- Builder (mirror Shred -> Claw fallback properly)
if EloCaty.cfg.shredFallback then
  if IsSpellInRange and IsSpellInRange("Shred", "target") == 1 then
    return "Shred"
  end
  return "Claw"
end
return "Claw"

end

function EloCaty:UpdateNextIcon()
  EnsureIconFrame()

  if not EloCaty.ui.enabled then
    EloCaty.ui.frame:Hide()
    return
  end

  local spell = EloCaty:GetNextSpell()
  if not spell then
    EloCaty.ui.frame:Hide()
    return
  end

  local tex = SpellTextureByBase(spell)
  if tex then
    EloCaty.ui.frame.tex:SetTexture(tex)
    EloCaty.ui.frame:Show()
  else
    EloCaty.ui.frame:Hide()
  end
end

-- periodic refresh (Vanilla-safe)
do
  local updater = CreateFrame("Frame", "EloCatyIconUpdater", UIParent)
  local acc = 0
  updater:SetScript("OnUpdate", function()
    if not EloCaty or not EloCaty.UpdateNextIcon then return end
    acc = acc + arg1
    if acc >= 0.10 then
      acc = 0
      EloCaty:UpdateNextIcon()
    end
  end)
end

--------------------------------------------------
-- SLASH COMMANDS
--------------------------------------------------
local function Print(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff7c0aEloCaty|r: " .. msg)
  end
end

local function ShowHelp()
  Print("Commands:")
  Print("/elocaty icon        - toggle icon on/off")
  Print("/elocaty icon 40     - set icon size (12-128)")
  Print("/elocaty lock        - lock icon (no dragging)")
  Print("/elocaty unlock      - unlock icon (dragging)")
  Print("/elocaty help        - show this help")
end

SLASH_ELOCATY1 = "/elocaty"
SlashCmdList = SlashCmdList or {}

SlashCmdList["ELOCATY"] = function(msg)
  msg = msg or ""
  msg = string.lower(msg)

  if msg == "" or msg == "help" then
    ShowHelp()
    return
  end

  -- /elocaty icon 40
  if string.sub(msg, 1, 4) == "icon" then
    local arg = string.match(msg, "icon%s+(%d+)")
    if arg then
      SetIconSize(arg)
      EloCaty.ui.enabled = true
      EnsureIconFrame()
      EloCaty:UpdateNextIcon()
      Print("Icon size set to " .. tostring(EloCaty.ui.size) .. "px.")
      return
    end

    -- /elocaty icon (toggle)
    EloCaty.ui.enabled = not EloCaty.ui.enabled
    EnsureIconFrame()
    EloCaty:UpdateNextIcon()
    Print("Icon " .. (EloCaty.ui.enabled and "enabled" or "disabled") .. ".")
    return
  end

  if msg == "lock" then
    EloCaty.ui.locked = true
    EnsureIconFrame()
    ApplyLockState()
    Print("Icon locked.")
    return
  end

  if msg == "unlock" then
    EloCaty.ui.locked = false
    EnsureIconFrame()
    ApplyLockState()
    Print("Icon unlocked (drag with left mouse).")
    return
  end

  ShowHelp()
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
        EloCaty:UpdateNextIcon()
        return
      end

      if needMark then
        CastSpellByName("Mark of the Wild")
        if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
        EloCaty:UpdateNextIcon()
        return
      end
      if needThorns then
        CastSpellByName("Thorns")
        if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
        EloCaty:UpdateNextIcon()
        return
      end
    end
  end

  -- Ensure Cat Form for prowl/rotation
  if not EnsureCatForm() then
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    EloCaty:UpdateNextIcon()
    return
  end

  prowled = HasAuraPrefix("player", "Prowl", false)

  -- OUT OF COMBAT PROWL: only when we don't have a valid attack target
  if EloCaty.cfg.useProwl and (not canAttack) then
    if not prowled then
      CastSpellByName("Prowl")
      if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
      EloCaty:UpdateNextIcon()
      return
    end
  end

  -- If no valid target, stop here
  if not canAttack then
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    EloCaty:UpdateNextIcon()
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
    EloCaty:UpdateNextIcon()
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
    EloCaty:UpdateNextIcon()
    return
  end

  -- Bite (pooled to minimum energy)
  if cp >= (EloCaty.cfg.biteCP or 3) then
    if energy >= (EloCaty.cfg.biteMinEnergy or 60) then
      CastSpellByName("Ferocious Bite")
    end
    if EloCaty.cfg.clearErrors then UIErrorsFrame:Clear() end
    EloCaty:UpdateNextIcon()
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
    EloCaty:UpdateNextIcon()
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
  EloCaty:UpdateNextIcon()
end
