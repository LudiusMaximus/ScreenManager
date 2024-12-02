local folderName, Addon = ...
local L = LibStub("AceAddon-3.0"):GetAddon(folderName)

-- For the options menu.
local appName = "Screen Manager"


-- A local variable for saved variable ScreenManager_config for easier access.
local config

local CONFIG_DEFAULTS = {
  fadeInAfterLoading             = false,
  fadeInAfterLoading_notInCombat = true,
  fadeInAfterLoading_startAfter  = 0.2,
  fadeInAfterLoading_fadeTime    = 1.2,
}



-- If I ever do i18n for this, it would be here.
_G["BINDING_NAME_SCREEN_MANAGER_FULLSCREEN_TOGGLE"] = "Fullscreen Toggle"


local keyPressFrame = CreateFrame("Frame")
local KeyPressedFunction = function(self, key)

  if key == "ESCAPE" then
    StaticPopup_Hide("SCREEN_MANAGER_KEYBIND_PROMPT")
    return
  end

  if key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" or key == "LSHIFT" or key == "RSHIFT" then
    return
  end
  
  if IsShiftKeyDown() then
    key = "SHIFT-" .. key
  end
  if IsControlKeyDown() then
    key = "CTRL-" .. key
  end
  if IsAltKeyDown() then
    key = "ALT-" .. key
  end


  -- Check last key bind.
  local lastKey = GetBindingKey("SCREEN_MANAGER_FULLSCREEN_TOGGLE")
    
  if lastKey and lastKey == key then
    StaticPopup_Hide("SCREEN_MANAGER_KEYBIND_PROMPT")
    return
  end
  
  
  -- Check if key is already taken. GetBindingAction() returns "" if key has no action.
  local command = GetBindingAction(key)
  if command ~= "" and command ~= "SCREEN_MANAGER_FULLSCREEN_TOGGLE" then
    local data = {
      ["lastKey"] = lastKey,
      ["key"] = key,
    }
    StaticPopup_Hide("SCREEN_MANAGER_KEYBIND_PROMPT")
    StaticPopup_Show("SCREEN_MANAGER_KEYBIND_CONFIRM", key .. " is already assigned to \"" .. GetBindingName(command) .. "\". Do you really want to assign it to \"" .. GetBindingName("SCREEN_MANAGER_FULLSCREEN_TOGGLE") .. "\" instead?", _, data)
    return
  end
  
  
  -- Assign new binding.
  if lastKey then
    SetBinding(lastKey)
  end
  SetBinding(key)
  SetBinding(key, "SCREEN_MANAGER_FULLSCREEN_TOGGLE")
  StaticPopup_Hide("SCREEN_MANAGER_KEYBIND_PROMPT")
  LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
  
end


local coverOptionsFrame = CreateFrame("Frame")
coverOptionsFrame:SetFrameStrata("HIGH")
coverOptionsFrame:SetFrameLevel(10000)
coverOptionsFrame.blackTexture = coverOptionsFrame:CreateTexture(nil, "ARTWORK")
coverOptionsFrame.blackTexture:SetAllPoints()
coverOptionsFrame.blackTexture:SetColorTexture(0, 0, 0, 0.75)
coverOptionsFrame:EnableMouse(true)

local function ShowCoverOptionsFrame()

  if SettingsPanel and SettingsPanel:IsShown() then
    coverOptionsFrame:ClearAllPoints()
    coverOptionsFrame:SetPoint("TOPLEFT", SettingsPanel, "TOPLEFT", 3, -1)
    coverOptionsFrame:SetPoint("BOTTOMRIGHT", SettingsPanel, "BOTTOMRIGHT", 0, 1)
    coverOptionsFrame:Show()
  end

end


StaticPopupDialogs["SCREEN_MANAGER_KEYBIND_PROMPT"] = {

  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see https://authors.curseforge.com/forums/world-of-warcraft/general-chat/lua-code-discussion/226040-how-to-reduce-chance-of-ui-taint-from
  text = "%s",

  OnShow = function ()
    ShowCoverOptionsFrame()
    keyPressFrame:SetScript("OnKeyDown", KeyPressedFunction)
  end,
  OnHide = function()
    keyPressFrame:SetScript("OnKeyDown", nil)
    coverOptionsFrame:Hide()
  end,

  button1 = "Cancel",
  OnButton1 = function() end,
}


StaticPopupDialogs["SCREEN_MANAGER_KEYBIND_CONFIRM"] = {

  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,  -- avoid some UI taint, see https://authors.curseforge.com/forums/world-of-warcraft/general-chat/lua-code-discussion/226040-how-to-reduce-chance-of-ui-taint-from
  text = "%s",

  OnShow = function ()
    ShowCoverOptionsFrame()
  end,
  OnHide = function()
    coverOptionsFrame:Hide()
  end,

  -- So that we can have different functions for each button.
  selectCallbackByIndex = true,

  button1 = "No",
  OnButton1 = function() end,
  
  button2 = "Yes",
  OnButton2 = function(_, data)
    if data.lastKey then
      SetBinding(data.lastKey)
    end
    SetBinding(data.key)
    SetBinding(data.key, "SCREEN_MANAGER_FULLSCREEN_TOGGLE")
    LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
  end,
}



local optionsTable = {
  type = "group",
  args = {

    n01 = {order = 0.1, type = "description", name = " ",},

    fullScreenToggleGroup = {
      type = "group",
      name = "Fullscreen Toggle",
      order = 1,
      inline = true,
      args = {
                
        fullScreenToggleSpace = {order = 0, type = "description", name = " ", width = 0.04,},
        fullScreenToggleLabel = {
          order = 1,
          type = "description",
          name =  function()
                    local key = GetBindingKey("SCREEN_MANAGER_FULLSCREEN_TOGGLE")
                    if key then
                      return "Assigned Hotkey: |cffffd200" .. key .. "|r"
                    else
                      return "Assigned Hotkey: |cff808080Not Bound|r"
                    end
                  end,
          width = 1.5 - 0.04,
        },
      
        fullScreenToggleAssignButton = {
          order = 2,
          type = "execute",
          name = "New key bind",
          desc = "Assign a new hotkey binding.",
          width = "normal",
          func =  function()
                    StaticPopup_Show("SCREEN_MANAGER_KEYBIND_PROMPT", SETTINGS_BIND_KEY_TO_COMMAND_OR_CANCEL:format(GetBindingName("SCREEN_MANAGER_FULLSCREEN_TOGGLE"), GetBindingText("ESCAPE")))
                  end,
        },
        
        fullScreenToggleUnassignButton = {
          order = 2,
          type = "execute",
          name = "Unbind",
          desc = "Unassign the current binding.",
          width = "normal",
          func =  function()
                    SetBinding(GetBindingKey("SCREEN_MANAGER_FULLSCREEN_TOGGLE"))
                  end,
          disabled =  function()
                        if GetBindingKey("SCREEN_MANAGER_FULLSCREEN_TOGGLE") then return false else return true end
                      end,
        },
      },
    },
    
    n11 = {order = 1.1, type = "description", name = " ",},

    fadeInAfterLoadingGroup = {
      type = "group",
      name = "Fade in after loading screen",
      order = 2,
      inline = true,
      args = {
      
        fadeInAfterLoadingToggle = {
          order = 1,
          type = "toggle",
          name = "Enable",
          desc = "Gradually fade in from black after the loading screen.",
          width = 1,
          get = function() return config.fadeInAfterLoading end,
          set = function(_, newValue) config.fadeInAfterLoading = newValue end,
        },
      
        fadeInAfterLoadingNotInCombatToggle = {
          order = 2,
          type = "toggle",
          name = "Disable in combat",
          desc = "Directly show the game without fade when in combat.",
          width = 1,
          disabled = function() return not config.fadeInAfterLoading end,
          get = function() return config.fadeInAfterLoading_notInCombat end,
          set = function(_, newValue) config.fadeInAfterLoading_notInCombat = newValue end,
        },
        
        n21 = {order = 2.1, type = "description", name = " ",},
      
        fadeInAfterLoadingStartAfter = {
          order = 3,
          type = "range",
          name = "Seconds before fading starts",
          desc = "How long the screen stays black after the loading screen before the fade in starts.",
          min = 0,
          max = 5,
          step = .1,
          width = 1.5,
          disabled = function() return not config.fadeInAfterLoading end,
          get = function() return config.fadeInAfterLoading_startAfter end,
          set = function(_, newValue) config.fadeInAfterLoading_startAfter = newValue end,
        },
        
        blank31 = {order = 3.1, type = "description", name = " ", width = 0.1,},
        
        fadeInAfterLoadingFadeTime = {
          order = 4,
          type = "range",
          name = "Seconds to fade in",
          desc = "How long the fade in takes.",
          min = 0,
          max = 5,
          step = .1,
          width = 1.5,
          disabled = function() return not config.fadeInAfterLoading end,
          get = function() return config.fadeInAfterLoading_fadeTime end,
          set = function(_, newValue) config.fadeInAfterLoading_fadeTime = newValue end,
        },
        
        n41 = {order = 4.1, type = "description", name = " ",},
        
        fadeInAfterLoadingTest = {
          order = 5,
          type = "execute",
          name = "Test",
          desc = "Test what the fade in looks like.",
          width = "normal",
          disabled = function() return not config.fadeInAfterLoading end,
          func = Addon.FadeIn,
        },
        
        blank51 = {order = 5.1, type = "description", name = " ", width = 0.1,},
        
        fadeInAfterLoadingRestoreDefaults = {
          order = 6,
          type = "execute",
          name = "Restore defaults",
          desc = "Restore settings to the preference of the developer.",
          width = "normal",
          disabled =  function()
                        if not config.fadeInAfterLoading then return true end
                        if config.fadeInAfterLoading_notInCombat == CONFIG_DEFAULTS.fadeInAfterLoading_notInCombat and
                            config.fadeInAfterLoading_startAfter == CONFIG_DEFAULTS.fadeInAfterLoading_startAfter and
                            config.fadeInAfterLoading_fadeTime == CONFIG_DEFAULTS.fadeInAfterLoading_fadeTime then
                          return true
                        end
                      end,
          func =  function()
                    config.fadeInAfterLoading_notInCombat = CONFIG_DEFAULTS.fadeInAfterLoading_notInCombat
                    config.fadeInAfterLoading_startAfter = CONFIG_DEFAULTS.fadeInAfterLoading_startAfter
                    config.fadeInAfterLoading_fadeTime = CONFIG_DEFAULTS.fadeInAfterLoading_fadeTime
                  end,
        },
      
      },
      
    },
  },
}



function L:OnInitialize()

  ScreenManager_config = ScreenManager_config or CONFIG_DEFAULTS
  -- For easier access.
  config = ScreenManager_config

  -- Remove keys from previous versions.
  for k, v in pairs(config) do
    -- print (k, v)
    if CONFIG_DEFAULTS[k] == nil then
      -- print(k, "not in CONFIG_DEFAULTS")
      config[k] = nil
    end
  end

  -- Set CONFIG_DEFAULTS for new key.
  for k, v in pairs(CONFIG_DEFAULTS) do
    -- print (k, v)
    if config[k] == nil then
      -- print(k, "not there")
      config[k] = v
    end
  end

  LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(appName, optionsTable)
  self.optionsMenu = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(appName)
end
