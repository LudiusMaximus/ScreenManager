local folderName, addon = ...
local L = LibStub("AceAddon-3.0"):NewAddon(folderName)


-- If monitors have different DPI settings in the operating system,
-- simultaneously switching monitor and changing the windowed size will
-- not give the expected result. We therefore have to remember
-- the relations of monitor scalings and which was the last monitor
-- before a swap.
local lastWindowedMonitor = nil
local intendedWidth       = nil
local intendedHeight      = nil
-- Monitor scalings are stored in saved variable ScreenManager_config.monitorScalings.


-- If the last monitor switch happend during fullscreen,
-- the next switch to windowed might end up with the wrong size
-- if the monitors have different DPI scalings. We compensate
-- with an extra fullscreen/windowed cycle or (in the case
-- of the pet frame visible) by applying a factor to the target size.
local lastMonitorSwitchWasFullscreen = nil


local math_floor = _G.math.floor
local math_abs   = _G.math.abs

local function Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math_floor(num * mult + 0.5) / mult
end


-- Suppress the sound effect that plays when opening/closing the profession UI.
-- Trick by MunkDev: https://www.wowinterface.com/forums/showthread.php?p=325688#post325688
local function StopLastSound()
  local _, handle = PlaySound(SOUNDKIT[next(SOUNDKIT)], "SFX", false)
  if handle then
    StopSound(handle-1)
    StopSound(handle)
  end
end


-- Return values can be used with C_VideoOptions.SetGameWindowSize().
-- The third return value is false, iff the window already has the ideal size.
local function GetIdealWindowSize(monitorId)

  local maxWidth, maxHeight = C_VideoOptions.GetDefaultGameWindowSize(monitorId):GetXY()
  -- print("GetIdealWindowSize: current monitor dimensions", maxWidth, maxHeight)

  -- Find the largest (yet smaller than fullscreen) standard window size for this monitor.
  local sizes = C_VideoOptions.GetGameWindowSizes(monitorId, false)
  for _, v in pairs(sizes) do
    local _, sizeHeight = v:GetXY()
    -- print("GetIdealWindowSize: considering", v:GetXY())
    if sizeHeight < maxHeight then
      local newWidth = sizeHeight * Round(maxWidth/maxHeight, 2)
      -- print("GetIdealWindowSize: Ideal windowed size is", newWidth, sizeHeight, "which has a smaller height than", maxWidth, maxHeight, "but retains the same aspect ratio.")

      -- Calcualte if resize is even needed.
      local currentWidth, currentHeight = C_VideoOptions.GetCurrentGameWindowSize():GetXY()
      -- print("GetIdealWindowSize Current window size is", currentWidth, currentHeight)
      local resizeNeeded = (newWidth ~= currentWidth) or (sizeHeight ~= currentHeight)

      return newWidth, sizeHeight, resizeNeeded
    end
  end
end





-- ===================================================================
-- "apply proxy" pattern: taint-free UpdateWindow()
-- ===================================================================
--
-- Calling UpdateWindow() directly from our addon synchronously fires
-- OnSizeChanged on every resizable frame. Those handlers read values
-- from secure APIs (e.g. healthbar:GetMinMaxValues()) while running on
-- our addon's tainted call stack, which then makes Blizzard UI code
-- throw errors such as
--   "attempt to compare local 'maxHealth' (a secret number value
--    tainted by 'ScreenManager')"
-- inside UnitFrameHealPredictionBars_Update whenever PetFrame (or any
-- similar unit frame) is visible.
--
-- The only way to run UpdateWindow() with a clean stack is to have
-- the game engine itself initiate the call chain.
--
-- The solution: SettingsPanel.ApplyButton's OnClick already does
-- SettingsPanelMixin:Commit() -> ... -> UpdateWindow() securely when
-- the button is clicked by a real user action. We create a hidden
-- SecureActionButton whose "click" action forwards to the ApplyButton,
-- and bind the user's hotkey to this proxy via SetOverrideBindingClick.
-- When the key is pressed:
--   1. WoW's C input layer calls proxy:Click() from a secure stack.
--   2. SECURE_ACTIONS.click (Blizzard code in SecureTemplates.lua)
--      reads the 'clickbutton' attribute as data -- just a table
--      reference, no addon Lua executed -- and calls
--      ApplyButton:Click(), still on the secure stack.
--   3. ApplyButton's OnClick -> Commit() -> UpdateWindow() all run
--      without any addon Lua on the stack, so every value produced
--      downstream (including those read by OnSizeChanged handlers)
--      stays untainted.
--
-- PreClick, however, is attached via SetScript from our addon, so it
-- *does* run on our stack. We use it only to *stage* values via
-- Settings.SetValue; the apply itself has to happen through the
-- secure dispatch that follows PreClick's return.
--
-- Cost: the Settings commit triggers the GAME_SETTINGS_TIMED_CONFIRMATION
-- popup ("Keep these display settings?"). We auto-dismiss it via the
-- StaticPopup_Show hook at the top of this file.
-- ===================================================================


local autoCloseSettingsConfirmation = false
local uiParentWasHiddenForSettings = false
local petFrameWasShownForSettings = false
hooksecurefunc("StaticPopup_Show", function(which, args)

  if which ~= "GAME_SETTINGS_TIMED_CONFIRMATION" or not autoCloseSettingsConfirmation then return end

  StopLastSound()
  for i = 1, 10 do
    local frame = _G["StaticPopup" .. i]
    if frame and frame:IsShown() and frame.which and frame.which == which then

      _G["StaticPopup" .. i .. "Button1"]:Click("LeftButton")
      StopLastSound()
      -- Our immediate clicking of the button does not stop the revert timer.
      -- So we have to stop it in the next frame.
      C_Timer.After(0, function() SettingsPanel:CancelPendingRevertTimer() end)

      autoCloseSettingsConfirmation = false
      if SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
        -- If UIParent was hidden before we showed it for the settings, hide it again.
        if uiParentWasHiddenForSettings then
          UIParent:Hide()
          uiParentWasHiddenForSettings = false
          -- If PetFrame was shown before we hid it, show it again.
          -- This is possible without taint here, because we are on the secure "apply button click" path.
          if petFrameWasShownForSettings and PetFrame then
            PetFrame:Show()
            petFrameWasShownForSettings = false
          end
        end
      end

    end
  end

end)



-- Shared setup for both proxies' secure-path PreClicks: arm the auto-dismiss flag
-- for the GAME_SETTINGS_TIMED_CONFIRMATION popup, and make sure the SettingsPanel
-- is visible so the upcoming ApplyButton:Click() can actually dispatch.
-- If UIParent itself is hidden, we have to show it -- but we hide PetFrame first,
-- because PetFrame's OnShow handlers call secure APIs (e.g. GetMinMaxValues()).
-- Running them on our tainted PreClick stack would propagate taint into Blizzard
-- code. Once SettingsPanel.ApplyButton:Click() fires later from a clean secure
-- stack, the StaticPopup_Show hook restores PetFrame and UIParent without taint.
local function PrepareSecureSettingsCommit()
  autoCloseSettingsConfirmation = true
  if not SettingsPanel:IsShown() then
    if not UIParent:IsShown() then
      uiParentWasHiddenForSettings = true
      if PetFrame and PetFrame:IsShown() then
        petFrameWasShownForSettings = true
        PetFrame:Hide()
      end
      UIParent:Show()
    end
    ShowUIPanel(SettingsPanel)
  end
end



-- #################################################
-- ######### Windowed / Fullscreen toggle. #########
-- #################################################

local applyProxy = CreateFrame("Button", "ScreenManagerFullscreenApplyProxy", UIParent, "SecureActionButtonTemplate")
applyProxy:RegisterForClicks("AnyDown")
applyProxy:SetAttribute("type", "click")
applyProxy:SetAttribute("clickbutton", SettingsPanel.ApplyButton)
applyProxy:SetScript("PreClick", function()

  -- If a pet exists, we cannot use UpdateWindow() without a taint error.
  -- But we can use a secure click on the SettingsPanel's ApplyButton.
  if UnitExists("pet") then

    -- Opening the SettingsPanel and hiding the subsequent GAME_SETTINGS_TIMED_CONFIRMATION
    -- does not work in combat. There is no better solution than to inform the user and no-op.
    if InCombatLockdown() then
      print("|cff00ccffScreenManager:|r Cannot toggle fullscreen mode during combat when a pet is summoned.")
      return
    end

    PrepareSecureSettingsCommit()


    -- If we were windowed...
    if GetCVar("gxMaximize") == "0" then
      -- Set fullscreen.
      Settings.SetValue("PROXY_DISPLAY_MODE", true)
      -- Set the monitor's default resolution (to be on the safe side).
      Settings.SetValue("PROXY_RESOLUTION", "0x0")

      -- Entering fullscreen invalidates any pending fullscreen-monitor-swap compensation.
      lastMonitorSwitchWasFullscreen = nil


    -- If we were fullscreen...
    else
      -- Set windowed.
      Settings.SetValue("PROXY_DISPLAY_MODE", false)

      -- If the option is enabled, set the window resolution to the best-fitting standard size.
      if ScreenManager_config.fullScreenToggle_windowResize then
        local newWidth, newHeight = GetIdealWindowSize(GetCVar("gxMonitor"))


        if lastMonitorSwitchWasFullscreen then
          local oldMonitor = lastMonitorSwitchWasFullscreen
          local currentMonitor = tonumber(GetCVar("gxMonitor"))

          local scalings = ScreenManager_config.monitorScalings
          if not scalings[oldMonitor] then scalings[oldMonitor] = 1 end
          if not scalings[currentMonitor] then scalings[currentMonitor] = 1 end

          -- Remember the old monitor so the DISPLAY_SIZE_CHANGED auto-correction can adjust.
          lastWindowedMonitor = oldMonitor
          intendedWidth = newWidth
          intendedHeight = newHeight

          -- The system's windowed-resolution context is still the monitor we swapped from in
          -- fullscreen, so we compensate the same way as a windowed-to-windowed monitor swap (see below).
          -- No clamp needed here: unlike the monitor-toggle case, the monitor change has
          -- already been committed, so the system is no longer validating against oldMonitor's max.
          local factor = scalings[oldMonitor] / scalings[currentMonitor]

          if factor ~= 1 then
            newWidth  = Round(newWidth  * factor, 0)
            newHeight = Round(newHeight * factor, 0)
          end

          lastMonitorSwitchWasFullscreen = nil
        end

        Settings.SetValue("PROXY_RESOLUTION", newWidth.."x"..newHeight)
      end
    end

    -- Closing of the GAME_SETTINGS_TIMED_CONFIRMATION and SettingsPanel is taken care of by the
    -- StaticPopup_Show hook (see above).



  -- If there is no pet, we can use the easy path with UpdateWindow(), which also works in combat.
  else

    -- If we were windowed...
    if GetCVar("gxMaximize") == "0" then
      SetCVar("gxMaximize", "1")

      -- Entering fullscreen invalidates any pending fullscreen-monitor-swap compensation.
      lastMonitorSwitchWasFullscreen = nil

    -- If we were fullscreen...
    else
      SetCVar("gxMaximize", "0")

      -- If the option is enabled, change window to the best-fitting standard size.
      if ScreenManager_config.fullScreenToggle_windowResize then
        -- Got to apply the previous changing back to windowed.
        local newWidth, newHeight, resizeNeeded = GetIdealWindowSize(GetCVar("gxMonitor"))
        if resizeNeeded then
          C_VideoOptions.SetGameWindowSize(newWidth, newHeight)
        end

        if lastMonitorSwitchWasFullscreen then
          -- Add another fullscreen/windows cycle which will center the window on screen.
          UpdateWindow()
          SetCVar("gxMaximize", "1")
          UpdateWindow()
          SetCVar("gxMaximize", "0")

          lastMonitorSwitchWasFullscreen = nil
        end

      end

    end

    UpdateWindow()

  end

end)


-- Route the SCREEN_MANAGER_FULLSCREEN_TOGGLE keybind through the secure proxy.
-- The binding in Bindings.xml only reserves the UI slot; pressing the key
-- goes through SetOverrideBindingClick, which fires the proxy's OnClick from
-- the input system (secure context). Calling :Click() from a Lua-script binding
-- would taint the dispatch, which is why we use an override binding instead.
local function RefreshFullscreenOverride()
  ClearOverrideBindings(applyProxy)
  local key1, key2 = GetBindingKey("SCREEN_MANAGER_FULLSCREEN_TOGGLE")
  if key1 then SetOverrideBindingClick(applyProxy, false, key1, applyProxy:GetName(), "LeftButton") end
  if key2 then SetOverrideBindingClick(applyProxy, false, key2, applyProxy:GetName(), "LeftButton") end
end







-- ###################################
-- ######### Monitor toggle. #########
-- ###################################


-- Determine which monitor the keybind should switch to next.
-- Returns nil if toggling is not possible (fewer than 2 real monitors).
-- Second and third return values indicate, if the game window is currently windowed and maximised,
-- i.e. monitor toggle is not possible.
function ComputeNextMonitor()

  -- In the returned table of GetMonitorCount(), monitor 1 is at index 2. Indices 0 and 1 are irrelevant.
  -- Hence, if you have less than 3 indices, you don't have more than 1 monitor.
  local numIndices = GetMonitorCount()
  if numIndices < 3 then return nil end

  -- gxMonitor holds the actual monitor number. So we have to add 1 to get the index in numIndices.
  local currentIndex = tonumber(GetCVar("gxMonitor")) + 1
  -- print("currentIndex", currentIndex)


  local wasWindowed = false
  local wasMaxWidth = false

  if GetCVar("gxMaximize") == "0" then
    wasWindowed = true
    local maxWidth = C_VideoOptions.GetDefaultGameWindowSize(currentIndex-1):GetXY()
    local actualWidth = GetPhysicalScreenSize()
    if actualWidth == maxWidth then
      wasMaxWidth = true
    end
  end


  -- If gxMonitor==0 (i.e. currentIndex==1), the primary monitor is used.
  -- To get the actual monitor, we have to check the isPrimary return value of GetMonitorName().
  if currentIndex == 1 then
    -- Proper monitor count only starts at index 2 (monitor 1).
    for index = 2, numIndices do
      local _, isPrimary = GetMonitorName(index)
      -- local monitorResolutionWidth, monitorResolutionHeight = C_VideoOptions.GetDefaultGameWindowSize(index-1):GetXY()
      -- print("Monitor", index-1, monitorResolutionWidth, monitorResolutionHeight, isPrimary and "(primary)" or "")
      if isPrimary then
        currentIndex = index
        break
      end
    end
  end

  -- print("currentIndex", currentIndex)

  -- Increment the monitor, modulo number of monitors.
  local nextIndex = currentIndex + 1
  if nextIndex > numIndices then
    nextIndex = 2  -- First monitor.
  end
  -- print("nextIndex", nextIndex)

  -- Returning again the actual gxMonitor monitor number.
  return nextIndex - 1, currentIndex - 1, wasWindowed, wasMaxWidth

end



local monitorProxy = CreateFrame("Button", "ScreenManagerMonitorApplyProxy", UIParent, "SecureActionButtonTemplate")
monitorProxy:RegisterForClicks("AnyDown")
monitorProxy:SetAttribute("type", "click")
monitorProxy:SetAttribute("clickbutton", SettingsPanel.ApplyButton)
monitorProxy:SetScript("PreClick", function()

  local nextMonitor, currentMonitor, wasWindowed, wasMaxWidth = ComputeNextMonitor()
  if not nextMonitor then return end
  -- print("Monitor after toggle:", nextMonitor)
  -- print("Last toggle happend windowed", wasWindowed)


  -- If a pet exists, we cannot use UpdateWindow() without a taint error.
  -- We then use the secure click on the SettingsPanel's ApplyButton.
  if UnitExists("pet") then

    -- Opening the SettingsPanel and hiding the subsequent GAME_SETTINGS_TIMED_CONFIRMATION
    -- does not work in combat. There is no better solution than to inform the user and no-op.
    if InCombatLockdown() then
      print("|cff00ccffScreenManager:|r Cannot toggle monitor during combat when a pet is summoned.")
      return
    end

    -- Switching monitors does not work while windowed with a maximised window.
    -- So we temporarily switch to fullscreen.
    if wasWindowed and wasMaxWidth then
      print("|cff00ccffScreenManager:|r Cannot toggle monitor when the game window is maximised and a pet is summoned.")
      return
    end


    PrepareSecureSettingsCommit()

    -- The Settings commit will apply gxMonitor and run UpdateWindow() on a secure stack.
    Settings.SetValue("PROXY_PRIMARY_MONITOR", nextMonitor)


    -- If we are windowed and the option is enabled, change window to the best-fitting standard size.
    if wasWindowed and ScreenManager_config.monitorToggle_windowResize then

      -- Shortcut variable.
      local scalings = ScreenManager_config.monitorScalings

      -- Always initialize new monitors with scaling 1.
      if not scalings[currentMonitor] then
        scalings[currentMonitor] = 1
      end
      if not scalings[nextMonitor] then
        scalings[nextMonitor] = 1
      end
      -- print("##### Coming from monitor", currentMonitor, "with scaling", ScreenManager_config.monitorScalings[currentMonitor], "going to monitor", nextMonitor, "with scaling", ScreenManager_config.monitorScalings[nextMonitor])


      -- Get ideal window size for nextMonitor.
      local newWidth, newHeight = GetIdealWindowSize(nextMonitor)

      -- Remember last windowed monitor for calculation of the scale relations.
      lastWindowedMonitor = currentMonitor
      intendedWidth = newWidth
      intendedHeight = newHeight


      -- Apply the factor based on monitor scalings.
      local factor = scalings[currentMonitor] / scalings[nextMonitor]

      if factor ~= 1 then
        -- print("Current monitor", currentMonitor, "has scaling", scalings[currentMonitor], "which is", factor, "times the scaling of monitor", nextMonitor, "which is", scalings[nextMonitor])
        -- print("So we have to multiply our intended width and height by", factor)

        newWidth = Round(newWidth * factor, 0)
        newHeight = Round(newHeight * factor, 0)
        -- print("To achieve our intended", intendedWidth, intendedHeight, "we need to set", newWidth, newHeight)

        -- We can only set the values to the maximum of the current monitor, which might be limiting
        -- when switching from a small/high-scaling monitor to a larger/low-scaling monitor.
        local monitorResolutionWidth, monitorResolutionHeight = C_VideoOptions.GetDefaultGameWindowSize(currentMonitor):GetXY()
        -- print("Current monitor", currentMonitor, "has dimensions", monitorResolutionWidth, monitorResolutionHeight)

        local limitReached = false
        if monitorResolutionWidth < newWidth then
          newHeight = Round(newHeight * monitorResolutionWidth/newWidth, 0)
          newWidth = monitorResolutionWidth
          limitReached = true
        end
        if monitorResolutionHeight < newHeight then
          newWidth = Round(newWidth * monitorResolutionHeight/newHeight, 0)
          newHeight = monitorResolutionHeight
          limitReached = true
        end
        if limitReached then
          print(("|cff00ccffScreenManager:|r The ideal window size of %1$sx%2$s could not be achieved. The best achievable size with the same aspect ratio was %3$sx%4$s. Now switching to fullscreen and back (hotkey: %5$s) will set the ideal size."):format(intendedWidth, intendedHeight, Round(newWidth/factor, 0), Round(newHeight/factor, 0), GetBindingKey(addon.fullScreenToggleBindingName) or "none"))
        end

        -- Correct intended width and height to what we realistically can achieve.
        intendedWidth = Round(newWidth / factor, 0)
        intendedHeight = Round(newHeight / factor, 0)
      end

      -- print("Setting", newWidth, newHeight, "to actually achieve", intendedWidth, intendedHeight)
      Settings.SetValue("PROXY_RESOLUTION", newWidth.."x"..newHeight)
    end

    -- Closing of the GAME_SETTINGS_TIMED_CONFIRMATION and SettingsPanel is taken care of by
    -- the StaticPopup_Show hook (see above).


  -- If there is no pet, we can use the easy path with UpdateWindow(), which also works in combat.
  else
    -- Note: Hiding PetFrame would NOT help prevent taint here, unlike in the secure path above.
    -- Why: We call UpdateWindow() directly from PreClick (on our tainted stack). By the time
    -- UpdateWindow() internally calls frame resize handlers, PetFrame's handler would run
    -- on a stack that already includes our addon taint. The taint originates from the
    -- UpdateWindow() call itself, not from frame visibility. PetFrame being hidden/shown
    -- would only matter if UpdateWindow() ran later on a clean stack (like in the secure path).

    -- Switching monitors does not work while windowed with a maximised window.
    -- So we temporarily switch to fullscreen.
    if wasWindowed and wasMaxWidth then
      -- print("Switching to fullscreen to enable monitor switch, which would not be possible for maximised window.")
      SetCVar("gxMaximize", "1")
      -- No UpdateWindow() needed between SetCVar of "gxMaximize" and "gxMonitor".
    end

    -- Switch monitor.
    SetCVar("gxMonitor", nextMonitor)

    -- If needed, return to windowed and/or set fitting window size after swap.
    if wasWindowed then

      -- If we changed to fullscreen for the monitor switch, change back to windowed.
      if GetCVar("gxMaximize") == "1" then
        -- Got to UpdateWindow so the monitor maximisation and switch is applied before minimizing it again.
        UpdateWindow()
        SetCVar("gxMaximize", "0")
      end

      -- If the option is enabled, change window to the best-fitting standard size.
      if ScreenManager_config.monitorToggle_windowResize then
        -- Got to apply the previous changes (monitor switch and possibly changing back to windowed).
        UpdateWindow()
        local newWidth, newHeight, resizeNeeded = GetIdealWindowSize(nextMonitor)
        if resizeNeeded then
          C_VideoOptions.SetGameWindowSize(newWidth, newHeight)
          -- Add another fullscreen/windows cycle which will center the window on screen.
          UpdateWindow()
          SetCVar("gxMaximize", "1")
          UpdateWindow()
          SetCVar("gxMaximize", "0")
        end
      end

    end

    UpdateWindow()
  end


  -- Only reached if no early-return fired, i.e. the swap actually happened (or was staged).
  -- Track the source monitor so the next fullscreen-to-windowed transition can compensate.
  if not wasWindowed then
    lastMonitorSwitchWasFullscreen = currentMonitor
  end

end)


-- Route the SCREEN_MANAGER_MONITOR_TOGGLE keybind through the secure proxy.
-- Same mechanism as RefreshFullscreenOverride above.
local function RefreshMonitorOverride()
  ClearOverrideBindings(monitorProxy)
  local key1, key2 = GetBindingKey("SCREEN_MANAGER_MONITOR_TOGGLE")
  if key1 then SetOverrideBindingClick(monitorProxy, false, key1, monitorProxy:GetName(), "LeftButton") end
  if key2 then SetOverrideBindingClick(monitorProxy, false, key2, monitorProxy:GetName(), "LeftButton") end
end



local bindingFrame = CreateFrame("Frame")
bindingFrame:RegisterEvent("PLAYER_LOGIN")
bindingFrame:RegisterEvent("UPDATE_BINDINGS")
bindingFrame:SetScript("OnEvent", function()
  RefreshFullscreenOverride()
  RefreshMonitorOverride()
end)








-- #################################################
-- ######### Fade in after loading screen. #########
-- #################################################


local fadeInFrame = CreateFrame("Frame")
fadeInFrame:SetAllPoints(UIParent)
fadeInFrame:SetFrameStrata("TOOLTIP")
fadeInFrame:SetFrameLevel(10000)
fadeInFrame:Show()

fadeInFrame.blackTexture = fadeInFrame:CreateTexture(nil, "ARTWORK")
fadeInFrame.blackTexture:SetAllPoints()
fadeInFrame.blackTexture:SetColorTexture(0, 0, 0, 1)

fadeInFrame:Hide()

addon.FadeIn = function()

  if not ScreenManager_config.fadeInAfterLoading then return end

  -- The first few OnUpdate have an unrealistically high elapsed time.
  local ignoreFirstFrames = 3

  local initWait = 0
  local alpha = 1

  fadeInFrame:Show()
  fadeInFrame:SetAlpha(alpha)

  fadeInFrame:SetScript("OnUpdate", function(self, elapsed)

    if ignoreFirstFrames > 0 then
      ignoreFirstFrames = ignoreFirstFrames - 1
      return
    end

    if initWait < ScreenManager_config.fadeInAfterLoading_startAfter then
      initWait = initWait + elapsed
      return
    end

    alpha = alpha - elapsed / ScreenManager_config.fadeInAfterLoading_fadeTime
    if alpha <= 0 then
      self:SetScript("OnUpdate", nil)
      self:Hide()
    else
      self:SetAlpha(alpha)
    end
  end)

end

fadeInFrame:SetScript("OnEvent", addon.FadeIn)
fadeInFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local combatCheckFrame = CreateFrame("Frame")
combatCheckFrame:Hide()
combatCheckFrame:SetScript("OnEvent", function()
  if fadeInFrame:IsShown() and ScreenManager_config.fadeInAfterLoading_notInCombat then
    fadeInFrame:Hide()
  end
end)
combatCheckFrame:RegisterEvent("PLAYER_REGEN_DISABLED")









-- ##################################################################################
-- ######### Automatic profile switching and checking for monitor scalings. #########
-- ##################################################################################

-- Our toggles trigger DISPLAY_SIZE_CHANGED several times. But we are only interested
-- in the final result. Thus, we implement a debounce timer.
local displayChangeDebounceTimer = nil

local displayChangeFrame = CreateFrame("Frame")
displayChangeFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
displayChangeFrame:SetScript("OnEvent", function()

  if displayChangeDebounceTimer then displayChangeDebounceTimer:Cancel() end
  displayChangeDebounceTimer = C_Timer.NewTimer(0.3, function()

    displayChangeDebounceTimer = nil

    -- The actual screen resolution.
    local screen_width, screen_height = GetPhysicalScreenSize()
    -- Same as:
    -- local screen_width, screen_height = C_VideoOptions.GetCurrentGameWindowSize():GetXY()

    print("DISPLAY_SIZE_CHANGED", screen_width, screen_height, Round(screen_width/screen_height, 2))



    if lastWindowedMonitor and intendedWidth and intendedHeight
        and (math_abs(screen_width-intendedWidth)/intendedWidth > 0.1 or math_abs(screen_height-intendedHeight)/intendedHeight > 0.1) then

      -- print("Expected", intendedWidth, intendedHeight, "Got", screen_width, screen_height)


      local currentMonitor = tonumber(GetCVar("gxMonitor"))
      local scalings = ScreenManager_config.monitorScalings

      print(("|cff00ccffScreenManager:|r Learned new DPI scaling ratio between monitor %1$s and monitor %2$s. Next toggle will result in better window size."):format(lastWindowedMonitor, currentMonitor))

      -- Correct scalings[currentMonitor] such that it will be correct the next time.
      -- screen_width/intendedWidth is the ratio between the real and assumed
      -- scaling-of-new-over-old; we attribute the whole error to the new monitor.
      -- Width and height should give the same ratio; average them to absorb rounding.
      local correction = (screen_width/intendedWidth + screen_height/intendedHeight) / 2
      scalings[currentMonitor] = scalings[currentMonitor] * correction
    end

    lastWindowedMonitor = nil
    intendedWidth       = nil
    intendedHeight      = nil


    -- The size as it is calculated by the UI.
    -- Width x height for a 21:9 monitor are always 1843 x 768 when you multiply GetScreenWidth() * UIParent:GetEffectiveScale()
    -- https://warcraft.wiki.gg/wiki/UI_scaling#Screen_units
    -- -- GetScreenWidth() is the same as UIParent:GetWidth()     GetScreenHeight() is the same as UIParent:GetHeight()
    -- local ui_scale = UIParent:GetEffectiveScale()
    -- local ui_width = GetScreenWidth() * ui_scale
    -- local ui_height = GetScreenHeight() * ui_scale
    -- print(Round(ui_width, 0), Round(ui_height, 0), Round(ui_width/ui_height, 2))

  end)

end)


















-- local ButtonFrameTemplate_HidePortrait = _G.ButtonFrameTemplate_HidePortrait

-- ---------------------
-- -- Constants --------
-- ---------------------

-- local CONFIG_FRAME_WIDTH = 400
-- local CONFIG_FRAME_HEIGHT = 550


-- local CONFIG_DEFAULTS = {

  -- viewportWidth  = UIParent:GetWidth(),
  -- viewportHeight = UIParent:GetHeight(),
  -- viewportX      = 0,
  -- viewportY      = 0,

-- }



-- ---------------------
-- -- Locals -----------
-- ---------------------

-- -- The config variable.
-- local config = nil



-- local function ApplySettings()

  -- -- print(config.viewportHeight, config.viewportWidth, config.viewportX, config.viewportY)


  -- local maxWidth = UIParent:GetWidth()
  -- local maxHeight = UIParent:GetHeight()



  -- local topLeftX = config.viewportX
  -- local topLeftY = config.viewportY + config.viewportHeight - maxHeight
  -- local bottomRightX = config.viewportX + config.viewportWidth - maxWidth
  -- local bottomRightY = config.viewportY

  -- if bottomRightX > 0 then bottomRightX = 0 end
  -- if topLeftY > 0 then topLeftY = 0 end


  -- WorldFrame:ClearAllPoints()
  -- WorldFrame:SetPoint("TOPLEFT", topLeftX, topLeftY)
  -- WorldFrame:SetPoint("BOTTOMRIGHT", bottomRightX, bottomRightY);

  -- -- WorldFrame:SetPoint("BOTTOMLEFT", config.viewportX, config.viewportY)
  -- -- WorldFrame:SetPoint("TOPRIGHT", config.viewportX + config.viewportWidth, config.viewportY + config.viewportHeight)

  -- -- WorldFrame:SetPoint("BOTTOMLEFT", 0, 0)
  -- -- WorldFrame:SetPoint("TOPRIGHT", SCREEN_WIDTH, SCREEN_HEIGHT)

-- end



-- local function AddSlider(parentFrame, anchor, offsetX, offsetY, sliderTitle, variableName, minValue, maxValue, valueStep, valueChangedFunction)
  -- local slider = CreateFrame("Slider", "screenManager_"..variableName.."Slider", parentFrame, "OptionsSliderTemplate")
  -- slider:SetPoint(anchor, offsetX, offsetY)
  -- slider:SetWidth(CONFIG_FRAME_WIDTH - 110)
  -- slider:SetHeight(17)
  -- slider:SetMinMaxValues(minValue, maxValue)
  -- slider:SetValueStep(valueStep)
  -- slider:SetObeyStepOnDrag(true)
  -- slider:SetValue(config[variableName])

  -- _G[slider:GetName() .. 'Low']:SetText(minValue)
  -- _G[slider:GetName() .. 'High']:SetText(maxValue)
  -- _G[slider:GetName() .. 'Text']:SetText(sliderTitle)

  -- slider.valueLabel = parentFrame:CreateFontString("screenManager_"..variableName.."SliderValueLabel", "OVERLAY")
  -- slider.valueLabel:SetFontObject("Game12Font")
  -- slider.valueLabel:SetTextColor(1, 1, 1)
  -- slider.valueLabel:SetPoint("LEFT", slider, "RIGHT", 15, 0)
  -- slider.valueLabel:SetWidth(50)
  -- slider.valueLabel:SetJustifyH("CENTER")
  -- slider.valueLabel:SetText(config[variableName])

  -- slider:SetScript("OnValueChanged", function(self, value)
      -- config[variableName] = value
      -- self.valueLabel:SetText(value)
      -- if valueChangedFunction then valueChangedFunction(self, value) end
    -- end
  -- )

  -- slider:SetScript("OnMouseUp", function(self, value)
      -- ApplySettings()
    -- end
  -- )

-- end



-- local cf = nil

-- local function DrawConfigFrame()

  -- if cf then return end

  -- cf = CreateFrame("Frame", "screenManager_configFrame", UIParent, "ButtonFrameTemplate")

  -- cf:SetPoint("TOPLEFT")
  -- ButtonFrameTemplate_HidePortrait(cf)
  -- -- SetPortraitToTexture(...)
  -- -- ButtonFrameTemplate_HideAttic(cf)
  -- -- ButtonFrameTemplate_HideButtonBar(cf)

  -- cf:SetFrameStrata("HIGH")
  -- cf:SetWidth(CONFIG_FRAME_WIDTH)
  -- cf:SetHeight(CONFIG_FRAME_HEIGHT)
  -- cf:SetMovable(true)
  -- cf:EnableMouse(true)
  -- cf:RegisterForDrag("LeftButton")
  -- cf:SetScript("OnDragStart", cf.StartMoving)
  -- cf:SetScript("OnDragStop", cf.StopMovingOrSizing)
  -- cf:SetClampedToScreen(true)


  -- _G[cf:GetName().."TitleText"]:SetText("Screen Manager - Config")
  -- _G[cf:GetName().."TitleText"]:ClearAllPoints()
  -- _G[cf:GetName().."TitleText"]:SetPoint("TOPLEFT", 10, -6)


  -- -- print("DrawConfigFrame", UIParent:GetWidth(), UIParent:GetHeight())

  -- AddSlider(cf.Inset, "TOPLEFT", 20, -20, "Viewport width", "viewportWidth", 0, UIParent:GetWidth(), 1)
  -- AddSlider(cf.Inset, "TOPLEFT", 20, -60, "Viewport height", "viewportHeight", 0, UIParent:GetHeight(), 1)
  -- AddSlider(cf.Inset, "TOPLEFT", 20, -100, "Viewport X", "viewportX", 0, UIParent:GetWidth(), 1)
  -- AddSlider(cf.Inset, "TOPLEFT", 20, -140, "Viewport Y", "viewportY", 0, UIParent:GetHeight(), 1)


  -- tinsert(UISpecialFrames, cf:GetName())

-- end



-- local addonLoadedFrame = CreateFrame("Frame")
-- addonLoadedFrame:RegisterEvent("ADDON_LOADED")

-- addonLoadedFrame:SetScript("OnEvent", function(self, event, arg1)
  -- if arg1 == folderName then

    -- if not config then
      -- config = CONFIG_DEFAULTS
    -- else

      -- -- Remove obsolete values from saved variables.
      -- for k in pairs (config) do
        -- if CONFIG_DEFAULTS[k] == nil then
          -- config[k] = nil
        -- end
      -- end

      -- -- Fill missing values.
      -- for k, v in pairs (CONFIG_DEFAULTS) do
        -- if config[k] == nil then
          -- config[k] = v
        -- end
      -- end


    -- end




  -- end
-- end)








-- -- For debugging!
-- local startupFrame = CreateFrame("Frame")
-- startupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- startupFrame:SetScript("OnEvent", function()

  -- DrawConfigFrame()

  -- ApplySettings()

  -- cf:Show()
-- end)