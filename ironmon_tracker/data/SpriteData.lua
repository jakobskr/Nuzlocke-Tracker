SpriteData = {}
SpriteData.ActiveIcons = {}

SpriteData.Types = {
	Idle = "idle",
	Walk = "walk",
	Sleep = "sleep",
	Faint = "faint",
}

-- TODO: update all icon references to allow for animated sprites
-- TODO: add a sleep timer; if no input for a while, put icon to sleep

function SpriteData.initialize()
	SpriteData.ActiveIcons = {}
end

function SpriteData.addUpdateActiveIcon(pokemonID, animationType, startIndexFrame, framesElapsed)
	if not Drawing.isAnimatedIconSet() then return end

	if SpriteData.DEBUG then
		animationType = SpriteData.DebugType or animationType
	end

	animationType = animationType or SpriteData.Types.Idle
	startIndexFrame = startIndexFrame or 1
	framesElapsed = framesElapsed or 0.0
	-- Don't add if not a real animated pokemon, or the icon has already been added
	if not PokemonData.isValid(pokemonID) or not SpriteData.Icons[pokemonID] then
		return
	end

	-- Don't add the icon if the same pokemon + animation
	local activeIcon = SpriteData.ActiveIcons[pokemonID]
	if activeIcon and activeIcon.animationType == animationType then
		return
	end

	local icon = SpriteData.Icons[pokemonID][animationType]
	local canLoop = animationType ~= SpriteData.Types.Faint
	local totalDuration = 0
	local indexCutoffs = {}
	for _, frameDuration in ipairs(icon.durations or {}) do
		totalDuration = totalDuration + frameDuration
		table.insert(indexCutoffs, totalDuration)
	end
	if totalDuration <= 0 then
		return
	end

	activeIcon = {
		pokemonID = pokemonID,
		animationType = animationType,
		indexFrame = startIndexFrame,
		framesElapsed = framesElapsed,
		duration = totalDuration,
		inUse = true,
		step = function(self)
			-- Sync with client frame rate (turbo/unthrottle)
			local fpsMultiplier = math.max(client.get_approx_framerate() / 60, 1) -- minimum of 1
			local delta = 1.0 / fpsMultiplier
			self.framesElapsed = (self.framesElapsed + delta) % self.duration
			if not canLoop and self.indexFrame >= #indexCutoffs then
				return
			end
			-- Check if index frame has changed
			local prevIndex = self.indexFrame
			for i, cutoff in ipairs(indexCutoffs) do
				if self.framesElapsed <= cutoff then
					self.indexFrame = i
					break
				end
			end
			-- Trigger a screen draw if new animation frame is active
			if prevIndex ~= self.indexFrame then
				Program.Frames.waitToDraw = 0
			end
		end,
	}
	SpriteData.ActiveIcons[pokemonID] = activeIcon
	return activeIcon
end

function SpriteData.updateActiveIcons()
	if not Drawing.isAnimatedIconSet() then return end

	local j = Input.prevJoypadInput
	local canWalk = j["Left"] or j["Right"] or j["Up"] or j["Down"]
	canWalk = canWalk and not Battle.inBattle and not Battle.battleStarting and not Program.inStartMenu and not GameOverScreen.isDisplayed

	for _, activeIcon in pairs(SpriteData.ActiveIcons or {}) do
		-- Check if the walk/idle animation needs to be updated, reusing frame info
		if canWalk and activeIcon.animationType == SpriteData.Types.Idle then
			SpriteData.addUpdateActiveIcon(activeIcon.pokemonID, SpriteData.Types.Walk, activeIcon.indexFrame, activeIcon.framesElapsed)
		elseif not canWalk and activeIcon.animationType == SpriteData.Types.Walk then
			SpriteData.addUpdateActiveIcon(activeIcon.pokemonID, SpriteData.Types.Idle, activeIcon.indexFrame, activeIcon.framesElapsed)
		end

		if type(activeIcon.step) == "function" then
			activeIcon:step()
		end
	end
end

-- If an animated icon sprite is no longer being drawn, remove it from the animation frame counters
function SpriteData.cleanupActiveIcons()
	if not Drawing.isAnimatedIconSet() then return end

	local keysToRemove = {}
	for key, activeIcon in pairs(SpriteData.ActiveIcons or {}) do
		if not activeIcon.inUse then
			table.insert(keysToRemove, key)
		else
			activeIcon.inUse = false
		end
	end
	for _, key in ipairs(keysToRemove) do
		SpriteData.ActiveIcons[key] = nil
		-- TODO: Remove before PR
		if SpriteData.DEBUG then
			Utils.printDebug("Removing sprite -> %s", key)
		end
	end
end

-- TODO: remove references to DEBUG
SpriteData.DEBUG = true
SpriteData.DebugId = 1
SpriteData.DebugType = SpriteData.Types.Faint

SpriteData.Icons = {
	[1] = {
		[SpriteData.Types.Faint] = { w = 32, h = 24, x = 5, y = 11, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 5, y = 11, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 1, y = 4, durations = { 40, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = -3, y = 4, durations = { 4, 4, 4, 4, 4, 4 } },
	},
	[2] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 7, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 7, durations = { 40, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 7, durations = { 8, 10, 8, 10 } },
	},
	[3] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 7, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 7, durations = { 30, 16, 12, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 7, durations = { 8, 16, 8, 16 } },
	},
	[4] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 6, durations = { 12, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 1, y = 6, durations = { 6, 8, 6, 8 } },
	},
	[5] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = -1, durations = { 40, 2, 3, 3, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 4, y = 8, durations = { 8, 10, 8, 10 } },
	},
	[6] = {
		[SpriteData.Types.Faint] = { w = 48, h = 48, x = -3, y = 2, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = -3, y = 2, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = -3, y = 2, durations = { 15, 15, 15, 15 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = -3, y = 3, durations = { 8, 10, 8, 10 } },
	},
	[7] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 1, y = 10, durations = { 30, 2, 2, 4, 4, 4, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 12, 8, 12, 8 } },
	},
	[8] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 2, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[9] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 32, 12, 4, 4, 4, 4, 4, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 14, 8, 14 } },
	},
	[10] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 4, 10, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 10, 10, 10 } },
	},
	[11] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 14, 10, 14 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 4, 2, 2, 2, 2, 4, 4, 4, 4, 4 } },
	},
	[12] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 35, 30 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[13] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8 } },
	},
	[14] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 1, 1, 4, 1, 1 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 4, 4, 4, 10 } },
	},
	[15] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 56, x = 0, y = 0, durations = { 16, 8, 16, 16, 8, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4 } },
	},
	[16] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 35, 30 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 4, 4, 4, 4 } },
	},
	[17] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 2, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[18] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 2, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[19] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 2, 2, 2, 4, 2, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 48, h = 40, x = 0, y = 0, durations = { 6, 4, 4, 4, 4, 4, 4 } },
	},
	[20] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 35, 30 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 6, 3, 4, 3, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 4, 6, 4, 4, 4, 4 } },
	},
	[21] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 2, 3, 4, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 4, 4, 4, 4 } },
	},
	[22] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 72, x = 0, y = 0, durations = { 40, 20, 4, 4, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 4, 5, 6, 4, 5, 6 } },
	},
	[23] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 16, 16 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6 } },
	},
	[24] = {
		[SpriteData.Types.Faint] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 6, 6 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 32, 14 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 6, 6, 8, 6, 6, 6 } },
	},
	[25] = {
		[SpriteData.Types.Faint] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 40, 2, 3, 3, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[26] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 40, 2, 4, 4, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[27] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 2, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[28] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 25, 10, 25, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[29] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 24, 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 6, 4, 4, 4, 4, 4, 4 } },
	},
	[30] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 2, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[31] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 20, 6, 6, 6, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[32] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 6, 6, 5, 6, 6, 4 } },
	},
	[33] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 10, 2, 2, 2, 2, 2, 2, 2, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 6, 12, 6, 12 } },
	},
	[34] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 35, 12 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 14, 8, 14 } },
	},
	[35] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 3, 4, 5, 4, 3 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 4, 8, 4, 8, 4, 8, 4 } },
	},
	[36] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 6, 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 6, 6, 6, 8, 6, 6, 6 } },
	},
	[37] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 12, 20, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 4, 4, 4, 6 } },
	},
	[38] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[39] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 35, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 25, 8, 15, 8, 15 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 4, 4, 4, 6 } },
	},
	[40] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 35, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 4, 6, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[41] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 10, 6, 6, 6, 6, 6, 6, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[42] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[43] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 4, 8, 6, 8, 4, 8, 6 } },
	},
	[44] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[45] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 35, 30 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 3, 3, 8, 3, 3, 30, 3, 3, 8, 3, 3 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[46] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 24, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 24, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[47] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[48] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 16, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 6, 6, 6, 8 } },
	},
	[49] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 30, 8, 8, 30, 8, 8 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 12, 12, 12, 12, 12, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[50] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 16, 16 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 8, 8 } },
	},
	[51] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 12, 16 } },
		[SpriteData.Types.Walk] = { w = 56, h = 48, x = 0, y = 0, durations = { 8, 8, 8 } },
	},
	[52] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 12, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[53] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[54] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 35, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 16, 20, 16, 20 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[55] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 35, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 20, 40, 20 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[56] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 4, 4, 4, 8, 4, 4, 4 } },
	},
	[57] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 22, 4, 6, 4, 22, 4, 6, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[58] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 40, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[59] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[60] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 30, 8, 6, 6, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 6, 6, 6, 6 } },
	},
	[61] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 2, 4, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[62] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 2, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[63] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 24, 8, 8, 24, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10, 8, 10, 8, 10 } },
	},
	[64] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 4, 4, 6, 6, 6, 6, 6, 6, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[65] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[66] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[67] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[68] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 40, 2, 2, 2, 2, 2, 2, 2, 2, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[69] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 20, 22 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[70] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 12, 10, 12, 12, 10, 12 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 16, 8, 16, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[71] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 35, 3, 3, 5, 5, 5, 3, 3, 3 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[72] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 4, 8, 8, 4, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[73] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 10, 10, 6, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[74] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 9, 8, 20, 9, 8, 20 } },
		[SpriteData.Types.Idle] = { w = 32, h = 24, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[75] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[76] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 25 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[77] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[78] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[79] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 40, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[80] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 30, 30 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[81] = {
		[SpriteData.Types.Faint] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 2, 2, 2, 1, 2, 1, 4 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 20, 8, 8, 20, 8, 8 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 10, 14, 10, 14 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 6, 6, 8, 6, 6 } },
	},
	[82] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 14, 10, 14, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[83] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 12, 30, 12 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 6, 12, 6, 12 } },
	},
	[84] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 6, 12, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[85] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 40, 10, 16, 10, 16, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[86] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 20 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 6, 8, 10, 6, 6, 6 } },
	},
	[87] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 40, x = 0, y = 0, durations = { 30, 12, 8, 12, 8, 12 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 6, 6, 6, 10, 8, 8 } },
	},
	[88] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 40, 8, 30, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
	},
	[89] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 8, 30, 8 } },
		[SpriteData.Types.Walk] = { w = 48, h = 40, x = 0, y = 0, durations = { 10, 8, 6, 10, 8 } },
	},
	[90] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 24, 10, 10, 24, 10, 10 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 14, 40, 14, 30 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 10, 6, 10, 10, 6, 10 } },
	},
	[91] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 22, 15, 10, 22, 15, 10 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 12, 12, 12, 14, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 10, 8, 8 } },
	},
	[92] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 56, x = 0, y = 0, durations = { 6, 6, 6, 16, 6, 6, 6, 16 } },
		[SpriteData.Types.Idle] = { w = 48, h = 56, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 48, h = 64, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[93] = {
		[SpriteData.Types.Faint] = { w = 40, h = 56, x = 0, y = 0, durations = { 4, 3, 16, 3, 1, 3, 3, 2, 2, 6, 2, 4 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 8, 20, 8, 8, 20 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 14, 8, 14, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 6, 6, 6, 10, 6, 6, 6, 6, 10, 6 } },
	},
	[94] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 4, 3, 3, 3, 3, 3, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[95] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 64, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 96, h = 104, x = 0, y = 0, durations = { 16, 16, 16, 16 } },
		[SpriteData.Types.Walk] = { w = 88, h = 112, x = 0, y = 0, durations = { 10, 14, 10, 14 } },
	},
	[96] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 2, 2, 2, 2, 4, 2, 2, 2, 2 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 35, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 10, 6, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[97] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 35, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 30, 1, 2, 3, 3, 3, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[98] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 30 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[99] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 30 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[100] = {
		[SpriteData.Types.Faint] = { w = 32, h = 24, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 22, 6, 2, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 6, 10, 4, 4, 4, 6, 8 } },
	},
	[101] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 10, 18, 10, 18 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 4, 4, 6, 8, 6, 4, 10 } },
	},
	[102] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 2, 4, 4, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[103] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 40, 12, 8, 12 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[104] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 1, 2, 3, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[105] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 6, 16, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[106] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 40, 20 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 10, 12, 10, 12 } },
	},
	[107] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 56, x = 0, y = 0, durations = { 30, 6, 8, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[108] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 48, x = 0, y = 0, durations = { 36, 12, 10, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 14, 10, 14 } },
	},
	[109] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 10, 10, 8, 10, 10, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 6, 6, 6, 6, 8, 6, 6, 6, 6, 8 } },
	},
	[110] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
	},
	[111] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 32, x = 0, y = 0, durations = { 40, 20, 15 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[112] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 48, x = 0, y = 0, durations = { 40, 26 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[113] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 35, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 2, 3, 4, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[114] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 34, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 6, 6, 6, 6, 6 } },
	},
	[115] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 30, 3, 4, 3, 20 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 16, 10, 16, 10 } },
	},
	[116] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 16, 8, 16 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[117] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 56, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 12, 12, 12, 12, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 8, 10, 8, 10 } },
	},
	[118] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 16, 10, 16, 10, 16, 10, 16, 2, 4, 4, 4, 12, 10, 16, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10, 10, 10 } },
	},
	[119] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 16, 10, 16, 10, 16, 10, 16, 2, 4, 4, 4, 12, 10, 16, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 10, 8, 10, 8 } },
	},
	[120] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 36, 10, 6, 10 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[121] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 60, 4, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[122] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 20, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[123] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 10, 14, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[124] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 14, 30, 14 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[125] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 28, 18, 28, 18 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[126] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 6, 12, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[127] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 2, 6, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[128] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 3, 6, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 6, 6, 6, 6, 6, 6 } },
	},
	[129] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 10, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 2, 4, 6, 4, 2, 6 } },
	},
	[130] = {
		[SpriteData.Types.Sleep] = { w = 72, h = 112, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 72, h = 128, x = 0, y = 0, durations = { 18, 8, 18, 8 } },
		[SpriteData.Types.Walk] = { w = 88, h = 128, x = 0, y = 0, durations = { 10, 14, 10, 14 } },
	},
	[131] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 56, x = 0, y = 0, durations = { 40, 12, 16, 12 } },
		[SpriteData.Types.Walk] = { w = 48, h = 56, x = 0, y = 0, durations = { 10, 12, 10, 12 } },
	},
	[132] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 16, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 10, 8, 10, 8, 8 } },
	},
	[133] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 16, 16 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4, 6, 2, 2 } },
	},
	[134] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 60, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[135] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 60, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[136] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 12, 16, 12, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[137] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 16, 8, 16, 16, 8, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 12, 8, 12, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
	},
	[138] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[139] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 20 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[140] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 40, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[141] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 20, 10, 20, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 6, 4, 8, 4, 6, 4, 8, 4 } },
	},
	[142] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 64, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[143] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 40, 1, 3, 4, 3, 1 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[144] = {
		[SpriteData.Types.Sleep] = { w = 56, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 88, h = 88, x = 0, y = 0, durations = { 8, 10, 8, 16 } },
		[SpriteData.Types.Walk] = { w = 88, h = 88, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[145] = {
		[SpriteData.Types.Sleep] = { w = 56, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 56, h = 96, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
		[SpriteData.Types.Walk] = { w = 56, h = 96, x = 0, y = 0, durations = { 6, 6, 6, 6 } },
	},
	[146] = {
		[SpriteData.Types.Sleep] = { w = 48, h = 64, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 80, h = 96, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
		[SpriteData.Types.Walk] = { w = 80, h = 96, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[147] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 20, 10, 20 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 8, 8, 8, 8 } },
	},
	[148] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 56, x = 0, y = 0, durations = { 8, 6, 6, 8, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 48, h = 56, x = 0, y = 0, durations = { 8, 6, 6, 8, 6, 6, 6 } },
	},
	[149] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 64, x = 0, y = 0, durations = { 40, 2, 2, 3, 3, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[150] = {
		[SpriteData.Types.Faint] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 40, 2, 4, 6, 8, 6, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 48, h = 56, x = 0, y = 0, durations = { 12, 6, 6, 12, 6, 6 } },
	},
	[151] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 56, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 12, 8, 12, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
	},
	[152] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 40, 2, 4, 3, 1, 1 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[153] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 40, 14, 20, 14 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[154] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 14, 20, 14 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 10, 14, 10, 14 } },
	},
	[155] = {
		[SpriteData.Types.Faint] = { w = 32, h = 24, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 40, 16 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[156] = {
		[SpriteData.Types.Faint] = { w = 32, h = 16, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 8, 4, 8, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 24, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[157] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 30, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[158] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 4, 2, 6, 3, 2, 3 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[159] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 25 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 12, 10, 12, 10 } },
	},
	[160] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 36, 2, 4, 2, 2, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[161] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 72, x = 0, y = 0, durations = { 30, 10, 2, 2, 3, 3, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[162] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 12, 4, 12, 4, 12 } },
		[SpriteData.Types.Walk] = { w = 56, h = 64, x = 0, y = 0, durations = { 6, 4, 4, 4, 4, 4, 4, 6 } },
	},
	[163] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 48, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 6, 6, 6, 8 } },
	},
	[164] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 64, x = 0, y = 0, durations = { 40, 2, 2, 6, 1, 2, 3, 6, 3, 2, 2, 2, 3, 3, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[165] = {
		[SpriteData.Types.Faint] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4 } },
	},
	[166] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4 } },
	},
	[167] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 40, 2, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 24, x = 0, y = 0, durations = { 10, 10, 10 } },
	},
	[168] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 12, 2, 2, 2, 2, 2, 2, 2, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[169] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 12, 12, 12, 12, 12, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[170] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 16, 8, 8, 16, 8, 8, 8 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 14, 10, 12, 12, 14 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 4, 6, 8, 8, 8, 10 } },
	},
	[171] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 20, 14, 14, 20, 14, 14 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 20, 6, 6, 6, 8, 8, 20, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[172] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 32, 4, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[173] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 36, 18 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 6, 6, 6, 8, 6, 6, 6 } },
	},
	[174] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 16, 16 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 4, 4, 4, 8 } },
	},
	[175] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 8, 10, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 6, 8, 8, 6, 8 } },
	},
	[176] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 30, 4, 3, 3, 3, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[177] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 4, 8, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[178] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 30 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[179] = {
		[SpriteData.Types.Faint] = { w = 32, h = 24, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 4, 3, 3, 3, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[180] = {
		[SpriteData.Types.Faint] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 4, 3, 3, 3, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[181] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 8, 8, 4, 6, 4, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[182] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 8, 4, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[183] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 26, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 8, 10, 8 } },
	},
	[184] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[185] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[186] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 40, 3, 5, 3, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 72, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 10 } },
	},
	[187] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 60, 10, 8, 10, 8, 6, 4, 2, 8, 8, 8, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4 } },
	},
	[188] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 20, 20 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[189] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[190] = {
		[SpriteData.Types.Faint] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 18 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 4, 6, 4, 8, 4, 6, 4 } },
	},
	[191] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 26, 18 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 4, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[192] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 1, 2, 3, 4, 3, 2, 1, 4, 1, 2, 3, 4, 3, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 14, 8, 14 } },
	},
	[193] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 } },
	},
	[194] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 24, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 6, 6, 6, 8, 6, 6, 6 } },
	},
	[195] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 56, x = 0, y = 0, durations = { 36, 4, 6, 8, 6, 4, 36 } },
		[SpriteData.Types.Walk] = { w = 48, h = 40, x = 0, y = 0, durations = { 10, 12, 10, 12 } },
	},
	[196] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[197] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[198] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 46, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 4, 4, 8, 4, 4, 8 } },
	},
	[199] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 20, 8, 12, 12, 8, 20, 8, 12, 12, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 10, 12, 10, 12 } },
	},
	[200] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[201] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 4, 35, 4 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 20, 8, 20, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 6, 5, 5, 6, 6, 6, 5, 5, 6 } },
	},
	[202] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 4, 4, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[203] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 12, 4, 4, 4, 4, 4, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[204] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 26, 22 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
	},
	[205] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 8, 20, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[206] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 24, x = 0, y = 0, durations = { 36, 19 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 6, 6, 6, 6 } },
	},
	[207] = {
		[SpriteData.Types.Faint] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 64, x = 0, y = 0, durations = { 6, 4, 4, 4, 8, 4, 4, 4 } },
	},
	[208] = {
		[SpriteData.Types.Sleep] = { w = 48, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 64, h = 112, x = 0, y = 0, durations = { 18, 8, 18, 8 } },
		[SpriteData.Types.Walk] = { w = 72, h = 112, x = 0, y = 0, durations = { 10, 14, 10, 14 } },
	},
	[209] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 2, 3, 4, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[210] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 30 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[211] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 12, 10, 10, 10, 12, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[212] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 30, 2, 3, 3, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[213] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 14, 20, 14 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 14, 8, 14, 8 } },
	},
	[214] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 30, 8, 4, 8, 4, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[215] = {
		[SpriteData.Types.Faint] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 1, 2, 4, 2, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[216] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 40, 12, 8, 12, 8, 20 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[217] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[218] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 6, 34, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 14, 8, 16, 8 } },
	},
	[219] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 12 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[220] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 36, 6, 6, 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 8, 8, 12 } },
	},
	[221] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[222] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 52, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[223] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 10, 10, 8, 8, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[224] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 10, 8, 20, 4, 12 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 24, 20 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 10, 12, 8, 16, 8 } },
	},
	[225] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 12, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[226] = {
		[SpriteData.Types.Sleep] = { w = 48, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 64, h = 72, x = 0, y = 0, durations = { 12, 12, 12, 12, 12, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 64, h = 72, x = 0, y = 0, durations = { 6, 6, 8, 8, 6, 6, 6, 8, 8, 6 } },
	},
	[227] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 64, x = 0, y = 0, durations = { 40, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 72, x = 0, y = 0, durations = { 4, 4, 4, 4, 8, 8, 8, 8, 8 } },
	},
	[228] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[229] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 64, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[230] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 64, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 40, h = 72, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[231] = {
		[SpriteData.Types.Faint] = { w = 40, h = 24, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 8, 20, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[232] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 40, 8, 20, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[233] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 12, 8, 12, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
	},
	[234] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6 } },
	},
	[235] = {
		[SpriteData.Types.Faint] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 36, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[236] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 30, 1, 2, 4, 4, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[237] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 56, x = 0, y = 0, durations = { 30, 2, 2, 2, 2, 2, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[238] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[239] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 30, 4, 6, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[240] = {
		[SpriteData.Types.Faint] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 30, 2, 3, 4, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[241] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 8, 3, 5, 3, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[242] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[243] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 56, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[244] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 56, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 10, 12, 10, 12 } },
	},
	[245] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 10, 12, 10, 12 } },
	},
	[246] = {
		[SpriteData.Types.Faint] = { w = 32, h = 24, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 30, 1, 2, 4, 2, 1, 16, 1, 2, 4, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[247] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 24, h = 56, x = 0, y = 0, durations = { 4, 4, 4, 12, 6, 4, 4, 36 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 6, 6, 6, 6, 6 } },
	},
	[248] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 14, 24, 14, 24 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 10, 16, 10, 16 } },
	},
	[249] = {
		[SpriteData.Types.Sleep] = { w = 56, h = 80, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 72, h = 96, x = 0, y = 0, durations = { 30, 30 } },
		[SpriteData.Types.Walk] = { w = 80, h = 96, x = 0, y = 0, durations = { 4, 4 } },
	},
	[250] = {
		[SpriteData.Types.Sleep] = { w = 56, h = 56, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 72, h = 112, x = 0, y = 0, durations = { 12, 10, 12, 10, 12 } },
		[SpriteData.Types.Walk] = { w = 72, h = 112, x = 0, y = 0, durations = { 8, 6, 8, 6, 8 } },
	},
	[251] = {
		[SpriteData.Types.Faint] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 56, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 24, h = 56, x = 0, y = 0, durations = { 8, 7, 6, 6, 6, 7 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4 } },
	},
	-- [252] = {
	-- 	[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 4, 2 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	-- },
	-- [253] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 18, 12 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 6, 6, 6, 8 } },
	-- },
	-- [254] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 30 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 10, 8, 10, 8 } },
	-- },
	-- [255] = {
	-- 	[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 3, 4, 3, 3 } },
	-- 	[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	-- },
	-- [256] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 40, 4, 6, 6, 4 } },
	-- 	[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	-- },
	-- [257] = {
	-- 	[SpriteData.Types.Sleep] = { w = 40, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 30, 30 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	-- },
	-- [258] = {
	-- 	[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 38, 2, 2, 5, 3, 3, 2 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 4, 6, 4, 6, 6, 4 } },
	-- },
	-- [259] = {
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 36, 16, 36, 16 } },
	-- 	[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	-- },
	-- [260] = {
	-- 	[SpriteData.Types.Faint] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 40, 1, 2, 4, 2, 2 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	-- },
	-- [261] = {
	-- 	[SpriteData.Types.Faint] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 8, 5, 8, 5, 8 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4, 4 } },
	-- },
	-- [262] = {
	-- 	[SpriteData.Types.Faint] = { w = 48, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 48, h = 48, x = 0, y = 0, durations = { 40, 8, 5, 8, 5, 8 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
	-- },
	-- [263] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 2, 4, 4, 4, 2 } },
	-- 	[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 6, 4, 4, 2, 4, 4, 4 } },
	-- },
	-- [264] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 48, h = 40, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
	-- 	[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 6, 6, 6, 6, 6 } },
	-- },
	-- [265] = {
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 12, 4, 4, 4, 4, 4, 4 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 2, 4, 6, 4, 2 } },
	-- },
	-- [266] = {
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 2, 2, 120 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 2, 2, 120 } },
	-- },
	-- [267] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 40, h = 64, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
	-- 	[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 } },
	-- },
	-- [268] = {
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 2, 2, 120 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 2, 2, 120 } },
	-- },
	-- [269] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 6, 4, 4, 6, 4, 4 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 } },
	-- },
	-- [270] = {
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 24, 18, 24, 18 } },
	-- 	[SpriteData.Types.Walk] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	-- },
	-- [271] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 1, 2, 3, 4, 2, 1, 10 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	-- },
	-- [272] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 20 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	-- },
	-- [273] = {
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 36, 18 } },
	-- 	[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 4, 6, 4, 8, 4, 6, 4 } },
	-- },
	-- [274] = {
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	-- },
	-- [275] = {
	-- 	[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 24, 4, 4, 4, 24, 4, 4, 4 } },
	-- 	[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 4, 4, 4, 8, 4, 4, 4 } },
	-- },
	-- [276] = {
	-- 	[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 30, 35 } },
	-- 	[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 4, 6, 4, 4 } },
	-- 	[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 4, 4, 4, 4 } },
	-- },
	[277] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[278] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 18, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 6, 6, 6, 8 } },
	},
	[279] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 30 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 10, 8, 10, 8 } },
	},
	[280] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 3, 4, 3, 3 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[281] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 40, 4, 6, 6, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[282] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 30, 30 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[283] = {
		[SpriteData.Types.Faint] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 38, 2, 2, 5, 3, 3, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 4, 6, 4, 6, 6, 4 } },
	},
	[284] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 36, 16, 36, 16 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[285] = {
		[SpriteData.Types.Faint] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 40, 1, 2, 4, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[286] = {
		[SpriteData.Types.Faint] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 8, 5, 8, 5, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4, 4 } },
	},
	[287] = {
		[SpriteData.Types.Faint] = { w = 48, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 48, x = 0, y = 0, durations = { 40, 8, 5, 8, 5, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
	},
	[288] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 2, 4, 4, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 6, 4, 4, 2, 4, 4, 4 } },
	},
	[289] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 40, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 6, 6, 6, 6, 6 } },
	},
	[290] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 12, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 2, 4, 6, 4, 2 } },
	},
	[291] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 2, 2, 120 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 2, 2, 120 } },
	},
	[292] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 64, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[293] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 2, 2, 120 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 2, 2, 120 } },
	},
	[294] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 6, 4, 4, 6, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 } },
	},
	[295] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 24, 18, 24, 18 } },
		[SpriteData.Types.Walk] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[296] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 1, 2, 3, 4, 2, 1, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[297] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 20 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[298] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 36, 18 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 4, 6, 4, 8, 4, 6, 4 } },
	},
	[299] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[300] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 24, 4, 4, 4, 24, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 4, 4, 4, 8, 4, 4, 4 } },
	},
	[301] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 40, 4, 2, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[302] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 9 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 4, 4, 4, 4 } },
	},
	[303] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 12, 12, 16, 12, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 24, h = 56, x = 0, y = 0, durations = { 8, 4, 4, 4, 4, 8, 8, 4, 4, 4, 4, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 56, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 } },
	},
	[304] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 16, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 4, 6, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 4, 4, 4, 4 } },
	},
	[305] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 40, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[306] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 24, x = 0, y = 0, durations = { 40, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 24, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[307] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 4, 4, 4, 4, 4, 8, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[308] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 2, 6, 4, 2, 1, 3, 4, 4 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 4, 8, 14, 4, 5, 6, 8, 14, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 10, 10, 12, 14, 12, 10, 10, 12, 14, 12, 10 } },
	},
	[309] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 8, 6, 8, 6, 8, 6, 8, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[310] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 4, 8, 10, 4, 8 } },
	},
	[311] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 16, 8, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[312] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[313] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 16, 10, 16, 16, 10, 10, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 6, 6, 8, 6, 6, 6 } },
	},
	[314] = {
		[SpriteData.Types.Sleep] = { w = 72, h = 80, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 72, h = 104, x = 0, y = 0, durations = { 24, 12, 12, 24, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 72, h = 104, x = 0, y = 0, durations = { 10, 8, 6, 6, 8, 8, 10, 8, 6, 6, 6, 8 } },
	},
	[315] = {
		[SpriteData.Types.Faint] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 8, 6, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 4, 5, 6, 6, 6, 5, 4 } },
	},
	[316] = {
		[SpriteData.Types.Faint] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 60, 10, 5, 5, 5, 5, 5, 5, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[317] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 2, 6, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[318] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 8, 16, 8, 8, 8, 8, 16, 8, 8 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 4, 4, 4, 4, 4, 4, 4, 4, 6, 6, 6, 6, 6 } },
	},
	[319] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[320] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 30, 6, 4, 4, 4, 4, 4, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[321] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 20, 20, 20 } },
		[SpriteData.Types.Walk] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[322] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 12 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[323] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 12, 10, 10, 12, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 6, 6, 8, 6, 6 } },
	},
	[324] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 20, 12, 12, 20, 12, 12 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 6, 6, 6, 8, 8, 6, 8, 8 } },
	},
	[325] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 34, 8, 8, 8, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[326] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 24, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[327] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 24, 12, 24, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[328] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 12, 14, 12, 14 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10, 8, 10, 8, 10 } },
	},
	[329] = {
		[SpriteData.Types.Sleep] = { w = 48, h = 72, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 72, h = 80, x = 0, y = 0, durations = { 40, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 72, h = 80, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
	},
	[330] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 26, 8, 36 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6 } },
	},
	[331] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 26, 8, 8, 26 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 16, 16, 16, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 10, 8, 8, 8, 10, 8, 8, 8 } },
	},
	[332] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 8, 10, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[333] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 40, 4, 4, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 4, 6, 6, 6, 4, 6, 6, 6 } },
	},
	[334] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 64, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 72, x = 0, y = 0, durations = { 8, 9, 8, 8, 11, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 64, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[335] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 2, 2, 2, 2, 20, 4, 4, 4, 2, 2, 2, 2, 20, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[336] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 26, 2, 4, 4, 2, 1, 26, 1, 4, 4, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[337] = {
		[SpriteData.Types.Faint] = { w = 40, h = 24, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[338] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[339] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 8, 12, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[340] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 20, 8, 20 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[341] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 16, 6, 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6 } },
	},
	[342] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 14, 18, 14 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 6, 6, 8, 6, 6 } },
	},
	[343] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 40, 2, 8, 8, 8, 8, 8, 4 } },
		[SpriteData.Types.Walk] = { w = 48, h = 56, x = 0, y = 0, durations = { 8, 6, 6, 6, 6, 6, 6 } },
	},
	[344] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 10, 16, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[345] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 40, 2, 4, 4, 4, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[346] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[347] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 64, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[348] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[349] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[350] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 16, 10, 16, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6 } },
	},
	[351] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 40, 30 } },
		[SpriteData.Types.Idle] = { w = 24, h = 56, x = 0, y = 0, durations = { 30, 4, 4, 8, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 64, x = 0, y = 0, durations = { 4, 6, 4, 6, 4, 4, 4, 6, 4, 6, 4, 4 } },
	},
	[352] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 40, 12, 8, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[353] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 10, 6, 10 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 6, 4, 8, 4, 6, 4, 8, 4 } },
	},
	[354] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 10, 6, 10 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 6, 4, 8, 4, 6, 4, 8, 4 } },
	},
	[355] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 56, h = 48, x = 0, y = 0, durations = { 40, 2, 2, 2, 4, 6, 4, 6, 4, 2, 2, 2, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[356] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 16, 8, 16 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[357] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 56, x = 0, y = 0, durations = { 40, 2, 2, 3, 4, 3, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 24, h = 56, x = 0, y = 0, durations = { 10, 6, 6, 6, 10, 6, 6, 6 } },
	},
	[358] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 4, 4, 4, 4, 6, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 6, 6, 8, 6, 6 } },
	},
	[359] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 64, x = 0, y = 0, durations = { 60, 6, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 48, h = 56, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[360] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 2, 10, 2, 8, 2, 10, 2 } },
	},
	[361] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 8, 16, 8, 8, 8, 16, 8 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 24, 8, 8, 24, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[362] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 40, 8, 12, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[363] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6, 40 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[364] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 32, x = 0, y = 0, durations = { 60, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[365] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 2, 2, 6, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[366] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 50, 6, 2, 6, 4, 2, 2 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 10, 16, 10, 16 } },
	},
	[367] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 20, 30 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 8, 10, 8, 8, 10 } },
	},
	[368] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 16, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 8, 10, 8, 8, 8 } },
	},
	[369] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 72, x = 0, y = 0, durations = { 30, 3, 5, 4, 5, 4, 5, 4, 5, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 48, h = 56, x = 0, y = 0, durations = { 10, 14, 10, 14 } },
	},
	[370] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 1, 1, 4, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[371] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 1, 1, 4, 4, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 10, 6, 10 } },
	},
	[372] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 10, 8, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[373] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 6, 8, 6 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 10, 6, 6, 6, 8 } },
	},
	[374] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 56, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 56, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[375] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 56, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 48, h = 72, x = 0, y = 0, durations = { 16, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 48, h = 64, x = 0, y = 0, durations = { 14, 6, 8, 8, 8, 8, 6, 6, 6 } },
	},
	[376] = {
		[SpriteData.Types.Faint] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 40, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 30, 30 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[377] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 10, 10, 18, 10, 10, 18 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 24, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6 } },
	},
	[378] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 56, x = 0, y = 0, durations = { 40, 1, 2, 4, 4, 4, 4, 2, 1 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[379] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 14, 18, 14, 18 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8 } },
	},
	[380] = {
		[SpriteData.Types.Faint] = { w = 48, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 32, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 30, 4, 4, 4, 4, 4 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[381] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 48, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 30, 6, 4, 6, 4, 14, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
	},
	[382] = {
		[SpriteData.Types.Faint] = { w = 32, h = 24, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 34, 12, 8, 12 } },
		[SpriteData.Types.Walk] = { w = 24, h = 24, x = 0, y = 0, durations = { 6, 8, 6, 8 } },
	},
	[383] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 40, 16, 8, 16 } },
		[SpriteData.Types.Walk] = { w = 32, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[384] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 40, 6, 2, 6, 2, 6 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[385] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 35, 30 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 6, 6, 6, 6, 8 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[386] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 8, 4, 8, 4, 8, 4, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4 } },
	},
	[387] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 20 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4 } },
	},
	[388] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[389] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 48, x = 0, y = 0, durations = { 40, 4, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[390] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[391] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 48, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 48, h = 48, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[392] = {
		[SpriteData.Types.Faint] = { w = 40, h = 32, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 24, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 32, x = 0, y = 0, durations = { 40, 25 } },
		[SpriteData.Types.Walk] = { w = 24, h = 32, x = 0, y = 0, durations = { 10, 8, 10, 8 } },
	},
	[393] = {
		[SpriteData.Types.Faint] = { w = 40, h = 40, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 60, 4, 4, 4, 4, 4, 4, 6, 24 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 1, 2, 3, 3, 1, 4, 2, 2, 2, 2, 2, 2, 2 } },
	},
	[394] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 6, 12, 6, 12 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 12, 8, 12 } },
	},
	[395] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 24, h = 40, x = 0, y = 0, durations = { 40, 10, 14, 10 } },
		[SpriteData.Types.Walk] = { w = 24, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[396] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 18, 20, 18, 20 } },
		[SpriteData.Types.Walk] = { w = 32, h = 40, x = 0, y = 0, durations = { 8, 10, 8, 10 } },
	},
	[397] = {
		[SpriteData.Types.Faint] = { w = 56, h = 48, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 48, h = 48, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 56, h = 56, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 56, h = 80, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
	},
	[398] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 32, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 32, h = 40, x = 0, y = 0, durations = { 10, 10, 10, 10, 10, 10, 10, 10 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[399] = {
		[SpriteData.Types.Sleep] = { w = 40, h = 40, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 12, 12, 12, 12, 12, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[400] = {
		[SpriteData.Types.Sleep] = { w = 48, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 20 } },
		[SpriteData.Types.Walk] = { w = 48, h = 40, x = 0, y = 0, durations = { 8, 14, 8, 14 } },
	},
	[401] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 56, x = 0, y = 0, durations = { 40, 1, 4, 2, 3, 4, 3 } },
		[SpriteData.Types.Walk] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 18, 8, 18 } },
	},
	[402] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 48, x = 0, y = 0, durations = { 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
	},
	[403] = {
		[SpriteData.Types.Sleep] = { w = 32, h = 40, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 40, h = 40, x = 0, y = 0, durations = { 40, 40 } },
		[SpriteData.Types.Walk] = { w = 40, h = 40, x = 0, y = 0, durations = { 10, 10, 10, 10 } },
	},
	[404] = {
		[SpriteData.Types.Sleep] = { w = 64, h = 72, x = 0, y = 0, durations = { 16, 12, 16, 16, 12, 16 } },
		[SpriteData.Types.Idle] = { w = 64, h = 72, x = 0, y = 0, durations = { 10, 14, 14, 14, 14, 10, 14, 14, 14, 14 } },
		[SpriteData.Types.Walk] = { w = 64, h = 72, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[405] = {
		[SpriteData.Types.Faint] = { w = 56, h = 80, x = 0, y = 0, durations = { 10, 2, 2, 2, 2, 2, 10, 4, 2, 2, 2, 2, 16, 8, 6, 5, 3, 1, 2, 4, 2, 1, 20 } },
		[SpriteData.Types.Sleep] = { w = 56, h = 56, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 64, h = 80, x = 0, y = 0, durations = { 60, 10, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 10 } },
		[SpriteData.Types.Walk] = { w = 64, h = 88, x = 0, y = 0, durations = { 10, 12, 10, 12 } },
	},
	[406] = {
		[SpriteData.Types.Sleep] = { w = 72, h = 96, x = 0, y = 0, durations = { 10, 10, 10, 30, 10, 10, 10, 30 } },
		[SpriteData.Types.Idle] = { w = 80, h = 120, x = 0, y = 0, durations = { 14, 10, 14, 10 } },
		[SpriteData.Types.Walk] = { w = 80, h = 128, x = 0, y = 0, durations = { 8, 8, 6, 4, 4, 4, 8, 8, 6, 6, 6, 6 } },
	},
	[407] = {
		[SpriteData.Types.Faint] = { w = 56, h = 64, x = 0, y = 0, durations = { 8, 12, 4, 10 } },
		[SpriteData.Types.Sleep] = { w = 40, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 48, h = 64, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 48, h = 64, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 } },
	},
	[408] = {
		[SpriteData.Types.Faint] = { w = 56, h = 80, x = 0, y = 0, durations = { 10, 6, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 1, 6, 3, 10 } },
		[SpriteData.Types.Sleep] = { w = 48, h = 32, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 64, h = 80, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8 } },
		[SpriteData.Types.Walk] = { w = 64, h = 80, x = 0, y = 0, durations = { 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4 } },
	},
	[409] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 48, x = 0, y = 0, durations = { 8, 8, 8, 24, 8, 8, 8, 24 } },
		[SpriteData.Types.Idle] = { w = 40, h = 48, x = 0, y = 0, durations = { 12, 8, 12, 8 } },
		[SpriteData.Types.Walk] = { w = 40, h = 48, x = 0, y = 0, durations = { 6, 6, 6, 6, 6, 6, 6, 6, 6 } },
	},
	[410] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 56, x = 0, y = 0, durations = { 30, 35 } },
		[SpriteData.Types.Idle] = { w = 32, h = 64, x = 0, y = 0, durations = { 12, 12, 12, 12, 12, 12, 12, 12 } },
		[SpriteData.Types.Walk] = { w = 40, h = 64, x = 0, y = 0, durations = { 8, 8, 8, 8, 8, 8, 8, 8 } },
	},
	[411] = {
		[SpriteData.Types.Sleep] = { w = 24, h = 56, x = 0, y = 0, durations = { 28, 10, 10, 28, 10, 10 } },
		[SpriteData.Types.Idle] = { w = 24, h = 48, x = 0, y = 0, durations = { 18, 8, 18, 8 } },
		[SpriteData.Types.Walk] = { w = 32, h = 56, x = 0, y = 0, durations = { 4, 4, 6, 6, 4, 4, 4, 4, 6, 6, 4, 4 } },
	},
}