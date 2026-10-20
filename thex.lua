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
	Ui.panel(card)
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
		local button
		if index == 1 then
			button = Ui.accentButton(row, spec.title or "OK", UDim2.fromOffset(108, 34), index)
		else
			button = Ui.inst("TextButton", {
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
			Ui.field(button)
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

modules["Games"] = function(require)
local Games = {}

function Games.ids(list)
	local set = {}
	local count = 0
	if type(list) ~= "table" then
		return set, count
	end
	local function add(value)
		local id = tonumber(value)
		if id and not set[id] then
			set[id] = true
			count += 1
		end
	end
	for key, value in pairs(list) do
		if type(value) == "number" or (type(value) == "string" and tonumber(value)) then
			add(value)
		elseif value ~= false and tonumber(key) then
			add(key)
		end
	end
	return set, count
end

function Games.count(list)
	local _, count = Games.ids(list)
	return count
end

function Games.supported(list)
	local set = Games.ids(list)
	return set[game.PlaceId] == true or set[game.GameId] == true
end

return Games
end

modules[""] = function(require)
local Notify = require("Notify")
local Theme = require("Theme")
local Window = require("Window")

local TheX = {
	version = "1.1.0",
}

local windows = {}

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
	return Notify.show(config)
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
	Notify.clear()
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

local mounted = nil

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
	Ui.glass(card, "notice", 0.08, 0.45)
	Ui.corner(card, 10)
	Ui.padding(card, 12)
	Ui.list(card, 4)

	local bar = Ui.inst("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = card,
	})
	Ui.gradient(bar, "accent", "accent2", 0)
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

function Notify.show(config)
	if mounted == nil or mounted.Parent == nil then
		mounted = Notify.mount()
	end
	return Notify.push(mounted, config or {})
end

function Notify.clear()
	if mounted and mounted.Parent then
		mounted:Destroy()
	end
	mounted = nil
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
local Profile = require("Widgets/Profile")
local Stats = require("Widgets/Stats")
local GameInfo = require("Widgets/GameInfo")
local Actions = require("Widgets/Actions")

local Tab = {}

function Tab.create(window, config)
	local tab = {
		window = window,
		selected = false,
		hovered = false,
		_order = 0,
	}

	tab.tabButton = Ui.inst("TextButton", {
		Name = (config.title or "Tab") .. "Tab",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, -16, 0, 34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = window.rail,
	})
	local fill = Ui.inst("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = tab.tabButton,
	})
	Ui.corner(fill, 8)
	Theme.paint(fill, "BackgroundColor3", "accent")
	Ui.inst("UIGradient", {
		Transparency = NumberSequence.new(0.7, 0.97),
		Parent = fill,
	})
	local indicator = Ui.inst("Frame", {
		Name = "Indicator",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(3, 18),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = tab.tabButton,
	})
	Ui.corner(indicator, 2)
	Ui.gradient(indicator, "accent", "accent2", 90)
	local label = Ui.label({
		Text = config.title or "Tab",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -18, 1, 0),
		ZIndex = 3,
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
		indicator.Visible = self.selected
		local fillTransparency = (self.selected and 0) or (self.hovered and 0.55) or 1
		Ui.tween(fill, { BackgroundTransparency = fillTransparency }, 0.12)
		local token = (self.selected and "accent") or (self.hovered and "text") or "muted"
		label.TextColor3 = Theme.color(token)
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
	function tab:profile(options)
		return Profile.create(self, options or {})
	end
	function tab:stats(options)
		return Stats.create(self, options or {})
	end
	function tab:gameInfo(options)
		return GameInfo.create(self, options or {})
	end
	function tab:actions(options)
		return Actions.create(self, options or {})
	end

	tab.tabButton.MouseButton1Click:Connect(function()
		window:select(tab)
	end)
	tab.tabButton.MouseEnter:Connect(function()
		tab.hovered = true
		tab:paint()
	end)
	tab.tabButton.MouseLeave:Connect(function()
		tab.hovered = false
		tab:paint()
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
			window = Color3.fromRGB(10, 17, 40),
			rail = Color3.fromRGB(12, 22, 50),
			bar = Color3.fromRGB(15, 28, 61),
			row = Color3.fromRGB(19, 35, 74),
			text = Color3.fromRGB(230, 240, 255),
			muted = Color3.fromRGB(143, 163, 199),
			accent = Color3.fromRGB(0, 180, 255),
			accent2 = Color3.fromRGB(37, 99, 255),
			accentText = Color3.fromRGB(245, 250, 255),
			glow = Color3.fromRGB(0, 200, 255),
			stroke = Color3.fromRGB(38, 62, 118),
			track = Color3.fromRGB(24, 42, 86),
			danger = Color3.fromRGB(232, 72, 104),
			success = Color3.fromRGB(46, 230, 150),
			warning = Color3.fromRGB(214, 150, 110),
			notice = Color3.fromRGB(13, 24, 54),
		},
		Light = {
			window = Color3.fromRGB(246, 242, 234),
			rail = Color3.fromRGB(236, 230, 218),
			bar = Color3.fromRGB(226, 218, 204),
			row = Color3.fromRGB(255, 252, 246),
			text = Color3.fromRGB(36, 32, 28),
			muted = Color3.fromRGB(110, 100, 88),
			accent = Color3.fromRGB(176, 98, 32),
			accent2 = Color3.fromRGB(140, 66, 18),
			accentText = Color3.fromRGB(255, 248, 238),
			glow = Color3.fromRGB(196, 124, 54),
			stroke = Color3.fromRGB(214, 204, 188),
			track = Color3.fromRGB(214, 206, 192),
			danger = Color3.fromRGB(168, 64, 54),
			success = Color3.fromRGB(46, 140, 84),
			warning = Color3.fromRGB(176, 108, 62),
			notice = Color3.fromRGB(255, 250, 242),
		},
	},
}

local bindings = {}
local listeners = {}

function Theme.color(token)
	local palette = Theme.palettes[Theme.name] or Theme.palettes.Dark
	return palette[token] or Theme.palettes.Dark[token]
end

local function bind(instance, apply)
	apply()
	table.insert(bindings, { instance, apply })
end

function Theme.paint(instance, property, token)
	bind(instance, function()
		instance[property] = Theme.color(token)
	end)
end

function Theme.gradient(gradient, from, to)
	bind(gradient, function()
		gradient.Color = ColorSequence.new(Theme.color(from), Theme.color(to))
	end)
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
			binding[2]()
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

function Ui.stroke(parent, token, transparency, thickness)
	local stroke = Ui.inst("UIStroke", {
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	Theme.paint(stroke, "Color", token or "stroke")
	return stroke
end

function Ui.gradient(parent, from, to, rotation)
	local gradient = Ui.inst("UIGradient", {
		Rotation = rotation or 0,
		Parent = parent,
	})
	Theme.gradient(gradient, from, to)
	return gradient
end

function Ui.glass(frame, token, transparency, strokeTransparency)
	Theme.paint(frame, "BackgroundColor3", token or "row")
	frame.BackgroundTransparency = transparency or 0.3
	return Ui.stroke(frame, "glow", strokeTransparency or 0.82, 1)
end

function Ui.panel(frame)
	Ui.corner(frame, 10)
	return Ui.glass(frame, "bar", 0.04, 0.45)
end

function Ui.field(object)
	Theme.paint(object, "BackgroundColor3", "track")
	object.BackgroundTransparency = 0.15
	local stroke = Ui.stroke(object, "glow", 0.75, 1)
	local hovered = false
	local focused = false
	local function refresh()
		Ui.tween(stroke, { Transparency = (focused and 0.15) or (hovered and 0.4) or 0.75 }, 0.12)
	end
	object.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	object.MouseLeave:Connect(function()
		hovered = false
		refresh()
	end)
	if object:IsA("TextBox") then
		object.Focused:Connect(function()
			focused = true
			refresh()
		end)
		object.FocusLost:Connect(function()
			focused = false
			refresh()
		end)
	end
	return stroke
end

local REST = Color3.fromRGB(214, 222, 236)
local BRIGHT = Color3.new(1, 1, 1)

function Ui.accentButton(parent, text, size, order)
	local holder = Ui.inst("Frame", {
		Name = "Button",
		BackgroundTransparency = 1,
		Size = size or UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		Parent = parent,
	})
	local face = Ui.inst("TextButton", {
		Name = "Face",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = REST,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Ui.corner(face, 8)
	Ui.gradient(face, "accent", "accent2", 0)
	local stroke = Ui.stroke(face, "glow", 0.65, 1)
	local label = Ui.label({
		Text = text or "",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1),
		Parent = face,
	})
	Theme.paint(label, "TextColor3", "accentText")

	local hovered = false
	local pressed = false
	local function refresh()
		Ui.tween(face, {
			BackgroundColor3 = (hovered or pressed) and BRIGHT or REST,
			Size = pressed and UDim2.new(1, -6, 1, -4) or UDim2.fromScale(1, 1),
		}, 0.1)
		Ui.tween(stroke, { Transparency = hovered and 0.15 or 0.65 }, 0.12)
	end
	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	face.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	face.MouseLeave:Connect(function()
		hovered = false
		pressed = false
		refresh()
	end)
	face.InputBegan:Connect(function(input)
		if isPress(input) then
			pressed = true
			refresh()
		end
	end)
	face.InputEnded:Connect(function(input)
		if isPress(input) then
			pressed = false
			refresh()
		end
	end)
	return face, label, holder
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
	Ui.glass(row)
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
	Ui.glass(row)
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

modules["Widgets/Actions"] = function(require)
local Ui = require("Ui")
local Notify = require("Notify")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Actions = {}

local GAP = 8

local function clipboard()
	local candidates = {
		setclipboard,
		toclipboard,
		syn and syn.write_clipboard,
	}
	for index = 1, 3 do
		if type(candidates[index]) == "function" then
			return candidates[index]
		end
	end
	return nil
end

local function copy(label, value)
	local text = tostring(value or "")
	if text == "" then
		Notify.show({ title = label, content = "There is no " .. label .. " in this session.", duration = 4 })
		return
	end
	local write = clipboard()
	if write and pcall(write, text) then
		Notify.show({ title = "Copied " .. label, content = text, duration = 3 })
		return
	end
	Notify.show({ title = label, content = "Clipboard is not available. Copy it manually: " .. text, duration = 10 })
end

local function rejoin()
	local player = Players.LocalPlayer
	Notify.show({ title = "Rejoining", content = "Teleporting back to this server...", duration = 4 })
	local ok, err = pcall(function()
		if #Players:GetPlayers() <= 1 or game.JobId == "" then
			TeleportService:Teleport(game.PlaceId, player)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		end
	end)
	if not ok then
		Notify.show({ title = "Rejoin failed", content = tostring(err), duration = 6 })
	end
end

function Actions.defaults()
	return {
		{ title = "Rejoin", onClick = rejoin },
		{
			title = "Copy Job ID",
			onClick = function()
				copy("Job ID", game.JobId)
			end,
		},
		{
			title = "Copy Place ID",
			onClick = function()
				copy("Place ID", game.PlaceId)
			end,
		},
	}
end

function Actions.create(tab, config)
	local buttons = type(config.buttons) == "table" and #config.buttons > 0 and config.buttons or Actions.defaults()
	local count = #buttons
	local row = Ui.inst("Frame", {
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = tab:nextOrder(),
		Parent = tab.page,
	})
	Ui.list(row, GAP, Enum.FillDirection.Horizontal)

	for index, spec in ipairs(buttons) do
		local width = UDim2.new(1 / count, -GAP * (count - 1) / count, 1, 0)
		local button = Ui.accentButton(row, spec.title or "Run", width, index)
		button.MouseButton1Click:Connect(function()
			Ui.fire(spec.onClick)
		end)
	end

	local player = Players.LocalPlayer
	tab.window:connect(TeleportService.TeleportInitFailed, function(target, _result, message)
		if target == player then
			Notify.show({ title = "Rejoin failed", content = tostring(message), duration = 6 })
		end
	end)

	return {
		type = "actions",
		set = function() end,
		get = function() end,
		encode = function() end,
	}
end

return Actions
end

modules["Widgets/Button"] = function(require)
local Ui = require("Ui")

local Button = {}

function Button.create(tab, config)
	local row = Ui.card(tab.page, tab:nextOrder())
	Ui.title(row, config.title or "Button", 1)
	Ui.note(row, config.description, 2)

	local button = Ui.accentButton(row, config.buttonText or "Run", UDim2.new(1, 0, 0, 34), 3)
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
	Ui.stroke(swatch, "glow", 0.5, 1)

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
		local origin = tab.window.gui.AbsolutePosition
		local x = swatch.AbsolutePosition.X - origin.X - 180
		local y = swatch.AbsolutePosition.Y - origin.Y + swatch.AbsoluteSize.Y + 6
		local panel = Ui.inst("Frame", {
			Name = "ColorPanel",
			Position = UDim2.fromOffset(math.max(8, x), y),
			Size = UDim2.fromOffset(220, height),
			BorderSizePixel = 0,
		})
		Ui.panel(panel)
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
	Ui.field(opener)
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
		local origin = tab.window.gui.AbsolutePosition
		local top = opener.AbsolutePosition.Y - origin.Y
		local x = opener.AbsolutePosition.X - origin.X
		local y = top + opener.AbsoluteSize.Y + 6
		local viewport = tab.window.gui.AbsoluteSize
		if y + height > viewport.Y - 8 then
			y = math.max(8, top - height - 6)
		end

		local menu = Ui.inst("Frame", {
			Name = "Menu",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(width, height),
			BorderSizePixel = 0,
		})
		Ui.panel(menu)
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
			Ui.inst("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				Parent = item,
			})
			Theme.paint(item, "TextColor3", selected and "accent" or "text")
			Theme.paint(item, "BackgroundColor3", "accent")
			item.MouseEnter:Connect(function()
				Ui.tween(item, { BackgroundTransparency = 0.85 }, 0.1)
			end)
			item.MouseLeave:Connect(function()
				Ui.tween(item, { BackgroundTransparency = 1 }, 0.1)
			end)
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

modules["Widgets/GameInfo"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local Games = require("Games")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local GameInfo = {}

local COVER = 92

local function clean(text)
	text = string.gsub(tostring(text or ""), "%s+", " ")
	if #text > 240 then
		text = string.sub(text, 1, 237) .. "..."
	end
	return text
end

function GameInfo.create(tab, config)
	local supported = Games.supported(config.supportedGames)
	local row = Ui.line(tab.page, tab:nextOrder(), COVER + 24)

	local cover = Ui.inst("ImageLabel", {
		Name = "Cover",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(COVER, COVER),
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Crop,
		Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150",
		Parent = row,
	})
	Theme.paint(cover, "BackgroundColor3", "window")
	Ui.corner(cover, 10)
	Ui.stroke(cover, "glow", 0.3, 1)

	local badge = Ui.label({
		Name = "Badge",
		Text = supported and "Supported" or "Not supported",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.82,
		Parent = row,
	})
	local tone = supported and "success" or "warning"
	Theme.paint(badge, "BackgroundColor3", tone)
	Theme.paint(badge, "TextColor3", tone)
	Ui.corner(badge, 11)
	Ui.stroke(badge, tone, 0.35, 1)
	Ui.inst("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = badge,
	})

	local left = 12 + COVER + 14
	local name = Ui.label({
		Text = "Loading...",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(left, 12),
		Size = UDim2.new(1, -(left + 122), 0, 22),
		Parent = row,
	})
	Theme.paint(name, "TextColor3", "text")
	local description = Ui.label({
		Text = "",
		TextSize = 12,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(left, 38),
		Size = UDim2.new(1, -(left + 12), 0, 46),
		Parent = row,
	})
	Theme.paint(description, "TextColor3", "muted")
	local info = Ui.label({
		Text = "",
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(left, COVER - 4),
		Size = UDim2.new(1, -(left + 12), 0, 14),
		Parent = row,
	})
	Theme.paint(info, "TextColor3", "accent")

	local function refreshInfo()
		local count = #Players:GetPlayers()
		local ok, max = pcall(function()
			return Players.MaxPlayers
		end)
		local players = (ok and type(max) == "number" and max > 0) and (count .. "/" .. max) or tostring(count)
		info.Text = string.format("PlaceId %d  ·  %s players", game.PlaceId, players)
	end
	refreshInfo()
	tab.window:connect(Players.PlayerAdded, refreshInfo)
	tab.window:connect(Players.PlayerRemoving, function()
		task.defer(refreshInfo)
	end)

	task.spawn(function()
		local ok, product = pcall(function()
			return MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		if not row.Parent then
			return
		end
		if ok and type(product) == "table" and type(product.Name) == "string" and product.Name ~= "" then
			name.Text = product.Name
			description.Text = clean(product.Description)
		else
			name.Text = tostring(game.PlaceId)
			description.Text = ""
		end
	end)

	return {
		type = "gameInfo",
		supported = supported,
		set = function() end,
		get = function()
			return supported
		end,
		encode = function() end,
	}
end

return GameInfo
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
	Ui.field(box)
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
	Ui.field(chip)
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

modules["Widgets/Profile"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local Players = game:GetService("Players")

local Profile = {}

local AVATAR = 64

function Profile.create(tab, config)
	local player = Players.LocalPlayer
	local row = Ui.inst("Frame", {
		Name = "Profile",
		Size = UDim2.new(1, 0, 0, 92),
		BorderSizePixel = 0,
		LayoutOrder = tab:nextOrder(),
		Parent = tab.page,
	})
	Ui.glass(row, "row", 0.2, 0.5)
	Ui.corner(row, 10)

	local tint = Ui.inst("Frame", {
		Name = "Tint",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = row,
	})
	Ui.corner(tint, 10)
	Theme.paint(tint, "BackgroundColor3", "accent")
	Ui.inst("UIGradient", {
		Transparency = NumberSequence.new(1, 0.72),
		Parent = tint,
	})

	local halo = Ui.inst("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(AVATAR, AVATAR),
		BorderSizePixel = 0,
		Parent = row,
	})
	Theme.paint(halo, "BackgroundColor3", "window")
	Ui.inst("UICorner", {
		CornerRadius = UDim.new(0.5, 0),
		Parent = halo,
	})
	Ui.stroke(halo, "glow", 0.1, 2)
	local ring = Ui.inst("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 8, 1, 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = halo,
	})
	Ui.inst("UICorner", {
		CornerRadius = UDim.new(0.5, 0),
		Parent = ring,
	})
	Ui.stroke(ring, "glow", 0.75, 3)
	local headshot = Ui.inst("ImageLabel", {
		Name = "Headshot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = player and ("rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150") or "",
		Parent = halo,
	})
	Ui.inst("UICorner", {
		CornerRadius = UDim.new(0.5, 0),
		Parent = headshot,
	})

	local left = 14 + AVATAR + 16
	local name = Ui.label({
		Text = player and player.DisplayName or "Player",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(left, 16),
		Size = UDim2.new(1, -(left + 12), 0, 22),
		Parent = row,
	})
	Theme.paint(name, "TextColor3", "text")
	local handle = Ui.label({
		Text = player and ("@" .. player.Name) or "",
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(left, 40),
		Size = UDim2.new(1, -(left + 12), 0, 16),
		Parent = row,
	})
	Theme.paint(handle, "TextColor3", "muted")
	local meta = Ui.label({
		Text = player and string.format("UserId %d  ·  %d days old", player.UserId, player.AccountAge) or "",
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(left, 60),
		Size = UDim2.new(1, -(left + 12), 0, 14),
		Parent = row,
	})
	Theme.paint(meta, "TextColor3", "accent")

	return {
		type = "profile",
		set = function() end,
		get = function() end,
		encode = function() end,
	}
end

return Profile
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
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	Ui.corner(fill, 4)
	Ui.gradient(fill, "accent2", "accent", 0)
	local knob = Ui.inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BorderSizePixel = 0,
		Parent = track,
	})
	Ui.corner(knob, 7)
	Theme.paint(knob, "BackgroundColor3", "text")
	Ui.stroke(knob, "glow", 0.3, 2)

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

modules["Widgets/Stats"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local Games = require("Games")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")

local Stats = {}

local CELL_HEIGHT = 64
local GAP = 8
local MIN_WIDE_CELL = 100

local function clock(seconds)
	seconds = math.floor(seconds)
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

local function readPing(player)
	local ok, seconds = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and type(seconds) == "number" and seconds > 0 then
		return seconds * 1000
	end
	local found, ms = pcall(function()
		return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if found and type(ms) == "number" then
		return ms
	end
	return nil
end

function Stats.create(tab, config)
	local window = tab.window
	local player = Players.LocalPlayer
	local holder = Ui.inst("Frame", {
		Name = "Stats",
		Size = UDim2.new(1, 0, 0, CELL_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = tab:nextOrder(),
		Parent = tab.page,
	})
	local grid = Ui.inst("UIGridLayout", {
		CellPadding = UDim2.fromOffset(GAP, GAP),
		CellSize = UDim2.new(0.25, -GAP * 3 / 4, 0, CELL_HEIGHT),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = holder,
	})

	local function layout()
		local columns = holder.AbsoluteSize.X >= (MIN_WIDE_CELL * 4) + (GAP * 3) and 4 or 2
		local rows = math.ceil(4 / columns)
		grid.CellSize = UDim2.new(1 / columns, -GAP * (columns - 1) / columns, 0, CELL_HEIGHT)
		holder.Size = UDim2.new(1, 0, 0, (rows * CELL_HEIGHT) + ((rows - 1) * GAP))
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	local function card(order, title)
		local cell = Ui.inst("Frame", {
			Name = title,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = holder,
		})
		Ui.glass(cell, "row", 0.3, 0.7)
		Ui.corner(cell, 10)
		local name = Ui.label({
			Text = string.upper(title),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(1, -24, 0, 14),
			Parent = cell,
		})
		Theme.paint(name, "TextColor3", "muted")
		local value = Ui.label({
			Text = "--",
			Font = Enum.Font.GothamBold,
			TextSize = 20,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -24, 0, 26),
			Parent = cell,
		})
		Theme.paint(value, "TextColor3", "accent")
		return value
	end

	local maps = card(1, "Maps")
	local session = card(2, "Session")
	local fps = card(3, "FPS")
	local ping = card(4, "Ping")
	layout()

	local control = { type = "stats" }
	function control:set(count)
		maps.Text = tostring(tonumber(count) or 0)
	end
	function control:get()
		return tonumber(maps.Text)
	end
	function control:encode() end
	control:set(config.maps or Games.count(config.supportedGames))

	local frames = 0
	window:connect(RunService.RenderStepped, function()
		frames += 1
	end)
	session.Text = clock(os.clock() - window.startedAt)
	task.spawn(function()
		local last = os.clock()
		while window.session.alive and holder.Parent do
			task.wait(0.5)
			local now = os.clock()
			fps.Text = tostring(math.floor((frames / math.max(now - last, 1e-3)) + 0.5))
			frames = 0
			last = now
			session.Text = clock(now - window.startedAt)
			local ms = player and readPing(player)
			ping.Text = ms and (tostring(math.floor(ms + 0.5)) .. " ms") or "--"
		end
	end)

	return control
end

return Stats
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
	local shine = Ui.gradient(track, "accent", "accent2", 0)
	local stroke = Ui.stroke(track, "glow", 0.7, 1)

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
		shine.Enabled = enabled
		track.BackgroundColor3 = enabled and Color3.new(1, 1, 1) or Theme.color("track")
		stroke.Transparency = enabled and 0.3 or 0.7
		knob.BackgroundColor3 = enabled and Theme.color("accentText") or Theme.color("muted")
		Ui.tween(knob, { Position = UDim2.fromOffset(enabled and 23 or 3, 3) }, 0.14)
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
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Window = {}

local RAIL_WIDTH = 156
local BAR_HEIGHT = 56
local PORTRAIT_HEIGHT = 100
local AVATAR_HEIGHT = PORTRAIT_HEIGHT + 54

local function asKey(value)
	if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
		return value
	end
	if type(value) == "string" and Enum.KeyCode[value] then
		return Enum.KeyCode[value]
	end
	return Enum.KeyCode.LeftControl
end

local function asVector(value, fallback)
	if typeof(value) == "Vector2" then
		return value
	end
	if typeof(value) == "UDim2" then
		return Vector2.new(value.X.Offset, value.Y.Offset)
	end
	return fallback
end

local function viewportSize()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
end

local function startSize(config, minSize)
	local size = config.size or UDim2.fromOffset(680, 500)
	if size.X.Scale ~= 0 or size.Y.Scale ~= 0 then
		return size
	end
	local viewport = viewportSize()
	if viewport.X < 200 or viewport.Y < 200 then
		return size
	end
	local width = math.min(size.X.Offset, math.max(minSize.X, viewport.X - 24))
	local height = math.min(size.Y.Offset, math.max(minSize.Y, viewport.Y - 24))
	return UDim2.fromOffset(width, height)
end

local function avatarCard(sidebar)
	local player = Players.LocalPlayer
	local card = Ui.inst("Frame", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.new(1, -16, 0, AVATAR_HEIGHT),
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	Ui.glass(card, "row", 0.35, 0.7)
	Ui.corner(card, 10)
	Ui.padding(card, 8)

	local frame = Ui.inst("Frame", {
		Name = "Portrait",
		Size = UDim2.new(1, 0, 0, PORTRAIT_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = card,
	})
	Ui.corner(frame, 8)
	Ui.gradient(frame, "row", "window", 90)
	Ui.stroke(frame, "glow", 0.2, 1)
	Ui.inst("ImageLabel", {
		Name = "Image",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(1.3, 1.3),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = player and ("rbxthumb://type=Avatar&id=" .. player.UserId .. "&w=150&h=150") or "",
		Parent = frame,
	})

	local name = Ui.label({
		Text = player and player.DisplayName or "Player",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, PORTRAIT_HEIGHT + 6),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = card,
	})
	Theme.paint(name, "TextColor3", "text")
	local handle = Ui.label({
		Text = player and ("@" .. player.Name) or "",
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, PORTRAIT_HEIGHT + 22),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = card,
	})
	Theme.paint(handle, "TextColor3", "muted")
	return card
end

local function grip(parent)
	local button = Ui.inst("TextButton", {
		Name = "Resize",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -3, 1, -3),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 5,
		Parent = parent,
	})
	for _, spot in ipairs({ { 12, 4 }, { 8, 8 }, { 12, 8 }, { 4, 12 }, { 8, 12 }, { 12, 12 } }) do
		local dot = Ui.inst("Frame", {
			Position = UDim2.fromOffset(spot[1] - 1, spot[2] - 1),
			Size = UDim2.fromOffset(2, 2),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Parent = button,
		})
		Theme.paint(dot, "BackgroundColor3", "glow")
	end
	return button
end

function Window.create(config)
	config = config or {}
	if config.theme then
		Theme.set(config.theme)
	end
	local minSize = asVector(config.minSize, Vector2.new(460, 320))

	local gui = Ui.screen("TheX", 100000)
	local shell = Ui.inst("Frame", {
		Name = "Shell",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = startSize(config, minSize),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	for index, layer in ipairs({ { 2, 0.6 }, { 5, 0.82 }, { 10, 0.92 } }) do
		local glow = Ui.inst("Frame", {
			Name = "Glow" .. index,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = shell,
		})
		Ui.corner(glow, 12)
		Ui.stroke(glow, "glow", layer[2], layer[1])
	end

	local frame = Ui.inst("Frame", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		ZIndex = 1,
		Parent = shell,
	})
	Ui.gradient(frame, "bar", "window", 90)
	Ui.corner(frame, 12)
	Ui.stroke(frame, "glow", 0.35, 1)

	local bar = Ui.inst("Frame", {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		Parent = frame,
	})
	local divider = Ui.inst("Frame", {
		Name = "Divider",
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		Parent = bar,
	})
	Theme.paint(divider, "BackgroundColor3", "glow")
	Ui.inst("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85),
			NumberSequenceKeypoint.new(0.3, 0.35),
			NumberSequenceKeypoint.new(1, 0.9),
		}),
		Parent = divider,
	})

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
		Font = Enum.Font.GothamBold,
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
	Theme.paint(subtitle, "TextColor3", "accent")

	local close = Ui.inst("TextButton", {
		Name = "Close",
		AutoButtonColor = false,
		Text = "x",
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = bar,
	})
	Ui.corner(close, 8)
	Theme.paint(close, "BackgroundColor3", "danger")
	Theme.paint(close, "TextColor3", "text")
	local closeStroke = Ui.stroke(close, "danger", 0.6, 1)
	close.MouseEnter:Connect(function()
		Ui.tween(close, { BackgroundTransparency = 0.1 }, 0.12)
		Ui.tween(closeStroke, { Transparency = 0.2 }, 0.12)
	end)
	close.MouseLeave:Connect(function()
		Ui.tween(close, { BackgroundTransparency = 0.8 }, 0.12)
		Ui.tween(closeStroke, { Transparency = 0.6 }, 0.12)
	end)

	local body = Ui.inst("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, BAR_HEIGHT),
		Size = UDim2.new(1, 0, 1, -BAR_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = frame,
	})
	local sidebar = Ui.inst("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, RAIL_WIDTH, 1, 0),
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Parent = body,
	})
	Theme.paint(sidebar, "BackgroundColor3", "rail")
	local edge = Ui.inst("Frame", {
		Name = "Edge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	Theme.paint(edge, "BackgroundColor3", "glow")

	local showAvatar = config.showAvatar ~= false
	local rail = Ui.inst("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 1, showAvatar and -(AVATAR_HEIGHT + 16) or 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	})
	Theme.paint(rail, "ScrollBarImageColor3", "accent")
	local railLayout = Ui.list(rail, 4)
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Ui.inst("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 8),
		Parent = rail,
	})
	if showAvatar then
		avatarCard(sidebar)
	end

	local pages = Ui.inst("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(RAIL_WIDTH, 0),
		Size = UDim2.new(1, -RAIL_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = body,
	})
	local resize = grip(frame)

	local window = {
		gui = gui,
		shell = shell,
		frame = frame,
		sidebar = sidebar,
		rail = rail,
		pages = pages,
		tabs = {},
		controls = {},
		dead = false,
		startedAt = os.clock(),
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
	local resizing = false
	local pressStart
	local startPos
	local startDims

	drag.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		dragging = true
		pressStart = input.Position
		startPos = shell.Position
	end)
	resize.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		local topLeft = shell.AbsolutePosition - gui.AbsolutePosition
		shell.AnchorPoint = Vector2.zero
		shell.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
		resizing = true
		pressStart = input.Position
		startDims = shell.AbsoluteSize
	end)
	window:connect(UserInputService.InputEnded, function(input)
		if isPress(input) then
			dragging = false
			resizing = false
		end
	end)
	window:connect(UserInputService.InputChanged, function(input)
		if window.dead or not isMove(input) then
			return
		end
		if resizing then
			local delta = input.Position - pressStart
			local screen = gui.AbsoluteSize
			local topLeft = shell.AbsolutePosition - gui.AbsolutePosition
			local maxWidth = math.max(minSize.X, screen.X - topLeft.X)
			local maxHeight = math.max(minSize.Y, screen.Y - topLeft.Y)
			shell.Size = UDim2.fromOffset(
				math.clamp(startDims.X + delta.X, minSize.X, maxWidth),
				math.clamp(startDims.Y + delta.Y, minSize.Y, maxHeight)
			)
		elseif dragging then
			local delta = input.Position - pressStart
			shell.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	window:connect(UserInputService.InputBegan, function(input)
		if window.dead or window.session.capturing or window.session.suppress == input then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == toggleKey then
			shell.Visible = not shell.Visible
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
