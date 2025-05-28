local folderName, Addon = ...
local L = LibStub("AceAddon-3.0"):NewAddon(folderName)



local math_floor = _G.math.floor
local function Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math_floor(num * mult + 0.5) / mult
end





-- #################################################
-- ######### Windowed / Fullscreen toggle. #########
-- #################################################

-- Global function to call via keybind.
ScreenManager_FullscreenToggle = function()
  if GetCVar("gxMaximize") == "0" then
    SetCVar("gxMaximize", "1")
  else
    SetCVar("gxMaximize", "0")
  end
  -- print("Toggle between fullscreen and windowed.")
  UpdateWindow()
end




-- ###################################
-- ######### Monitor toggle. #########
-- ###################################

-- Pick a window resolution suitable for this monitor with the same apect ratio.
local function FitNonMaxWindowIntoMonitor()

  if not ScreenManager_config.monitorToggle_windowResize then return end

  -- Should not be called for fullscreen. But checking to be on the safe side.
  if GetCVar("gxMaximize") == "1" then return end

  local currentMonitor = tonumber(GetCVar("gxMonitor"))
  local maxWidth, maxHeight = C_VideoOptions.GetDefaultGameWindowSize(currentMonitor):GetXY()
  local actualWidth = GetPhysicalScreenSize()

  -- Only if we are not already maximised.
  if actualWidth == maxWidth then
    -- print("No FitNonMaxWindowIntoMonitor() needed, because of maximised window.")
    return
  end

  local sizes = C_VideoOptions.GetGameWindowSizes(currentMonitor, false)
  for k, v in pairs(sizes) do
    local _, sizeHeight = v:GetXY()
    if sizeHeight < maxHeight then
      local newWidth = sizeHeight * Round(maxWidth/maxHeight, 2)
      -- print("Changing window to", newWidth, sizeHeight, "which is smaller than", maxWidth, maxHeight, "with the same aspect ratio of", Round(maxWidth/maxHeight, 2))
      C_VideoOptions.SetGameWindowSize(newWidth, sizeHeight)
      UpdateWindow()
      break
    end
  end
end



-- Global function to call via keybind.
ScreenManager_MonitorToggle = function()

  local numMonitors = GetMonitorCount()
  -- If you have 2 monitors, the game will list 3, because the "Primary" monitor is at index 0 and among the other indices.
  if numMonitors < 3 then return end
  
  
  local currentMonitor = tonumber(GetCVar("gxMonitor"))
  -- print("Monitor before toggle:", currentMonitor)


  -- Switching monitors with gxMaximize does not work when you are in maximised windowed view.
  -- So to be on the safe side we temporarily switch to fullscreen and back.
  local wasWindowed = false
  local wasMaxWidth = false
  if GetCVar("gxMaximize") == "0" then
    wasWindowed = true
    
    local maxWidth = C_VideoOptions.GetDefaultGameWindowSize(currentMonitor):GetXY()
    local actualWidth = GetPhysicalScreenSize()
    if actualWidth == maxWidth then
      wasMaxWidth = true
    end
    
    if wasMaxWidth then
      -- print("Switching to fullscreen to enable monitor switch, which would not be possible for maximised window.")
      SetCVar("gxMaximize", "1")
      UpdateWindow()
    end
  end

  
  
  local primaryMonitor = nil
  for index = 2, numMonitors do
    local _, isPrimary = GetMonitorName(index)
    if isPrimary then
      primaryMonitor = index - 1
      break
    end
  end
  if currentMonitor == 0 then currentMonitor = primaryMonitor end
  
  if currentMonitor >= numMonitors - 1 then
    currentMonitor = 1
  else
    currentMonitor = currentMonitor + 1
  end

  -- print("Monitor after toggle:", currentMonitor)
  SetCVar("gxMonitor", currentMonitor)
  UpdateWindow()
  
  if wasWindowed then
    if wasMaxWidth then
      SetCVar("gxMaximize", "0")
      -- print("Restoring windowed view.")
      UpdateWindow()
    else
      FitNonMaxWindowIntoMonitor()
    end
  end

end




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

Addon.FadeIn = function()

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
  
fadeInFrame:SetScript("OnEvent", Addon.FadeIn)
fadeInFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local combatCheckFrame = CreateFrame("Frame")
combatCheckFrame:Hide()
combatCheckFrame:SetScript("OnEvent", function()
  if fadeInFrame:IsShown() and ScreenManager_config.fadeInAfterLoading_notInCombat then
    fadeInFrame:Hide()
  end
end)
combatCheckFrame:RegisterEvent("PLAYER_REGEN_DISABLED")









-- ################################################
-- ######### Automatic profile switching. #########
-- ################################################

local desiredMonitor = nil

local displayChangeFrame = CreateFrame("Frame")
displayChangeFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
displayChangeFrame:SetScript("OnEvent", function()

  -- The actual screen resolution.
  local screen_width, screen_height = GetPhysicalScreenSize()
  -- Same as:
  -- local screen_width, screen_height = C_VideoOptions.GetCurrentGameWindowSize():GetXY()
  
  print("DISPLAY_SIZE_CHANGED", screen_width, screen_height, Round(screen_width/screen_height, 2))
  
  -- The size as it is calculated by the UI.
  -- Width x height for a 21:9 screen are always 1843 x 768 when you multiply GetScreenWidth() * UIParent:GetEffectiveScale()
  -- https://warcraft.wiki.gg/wiki/UI_scaling#Screen_units
  -- -- GetScreenWidth() is the same as UIParent:GetWidth()     GetScreenHeight() is the same as UIParent:GetHeight()
  -- local ui_scale = UIParent:GetEffectiveScale()
  -- local ui_width = GetScreenWidth() * ui_scale
  -- local ui_height = GetScreenHeight() * ui_scale
  -- print(Round(ui_width, 0), Round(ui_height, 0), Round(ui_width/ui_height, 2))

  
  
  
  -- ############################################
  -- ######### Fixes for monitor toggle. ########
  -- ############################################
  
  -- When we minimise the window with double click on the title bar, the window might snap back to its previous monitor.
  -- Check if you have been minimised form maximised to non-maximised window.
  if GetCVar("gxMaximize") == "0" then
    local currentMonitor = tonumber(GetCVar("gxMonitor"))
    local maxWidth, maxHeight = C_VideoOptions.GetDefaultGameWindowSize(currentMonitor):GetXY()
    local actualWidth = GetPhysicalScreenSize()
    
    if actualWidth == maxWidth then
      -- print("Detected full width window!")

      -- We are remembering the monitor to possibly switch it back.
      desiredMonitor = currentMonitor
      -- print("Remembering desired monitor", desiredMonitor)
      
    else
      if desiredMonitor then
        -- print("Detected switch from full-width to non-full-width window!")
        
        if desiredMonitor ~= tonumber(GetCVar("gxMonitor")) then
          -- print("Fixing snapped-back monitor from wrong", tonumber(GetCVar("gxMonitor")), "to correct", desiredMonitor)
          SetCVar("gxMonitor", desiredMonitor)
          -- print("Forgetting desired monitor", desiredMonitor)
          desiredMonitor = nil
          UpdateWindow()
        else
          -- print("No fixing of snapped-back monitor required!")
          -- print("Forgetting desired monitor", desiredMonitor)
          desiredMonitor = nil
        end
        
        FitNonMaxWindowIntoMonitor()
      end
    end
  end

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
  -- slider.valueLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
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
        -- if not CONFIG_DEFAULTS[k] then
          -- config[k] = nil
        -- end
      -- end

      -- -- Fill missing values.
      -- for k, v in pairs (CONFIG_DEFAULTS) do
        -- if not config[k] then
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