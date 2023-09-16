-- Author notes:
-- Author: Nash (@Inpultion)
-- Date of origin: 08/09/2023
-- Last edit: NAN/09/2023

--[[
	.new(contentData: leaderboardData) -> leaderboardObject

	Methods:
	- self:DisableLocalTesting(state: boolean) -> void
	- self:Clear() -> void
	= self:Load() -> boolean
	- self:Update() -> boolean
	- self:Append() -> void
	- self:Erase() -> boolean
	- self:ClearCache() -> void
	- self:AutoUpdate() -> void - This method yields
	- self:BreakAutoUpdater() -> void
	- self:AttachRefreshTimer() -> void
	- self:BindRankToCharacter() -> void
	- self:BindRankToIcon() -> void
	- self:version() -> string
]]

-- TODO:
-- Add UI leaderboard compatability

-- exports
export type leaderboardData = {
	datastoreKey: string?,
	leaderboardIconParent: GuiObject?,
	iconTemplate: any?,
	format: any?, -- Why no "function" type >:(
	lines: number?,
	descendingOrder: boolean?,
	displayNamesEnabled: boolean?,
	showDisplayNameIfSameAsName: boolean?,
	thumbnailsEnabled: boolean?,
	thumbnailCache: boolean?,
	userDataCache: boolean?,
	debug: boolean?,
	frontPrefix: string?,
	backPrefix: string?,
}

local mainModule = {}
mainModule.__index = mainModule

-- services
local datastoreService: DataStoreService = game:GetService("DataStoreService")
local players: Players = game:GetService("Players")
local userService: UserService = game:GetService("UserService")
local collectionService: CollectionService = game:GetService("CollectionService")
local replicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- variables
local thumbnailCache: any = {}
local userDataCache: any = {}

local blankHumanoidDescription: HumanoidDescription = Instance.new("HumanoidDescription")

local leaderboardUtilFolder: Folder = replicatedStorage:FindFirstChild("Leaderboard Util Folder") :: Folder or Instance.new("Folder")
leaderboardUtilFolder.Name = "Leaderboard_Util_Folder"
leaderboardUtilFolder.Parent = replicatedStorage

local packages: Folder = script:WaitForChild("packages") :: Folder
local abbreviators: Folder = packages:WaitForChild("abbreviators") :: Folder

-- modules
local createTemplate: any = require(script:WaitForChild("Icon Template", 10))
local abbreviateTime: any = require(abbreviators:WaitForChild("Abbreviate Time", 10))
local abbreviateNumber: any = require(abbreviators:WaitForChild("Abbreviate Number", 10))

-- functions
local function Debug(...)
	for index: number, bug: string in pairs({...}) do
		warn(bug)
	end
end

-- @ RequestThumbnailAsync: Returns an image of a players"Headshot" icon
local function RequestThumbnailAsync(userId: number, cache: boolean, debug: boolean)
	if (thumbnailCache[userId]) then
		return thumbnailCache[userId]
	end
	
	local success: boolean, result: string? = pcall(
		function ()
			return players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end
	)
	
	if (not success) then
		if (debug) then
			Debug(result, " - Failed to acquire current page")
		end
		
		return "rbxasset://textures/ui/GuiImagePlaceholder.png" -- I'm returning the placeholder just in case the actual headshot doesn't load.
	end
	
	if (cache) then
		thumbnailCache[userId] = result
	end
	
	return result
end

local function FlipKeys(t: any)
	local t0: any = {}
	
	for index: number, value: any in pairs(t) do
		t0[value.Id] = value
	end
	
	return t0
end

-- @ ApplyDescriptionToCharacterFromUserId: Applies a humanoid description to a character based on the given rank.
local function ApplyDescriptionToCharacterFromUserId(userId: number, character: Model, debug: boolean)
	local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")
	
	if (not humanoid) then
		return
	end
	
	local succcess: boolean, result: HumanoidDescription = pcall(
		function ()
			return players:GetHumanoidDescriptionFromUserId(userId)
		end
	)
	
	if (not succcess) then
		if (debug) then
			Debug(result, " - Failed to retrieve HumanoidDescription for" .. userId)
		end
		
		return
	end
	
	character:PivotTo(character:GetPivot() * CFrame.new(0, -humanoid.HipHeight, 0))
	
	humanoid:ApplyDescription(blankHumanoidDescription)
	humanoid:ApplyDescription(result)
	
	character:PivotTo(character:GetPivot() * CFrame.new(0, humanoid.HipHeight, 0))
end

-- @ new: Constructs a new leaderboard
function mainModule.new(contentData: leaderboardData)
	local self: any = {}
	setmetatable(self, mainModule)
	
	assert(typeof(contentData.leaderboardIconParent) == "Instance", "No predefined parent was assigned for the icon, or the parent wasn't a 'Instance' class.")
	assert(type(contentData.datastoreKey) == "string", "No datastore key was provided, or the datastore key provided wasn't a 'string' type.")
	
	-- whether or not to save test id's
	self.disabledLocalServer = false
	
	-- the parent of each icon
	self.iconParent = contentData.leaderboardIconParent
	
	-- the formatter is used to convert the number in the leaderboard into a different style. e.g. 86400 = 86,400 or 86400 = 86k or 86400 = 1:00:00:00.
	-- there are 3 built in formatters: "Comma", "Abbreviate" and "Time".
	self.formatter = contentData.format or "Comma"
	
	self.lines = contentData.lines or 25
	self.descendingOrder = contentData.descendingOrder or false
	
	self.displayNamesEnabled = contentData.displayNamesEnabled or true
	self.thumbnailsEnabled = contentData.thumbnailsEnabled or false
	self.thumbnailCache = contentData.thumbnailCache or true
	self.userDataCache = contentData.userDataCache or true
	self.showDisplayNameIfSameAsName = contentData.showDisplayNameIfSameAsName or false
	
	self.template = contentData.iconTemplate or createTemplate

	self.fakeUserData = {
		Username = "NIL",
		DisplyName = "NIL",
	}
	
	self.autoUpdating = false
	self.currentTimer = 1
	self.updateTimers = {}
	
	self.characterBinds = {}
	self.iconBinds = {}
	
	self._appendingUserIds = {}
	
	self.frontPrefix = contentData.frontPrefix or ""
	self.backPrefix = contentData.backPrefix or ""
	
	-- enabling debugging will display warnings that come from a failed request.
	self.debug = contentData.debug or false
	
	self.datastoreKey = contentData.datastoreKey
	self.datastoreProfile = datastoreService:GetOrderedDataStore(self.datastoreKey)
	self.lastCache = {}
	
	return self
end

-- @ DisableLocalServerTesting: Disables any "test accounts" from being added to the database.
-- This function should really only be used when you're play testing in studio with the built in "Test" feature.
function mainModule:DisableLocalServerTesting(state: boolean?)
	self.disabledLocalServer = (state or true)
end

-- @ Clear: Clears any "Frame"(s) from the provided GUI.
function mainModule:Clear()
	for index: number, object: any in pairs(collectionService:GetTagged("LEADERBOARD_ICON/" .. self.datastoreKey)) do
		object:Destroy()
		object = nil
	end
end


-- @ Load: Instances (a) new "Frame"(s) based on the "OrderedData".
-- Make sure to use :Clear before using.
function mainModule:Load()
	-- I'm doing the actual appending in the load function to prevent people from spamming the roblox datastore API.
	-- TODO: Anti-flood system to ensure no limit errors occur.
	for userId: number, value: number in pairs(self._appendingUserIds) do
		local success: boolean, result: any = pcall(
			function ()
				return self.datastoreProfile:SetAsync(userId, value)
			end
		)

		if (not success) then
			if (self.debug) then
				Debug(result, " - Failed to append")
			end
		end
		
		self._appendingUserIds[userId] = nil
	end
	
	local success: boolean, result: DataStorePages = pcall(
		function ()
			return self.datastoreProfile:GetSortedAsync(self.descendingOrder, self.lines)
		end
	)
	
	if (not success) then
		if (self.debug) then
			Debug(result, " - Failed to acquire datastore page")
		end
		
		return
	end
	
	local success: boolean, page: any = pcall(
		function ()
			return result:GetCurrentPage()
		end
	)
	
	if (not success) then
		if (self.debug) then
			Debug(result, " - Failed to acquire current page")
		end
		
		return
	end
	
	local userIds: any = {}
	
	for rank: number, data: any in pairs(page) do
		table.insert(userIds, tonumber(data.key))
	end
	
	for rank: number, character: Model in pairs(self.characterBinds) do
		if (not page[rank]) then
			continue
		end
		
		ApplyDescriptionToCharacterFromUserId(tonumber(page[rank].key) :: number, character, self.debug)
	end
	
	local userData: any = userService:GetUserInfosByUserIdsAsync(userIds)
	local flippedUserData: any = FlipKeys(userData)
	
	for rank: number, data: any in pairs(page) do
		local userId: number = tonumber(data.key) :: number
		local value: number = tonumber(data.value) :: number
		local thumbnail: string
		
		if (self.thumbnailsEnabled) then
			thumbnail = RequestThumbnailAsync(userId, self.thumbnailCache, self.debug)
		end
		
		if (self.userDataCache and not userDataCache[userId]) then
			userDataCache[userId] = flippedUserData[userId]
		end
		
		if (type(self.formatter) == "string") then
			if (self.formatter == "Abbreviate") then
				value = abbreviateNumber(value)
			elseif (self.formatter == "Comma") then
				value = abbreviateNumber(value, "Comma")
			elseif (self.formatter == "Time") then
				value = abbreviateTime(value)
			end
		else
			value = self.formatter(value)
		end
		
		local iconTemplate: GuiObject = self.template(
			(userDataCache[userId] or flippedUserData[userId] or self.fakeUserData).Username,
			self.frontPrefix .. value .. self.backPrefix,
			rank,
			(userDataCache[userId] or flippedUserData[userId] or self.fakeUserData).DisplayName,
			thumbnail,
			self.showDisplayNameIfSameAsName
		)
		
		collectionService:AddTag(iconTemplate, "LEADERBOARD_ICON/" .. self.datastoreKey)
		
		if (self.iconBinds[rank]) then
			self.iconBinds[rank](iconTemplate)
		end
		
		iconTemplate.Parent = self.iconParent
	end
	
	self.lastCache = page
	
	return success
end

-- @ Update: A combination of :Clear() and :Load()
function mainModule:Update()
	self:Clear() return self:Load()
end

-- @ Append: Appends a value to the appendingUserIds table
function mainModule:Append(userId: number, value: number)
	if (type(userId) ~= "number" or type(value) ~= "number") then
		warn("incorrect types provided, unable to append.")
		
		return
	end
	
	if (userId < 1 and self.disabledLocalServer) then
		warn("Couldn't append [" .. userId .. "] because the userId provided was a test id.")
		
		return
	end
	
	self._appendingUserIds[userId] = value
end

-- @ Erase: Will erase a player's data from the ordered datastore
function mainModule:Erase(userId: number)
	if (type(userId) ~= "number") then
		warn("incorrect types provided, unable to erase.")

		return
	end
	
	local success: boolean, result: any = pcall(
		function ()
			return self.datastoreProfile:RemoveAsync(userId)
		end
	)

	if (not success) then
		if (self.debug) then
			Debug(result, " - Failed to acquire current page")
		end
	end
	
	return success
end

-- @ ClearCache: Clears the cache for thumbnail content and user data content
function mainModule:ClearCache()
	for index: number in pairs(thumbnailCache) do
		thumbnailCache[index] = nil
	end
	
	for index: number in pairs(userDataCache) do
		userDataCache[index] = nil
	end
	
	thumbnailCache = {}
	userDataCache = {}
end

-- @ AutoUpdate: Equivalent of doing: while (true) do task.wait(x) self:Update() end
function mainModule:AutoUpdate(updateTime: number)
	if (type(updateTime) ~= "number") then
		warn("incorrect types provided, unable to auto update.")

		return
	end
	
	self.autoUpdating = true
	
	local updateThread: thread = coroutine.create(function()
		while (self.autoUpdating) do
			self.currentTimer -= 1
			
			if (#self.updateTimers > 0) then
				for index: number, textLabel: TextLabel in pairs(self.updateTimers) do
					if (textLabel) then
						textLabel.Text = "Refresh in: " .. abbreviateTime(self.currentTimer)
					else
						self.updateTimers[index] = nil
					end
				end
			end
			
			if (self.currentTimer == 0) then
				self.currentTimer = updateTime

				self:Update()
			end

			task.wait(1)
		end
	end)
	
	coroutine.resume(updateThread)
end

-- @ BreakAutoUpdater: Stops the auto updater
function mainModule:BreakAutoUpdater()
	self.autoUpdating = false
end

-- @ AttachUpdateTimer: Attaches a "TextLabel" which will replicate the "Auto updater" timer value to
function mainModule:AttachRefreshTimer(refreshTimer: TextLabel)
	table.insert(self.updateTimers, refreshTimer)
end

-- @ BindRankToCharacter: Binds a rank to an associated character
function mainModule:BindRankToCharacter(rank: number, character: Model)
	if (type(rank) ~= "number") then
		if (self.debug) then
			warn("can't append 'rank'; ensure the correct type is provided")
		end
		
		return
	end
	
	self.characterBinds[rank] = character
end

-- @ BindRankToIcon: Binds a rank to a special modifier callback function
function mainModule:BindRankToIcon(rank: number, modifier: any)
	if (type(rank) ~= "number") then
		if (self.debug) then
			warn("can't append 'rank'; ensure the correct type is provided")
		end

		return
	end
	
	self.iconBinds[rank] = modifier
end

-- @ GetPlayerFromRank: Returns a player (if one) based on the rank provided
-- Remember, if that user is not within the game, the function will return nil
-- Set it up in this way:
--[[

	local player: Player = self:GetPlayerFromRank(n)
	
	if (not player) then
		return
	end

	-- your code...
]]
function mainModule:GetPlayerFromRank(rank: number)
	if (type(rank) ~= "number") then
		if (self.debug) then
			warn("can't append 'rank'; ensure the correct type is provided")
		end

		return
	end
	
	local isCached: boolean = self.lastCache[rank] ~= nil
	
	if (not isCached) then
		if (self.debug) then
			warn("no rank within the datastore was found")
		end
		
		return
	end
	
	return players:GetPlayerByUserId(tonumber(self.lastCache[rank].key) :: number)
end

-- @ version: A minor method which returns the current version of the module
function mainModule:version()
	return require(script:WaitForChild("VERSION", 10))
end

return mainModule
