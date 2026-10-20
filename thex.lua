-- TheX UI library
-- Copyright (c) 2026 TheX
local modules = {}
local cache = {}
local function require(id)
	if cache[id] == nil then
		cache[id] = modules[id](require)
	end
	return cache[id]
end

modules["Config"] = function(require)
local HttpService = game:GetService("HttpService")

local Config = {
	memory = {},
}

local function ensureFolder(path)
	if type(makefolder) ~= "function" or type(isfolder) ~= "function" then
		return
	end
	local folder = string.match(path, "^(.*)/[^/]+$")
	if not folder or folder == "" then
		return
	end
	local built = ""
	for part in string.gmatch(folder, "[^/]+") do
		built = (built == "") and part or (built .. "/" .. part)
		local ok, exists = pcall(isfolder, built)
		if ok and not exists then
			pcall(makefolder, built)
		end
	end
end

local function fileExists(path)
	if type(isfile) ~= "function" then
		return false
	end
	local ok, result = pcall(isfile, path)
	return ok and result == true
end

function Config.save(path, controls)
	local data = {}
	for id, control in pairs(controls) do
		data[id] = {
			type = control.type,
			value = control:encode(),
		}
	end

	local payload = HttpService:JSONEncode(data)
	if type(writefile) == "function" then
		ensureFolder(path)
		local ok, err = pcall(writefile, path, payload)
		if not ok then
			warn("[TheX] Could not save config: " .. tostring(err))
			return false
		end
		return true
	end

	Config.memory[path] = payload
	return true
end

function Config.load(path, controls)
	local payload = nil
	if fileExists(path) and type(readfile) == "function" then
		local ok, contents = pcall(readfile, path)
		if ok and type(contents) == "string" then
			payload = contents
		end
	end
	if not payload then
		payload = Config.memory[path]
	end
	if type(payload) ~= "string" then
		return false
	end

	local ok, data = pcall(function()
		return HttpService:JSONDecode(payload)
	end)
	if not ok or type(data) ~= "table" then
		return false
	end

	for id, saved in pairs(data) do
		local control = controls[id]
		if control and type(saved) == "table" then
			control:set(saved.value)
		end
	end
	return true
end

return Config
end

modules["Dialog"] = function(require)
local Theme = require("Theme")
local Ui = require("Ui")

local Dialog = {}

function Dialog.open(parent, config)
	local overlay = Ui.inst("TextButton", {
		Name = "Dialog",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = parent,
	})

	local card = Ui.inst("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		ZIndex = 9,
		Parent = overlay,
	})
	Theme.paint(card, "BackgroundColor3", "window")
	Ui.corner(card, 10)
	Ui.padding(card, 14)
	Ui.list(card, 10)

	local title = Ui.label({
		Text = config.title or "Dialog",
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 1,
		ZIndex = 9,
		Parent = card,
	})
	Theme.paint(title, "TextColor3", "text")

	local body = Ui.label({
		Text = config.content or "",
		TextSize = 14,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		ZIndex = 9,
		Parent = card,
	})
	Theme.paint(body, "TextColor3", "muted")

	local buttons = config.buttons
	if type(buttons) ~= "table" or #buttons == 0 then
		buttons = {
			{ title = "Close" },
		}
	end

	local row = Ui.inst("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 3,
		ZIndex = 9,
		Parent = card,
	})
	Ui.inst("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})

	local function close()
		if overlay.Parent then
			overlay:Destroy()
		end
	end

	for index, spec in ipairs(buttons) do
		local button = Ui.inst("TextButton", {
			AutoButtonColor = false,
			Text = spec.title or "OK",
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			Size = UDim2.fromOffset(108, 34),
			BorderSizePixel = 0,
			LayoutOrder = index,
			ZIndex = 10,
			Parent = row,
		})
		Ui.corner(button, 8)
		if index == 1 then
			Theme.paint(button, "BackgroundColor3", "accent")
			Theme.paint(button, "TextColor3", "accentText")
		else
			Theme.paint(button, "BackgroundColor3", "track")
			Theme.paint(button, "TextColor3", "text")
		end
		button.MouseButton1Click:Connect(function()
			close()
			Ui.fire(spec.onClick)
		end)
	end

	return { close = close }
end

return Dialog
end

modules[""] = function(require)
local Notify = require("Notify")
local Theme = require("Theme")
local Window = require("Window")

local TheX = {
	version = "1.0.0",
}

local windows = {}
local noticeGui = nil

function TheX.window(config)
	local window = Window.create(config)
	table.insert(windows, window)
	local destroy = window.destroy
	function window:destroy()
		destroy(self)
		local remaining = {}
		for _, other in ipairs(windows) do
			if other ~= self then
				table.insert(remaining, other)
			end
		end
		windows = remaining
	end
	return window
end

function TheX.notify(config)
	if noticeGui == nil or noticeGui.Parent == nil then
		noticeGui = Notify.mount()
	end
	return Notify.push(noticeGui, config or {})
end

function TheX.setTheme(name)
	return Theme.set(name)
end

function TheX.themeNames()
	return Theme.names()
end

function TheX.destroy()
	for _, window in ipairs(windows) do
		window:destroy()
	end
	table.clear(windows)
	if noticeGui and noticeGui.Parent then
		noticeGui:Destroy()
	end
	noticeGui = nil
end

if getgenv then
	getgenv().TheX = TheX
end

return TheX
end

modules["Notify"] = function(require)
local Theme = require("Theme")
local Ui = require("Ui")

local Notify = {}

function Notify.mount()
	local gui = Ui.screen("TheXNotices", 100001)
	local holder = Ui.inst("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Ui.list(holder, 8)
	holder.Name = "Holder"
	return gui
end

function Notify.push(gui, config)
	local holder = gui:FindFirstChild("Holder")
	if not holder then
		return nil
	end

	local card = Ui.inst("TextButton", {
		Name = "Notice",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Theme.paint(card, "BackgroundColor3", "notice")
	Ui.corner(card, 8)
	Ui.padding(card, 12)
	Ui.list(card, 4)

	local bar = Ui.inst("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = card,
	})
	Theme.paint(bar, "BackgroundColor3", "accent")
	Ui.corner(bar, 2)

	local title = Ui.label({
		Text = config.title or "Notice",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 2,
		Parent = card,
	})
	Theme.paint(title, "TextColor3", "text")

	local body = Ui.label({
		Text = config.content or "",
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = card,
	})
	Theme.paint(body, "TextColor3", "muted")

	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		if card.Parent then
			card:Destroy()
		end
	end

	card.MouseButton1Click:Connect(dismiss)
	if type(config.duration) == "number" then
		task.delay(config.duration, dismiss)
	end
	return { dismiss = dismiss }
end

return Notify
end

modules["Tab"] = function(require)
local Theme = require("Theme")
local Ui = require("Ui")
local Paragraph = require("Widgets/Paragraph")
local Button = require("Widgets/Button")
local Toggle = require("Widgets/Toggle")
local Slider = require("Widgets/Slider")
local Dropdown = require("Widgets/Dropdown")
local Input = require("Widgets/Input")
local Keybind = require("Widgets/Keybind")
local Colorpicker = require("Widgets/Colorpicker")

local Tab = {}

function Tab.create(window, config)
	local tab = {
		window = window,
		selected = false,
		_order = 0,
	}

	tab.tabButton = Ui.inst("TextButton", {
		Name = (config.title or "Tab") .. "Tab",
		AutoButtonColor = false,
		Text = config.title or "Tab",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -16, 0, 34),
		BorderSizePixel = 0,
		Parent = window.rail,
	})
	Ui.corner(tab.tabButton, 8)
	Ui.inst("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		Parent = tab.tabButton,
	})

	tab.page = Ui.inst("ScrollingFrame", {
		Name = (config.title or "Tab") .. "Page",
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window.pages,
	})
	Theme.paint(tab.page, "ScrollBarImageColor3", "accent")
	Ui.padding(tab.page, 10)
	Ui.list(tab.page, 8)

	function tab:nextOrder()
		self._order += 1
		return self._order
	end

	function tab:paint()
		self.page.Visible = self.selected
		self.tabButton.BackgroundColor3 = self.selected and Theme.color("accent") or Theme.color("rail")
		self.tabButton.TextColor3 = self.selected and Theme.color("accentText") or Theme.color("text")
	end

	function tab:paragraph(options)
		return Paragraph.create(self, options or {})
	end
	function tab:button(options)
		return Button.create(self, options or {})
	end
	function tab:toggle(options)
		return Toggle.create(self, options or {})
	end
	function tab:slider(options)
		return Slider.create(self, options or {})
	end
	function tab:dropdown(options)
		return Dropdown.create(self, options or {})
	end
	function tab:input(options)
		return Input.create(self, options or {})
	end
	function tab:keybind(options)
		return Keybind.create(self, options or {})
	end
	function tab:colorpicker(options)
		return Colorpicker.create(self, options or {})
	end

	tab.tabButton.MouseButton1Click:Connect(function()
		window:select(tab)
	end)
	Theme.onChange(function()
		if tab.tabButton.Parent then
			tab:paint()
		end
	end)
	tab:paint()
	return tab
end

return Tab
end

modules["Theme"] = function(require)
local Theme = {
	name = "Dark",
	palettes = {
		Dark = {
			window = Color3.fromRGB(22, 24, 31),
			rail = Color3.fromRGB(28, 31, 40),
			bar = Color3.fromRGB(34, 38, 49),
			row = Color3.fromRGB(40, 44, 58),
			text = Color3.fromRGB(240, 237, 230),
			muted = Color3.fromRGB(168, 164, 154),
			accent = Color3.fromRGB(214, 146, 58),
			accentText = Color3.fromRGB(32, 22, 10),
			stroke = Color3.fromRGB(68, 72, 86),
			track = Color3.fromRGB(54, 58, 72),
			danger = Color3.fromRGB(186, 84, 74),
			notice = Color3.fromRGB(30, 33, 43),
		},
		Light = {
			window = Color3.fromRGB(246, 242, 234),
			rail = Color3.fromRGB(236, 230, 218),
			bar = Color3.fromRGB(226, 218, 204),
			row = Color3.fromRGB(255, 252, 246),
			text = Color3.fromRGB(36, 32, 28),
			muted = Color3.fromRGB(110, 100, 88),
			accent = Color3.fromRGB(176, 98, 32),
			accentText = Color3.fromRGB(255, 248, 238),
			stroke = Color3.fromRGB(214, 204, 188),
			track = Color3.fromRGB(214, 206, 192),
			danger = Color3.fromRGB(168, 64, 54),
			notice = Color3.fromRGB(255, 250, 242),
		},
	},
}

local bindings = {}
local listeners = {}

function Theme.color(token)
	local palette = Theme.palettes[Theme.name] or Theme.palettes.Dark
	return palette[token]
end

function Theme.paint(instance, property, token)
	instance[property] = Theme.color(token)
	table.insert(bindings, { instance, property, token })
end

function Theme.onChange(callback)
	table.insert(listeners, callback)
	return callback
end

function Theme.set(name)
	if not Theme.palettes[name] then
		return false
	end

	Theme.name = name
	local alive = {}
	for _, binding in ipairs(bindings) do
		local instance = binding[1]
		if instance and instance.Parent then
			instance[binding[2]] = Theme.color(binding[3])
			table.insert(alive, binding)
		end
	end
	bindings = alive

	for _, callback in ipairs(listeners) do
		task.spawn(callback, name)
	end
	return true
end

function Theme.names()
	local list = {}
	for name in pairs(Theme.palettes) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

return Theme
end

modules["Ui"] = function(require)
local Theme = require("Theme")
local TweenService = game:GetService("TweenService")

local Ui = {}

function Ui.inst(className, props)
	local object = Instance.new(className)
	local parent = nil
	if props then
		parent = props.Parent
		for key, value in pairs(props) do
			if key ~= "Parent" then
				object[key] = value
			end
		end
	end
	if parent then
		object.Parent = parent
	end
	return object
end

function Ui.corner(parent, radius)
	return Ui.inst("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
		Parent = parent,
	})
end

function Ui.padding(parent, pixels)
	return Ui.inst("UIPadding", {
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		Parent = parent,
	})
end

function Ui.list(parent, gap, direction)
	return Ui.inst("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap or 8),
		Parent = parent,
	})
end

function Ui.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = props.BorderSizePixel or 0
	props.Font = props.Font or Enum.Font.Gotham
	props.TextColor3 = props.TextColor3 or Theme.color("text")
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	props.TextSize = props.TextSize or 14
	return Ui.inst("TextLabel", props)
end

function Ui.fire(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local count = select("#", ...)
	local args = { ... }
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(args, 1, count))
		if not ok then
			warn("[TheX] " .. tostring(err))
		end
	end)
end

function Ui.tween(object, props, duration)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(duration or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

function Ui.card(parent, order)
	local row = Ui.inst("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.paint(row, "BackgroundColor3", "row")
	Ui.corner(row, 8)
	Ui.padding(row, 10)
	Ui.list(row, 6)
	return row
end

function Ui.line(parent, order, height)
	local row = Ui.inst("Frame", {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, height or 44),
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	Theme.paint(row, "BackgroundColor3", "row")
	Ui.corner(row, 8)
	return row
end

function Ui.title(parent, text, order)
	local label = Ui.label({
		Text = text or "",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = order or 1,
		Parent = parent,
	})
	Theme.paint(label, "TextColor3", "text")
	return label
end

function Ui.note(parent, text, order)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local label = Ui.label({
		Text = text,
		TextSize = 12,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 2,
		Parent = parent,
	})
	Theme.paint(label, "TextColor3", "muted")
	return label
end

function Ui.screen(name, displayOrder)
	local players = game:GetService("Players")
	local player = players.LocalPlayer or players.PlayerAdded:Wait()
	local parent
	if game:GetService("RunService"):IsStudio() then
		parent = player:WaitForChild("PlayerGui")
	else
		local ok, core = pcall(function()
			return game:GetService("CoreGui")
		end)
		parent = (ok and core) or player:WaitForChild("PlayerGui")
	end

	local gui = Ui.inst("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = displayOrder or 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})

	local protect = (type(protectgui) == "function" and protectgui) or (syn and syn.protect_gui)
	if protect then
		pcall(protect, gui)
	end
	return gui
end

return Ui
end

modules["Widgets/Button"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")

local Button = {}

function Button.create(tab, config)
	local row = Ui.card(tab.page, tab:nextOrder())
	Ui.title(row, config.title or "Button", 1)
	Ui.note(row, config.description, 2)

	local button = Ui.inst("TextButton", {
		AutoButtonColor = false,
		Text = config.buttonText or "Run",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 32),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = row,
	})
	Ui.corner(button, 8)
	Theme.paint(button, "BackgroundColor3", "accent")
	Theme.paint(button, "TextColor3", "accentText")
	button.MouseButton1Click:Connect(function()
		Ui.fire(config.onClick)
	end)

	return {
		type = "button",
		set = function() end,
		get = function() end,
		encode = function() end,
	}
end

return Button
end

modules["Widgets/Colorpicker"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local UserInputService = game:GetService("UserInputService")

local Colorpicker = {}

local function channelSlider(parent, label, initial, onSlide)
	local row = Ui.inst("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = parent,
	})
	local name = Ui.label({
		Text = label,
		TextSize = 12,
		Size = UDim2.fromOffset(16, 28),
		Parent = row,
	})
	Theme.paint(name, "TextColor3", "muted")
	local readout = Ui.label({
		Text = tostring(initial),
		TextSize = 12,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(32, 28),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
	Theme.paint(readout, "TextColor3", "text")
	local hit = Ui.inst("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Parent = row,
	})
	local track = Ui.inst("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 6),
		BorderSizePixel = 0,
		Parent = hit,
	})
	Ui.corner(track, 3)
	Theme.paint(track, "BackgroundColor3", "track")
	local knob = Ui.inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BorderSizePixel = 0,
		Parent = track,
	})
	Ui.corner(knob, 6)
	Theme.paint(knob, "BackgroundColor3", "accent")

	local function paint(number)
		local alpha = math.clamp(number / 255, 0, 1)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		readout.Text = tostring(math.floor(number + 0.5))
	end

	local function fromX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		local number = math.floor((alpha * 255) + 0.5)
		paint(number)
		onSlide(number)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		fromX(input.Position.X)
		local moveConn
		local endConn
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
				fromX(changed.Position.X)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(ended)
			if ended.UserInputType ~= Enum.UserInputType.MouseButton1 and ended.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			moveConn:Disconnect()
			endConn:Disconnect()
		end)
	end)

	paint(initial)
	return paint
end

function Colorpicker.create(tab, config)
	local allowAlpha = config.transparency == true
	local color = typeof(config.default) == "Color3" and config.default or Color3.fromRGB(214, 146, 58)
	local alpha = 0
	local row = Ui.line(tab.page, tab:nextOrder(), config.description and 64 or 48)

	local title = Ui.label({
		Text = config.title or "Color",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Position = UDim2.fromOffset(12, config.description and 8 or 0),
		Size = UDim2.new(1, -64, 0, config.description and 18 or 48),
		Parent = row,
	})
	Theme.paint(title, "TextColor3", "text")
	if config.description and config.description ~= "" then
		local note = Ui.label({
			Text = config.description,
			TextSize = 12,
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -64, 0, 18),
			Parent = row,
		})
		Theme.paint(note, "TextColor3", "muted")
	end

	local swatch = Ui.inst("TextButton", {
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BorderSizePixel = 0,
		Parent = row,
	})
	Ui.corner(swatch, 6)

	local control = { type = "color" }

	local function paintSwatch()
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = alpha
	end

	local function emit()
		Ui.fire(config.onChange, color, alpha)
	end

	function control:get()
		return color
	end

	function control:encode()
		return {
			r = color.R,
			g = color.G,
			b = color.B,
			t = alpha,
		}
	end

	function control:set(value, silent)
		if typeof(value) == "Color3" then
			color = value
		elseif type(value) == "table" then
			color = Color3.new(tonumber(value.r) or 0, tonumber(value.g) or 0, tonumber(value.b) or 0)
			alpha = allowAlpha and math.clamp(tonumber(value.t) or 0, 0, 1) or 0
		end
		paintSwatch()
		if silent ~= true then
			emit()
		end
	end

	local function open()
		tab.window:closePopup()
		local height = allowAlpha and 168 or 140
		local x = swatch.AbsolutePosition.X - 180
		local y = swatch.AbsolutePosition.Y + swatch.AbsoluteSize.Y + 6
		local panel = Ui.inst("Frame", {
			Name = "ColorPanel",
			Position = UDim2.fromOffset(math.max(8, x), y),
			Size = UDim2.fromOffset(220, height),
			BorderSizePixel = 0,
		})
		Theme.paint(panel, "BackgroundColor3", "bar")
		Ui.corner(panel, 8)
		Ui.padding(panel, 10)
		Ui.list(panel, 6)

		local function applyChannel(r, g, b)
			color = Color3.fromRGB(r, g, b)
			paintSwatch()
			emit()
		end

		local red = math.floor((color.R * 255) + 0.5)
		local green = math.floor((color.G * 255) + 0.5)
		local blue = math.floor((color.B * 255) + 0.5)
		channelSlider(panel, "R", red, function(number)
			red = number
			applyChannel(red, green, blue)
		end)
		channelSlider(panel, "G", green, function(number)
			green = number
			applyChannel(red, green, blue)
		end)
		channelSlider(panel, "B", blue, function(number)
			blue = number
			applyChannel(red, green, blue)
		end)
		if allowAlpha then
			channelSlider(panel, "A", math.floor(((1 - alpha) * 255) + 0.5), function(number)
				alpha = 1 - (number / 255)
				paintSwatch()
				emit()
			end)
		end
		tab.window:showPopup(panel)
	end

	swatch.MouseButton1Click:Connect(open)
	paintSwatch()
	tab.window:register(config.id, control)
	return control
end

return Colorpicker
end

modules["Widgets/Dropdown"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")

local Dropdown = {}

local function copyValues(source)
	local list = {}
	if type(source) == "table" then
		for _, name in ipairs(source) do
			table.insert(list, tostring(name))
		end
	end
	return list
end

function Dropdown.create(tab, config)
	local values = copyValues(config.values)
	local multi = config.multi == true
	local chosen = {}
	local single = values[1]

	if multi then
		if type(config.default) == "table" then
			for _, name in ipairs(config.default) do
				chosen[tostring(name)] = true
			end
		end
	elseif config.default ~= nil then
		single = tostring(config.default)
	end

	local row = Ui.card(tab.page, tab:nextOrder())
	Ui.title(row, config.title or "Dropdown", 1)
	Ui.note(row, config.description, 2)

	local opener = Ui.inst("TextButton", {
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, 32),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = row,
	})
	Ui.corner(opener, 8)
	Theme.paint(opener, "BackgroundColor3", "track")
	local current = Ui.label({
		Text = "",
		TextSize = 13,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -32, 1, 0),
		Parent = opener,
	})
	Theme.paint(current, "TextColor3", "text")
	local marker = Ui.label({
		Text = "v",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(16, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = opener,
	})
	Theme.paint(marker, "TextColor3", "muted")

	local control = { type = "dropdown" }

	local function selectedList()
		local list = {}
		for _, name in ipairs(values) do
			if chosen[name] then
				table.insert(list, name)
			end
		end
		return list
	end

	local function summary()
		if not multi then
			return single or ""
		end
		local list = selectedList()
		if #list == 0 then
			return "None"
		end
		return table.concat(list, ", ")
	end

	local function emit()
		if multi then
			Ui.fire(config.onChange, selectedList())
		else
			Ui.fire(config.onChange, single)
		end
	end

	function control:get()
		if multi then
			return selectedList()
		end
		return single
	end

	function control:encode()
		return control:get()
	end

	function control:set(value, silent)
		if multi then
			chosen = {}
			if type(value) == "table" then
				for _, name in ipairs(value) do
					chosen[tostring(name)] = true
				end
			end
		elseif value ~= nil then
			single = tostring(value)
		end
		current.Text = summary()
		if silent ~= true then
			emit()
		end
	end

	local function open()
		tab.window:closePopup()
		local count = math.max(#values, 1)
		local height = math.min(count, 8) * 30
		local width = math.max(opener.AbsoluteSize.X, 180)
		local x = opener.AbsolutePosition.X
		local y = opener.AbsolutePosition.Y + opener.AbsoluteSize.Y + 6
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		if y + height > viewport.Y - 8 then
			y = math.max(8, opener.AbsolutePosition.Y - height - 6)
		end

		local menu = Ui.inst("Frame", {
			Name = "Menu",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(width, height),
			BorderSizePixel = 0,
		})
		Theme.paint(menu, "BackgroundColor3", "bar")
		Ui.corner(menu, 8)
		local scroller = Ui.inst("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = menu,
		})
		Theme.paint(scroller, "ScrollBarImageColor3", "accent")
		Ui.list(scroller, 0)

		local function addItem(text, selected, onPick)
			local item = Ui.inst("TextButton", {
				AutoButtonColor = false,
				Text = (selected and "✓  " or "    ") .. text,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = scroller,
			})
			Theme.paint(item, "TextColor3", selected and "accent" or "text")
			item.MouseButton1Click:Connect(onPick)
		end

		if #values == 0 then
			addItem("Empty", false, function() end)
		end
		for _, name in ipairs(values) do
			local picked = multi and chosen[name] == true or (not multi and name == single)
			addItem(name, picked, function()
				if multi then
					chosen[name] = not chosen[name]
					current.Text = summary()
					emit()
					open()
				else
					single = name
					current.Text = summary()
					tab.window:closePopup()
					emit()
				end
			end)
		end
		tab.window:showPopup(menu)
	end

	opener.MouseButton1Click:Connect(open)
	current.Text = summary()
	tab.window:register(config.id, control)
	return control
end

return Dropdown
end

modules["Widgets/Input"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")

local Input = {}

function Input.create(tab, config)
	local row = Ui.card(tab.page, tab:nextOrder())
	Ui.title(row, config.title or "Input", 1)
	Ui.note(row, config.description, 2)

	local box = Ui.inst("TextBox", {
		ClearTextOnFocus = false,
		Text = tostring(config.default or ""),
		PlaceholderText = config.placeholder or "",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 32),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = row,
	})
	Ui.corner(box, 8)
	Ui.padding(box, 8)
	Theme.paint(box, "BackgroundColor3", "track")
	Theme.paint(box, "TextColor3", "text")
	Theme.paint(box, "PlaceholderColor3", "muted")

	local value = box.Text
	local control = { type = "input" }
	local writing = false

	function control:get()
		return value
	end

	function control:encode()
		return value
	end

	function control:set(nextValue, silent)
		local text = tostring(nextValue or "")
		if config.numeric and text ~= "" and tonumber(text) == nil then
			return
		end
		writing = true
		value = text
		box.Text = text
		writing = false
		if silent ~= true then
			Ui.fire(config.onChange, value)
		end
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if writing then
			return
		end
		if config.numeric and box.Text ~= "" and tonumber(box.Text) == nil then
			writing = true
			box.Text = value
			writing = false
			return
		end
		value = box.Text
		Ui.fire(config.onChange, value)
	end)

	tab.window:register(config.id, control)
	return control
end

return Input
end

modules["Widgets/Keybind"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local UserInputService = game:GetService("UserInputService")

local Keybind = {}

local function asKey(value)
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		return value
	end
	if type(value) == "string" and Enum.KeyCode[value] then
		return Enum.KeyCode[value]
	end
	return Enum.KeyCode.RightShift
end

function Keybind.create(tab, config)
	local row = Ui.line(tab.page, tab:nextOrder(), 48)
	local title = Ui.label({
		Text = config.title or "Keybind",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -132, 1, 0),
		Parent = row,
	})
	Theme.paint(title, "TextColor3", "text")

	local chip = Ui.inst("TextButton", {
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(108, 28),
		BorderSizePixel = 0,
		Text = "",
		Parent = row,
	})
	Ui.corner(chip, 8)
	Theme.paint(chip, "BackgroundColor3", "track")
	Theme.paint(chip, "TextColor3", "text")

	local key = asKey(config.default)
	local mode = config.mode == "Hold" and "Hold" or "Toggle"
	local held = false
	local control = { type = "keybind" }
	local session = tab.window.session

	local function paint()
		chip.Text = key.Name
	end

	function control:get()
		return key
	end

	function control:encode()
		return key.Name
	end

	function control:set(value, silent)
		key = asKey(value)
		paint()
		if silent ~= true then
			Ui.fire(config.onChange, key)
		end
	end

	chip.MouseButton1Click:Connect(function()
		session.capturing = true
		session.captureOwner = control
		chip.Text = "..."
	end)

	tab.window:connect(UserInputService.InputBegan, function(input)
		if not session.alive then
			return
		end
		if session.capturing then
			if session.captureOwner ~= control then
				return
			end
			if input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
				session.capturing = false
				session.captureOwner = nil
				paint()
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
				session.capturing = false
				session.captureOwner = nil
				session.suppress = input
				control:set(input.KeyCode)
				task.defer(function()
					if session.suppress == input then
						session.suppress = nil
					end
				end)
			end
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode ~= key then
			return
		end
		if mode == "Hold" then
			held = true
			Ui.fire(config.onClick, true)
		else
			held = not held
			Ui.fire(config.onClick, held)
		end
	end)

	tab.window:connect(UserInputService.InputEnded, function(input)
		if not session.alive or mode ~= "Hold" or session.capturing then
			return
		end
		if input.KeyCode == key and held then
			held = false
			Ui.fire(config.onClick, false)
		end
	end)

	paint()
	tab.window:register(config.id, control)
	return control
end

return Keybind
end

modules["Widgets/Paragraph"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")

local Paragraph = {}

function Paragraph.create(tab, config)
	local row = Ui.card(tab.page, tab:nextOrder())
	Ui.title(row, config.title or "Paragraph", 1)
	local body = Ui.label({
		Text = config.content or "",
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = row,
	})
	Theme.paint(body, "TextColor3", "muted")

	local control = {
		type = "paragraph",
	}
	function control:set(text)
		body.Text = tostring(text or "")
	end
	function control:get()
		return body.Text
	end
	function control:encode()
		return body.Text
	end
	return control
end

return Paragraph
end

modules["Widgets/Slider"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local UserInputService = game:GetService("UserInputService")

local Slider = {}

local function formatValue(value, step)
	if step >= 1 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%.2f", value)
end

function Slider.create(tab, config)
	local min = config.min or 0
	local max = config.max or 100
	local step = config.step or 1
	if step <= 0 then
		step = 1
	end

	local row = Ui.card(tab.page, tab:nextOrder())
	local header = Ui.inst("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = row,
	})
	local title = Ui.label({
		Text = config.title or "Slider",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Size = UDim2.new(1, -56, 1, 0),
		Parent = header,
	})
	Theme.paint(title, "TextColor3", "text")
	local readout = Ui.label({
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(56, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})
	Theme.paint(readout, "TextColor3", "accent")
	Ui.note(row, config.description, 2)

	local hit = Ui.inst("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 3,
		Parent = row,
	})
	local track = Ui.inst("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 8),
		BorderSizePixel = 0,
		Parent = hit,
	})
	Ui.corner(track, 4)
	Theme.paint(track, "BackgroundColor3", "track")
	local fill = Ui.inst("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BorderSizePixel = 0,
		Parent = track,
	})
	Ui.corner(fill, 4)
	Theme.paint(fill, "BackgroundColor3", "accent")
	local knob = Ui.inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BorderSizePixel = 0,
		Parent = track,
	})
	Ui.corner(knob, 7)
	Theme.paint(knob, "BackgroundColor3", "text")

	local value = math.clamp(config.default or min, min, max)
	local control = { type = "slider" }

	local function snap(number)
		local steps = math.floor(((number - min) / step) + 0.5)
		return math.clamp(min + (steps * step), min, max)
	end

	local function paint()
		local span = max - min
		local alpha = span == 0 and 0 or (value - min) / span
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		readout.Text = formatValue(value, step)
	end

	function control:get()
		return value
	end

	function control:encode()
		return value
	end

	function control:set(nextValue, silent)
		local number = tonumber(nextValue)
		if not number then
			return
		end
		value = snap(number)
		paint()
		if silent ~= true then
			Ui.fire(config.onChange, value)
		end
	end

	local function fromX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		control:set(min + ((max - min) * alpha))
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		fromX(input.Position.X)
		local moveConn
		local endConn
		moveConn = UserInputService.InputChanged:Connect(function(changed)
			if not tab.window.session.alive then
				moveConn:Disconnect()
				endConn:Disconnect()
				return
			end
			if changed.UserInputType == Enum.UserInputType.MouseMovement or changed.UserInputType == Enum.UserInputType.Touch then
				fromX(changed.Position.X)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(ended)
			if ended.UserInputType ~= Enum.UserInputType.MouseButton1 and ended.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			moveConn:Disconnect()
			endConn:Disconnect()
		end)
	end)

	control:set(value, true)
	tab.window:register(config.id, control)
	return control
end

return Slider
end

modules["Widgets/Toggle"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")

local Toggle = {}

function Toggle.create(tab, config)
	local row = Ui.line(tab.page, tab:nextOrder(), 48)
	local title = Ui.label({
		Text = config.title or "Toggle",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -78, 1, 0),
		Parent = row,
	})
	Theme.paint(title, "TextColor3", "text")

	local track = Ui.inst("TextButton", {
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 22),
		BorderSizePixel = 0,
		Parent = row,
	})
	Ui.corner(track, 11)
	Theme.paint(track, "BackgroundColor3", "track")

	local knob = Ui.inst("Frame", {
		Size = UDim2.fromOffset(16, 16),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 3),
		Parent = track,
	})
	Ui.corner(knob, 8)

	local enabled = config.default == true
	local control = { type = "toggle" }

	local function paint()
		knob.Position = UDim2.fromOffset(enabled and 23 or 3, 3)
		knob.BackgroundColor3 = enabled and Theme.color("accent") or Theme.color("muted")
	end

	function control:get()
		return enabled
	end

	function control:encode()
		return enabled
	end

	function control:set(value, silent)
		enabled = value == true
		paint()
		if silent ~= true then
			Ui.fire(config.onChange, enabled)
		end
	end

	track.MouseButton1Click:Connect(function()
		control:set(not enabled)
	end)
	paint()
	Theme.onChange(function()
		if row.Parent then
			paint()
		end
	end)
	tab.window:register(config.id, control)
	return control
end

return Toggle
end

modules["Window"] = function(require)
local Config = require("Config")
local Dialog = require("Dialog")
local Tab = require("Tab")
local Theme = require("Theme")
local Ui = require("Ui")
local UserInputService = game:GetService("UserInputService")

local Window = {}

local function asKey(value)
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		return value
	end
	if type(value) == "string" and Enum.KeyCode[value] then
		return Enum.KeyCode[value]
	end
	return Enum.KeyCode.LeftControl
end

function Window.create(config)
	config = config or {}
	if config.theme then
		Theme.set(config.theme)
	end

	local gui = Ui.screen("TheX", 100000)
	local frame = Ui.inst("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = config.size or UDim2.fromOffset(580, 460),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = gui,
	})
	Theme.paint(frame, "BackgroundColor3", "window")
	Ui.corner(frame, 12)
	local stroke = Ui.inst("UIStroke", {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = frame,
	})
	Theme.paint(stroke, "Color", "stroke")

	local bar = Ui.inst("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 56),
		BorderSizePixel = 0,
		Active = true,
		Parent = frame,
	})
	Theme.paint(bar, "BackgroundColor3", "bar")

	local drag = Ui.inst("TextButton", {
		Name = "Drag",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -52, 1, 0),
		Parent = bar,
	})

	local title = Ui.label({
		Text = config.title or "TheX",
		Font = Enum.Font.GothamMedium,
		TextSize = 18,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -72, 0, 22),
		Parent = bar,
	})
	Theme.paint(title, "TextColor3", "text")
	local subtitle = Ui.label({
		Text = config.subtitle or "",
		TextSize = 12,
		Position = UDim2.fromOffset(16, 30),
		Size = UDim2.new(1, -72, 0, 16),
		Parent = bar,
	})
	Theme.paint(subtitle, "TextColor3", "muted")

	local close = Ui.inst("TextButton", {
		Name = "Close",
		AutoButtonColor = false,
		Text = "x",
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BorderSizePixel = 0,
		Parent = bar,
	})
	Ui.corner(close, 8)
	Theme.paint(close, "BackgroundColor3", "danger")
	Theme.paint(close, "TextColor3", "accentText")

	local body = Ui.inst("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = frame,
	})
	local rail = Ui.inst("Frame", {
		Name = "Tabs",
		Size = UDim2.new(0, 156, 1, 0),
		BorderSizePixel = 0,
		Parent = body,
	})
	Theme.paint(rail, "BackgroundColor3", "rail")
	local railLayout = Ui.list(rail, 4)
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Ui.inst("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		Parent = rail,
	})

	local pages = Ui.inst("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(156, 0),
		Size = UDim2.new(1, -156, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = body,
	})

	local window = {
		gui = gui,
		frame = frame,
		rail = rail,
		pages = pages,
		tabs = {},
		controls = {},
		dead = false,
		session = {
			alive = true,
			capturing = false,
			captureOwner = nil,
			suppress = nil,
		},
		_connections = {},
		_closePopup = nil,
	}

	function window:connect(signal, fn)
		local connection = signal:Connect(fn)
		table.insert(self._connections, connection)
		return connection
	end

	function window:closePopup()
		local closePopup = self._closePopup
		self._closePopup = nil
		if closePopup then
			closePopup()
		end
	end

	function window:showPopup(popup)
		self:closePopup()
		local blocker = Ui.inst("TextButton", {
			Name = "PopupBlocker",
			AutoButtonColor = false,
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
			Parent = self.gui,
		})
		popup.ZIndex = 21
		popup.Parent = self.gui
		local function closePopup()
			if popup.Parent then
				popup:Destroy()
			end
			if blocker.Parent then
				blocker:Destroy()
			end
		end
		blocker.MouseButton1Click:Connect(closePopup)
		self._closePopup = closePopup
	end

	function window:register(id, control)
		if type(id) == "string" and id ~= "" then
			self.controls[id] = control
		end
	end

	function window:select(tab)
		if self.dead then
			return
		end
		self:closePopup()
		for _, other in ipairs(self.tabs) do
			other.selected = other == tab
			other:paint()
		end
	end

	function window:tab(options)
		local tab = Tab.create(self, options or {})
		table.insert(self.tabs, tab)
		if #self.tabs == 1 then
			self:select(tab)
		end
		return tab
	end

	function window:dialog(options)
		if self.dead then
			return nil
		end
		self:closePopup()
		return Dialog.open(self.frame, options or {})
	end

	function window:save(path)
		return Config.save(path or "TheX/config.json", self.controls)
	end

	function window:load(path)
		return Config.load(path or "TheX/config.json", self.controls)
	end

	function window:destroy()
		if self.dead then
			return
		end
		self.dead = true
		self.session.alive = false
		self:closePopup()
		for _, connection in ipairs(self._connections) do
			connection:Disconnect()
		end
		table.clear(self._connections)
		if self.gui.Parent then
			self.gui:Destroy()
		end
	end

	local toggleKey = asKey(config.toggleKey)
	local dragging = false
	local dragStart
	local startPos

	drag.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end)
	window:connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	window:connect(UserInputService.InputChanged, function(input)
		if not dragging or window.dead then
			dragging = false
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end)

	window:connect(UserInputService.InputBegan, function(input)
		if window.dead or window.session.capturing or window.session.suppress == input then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == toggleKey then
			frame.Visible = not frame.Visible
		end
	end)

	close.MouseButton1Click:Connect(function()
		window:destroy()
	end)

	return window
end

return Window
end

return require("")
