ExtrasScreen = {
	Colors = {
		text = "Lower box text",
		border = "Lower box border",
		boxFill = "Lower box background",
	},
}

-- Holds all the buttons for the screen
-- Buttons are created in CreateButtons()
ExtrasScreen.Buttons = {
	ViewLogFile = {
		type = Constants.ButtonTypes.ICON_BORDER,
		image = Constants.PixelImages.MAGNIFYING_GLASS,
		getText = function(self) return Resources.ExtrasScreen.ButtonViewLogs end,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 4, Constants.SCREEN.MARGIN + 14, 52, 16 },
		onClick = function(self)
			Program.changeScreenView(ViewLogWarningScreen)
		end,
	},
	TimeMachine = {
		type = Constants.ButtonTypes.ICON_BORDER,
		getText = function(self) return Resources.ExtrasScreen.ButtonTimeMachine end,
		image = Constants.PixelImages.CLOCK,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 60, Constants.SCREEN.MARGIN + 14, 76, 16 },
		onClick = function()
			TimeMachineScreen.buildOutPagedButtons()
			Program.changeScreenView(TimeMachineScreen)
		end
	},
	EstimateIVs = {
		type = Constants.ButtonTypes.FULL_BORDER,
		getText = function(self) return Resources.ExtrasScreen.ButtonEstimatePokemonIVs end,
		ivText = "",
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 4, Constants.SCREEN.MARGIN + 100, 132, 11 },
		onClick = function() ExtrasScreen.displayJudgeMessage() end
	},
	CrashRecovery = {
		type = Constants.ButtonTypes.ICON_BORDER,
		image = Constants.PixelImages.WARNING,
		getText = function(self) return Resources.ExtrasScreen.ButtonCrashRecovery end,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 4, Constants.SCREEN.MARGIN + 130, 85, 16 },
		onClick = function(self)
			Program.changeScreenView(CrashRecoveryScreen)
		end
	},
	Back = {
		type = Constants.ButtonTypes.FULL_BORDER,
		getText = function(self) return Resources.AllScreens.Back end,
		box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 112, Constants.SCREEN.MARGIN + 135, 24, 11 },
		onClick = function(self)
			ExtrasScreen.Buttons.EstimateIVs.ivText = "" -- keep hidden
			-- Save all of the Options to the Settings.ini file, and navigate back to the main Tracker screen
			Main.SaveSettings()
			Program.changeScreenView(NavigationMenu)
		end
	},
}

function ExtrasScreen.initialize()
	ExtrasScreen.createButtons()

	for _, button in pairs(ExtrasScreen.Buttons) do
		if button.textColor == nil then
			button.textColor = ExtrasScreen.Colors.text
		end
		if button.boxColors == nil then
			button.boxColors = { ExtrasScreen.Colors.border, ExtrasScreen.Colors.boxFill }
		end
	end

	local abraGif = FileManager.buildImagePath(FileManager.Folders.AnimatedPokemon, "abra", FileManager.Extensions.ANIMATED_POKEMON)
	local animatedBtnOption = ExtrasScreen.Buttons["Animated Pokemon popout"]
	if not FileManager.fileExists(abraGif) and animatedBtnOption ~= nil then
		animatedBtnOption.disabled = true
	end
end

function ExtrasScreen.createButtons()
	local optionKeyMap = {
		{"Show random ball picker", "OptionShowRandomBallPicker", },
		{"Display repel usage", "OptionDisplayRepelUsage", },
		{"Display pedometer", "OptionDisplayPedometer", },
		{"Display play time", "OptionDisplayPlayTime", },
		{"Animated Pokemon popout", "OptionAnimatedPokemonPopout", },
	}

	local startX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5
	local startY = ExtrasScreen.Buttons.ViewLogFile.box[2] + ExtrasScreen.Buttons.ViewLogFile.box[4] + 5
	local linespacing = Constants.SCREEN.LINESPACING + 1

	for _, optionTuple in ipairs(optionKeyMap) do
		ExtrasScreen.Buttons[optionTuple[1]] = {
			type = Constants.ButtonTypes.CHECKBOX,
			optionKey = optionTuple[1],
			getText = function(self) return Resources.ExtrasScreen[optionTuple[2]] end,
			clickableArea = { startX, startY, Constants.SCREEN.RIGHT_GAP - 12, 8 },
			box = {	startX, startY, 8, 8 },
			toggleState = Options[optionTuple[1]],
			updateSelf = function(self) self.toggleState = (Options[self.optionKey] == true) end,
			onClick = function(self)
				self.toggleState = Options.toggleSetting(self.optionKey)

				-- If Animated Pokemon popout is turned on, create the popup form, or destroy it.
				if self.optionKey == "Animated Pokemon popout" then
					if self.toggleState == true then
						Drawing.AnimatedPokemon:create()
					else
						Drawing.AnimatedPokemon:destroy()
					end
				elseif self.optionKey == "Display play time" and self.toggleState then
					-- Show help tip for pausing (4 seconds)
					Program.GameTimer.showPauseTipUntil = os.time() + 4
				end
				Program.redraw(true)
			end
		}
		startY = startY + linespacing
	end
end

function ExtrasScreen.displayJudgeMessage()
	local leadPokemon = Battle.getViewedPokemon(true)
	if leadPokemon ~= nil and PokemonData.isValid(leadPokemon.pokemonID) then
		-- Source: https://bulbapedia.bulbagarden.net/wiki/Stats_judge
		local result
		local ivEstimate = Utils.estimateIVs(leadPokemon) * 186
		if ivEstimate >= 151 then
			result = Resources.ExtrasScreen.EstimateResultOutstanding
		elseif ivEstimate >= 121 and ivEstimate <= 150 then
			result = Resources.ExtrasScreen.EstimateResultQuiteImpressive
		elseif ivEstimate >= 91 and ivEstimate <= 120 then
			result = Resources.ExtrasScreen.EstimateResultAboveAverage
		else
			result = Resources.ExtrasScreen.EstimateResultDecent
		end

		local pokemonName = PokemonData.Pokemon[leadPokemon.pokemonID].name
		ExtrasScreen.Buttons.EstimateIVs.ivText = string.format("%s: %s", pokemonName, result)

		-- Joey's Rattata meme (saving for later)
		-- local topPercentile = math.max(100 - 100 * Utils.estimateIVs(leadPokemon), 1)
		-- local percentText = string.format("%g", string.format("%d", topPercentile)) .. "%" -- %g removes insignificant 0's
		-- message = "In the top " .. percentText .. " of  " .. PokemonData.Pokemon[leadPokemon.pokemonID].name
	else
		ExtrasScreen.Buttons.EstimateIVs.ivText = Resources.ExtrasScreen.EstimateResultUnavailable
	end
	Program.redraw(true)
end

-- USER INPUT FUNCTIONS
function ExtrasScreen.checkInput(xmouse, ymouse)
	Input.checkButtonsClicked(xmouse, ymouse, ExtrasScreen.Buttons)
end

-- DRAWING FUNCTIONS
function ExtrasScreen.drawScreen()
	Drawing.drawBackgroundAndMargins()
	gui.defaultTextBackground(Theme.COLORS[ExtrasScreen.Colors.boxFill])

	local shadowcolor = Utils.calcShadowColor(Theme.COLORS[ExtrasScreen.Colors.boxFill])
	local topboxX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN
	local topboxY = Constants.SCREEN.MARGIN + 10
	local topboxWidth = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2)
	local topboxHeight = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2) - 10

	-- Draw header text
	local headerShadow = Utils.calcShadowColor(Theme.COLORS["Main background"])
	Drawing.drawText(topboxX, Constants.SCREEN.MARGIN - 2, Utils.toUpperUTF8(Resources.ExtrasScreen.Title), Theme.COLORS["Header text"], headerShadow)

	-- Draw top border box
	gui.drawRectangle(topboxX, topboxY, topboxWidth, topboxHeight, Theme.COLORS[ExtrasScreen.Colors.border], Theme.COLORS[ExtrasScreen.Colors.boxFill])

	-- Draw all buttons
	for _, button in pairs(ExtrasScreen.Buttons) do
		Drawing.drawButton(button, shadowcolor)
	end

	local ivBtn = ExtrasScreen.Buttons.EstimateIVs
	Drawing.drawText(topboxX + 4, ivBtn.box[2] + ivBtn.box[4] + 1, ivBtn.ivText, Theme.COLORS[ivBtn.textColor], shadowcolor)
end

