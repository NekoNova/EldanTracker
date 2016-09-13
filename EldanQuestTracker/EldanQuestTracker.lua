require "GameLib"
require "QuestLib"
require "Quest"
require "Episode"
require "Unit"

local EldanQuestTracker = {}

-- Constants
local karrLevelToColor = {
    [0] = "ffffffff",
    [Unit.CodeEnumLevelDifferentialAttribute.Grey] = "ff9aaea3",
    [Unit.CodeEnumLevelDifferentialAttribute.Green] = "ff37ff00",
    [Unit.CodeEnumLevelDifferentialAttribute.Cyan] = "ff46ffff",
    [Unit.CodeEnumLevelDifferentialAttribute.Blue] = "ff309afc",
    [Unit.CodeEnumLevelDifferentialAttribute.White] = "ffffffff",
    [Unit.CodeEnumLevelDifferentialAttribute.Yellow] = "ffffd400",
    [Unit.CodeEnumLevelDifferentialAttribute.Orange] = "ffff6a00",
    [Unit.CodeEnumLevelDifferentialAttribute.Red] = "ffff0000",
    [Unit.CodeEnumLevelDifferentialAttribute.Magenta] = "fffb00ff",
}
local karrLevelToString = {
    [0] = Apollo.GetString("Unknown_Unit"),
    [Unit.CodeEnumLevelDifferentialAttribute.Grey] = Apollo.GetString("QuestLog_Trivial"),
    [Unit.CodeEnumLevelDifferentialAttribute.Green] = Apollo.GetString("QuestLog_Easy"),
    [Unit.CodeEnumLevelDifferentialAttribute.Cyan] = Apollo.GetString("QuestLog_Simple"),
    [Unit.CodeEnumLevelDifferentialAttribute.Blue] = Apollo.GetString("QuestLog_Standard"),
    [Unit.CodeEnumLevelDifferentialAttribute.White] = Apollo.GetString("QuestLog_Average"),
    [Unit.CodeEnumLevelDifferentialAttribute.Yellow] = Apollo.GetString("QuestLog_Moderate"),
    [Unit.CodeEnumLevelDifferentialAttribute.Orange] = Apollo.GetString("QuestLog_Tough"),
    [Unit.CodeEnumLevelDifferentialAttribute.Red] = Apollo.GetString("QuestLog_Hard"),
    [Unit.CodeEnumLevelDifferentialAttribute.Magenta] = Apollo.GetString("QuestLog_Impossible")
}

-- Constructor
function EldanQuestTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    o.bQuestsInitialized = false
    o.tEpisodes = {}

    return o
end

-- Initializer
function EldanQuestTracker:Init()
    local bHasConfigureFunction = false
    local strConfigureButtonText = nil
    local tDependencies = {}

    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-- OnLoad
function EldanQuestTracker:OnLoad()
    Apollo.RegisterEventHandler("EldanObjectiveTrackerLoaded", "OnEldanObjectiveTrackerLoaded", self)
end

---------------------------------------------------------------------------------------------------
-- EventHandlers
---------------------------------------------------------------------------------------------------

-- OnEldanObjectiveTrackerLoaded
--
-- Fired once the OnLoad event is completed. We unregister our eventhandler and hook into the ones we care about.
-- This allows us to start collecting all relevant data as the player continues with the game.
function EldanQuestTracker:OnEldanObjectiveTrackerLoaded()
    Apollo.RemoveEventHandler("EldanObjectiveTrackerLoaded", self)

    Apollo.RegisterEventHandler("EpisodeStateChanged", "OnEpisodeStateChanged", self)
    Apollo.RegisterEventHandler("QuestStateChanged", "OnQuestStateChanged", self)
    Apollo.RegisterEventHandler("QuestTrackedChanged", "OnQuestTrackedChanged", self)
    Apollo.RegisterEventHandler("QuestObjectiveUpdated", "OnQuestObjectiveUpdated", self)
    Apollo.RegisterEventHandler("QuestInit", "OnQuestInit", self)
    Apollo.RegisterEventHandler("GenericEvent_QuestLog_TrackBtnClicked", "OnGenericEvent_QuestLog_TrackBtnClicked", self)
    Apollo.RegisterEventHandler("PlayerLevelChange", "OnPlayerLevelChange", self)
end

-- OnEpisodeStateChanged
--
-- Whenever an Episode changes state in the game, we will update our internal table of episodes.
-- When the episode is active, we will extract it's categories and quests, and store them for reference.
-- In all other cases we drop the reference until the episode becomes active again.
function EldanQuestTracker:OnEpisodeStateChanged(nId, eOldState, eNewState)
    local episode = QuestLib.GetEpisode(nId)

    if episode == nil or not self.bQuestsInitialized then return end

    if eNewState == Episode.EpisodeState_Active then
        local arrCategories = episode:GetCategories()
        local arrQuests = {}

        for idx = 1, #arrCategories do
            table.insert(arrQuests, episode:GetAllQuests(arrCategories[idx]:GetId()))
        end

        self.tEpisodes[nId] = { nId = nId, strName = episode:GetName(), arrQuests = arrQuests }
    else
        self.tEpisodes[nId] = nil
    end
end

function EldanQuestTracker:OnQuestStateChanged(queQuest, eState)
end

function EldanQuestTracker:OnQuestTrackerChanged(queQuest, bTracked)
end

function EldanQuestTracker:OnQuestObjectiveUpdated(queQuest, nIndex)
end

-- OnGenericEvent_QuestLog_TrackBtnClicked
--
-- This event is fired by the QuestLog Addon, and happens whenever a User clicks on the quest in the Log.
-- If this quest is not tracked, we're going to remove it from our quest array when present.
-- Or add it in case it isn't tracked yet.
function EldanQuestTracker:OnGenericEvent_QuestLog_TrackBtnClicked(queSelected)
    local nQuestId = queSelected:GetId()
    local episode = queSelected:GetEpisode()

    if queSelected:IsTracked() then
        local bInserted = false

        if self.tEpisodes[episode:GetId()] ~= nil then
            for k, v in pairs(self.tEpisodes[episode:GetId()].arrQuests) do
                if v:GetId() == nQuestId then
                    self.tEpisodes[episode:GetId()].arrQuests[k] = queSelected
                    bInserted = true -- We overwrite the existing quest object.
                    break
                end
            end

            -- If we did not overwrite the quest, then add it to the table for the episode.
            if not bInserted then
                table.insert(self.tEpisodes[episode:GetId()].arrQuests, queSelected)
            end
        else
            local arrCategories = episode:GetCategories()
            local arrQuests = {}

            for idx = 1, #arrCategories do
                table.insert(arrQuests, episode:GetAllQuests(arrCategories[idx]:GetId()))
            end

            self.tEpisodes[nId] = { nId = nId, strName = episode:GetName(), arrQuests = arrQuests }
        end
    else
        if self.tEpisodes[episode:GetId()] ~= nil then
            for k, v in pairs(self.tEpisodes[episode:GetId()].arrQuests) do
                if v:GetId() == nQuestId then
                    self.tEpisodes[episode:GetId()].arrQuests[k] = nil
                    break
                end
            end
        end
    end
end

-- OnQuestInit
--
-- Triggered when the quests are initialized in the game.
-- We use this hook to build up the initial database of Episodes and Quests so we can
-- provide other Addons with data.
function EldanQuestTracker:OnQuestInit()
    self.bQuestsInitialized = true
    self:BuildAll()
end

-- Create the instance of our Addon
local EldanQuestTrackerInst = EldanQuestTracker:new()
EldanQuestTrackerInst:Init()