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

  resolutionProfileList = {},
}


local currentResolutionProfileId = nil  -- Maybe in main.lua?

local selectedResolutionProfileId = nil
local editingResolutionProfileId = nil

local tmpEditingResolutionProfile = {}


local function SelectResolutionProfile()
  if currentResolutionProfileId then
    selectedResolutionProfileId = currentResolutionProfileId
  else
    selectedResolutionProfileId = next(config.resolutionProfileList)
  end
end



local function NewResolutionProfile()
  tinsert(config.resolutionProfileList, {name = "New Profle"})
  return #config.resolutionProfileList
end

local function StartEditingResolutionProfile(id)
  tmpEditingResolutionProfile = {}
  for k, v in pairs(config.resolutionProfileList[id]) do
    tmpEditingResolutionProfile[k] = v
  end
  editingResolutionProfileId = id
end

local function DeleteResolutionProfile(id)
  config.resolutionProfileList[id] = nil
  editingResolutionProfileId = nil
  SelectResolutionProfile()
end

local function SaveEditingResolutionProfile(id)
  for k, v in pairs(tmpEditingResolutionProfile) do
    if v ~= config.resolutionProfileList[id][k] then
      config.resolutionProfileList[id][k] = v
    end
  end
  editingResolutionProfileId = nil
end

local function CancelEditingResolutionProfile()
  tmpEditingResolutionProfile = {}
  editingResolutionProfileId = nil
end



local function GetResolutionProfileList()

  -- TODO: Meaningful sorting.
  local listToReturn = {}

  for k, v in pairs(config.resolutionProfileList) do
    listToReturn[k] = v["name"]
  end

  return listToReturn
end








-- If I ever do i18n for this, it would be here.
_G["BINDING_NAME_SCREEN_MANAGER_FULLSCREEN_TOGGLE"] = "Fullscreen Toggle"
_G["BINDING_NAME_SCREEN_MANAGER_MONITOR_TOGGLE"] = "Monitor Toggle"


local currentlyEditedCommand = nil

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
  local lastKey = GetBindingKey(currentlyEditedCommand)

  if lastKey and lastKey == key then
    StaticPopup_Hide("SCREEN_MANAGER_KEYBIND_PROMPT")
    return
  end


  -- Check if key is already taken. GetBindingAction() returns "" if key has no action.
  local command = GetBindingAction(key)
  if command ~= "" and command ~= currentlyEditedCommand then
    local data = {
      ["lastKey"] = lastKey,
      ["key"] = key,
      ["command"] = currentlyEditedCommand
    }
    StaticPopup_Hide("SCREEN_MANAGER_KEYBIND_PROMPT")
    StaticPopup_Show("SCREEN_MANAGER_KEYBIND_CONFIRM", key .. " is already assigned to \"" .. GetBindingName(command) .. "\". Do you really want to assign it to \"" .. GetBindingName(data.command) .. "\" instead?", _, data)
    return
  end


  -- Assign new binding.
  if lastKey then
    SetBinding(lastKey)
  end
  SetBinding(key)
  SetBinding(key, currentlyEditedCommand)
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

  OnShow = function (_, data)
    currentlyEditedCommand = data.command
    print(currentlyEditedCommand)
    ShowCoverOptionsFrame()
    keyPressFrame:SetScript("OnKeyDown", KeyPressedFunction)
  end,
  OnHide = function()
    currentlyEditedCommand = nil
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

  button1 = "Yes",
  OnButton1 = function(_, data)
    if data.lastKey then
      SetBinding(data.lastKey)
    end
    SetBinding(data.key)
    SetBinding(data.key, data.command)
    LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
  end,

  button2 = "No",
  OnButton2 = function() end,

}



local optionsTable = {
  type = "group",
  args = {

    n01 = {order = 0.1, type = "description", name = " ",},

    resolutionBasedLayoutsGroup = {
      order = 1,
      type = "group",
      name = "Screen Resolution-Based HUD Layouts",
      inline = true,
      args = {
        resolutionProfileSelect = {
          order = 1,
          type = "select",
          name = "Select a Profile",
          width = 2.3,
          desc = "|cFF00FF00Currently active profile is green.|r",
          get =
            function()
              return selectedResolutionProfileId
            end,
          set =
            function(_, newValue)
              selectedResolutionProfileId = newValue
              editingResolutionProfileId = nil
            end,
          values =
            function()
              return GetResolutionProfileList()
            end,
          disabled = function() return selectedResolutionProfileId ~= nil and selectedResolutionProfileId == editingResolutionProfileId end,
        },

        blank11 = {order = 1.1, type = "description", name = " ", width = 0.1,},

        resolutionProfileEditButton = {
          order = 2,
          type = "execute",
          name = "Edit",
          width = 0.5,
          func =
            function()
              StartEditingResolutionProfile(selectedResolutionProfileId)
            end,
          disabled = function() return selectedResolutionProfileId == nil or selectedResolutionProfileId == editingResolutionProfileId end,
        },

        blank21 = {order = 2.1, type = "description", name = " ", width = 0.1,},

        resolutionProfileNewButton = {
          order = 3,
          type = "execute",
          name = "New",
          width = 0.5,
          func =
            function()
              selectedResolutionProfileId = NewResolutionProfile()
              -- LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
            end,
          disabled = function() return selectedResolutionProfileId ~= nil and selectedResolutionProfileId == editingResolutionProfileId end,
        },

        resolutionProfileProperties = {
          order = 4,
          type = "group",
          name =
            function()
              if selectedResolutionProfileId ~= nil and selectedResolutionProfileId == editingResolutionProfileId then
                return "Editing Profile Properties"
              else
                return "Profile Properties "
              end
            end,
          inline = true,
          hidden =
            function()
              return selectedResolutionProfileId == nil
            end,
          args = {
            resolutionProfileName = {
              order = 1,
              type = "input",
              name = "Profile Name",
              width = 2.3,
              get =
                function()
                  if editingResolutionProfileId == nil and selectedResolutionProfileId ~= nil and config.resolutionProfileList[selectedResolutionProfileId].name then
                    return config.resolutionProfileList[selectedResolutionProfileId].name
                  elseif editingResolutionProfileId ~= nil and tmpEditingResolutionProfile.name then
                    return tmpEditingResolutionProfile.name
                  else
                    return ""
                  end
                end,
              set = function(_, newValue) tmpEditingResolutionProfile.name = newValue end,
              disabled = function() return editingResolutionProfileId == nil or selectedResolutionProfileId ~= editingResolutionProfileId end,
            },

            n11 = {order = 1.1, type = "description", name = " ", hidden = function() return editingResolutionProfileId == nil or selectedResolutionProfileId ~= editingResolutionProfileId end},

            resolutionProfileSaveButton = {
              order = 2,
              type = "execute",
              name = "Save",
              width = 1,
              func =
                function()
                  SaveEditingResolutionProfile(editingResolutionProfileId)
                  -- LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
                end,
              hidden = function() return editingResolutionProfileId == nil or selectedResolutionProfileId ~= editingResolutionProfileId end,
            },

            blank21 = {order = 2.1, type = "description", name = " ", width = 0.1, hidden = function() return editingResolutionProfileId == nil or selectedResolutionProfileId ~= editingResolutionProfileId end},

            resolutionProfileCancelButton = {
              order = 3,
              type = "execute",
              name = "Cancel",
              width = 1,
              func =
                function()
                  CancelEditingResolutionProfile()
                  -- LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
                end,
              hidden = function() return editingResolutionProfileId == nil or selectedResolutionProfileId ~= editingResolutionProfileId end,
            },

            blank31 = {order = 3.1, type = "description", name = " ", width = 0.1, hidden = function() return editingResolutionProfileId == nil or selectedResolutionProfileId ~= editingResolutionProfileId end},

            resolutionProfileDeleteButton = {
              order = 4,
              type = "execute",
              name = "Delete",
              width = 1,
              func =
                function()
                  DeleteResolutionProfile(editingResolutionProfileId)
                  -- LibStub("AceConfigRegistry-3.0"):NotifyChange(appName)
                end,
              hidden = function() return editingResolutionProfileId == nil or selectedResolutionProfileId ~= editingResolutionProfileId end,
            },

          },

        },

      },

    },



    n11 = {order = 1.1, type = "description", name = " ",},

    fullScreenToggleGroup = {
      type = "group",
      name = _G["BINDING_NAME_SCREEN_MANAGER_FULLSCREEN_TOGGLE"],
      order = 2,
      inline = true,
      args = {

        fullScreenToggleSpace = {order = 0, type = "description", name = " ", width = 0.04,},
        fullScreenToggleLabel = {
          order = 1,
          type = "description",
          name =
            function()
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
          width = 0.9,
          func =
            function()
              local data = { ["command"] = "SCREEN_MANAGER_FULLSCREEN_TOGGLE" }
              StaticPopup_Show("SCREEN_MANAGER_KEYBIND_PROMPT", SETTINGS_BIND_KEY_TO_COMMAND_OR_CANCEL:format(GetBindingName("SCREEN_MANAGER_FULLSCREEN_TOGGLE"), GetBindingText("ESCAPE")), _, data)
            end,
        },

        blank21 = {order = 2.1, type = "description", name = " ", width = 0.1,},

        fullScreenToggleUnassignButton = {
          order = 3,
          type = "execute",
          name = "Unbind",
          desc = "Unassign the current binding.",
          width = 0.9,
          func =
            function()
              SetBinding(GetBindingKey("SCREEN_MANAGER_FULLSCREEN_TOGGLE"))
            end,
          disabled =
            function()
              if GetBindingKey("SCREEN_MANAGER_FULLSCREEN_TOGGLE") then return false else return true end
            end,
        },
      },
    },
    
    
    n21 = {order = 2.1, type = "description", name = " ",},

    monitorToggleGroup = {
      type = "group",
      name = _G["BINDING_NAME_SCREEN_MANAGER_MONITOR_TOGGLE"],
      order = 3,
      inline = true,
      args = {

        monitorToggleSpace = {order = 0, type = "description", name = " ", width = 0.04,},
        monitorToggleLabel = {
          order = 1,
          type = "description",
          name =
            function()
              local key = GetBindingKey("SCREEN_MANAGER_MONITOR_TOGGLE")
              if key then
                return "Assigned Hotkey: |cffffd200" .. key .. "|r"
              else
                return "Assigned Hotkey: |cff808080Not Bound|r"
              end
            end,
          width = 1.5 - 0.04,
        },

        monitorToggleAssignButton = {
          order = 2,
          type = "execute",
          name = "New key bind",
          desc = "Assign a new hotkey binding.",
          width = 0.9,
          func =
            function()
              local data = { ["command"] = "SCREEN_MANAGER_MONITOR_TOGGLE" }
              StaticPopup_Show("SCREEN_MANAGER_KEYBIND_PROMPT", SETTINGS_BIND_KEY_TO_COMMAND_OR_CANCEL:format(GetBindingName("SCREEN_MANAGER_MONITOR_TOGGLE"), GetBindingText("ESCAPE")), _, data)
            end,
        },

        blank21 = {order = 2.1, type = "description", name = " ", width = 0.1,},

        monitorToggleUnassignButton = {
          order = 3,
          type = "execute",
          name = "Unbind",
          desc = "Unassign the current binding.",
          width = 0.9,
          func =
            function()
              SetBinding(GetBindingKey("SCREEN_MANAGER_MONITOR_TOGGLE"))
            end,
          disabled =
            function()
              if GetBindingKey("SCREEN_MANAGER_MONITOR_TOGGLE") then return false else return true end
            end,
        },
      },
    },
    

    n31 = {order = 3.1, type = "description", name = " ",},

    fadeInAfterLoadingGroup = {
      type = "group",
      name = "Fade in after loading screen",
      order = 4,
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
          desc = "When you are in combat, directly show the game after the loading screen without fade in.",
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
          desc = "How long the fade in takes to complete.",
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
          desc = "Restore settings to the preference of the addon developer.",
          width = "normal",
          disabled =
            function()
              if not config.fadeInAfterLoading then return true end
              if config.fadeInAfterLoading_notInCombat == CONFIG_DEFAULTS.fadeInAfterLoading_notInCombat and
                  config.fadeInAfterLoading_startAfter == CONFIG_DEFAULTS.fadeInAfterLoading_startAfter and
                  config.fadeInAfterLoading_fadeTime == CONFIG_DEFAULTS.fadeInAfterLoading_fadeTime then
                return true
              end
            end,
          func =
            function()
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

  SelectResolutionProfile()
end
