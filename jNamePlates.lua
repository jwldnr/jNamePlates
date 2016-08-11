-- locals and speed
local AddonName, Addon = ...;

local _G = _G;
local pairs = pairs;
local select = select;

local CLASS_COLORS = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS;
local ICON = {
  Alliance = '\124TInterface/PVPFrame/PVP-Currency-Alliance:16\124t',
  Horde = '\124TInterface/PVPFrame/PVP-Currency-Horde:16\124t'
}

-- helper functions
local function IsTanking(unit)
  return select(1, UnitDetailedThreatSituation('player', unit));
end

local function InCombat(unit)
  return (UnitAffectingCombat(unit) and UnitCanAttack('player', unit));
end

-- main
function Addon:Load()
  do
    local eventHandler = CreateFrame('Frame', nil);

    -- set OnEvent handler
    eventHandler:SetScript('OnEvent', function(handler, ...)
        self:OnEvent(...);
      end)

    eventHandler:RegisterEvent('PLAYER_LOGIN');
  end
end

-- frame events
function Addon:OnEvent(event, ...)
  local action = self[event];

  if (action) then
    action(self, event, ...);
  end
end

function Addon:PLAYER_LOGIN()
  self:ConfigNamePlates();
  self:HookActionEvents();
end

-- configuration (partial credits to Ketho)
function Addon:ConfigNamePlates()
  if (not InCombatLockdown()) then
    -- set distance back to 40 (down from 60)
    SetCVar('nameplateMaxDistance', 40);

    -- stop nameplates from clamping to screen
    SetCVar('nameplateOtherTopInset', -1);
    SetCVar('nameplateOtherBottomInset', -1);

    -- friendly nameplate healthbar class colors
    DefaultCompactNamePlateFriendlyFrameOptions.useClassColors = true;

    -- enemy nameplate healthbar hostile colors
    SetCVar('ShowClassColorInNameplate', 0);
    -- override any enabled cvar
    DefaultCompactNamePlateEnemyFrameOptions.useClassColors = false;

    -- disable the classification indicator on nameplates
    DefaultCompactNamePlateEnemyFrameOptions.showClassificationIndicator = false;

    -- set the selected border color on nameplates
    DefaultCompactNamePlateEnemyFrameOptions.selectedBorderColor = CreateColor(1, 1, 1, 1);
    DefaultCompactNamePlateFriendlyFrameOptions.selectedBorderColor = CreateColor(1, 1, 1, 1);

    -- prevent nameplates from fading when you move away
    SetCVar('nameplateMaxAlpha', 1);
    SetCVar('nameplateMinAlpha', 1);

    -- Prevent nameplates from getting smaller when you move away
    SetCVar('nameplateMaxScale', 1);
    SetCVar('nameplateMinScale', 1);

    -- always show names on nameplates
    for _, x in pairs({
        'Friendly',
        'Enemy'
      }) do
      for _, y in pairs({
          'displayNameWhenSelected',
          'displayNameByPlayerNameRules'
        }) do
        _G['DefaultCompactNamePlate'..x..'FrameOptions'][y] = false;
      end
    end
  end
end

-- hooks
do
  local function Frame_SetupNamePlate(frame, setupOptions, frameOptions)
    Addon:SetupNamePlate(frame, setupOptions, frameOptions);
  end

  local function Frame_UpdateHealthColor(frame)
    Addon:UpdateHealthColor(frame);
  end

  local function Frame_UpdateHealthBorder(frame)
    Addon:UpdateHealthBorder(frame);
  end

  local function Frame_UpdateName(frame)
    Addon:UpdateName(frame);
  end

  function Addon:HookActionEvents()
    hooksecurefunc('DefaultCompactNamePlateFrameSetupInternal', Frame_SetupNamePlate);
    hooksecurefunc('CompactUnitFrame_UpdateHealthColor', Frame_UpdateHealthColor);
    hooksecurefunc('CompactUnitFrame_UpdateHealthBorder', Frame_UpdateHealthBorder);
    hooksecurefunc('CompactUnitFrame_UpdateName', Frame_UpdateName);
  end
end

function Addon:SetupNamePlate(frame, setupOptions, frameOptions)
  -- set bar color and textures for health bar
  frame.healthBar.background:SetTexture('Interface\\TargetingFrame\\UI-StatusBar');
  frame.healthBar.background:SetVertexColor(0, 0, 0, 0.4);
  frame.healthBar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar');

  -- and cast bar
  frame.castBar.background:SetTexture('Interface\\TargetingFrame\\UI-StatusBar');
  frame.castBar.background:SetVertexColor(0, 0, 0, 0.4);
  frame.castBar:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar');

  -- create a border from template just like the one around the health bar
  frame.castBar.border = CreateFrame('Frame', nil, frame.castBar, 'NamePlateFullBorderTemplate');
end

function Addon:UpdateHealthColor(frame)
  if (UnitExists(frame.displayedUnit) and frame.isTanking or IsTanking(frame.displayedUnit)) then
    -- color of nameplate of unit targeting us
    local r, g, b = 1, 0, 1;

    if (r ~= frame.healthBar.r or g ~= frame.healthBar.g or b ~= frame.healthBar.b) then
      frame.healthBar:SetStatusBarColor(r, g, b);
      frame.healthBar.r, frame.healthBar.g, frame.healthBar.b = r, g, b;
    end
  end
end

function Addon:UpdateHealthBorder(frame)
  if (UnitIsUnit(frame.displayedUnit, 'target')) then
    local r, g, b = frame.healthBar.r, frame.healthBar.g, frame.healthBar.b;

    if (r ~= frame.healthBar.border.r or g ~= frame.healthBar.border.g or b ~= frame.healthBar.border.b) then
      frame.healthBar.border:SetVertexColor(r, g, b, 1);
    end
  end

  if (frame.castBar and frame.castBar.border) then
    -- color of nameplate castbar border
    local r, g, b, a = 0, 0, 0, 1;

    if (r ~= frame.castBar.border.r or g ~= frame.castBar.border.g or b ~= frame.castBar.border.b) then
      frame.castBar.border:SetVertexColor(r, g, b, a);
    end
  end
end

function Addon:UpdateName(frame)
  if (ShouldShowName(frame)) then
    local name = GetUnitName(frame.unit, false);
    frame.name:SetText(name);

    if (frame.optionTable.colorNameBySelection) then
      local level = UnitLevel(frame.unit);

      if (level == -1) then
        if (InCombat(frame.unit)) then
          frame.name:SetText(name .. '* (??)' or name);
        else
          frame.name:SetText(name .. ' (??)' or name);
        end
      else
        if (UnitIsPlayer(frame.unit)) then
          -- returns whether a unit is flagged for pvp activity
          local isPVP = UnitIsPVP(frame.unit);
          local faction = UnitFactionGroup(frame.unit);

          if (InCombat(frame.unit)) then
            -- player in combat
            frame.name:SetText((isPVP and faction) and ICON[faction] .. name .. '* (' .. level .. ')' or name .. '* (' .. level .. ')' or name);
          else
            -- player not in combat
            frame.name:SetText((isPVP and faction) and ICON[faction] .. name .. ' (' .. level .. ')' or name .. ' (' .. level .. ')' or name);
          end

          if (UnitIsEnemy('player', frame.unit)) then
            local _, class = UnitClass(frame.unit);
            local color = CLASS_COLORS[class];

            -- color enemy players name with class color
            frame.name:SetVertexColor(color.r, color.g, color.b);
          else
            -- color friendly players name white
            frame.name:SetVertexColor(1, 1, 1);
          end
        else
          if (InCombat(frame.unit)) then
            -- monster unit in combat
            frame.name:SetText(name .. '* (' .. level .. ')' or name);
          else
            -- monster unit not in combat
            frame.name:SetText(name .. ' (' .. level .. ')' or name);
          end
        end
      end

      -- we have no target
      if (UnitGUID('target') == nil) then
        -- set unit health bar alpha
        frame.healthBar:SetAlpha(1);
      else
        local nameplate = C_NamePlate.GetNamePlateForUnit('target');
        if (nameplate) then
          -- set targeted unit health bar alpha
          nameplate.UnitFrame.healthBar:SetAlpha(1);
          -- set non targeted unit health bar alpha
          frame.healthBar:SetAlpha(0.5);
        end
      end

      -- unit health bar color when we are tanking
      if (frame.isTanking or IsTanking(frame.displayedUnit)) then
        frame.name:SetVertexColor(1, 0, 0);
      else
        frame.name:SetVertexColor(1, 1, 1);
      end
    end
  end
end

-- call
Addon:Load();
