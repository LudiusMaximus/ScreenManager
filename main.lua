local folderName, Addon = ...
local L = LibStub("AceAddon-3.0"):NewAddon(folderName)



local math_floor = _G.math.floor
local function Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math_floor(num * mult + 0.5) / mult
end






-- local ButtonFrameTemplate_HidePortrait = _G.ButtonFrameTemplate_HidePortrait






-- -- For debugging.
-- local function PrintTable(t, indent)
  -- assert(type(t) == "table", "PrintTable() called for non-table!")

  -- local indentString = ""
  -- for i = 1, indent do
    -- indentString = indentString .. "  "
  -- end

  -- for k, v in pairs(t) do
    -- if type(v) ~= "table" then
      -- print(indentString, k, "=", v)
    -- else
      -- print(indentString, k, "=")
      -- print(indentString, "  {")
      -- PrintTable(v, indent + 2)
      -- print(indentString, "  }")
    -- end
  -- end
-- end






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







local displayChangeFrame = CreateFrame("Frame")
displayChangeFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
displayChangeFrame:SetScript("OnEvent", function()

  -- print("DISPLAY_SIZE_CHANGED")

  -- The actual screen resolution.
  local screen_width, screen_height = C_VideoOptions.GetCurrentGameWindowSize():GetXY()
  print(screen_width, screen_height, Round(screen_width/screen_height, 2))
  
  -- The size as it is calculated by the UI.
  -- Width x height for a 21:9 screen are always 1843 x 768 when you multiply GetScreenWidth() * UIParent:GetEffectiveScale()
  -- https://warcraft.wiki.gg/wiki/UI_scaling#Screen_units
  -- GetScreenWidth() = UIParent:GetWidth()     GetScreenHeight() = UIParent:GetHeight()
  -- local ui_scale = UIParent:GetEffectiveScale()
  -- local ui_width = GetScreenWidth() * ui_scale
  -- local ui_height = GetScreenHeight() * ui_scale
  -- print(Round(ui_width, 0), Round(ui_height, 0), Round(ui_width/ui_height, 2))
  
end)









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
  UpdateWindow()
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

  fadeInFrame:SetScript("OnUpdate", function(fadeInFrame, elapsed)

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
      fadeInFrame:SetScript("OnUpdate", nil)
      fadeInFrame:Hide()
    else
      fadeInFrame:SetAlpha(alpha)
    end
  end)
  
end
  
fadeInFrame:SetScript("OnEvent", Addon.FadeIn)
fadeInFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local combatCheckFrame = CreateFrame("Frame")
combatCheckFrame:Hide()
combatCheckFrame:SetScript("OnEvent", function(self, event, ...)
  if fadeInFrame:IsShown() and ScreenManager_config.fadeInAfterLoading_notInCombat then
    fadeInFrame:Hide()
  end
end)
combatCheckFrame:RegisterEvent("PLAYER_REGEN_DISABLED")


