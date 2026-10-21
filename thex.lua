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
local MarketplaceService = game:GetService("MarketplaceService")

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

function Games.list(list)
	local ordered = {}
	local seen = {}
	if type(list) ~= "table" then
		return ordered
	end
	local function add(value)
		local id = tonumber(value)
		if id and not seen[id] then
			seen[id] = true
			table.insert(ordered, id)
		end
	end
	for _, value in ipairs(list) do
		add(value)
	end
	for key, value in pairs(list) do
		if type(key) ~= "number" or key < 1 or key > #list or key % 1 ~= 0 then
			if type(value) == "number" or (type(value) == "string" and tonumber(value)) then
				add(value)
			elseif value ~= false and tonumber(key) then
				add(key)
			end
		end
	end
	return ordered
end

function Games.count(list)
	local _, count = Games.ids(list)
	return count
end

function Games.supported(list)
	local set = Games.ids(list)
	return set[game.PlaceId] == true or set[game.GameId] == true
end

local infoCache = {}
local infoWaiting = {}

function Games.info(placeId, callback)
	placeId = tonumber(placeId) or game.PlaceId
	local cached = infoCache[placeId]
	if cached ~= nil then
		task.spawn(callback, cached or nil)
		return
	end
	local waiting = infoWaiting[placeId]
	if waiting then
		table.insert(waiting, callback)
		return
	end
	infoWaiting[placeId] = { callback }
	task.spawn(function()
		local ok, product = pcall(function()
			return MarketplaceService:GetProductInfo(placeId)
		end)
		local result = ok and type(product) == "table" and type(product.Name) == "string" and product.Name ~= "" and product
		infoCache[placeId] = result or false
		local callbacks = infoWaiting[placeId]
		infoWaiting[placeId] = nil
		for _, fn in ipairs(callbacks) do
			task.spawn(fn, result or nil)
		end
	end)
end

function Games.creator(product)
	local creator = type(product) == "table" and product.Creator
	return type(creator) == "table" and type(creator.Name) == "string" and creator.Name or nil
end

function Games.updatedAgo(product)
	local stamp = type(product) == "table" and product.Updated
	if type(stamp) ~= "string" then
		return nil
	end
	local ok, date = pcall(DateTime.fromIsoDate, stamp)
	if not ok or not date then
		return nil
	end
	local days = math.floor((DateTime.now().UnixTimestamp - date.UnixTimestamp) / 86400)
	if days < 1 then
		return "Updated today"
	elseif days == 1 then
		return "Updated 1 day ago"
	elseif days < 60 then
		return "Updated " .. days .. " days ago"
	elseif days < 730 then
		return "Updated " .. (days // 30) .. " months ago"
	end
	return "Updated " .. (days // 365) .. " years ago"
end

return Games
end

modules["Icons"] = function(require)
local Icons = {
	base = "https://raw.githubusercontent.com/panupongainaim/TheX-ui/main/Assets/icons/",
	folder = "TheX/icons/1.2.0",
}

local glyphs = {
	logo = "X",
	home = "⌂",
	["gamepad-2"] = "◆",
	["file-code"] = "≡",
	settings = "⚙",
	bell = "◉",
	map = "▦",
	clock = "◷",
	monitor = "▭",
	signal = "▮",
	zap = "ϟ",
	["rotate-cw"] = "↻",
	clipboard = "❐",
	["chevron-right"] = "›",
	info = "i",
	["shield-check"] = "◈",
	["circle-check"] = "✓",
	["circle-alert"] = "!",
	crown = "♛",
	["badge-check"] = "✓",
	play = "▶",
	tag = "#",
	minus = "–",
	square = "□",
	copy = "❐",
	x = "✕",
	infinity = "∞",
	user = "●",
}

local assets = {}
local pending = {}

local function supported()
	return type(getcustomasset) == "function"
		and type(writefile) == "function"
		and type(isfile) == "function"
		and type(makefolder) == "function"
		and type(isfolder) == "function"
end

local function ensureFolder(path)
	local built = ""
	for part in string.gmatch(path, "[^/]+") do
		built = (built == "") and part or (built .. "/" .. part)
		local ok, exists = pcall(isfolder, built)
		if ok and not exists then
			pcall(makefolder, built)
		end
	end
end

local function fetch(name)
	local path = Icons.folder .. "/" .. name .. ".png"
	local cached, exists = pcall(isfile, path)
	if not (cached and exists) then
		local ok, body = pcall(function()
			return game:HttpGet(Icons.base .. name .. ".png", true)
		end)
		if not ok or type(body) ~= "string" or string.sub(body, 1, 4) ~= "\137PNG" then
			return nil
		end
		ensureFolder(Icons.folder)
		if not pcall(writefile, path, body) then
			return nil
		end
	end
	local ok, asset = pcall(getcustomasset, path)
	if ok and type(asset) == "string" and asset ~= "" then
		return asset
	end
	return nil
end

function Icons.glyph(name)
	return glyphs[name] or "•"
end

function Icons.request(name, callback)
	local asset = assets[name]
	if asset then
		task.spawn(callback, asset)
		return
	end
	if asset == false or not supported() then
		return
	end
	local waiting = pending[name]
	if waiting then
		table.insert(waiting, callback)
		return
	end
	pending[name] = { callback }
	task.spawn(function()
		local result = fetch(name)
		assets[name] = result or false
		local callbacks = pending[name]
		pending[name] = nil
		if result then
			for _, fn in ipairs(callbacks) do
				task.spawn(fn, result)
			end
		end
	end)
end

return Icons
end

modules[""] = function(require)
local Notify = require("Notify")
local Theme = require("Theme")
local Window = require("Window")

local TheX = {
	version = "1.2.0",
}

local windows = {}

function TheX.window(config)
	local window = Window.create(config, TheX.version)
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

local Notify = {
	history = {},
}

local HISTORY_LIMIT = 10

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
	config = config or {}
	table.insert(Notify.history, 1, {
		title = tostring(config.title or "Notice"),
		content = tostring(config.content or ""),
		time = os.time(),
	})
	while #Notify.history > HISTORY_LIMIT do
		table.remove(Notify.history)
	end
	if mounted == nil or mounted.Parent == nil then
		mounted = Notify.mount()
	end
	return Notify.push(mounted, config)
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
local CurrentMap = require("Widgets/CurrentMap")
local SystemStatus = require("Widgets/SystemStatus")
local Brand = require("Widgets/Brand")
local GamesList = require("Widgets/GamesList")
local Actions = require("Widgets/Actions")

local Tab = {}

local GAP = 10
local MIN_LEFT = 380

local widgets = {
	paragraph = Paragraph,
	button = Button,
	toggle = Toggle,
	slider = Slider,
	dropdown = Dropdown,
	input = Input,
	keybind = Keybind,
	colorpicker = Colorpicker,
	profile = Profile,
	stats = Stats,
	gameInfo = GameInfo,
	currentMap = CurrentMap,
	systemStatus = SystemStatus,
	brand = Brand,
	games = GamesList,
	actions = Actions,
}

local function container(window, page)
	local target = {
		window = window,
		page = page,
		_order = 0,
	}
	function target:nextOrder()
		self._order += 1
		return self._order
	end
	for name, widget in pairs(widgets) do
		target[name] = function(self, options)
			return widget.create(self, options or {})
		end
	end

	function target:columns(options)
		options = options or {}
		local rightWidth = tonumber(options.rightWidth) or 230
		local holder = Ui.inst("Frame", {
			Name = "Columns",
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = self:nextOrder(),
			Parent = self.page,
		})
		local function column(name)
			local frame = Ui.inst("Frame", {
				Name = name,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = holder,
			})
			Ui.list(frame, GAP)
			return frame
		end
		local leftFrame = column("Left")
		local rightFrame = column("Right")

		local function layout()
			local width = holder.AbsoluteSize.X
			local leftHeight = leftFrame.AbsoluteSize.Y
			local rightHeight = rightFrame.AbsoluteSize.Y
			if width >= MIN_LEFT + GAP + rightWidth then
				leftFrame.Position = UDim2.new()
				leftFrame.Size = UDim2.new(1, -(rightWidth + GAP), 0, 0)
				rightFrame.Position = UDim2.new(1, -rightWidth, 0, 0)
				rightFrame.Size = UDim2.new(0, rightWidth, 0, 0)
				holder.Size = UDim2.new(1, 0, 0, math.max(leftHeight, rightHeight))
			else
				leftFrame.Position = UDim2.new()
				leftFrame.Size = UDim2.new(1, 0, 0, 0)
				rightFrame.Position = UDim2.fromOffset(0, leftHeight + GAP)
				rightFrame.Size = UDim2.new(1, 0, 0, 0)
				holder.Size = UDim2.new(1, 0, 0, leftHeight + GAP + rightHeight)
			end
		end
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
		leftFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
		rightFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
		layout()

		return container(window, leftFrame), container(window, rightFrame)
	end

	return target
end

function Tab.create(window, config)
	local title = config.title or "Tab"

	local button = Ui.inst("TextButton", {
		Name = title .. "Tab",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, -20, 0, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = window.rail,
	})
	local fill = Ui.inst("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = button,
	})
	Ui.corner(fill, 10)
	local shine = Ui.gradient(fill, "accent2", "accent2", 0)
	shine.Transparency = NumberSequence.new(0, 0.45)
	local hover = Ui.inst("Frame", {
		Name = "Hover",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = button,
	})
	Ui.corner(hover, 10)
	Theme.paint(hover, "BackgroundColor3", "row")
	local fillStroke = Ui.stroke(fill, "glow", 1, 1)

	local icon = Ui.icon(button, config.icon or "chevron-right", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 2,
	})
	local label = Ui.label({
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -50, 1, 0),
		ZIndex = 2,
		Parent = button,
	})

	local page = Ui.inst("ScrollingFrame", {
		Name = title .. "Page",
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
	Theme.paint(page, "ScrollBarImageColor3", "accent")
	Ui.inst("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = page,
	})
	Ui.list(page, GAP)

	local tab = container(window, page)
	tab.tabButton = button
	tab.selected = false
	tab.hovered = false

	function tab:paint()
		self.page.Visible = self.selected
		Ui.tween(fill, { BackgroundTransparency = self.selected and 0 or 1 }, 0.14)
		Ui.tween(fillStroke, { Transparency = self.selected and 0.6 or 1 }, 0.14)
		Ui.tween(hover, { BackgroundTransparency = (not self.selected and self.hovered) and 0.5 or 1 }, 0.12)
		local token = (self.selected and "accentText") or (self.hovered and "text") or "muted"
		label.TextColor3 = Theme.color(token)
		icon:color(Theme.color(self.selected and "accentText" or (self.hovered and "text") or "muted"))
	end

	function tab:layout(compact)
		label.Visible = not compact
		if compact then
			icon.frame.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.frame.Position = UDim2.fromScale(0.5, 0.5)
			button.Size = UDim2.new(1, -12, 0, 40)
		else
			icon.frame.AnchorPoint = Vector2.new(0, 0.5)
			icon.frame.Position = UDim2.new(0, 14, 0.5, 0)
			button.Size = UDim2.new(1, -20, 0, 40)
		end
	end

	button.MouseButton1Click:Connect(function()
		window:select(tab)
	end)
	button.MouseEnter:Connect(function()
		tab.hovered = true
		tab:paint()
	end)
	button.MouseLeave:Connect(function()
		tab.hovered = false
		tab:paint()
	end)
	Theme.onChange(function()
		if button.Parent then
			tab:paint()
		end
	end)
	tab:layout(window.compact)
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
			purple = Color3.fromRGB(168, 102, 255),
			teal = Color3.fromRGB(32, 214, 196),
			premium = Color3.fromRGB(186, 128, 255),
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
			purple = Color3.fromRGB(122, 74, 196),
			teal = Color3.fromRGB(22, 138, 126),
			premium = Color3.fromRGB(140, 86, 200),
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

function Theme.bind(instance, apply)
	bind(instance, apply)
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
local Icons = require("Icons")
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

function Ui.icon(parent, name, props)
	props = props or {}
	local zIndex = props.ZIndex or 1
	local holder = Ui.inst("Frame", {
		Name = props.Name or "Icon",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = zIndex,
		Parent = parent,
	})
	local image = Ui.inst("ImageLabel", {
		Name = "Image",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = zIndex,
		Parent = holder,
	})
	local glyph = Ui.label({
		Name = "Glyph",
		Text = Icons.glyph(name),
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
		Parent = holder,
	})

	local icon = { frame = holder, image = image, glyph = glyph }
	function icon:color(value)
		image.ImageColor3 = value
		glyph.TextColor3 = value
	end
	if props.token then
		Theme.paint(image, "ImageColor3", props.token)
		Theme.paint(glyph, "TextColor3", props.token)
	elseif props.color then
		icon:color(props.color)
	else
		Theme.paint(glyph, "TextColor3", "accent")
	end
	Icons.request(name, function(asset)
		if holder.Parent then
			image.Image = asset
			image.Visible = true
			glyph.Visible = false
		end
	end)
	return icon
end

function Ui.sparkline(parent, token, props)
	props = props or {}
	local frame = Ui.inst("Frame", {
		Name = "Sparkline",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(60, 24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	local limit = props.points or 12
	local values = {}
	local segments = {}

	local function segment(index)
		local piece = segments[index]
		if not piece then
			piece = Ui.inst("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BorderSizePixel = 0,
				ZIndex = frame.ZIndex,
				Parent = frame,
			})
			Ui.corner(piece, 1)
			Theme.paint(piece, "BackgroundColor3", token)
			segments[index] = piece
		end
		return piece
	end

	local function draw()
		local size = frame.AbsoluteSize
		local count = #values
		for index = math.max(count, 1), #segments do
			segments[index].Visible = false
		end
		if count < 2 or size.X < 4 or size.Y < 4 then
			return
		end
		local low, high = math.huge, -math.huge
		for _, value in ipairs(values) do
			low = math.min(low, value)
			high = math.max(high, value)
		end
		local span = high - low
		local points = {}
		for index, value in ipairs(values) do
			local ratio = span > 1e-6 and (value - low) / span or 0.5
			local x = ((limit - count + index - 1) / (limit - 1)) * (size.X - 2) + 1
			local y = size.Y - 2 - ratio * (size.Y - 4)
			points[index] = Vector2.new(x, y)
		end
		for index = 1, count - 1 do
			local a, b = points[index], points[index + 1]
			local delta = b - a
			local piece = segment(index)
			piece.Visible = true
			piece.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
			piece.Size = UDim2.fromOffset(delta.Magnitude + 1.5, 2)
			piece.Rotation = math.deg(math.atan2(delta.Y, delta.X))
			piece.BackgroundTransparency = 0.8 * (1 - index / (count - 1))
		end
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(draw)

	local function push(value)
		table.insert(values, tonumber(value) or 0)
		if #values > limit then
			table.remove(values, 1)
		end
		draw()
	end
	return frame, push
end

function Ui.chip(parent, text, props)
	props = props or {}
	local tone = props.token or "muted"
	local height = props.height or 22
	local chip = Ui.inst("Frame", {
		Name = props.Name or "Chip",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or UDim2.new(),
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = props.fill or 0.86,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	Theme.paint(chip, "BackgroundColor3", tone)
	Ui.corner(chip, height // 2)
	Ui.stroke(chip, tone, props.strokeTransparency or 0.7, 1)
	Ui.inst("UIPadding", {
		PaddingLeft = UDim.new(0, 9),
		PaddingRight = UDim.new(0, 9),
		Parent = chip,
	})
	local layout = Ui.list(chip, 5, Enum.FillDirection.Horizontal)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	local dot
	if props.dot then
		dot = Ui.inst("Frame", {
			Name = "Dot",
			Size = UDim2.fromOffset(7, 7),
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Parent = chip,
		})
		Ui.inst("UICorner", {
			CornerRadius = UDim.new(0.5, 0),
			Parent = dot,
		})
		Theme.paint(dot, "BackgroundColor3", tone)
	end
	if props.icon then
		Ui.icon(chip, props.icon, {
			Size = UDim2.fromOffset(12, 12),
			LayoutOrder = 2,
			token = props.textToken or tone,
		})
	end
	local label = Ui.label({
		Text = text or "",
		Font = Enum.Font.GothamMedium,
		TextSize = props.textSize or 11,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		Parent = chip,
	})
	Theme.paint(label, "TextColor3", props.textToken or tone)
	return chip, label, dot
end

function Ui.sectionHeader(parent, iconName, text, props)
	props = props or {}
	local row = Ui.inst("Frame", {
		Name = "Header",
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	local icon = Ui.icon(row, iconName, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		token = props.token or "accent",
	})
	local label = Ui.label({
		Text = text or "",
		Font = Enum.Font.GothamBold,
		TextSize = props.textSize or 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -28, 1, 0),
		Parent = row,
	})
	Theme.paint(label, "TextColor3", "text")
	return row, label, icon
end

function Ui.box(parent, order, height)
	local box = Ui.inst("Frame", {
		Name = "Card",
		Size = UDim2.new(1, 0, 0, height or 0),
		AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = order,
		Parent = parent,
	})
	Ui.glass(box, "row", 0.45, 0.72)
	Ui.corner(box, 12)
	return box
end

function Ui.accentButton(parent, text, size, order, iconName)
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
	local label
	if iconName then
		local content = Ui.inst("Frame", {
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = face,
		})
		local layout = Ui.list(content, 8, Enum.FillDirection.Horizontal)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		Ui.icon(content, iconName, {
			Size = UDim2.fromOffset(16, 16),
			LayoutOrder = 1,
			token = "accentText",
		})
		label = Ui.label({
			Text = text or "",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			Parent = content,
		})
	else
		label = Ui.label({
			Text = text or "",
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.fromScale(1, 1),
			Parent = face,
		})
	end
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
local Theme = require("Theme")
local Notify = require("Notify")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Actions = {}

local GAP = 10
local BUTTON_HEIGHT = 42

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
		{ title = "Rejoin", icon = "rotate-cw", onClick = rejoin },
		{
			title = "Copy Job ID",
			icon = "clipboard",
			onClick = function()
				copy("Job ID", game.JobId)
			end,
		},
		{
			title = "Copy Place ID",
			icon = "clipboard",
			onClick = function()
				copy("Place ID", game.PlaceId)
			end,
		},
	}
end

local function actionButton(parent, spec, primary, order)
	local button = Ui.inst("TextButton", {
		Name = spec.title or "Action",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	Ui.corner(button, 10)
	local stroke
	if primary then
		local shine = Ui.gradient(button, "accent2", "accent", 0)
		shine.Transparency = NumberSequence.new(0, 0.1)
		stroke = Ui.stroke(button, "glow", 0.55, 1)
	else
		stroke = Ui.glass(button, "row", 0.5, 0.75)
	end
	local textToken = primary and "accentText" or "text"
	Ui.icon(button, spec.icon or "zap", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		token = textToken,
	})
	local label = Ui.label({
		Text = spec.title or "Run",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -72, 1, 0),
		Parent = button,
	})
	Theme.paint(label, "TextColor3", textToken)
	Ui.icon(button, "chevron-right", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		token = primary and "accentText" or "muted",
	})

	local rest = primary and 0.55 or 0.75
	local restFill = button.BackgroundTransparency
	button.MouseEnter:Connect(function()
		Ui.tween(stroke, { Transparency = 0.15 }, 0.12)
		if not primary then
			Ui.tween(button, { BackgroundTransparency = 0.25 }, 0.12)
		end
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(stroke, { Transparency = rest }, 0.12)
		Ui.tween(button, { BackgroundTransparency = restFill }, 0.12)
	end)
	button.MouseButton1Click:Connect(function()
		Ui.fire(spec.onClick)
	end)
	return button
end

function Actions.create(tab, config)
	local buttons = type(config.buttons) == "table" and #config.buttons > 0 and config.buttons or Actions.defaults()
	local card = Ui.box(tab.page, tab:nextOrder())
	card.Name = "Actions"
	Ui.padding(card, 14)
	Ui.list(card, GAP)

	local header = Ui.sectionHeader(card, "zap", config.title or "Quick Actions", { LayoutOrder = 0 })
	header.Size = UDim2.new(1, 0, 0, 28)

	for index, spec in ipairs(buttons) do
		actionButton(card, spec, index == 1, index)
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

modules["Widgets/Brand"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")

local Brand = {}

local HEIGHT = 92

local function italic(label, weight)
	pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", weight, Enum.FontStyle.Italic)
	end)
end

function Brand.create(tab, config)
	local card = Ui.box(tab.page, tab:nextOrder(), HEIGHT)
	card.Name = "Brand"

	local tint = Ui.inst("Frame", {
		Name = "Tint",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = card,
	})
	Ui.corner(tint, 12)
	local shine = Ui.gradient(tint, "accent2", "purple", 25)
	shine.Transparency = NumberSequence.new(0.6, 0.78)

	local mark = Ui.icon(card, "logo", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 18, 0.5, 0),
		Size = UDim2.fromOffset(110, 110),
	})
	mark.image.ImageTransparency = 0.88
	mark.glyph.TextTransparency = 0.9

	local title = Ui.label({
		Text = config.title or "TheX",
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, -24, 0, 36),
		Parent = card,
	})
	title.TextColor3 = Color3.new(1, 1, 1)
	italic(title, Enum.FontWeight.Heavy)
	Ui.gradient(title, "accent", "purple", 0)

	local tagline = Ui.label({
		Text = config.tagline or "More than just a script.",
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(1, -24, 0, 16),
		Parent = card,
	})
	Theme.paint(tagline, "TextColor3", "accent")
	italic(tagline, Enum.FontWeight.Medium)

	local swoosh = Ui.inst("Frame", {
		Name = "Swoosh",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 10, 0, 72),
		Size = UDim2.new(0.5, 0, 0, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = card,
	})
	Ui.corner(swoosh, 1)
	local swooshShine = Ui.gradient(swoosh, "accent", "purple", 0)
	swooshShine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.2),
		NumberSequenceKeypoint.new(1, 0.9),
	})

	return {
		type = "brand",
		set = function() end,
		get = function() end,
		encode = function() end,
	}
end

return Brand
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

modules["Widgets/CurrentMap"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local Games = require("Games")

local CurrentMap = {}

local COVER = 132
local PAD = 16
local HEADER = 24
local BUTTON_WIDTH = 140

local function clean(text)
	text = string.gsub(tostring(text or ""), "%s+", " ")
	if #text > 240 then
		text = string.sub(text, 1, 237) .. "..."
	end
	return text
end

function CurrentMap.create(tab, config)
	local supported = Games.supported(config.supportedGames)
	local top = PAD + HEADER + 14
	local row = Ui.box(tab.page, tab:nextOrder(), top + COVER + PAD)
	row.Name = "CurrentMap"

	local header = Ui.sectionHeader(row, "gamepad-2", config.title or "Current Map", {
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.new(1, -(PAD * 2), 0, HEADER),
	})
	local tone = supported and "success" or "warning"
	Ui.chip(header, supported and "Supported" or "Not supported", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		token = tone,
		dot = true,
		height = 24,
	})

	local cover = Ui.inst("ImageLabel", {
		Name = "Cover",
		Position = UDim2.fromOffset(PAD, top),
		Size = UDim2.fromOffset(COVER, COVER),
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Crop,
		Image = "rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=256&h=256",
		Parent = row,
	})
	Theme.paint(cover, "BackgroundColor3", "window")
	Ui.corner(cover, 12)
	Ui.stroke(cover, "glow", 0.5, 1)

	local left = PAD + COVER + 18
	local name = Ui.label({
		Text = "Loading...",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(left, top + 4),
		Size = UDim2.new(1, -(left + PAD), 0, 22),
		Parent = row,
	})
	Theme.paint(name, "TextColor3", "text")
	local creator = Ui.label({
		Text = "",
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(left, top + 28),
		Size = UDim2.new(1, -(left + PAD), 0, 16),
		Parent = row,
	})
	Theme.paint(creator, "TextColor3", "muted")
	local description = Ui.label({
		Text = "",
		TextSize = 12,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(left, top + 52),
		Size = UDim2.new(1, -(left + PAD), 0, 32),
		Parent = row,
	})
	Theme.paint(description, "TextColor3", "muted")

	local hasLoad = type(config.onLoad) == "function"
	local tags = Ui.inst("Frame", {
		Name = "Tags",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, left, 0, top + COVER - 8),
		Size = UDim2.new(1, -(left + PAD + (hasLoad and BUTTON_WIDTH + 12 or 0)), 0, 24),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = row,
	})
	local tagLayout = Ui.list(tags, 10, Enum.FillDirection.Horizontal)
	tagLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	Ui.chip(tags, "Game", {
		icon = "tag",
		token = "muted",
		LayoutOrder = 1,
	})
	local updated = Ui.label({
		Text = "",
		TextSize = 11,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = tags,
	})
	Theme.paint(updated, "TextColor3", "muted")

	if hasLoad then
		local button, _, holder = Ui.accentButton(row, config.loadText or "Load Script", UDim2.fromOffset(BUTTON_WIDTH, 40), nil, "play")
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -PAD, 0, top + COVER)
		button.MouseButton1Click:Connect(function()
			Ui.fire(config.onLoad)
		end)
	end

	Games.info(game.PlaceId, function(product)
		if not row.Parent then
			return
		end
		if product then
			name.Text = product.Name
			local by = Games.creator(product)
			creator.Text = by and ("by " .. by) or ""
			description.Text = clean(product.Description)
			updated.Text = Games.updatedAgo(product) or ""
		else
			name.Text = tostring(game.PlaceId)
		end
	end)

	return {
		type = "currentMap",
		supported = supported,
		set = function() end,
		get = function()
			return supported
		end,
		encode = function() end,
	}
end

return CurrentMap
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
	local rows = {}

	local function rowSelected(name)
		return (multi and chosen[name] == true) or (not multi and name == single)
	end

	local function refreshRows()
		for name, row in pairs(rows) do
			if row.item.Parent then
				row.setSelected(rowSelected(name))
			else
				rows[name] = nil
			end
		end
	end

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
		refreshRows()
		if silent ~= true then
			emit()
		end
	end

	local function open()
		tab.window:closePopup()
		rows = {}
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
			local picked = selected
			local function apply()
				item.Text = (picked and "✓  " or "    ") .. text
				item.TextColor3 = Theme.color(picked and "accent" or "text")
			end
			Theme.bind(item, apply)
			Theme.paint(item, "BackgroundColor3", "accent")
			item.MouseEnter:Connect(function()
				Ui.tween(item, { BackgroundTransparency = 0.85 }, 0.1)
			end)
			item.MouseLeave:Connect(function()
				Ui.tween(item, { BackgroundTransparency = 1 }, 0.1)
			end)
			local function setSelected(nextSelected)
				picked = nextSelected == true
				if item.Parent then
					apply()
				end
			end
			item.MouseButton1Click:Connect(function()
				onPick(setSelected)
			end)
			return item, setSelected
		end

		if #values == 0 then
			addItem("Empty", false, function() end)
		end
		for _, name in ipairs(values) do
			local item, setSelected = addItem(name, rowSelected(name), function(setSelected)
				if multi then
					chosen[name] = not chosen[name]
					current.Text = summary()
					setSelected(chosen[name] == true)
					emit()
				else
					single = name
					current.Text = summary()
					tab.window:closePopup()
					emit()
				end
			end)
			rows[name] = { item = item, setSelected = setSelected }
		end
		menu.Destroying:Connect(function()
			rows = {}
		end)
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
local Players = game:GetService("Players")

local GameInfo = {}

local PAD = 16
local ROW = 28
local KEY_WIDTH = 74

function GameInfo.create(tab, config)
	local supported = Games.supported(config.supportedGames)
	local card = Ui.box(tab.page, tab:nextOrder())
	card.Name = "GameInfo"
	Ui.padding(card, PAD)
	Ui.list(card, 4)

	local header = Ui.sectionHeader(card, "info", config.title or "Game Info", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 24),
	})
	header.Size = UDim2.new(1, 0, 0, 34)

	local order = 1
	local function line(key)
		order += 1
		local holder = Ui.inst("Frame", {
			Name = key,
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = card,
		})
		local keyLabel = Ui.label({
			Text = key,
			TextSize = 12,
			Size = UDim2.new(0, KEY_WIDTH, 1, 0),
			Parent = holder,
		})
		Theme.paint(keyLabel, "TextColor3", "muted")
		local colon = Ui.label({
			Text = ":",
			TextSize = 12,
			Position = UDim2.fromOffset(KEY_WIDTH, 0),
			Size = UDim2.new(0, 12, 1, 0),
			Parent = holder,
		})
		Theme.paint(colon, "TextColor3", "muted")
		local value = Ui.label({
			Text = "",
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(KEY_WIDTH + 14, 0),
			Size = UDim2.new(1, -(KEY_WIDTH + 14), 1, 0),
			Parent = holder,
		})
		Theme.paint(value, "TextColor3", "text")
		return value, holder
	end

	local title = line("Title")
	local creator = line("Creator")
	local kind = line("Type")
	local status, statusRow = line("Status")
	local players = line("Players")

	title.Text = "Loading..."
	creator.Text = "--"
	kind.Text = "Game"
	local tone = supported and "success" or "warning"
	status.Text = supported and "Supported" or "Not supported"
	status.Position = UDim2.fromOffset(KEY_WIDTH + 30, 0)
	status.Size = UDim2.new(1, -(KEY_WIDTH + 30), 1, 0)
	Theme.paint(status, "TextColor3", tone)
	local dot = Ui.inst("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, KEY_WIDTH + 14, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BorderSizePixel = 0,
		Parent = statusRow,
	})
	Ui.inst("UICorner", {
		CornerRadius = UDim.new(0.5, 0),
		Parent = dot,
	})
	Theme.paint(dot, "BackgroundColor3", tone)

	local function refreshPlayers()
		local count = #Players:GetPlayers()
		local ok, max = pcall(function()
			return Players.MaxPlayers
		end)
		players.Text = (ok and type(max) == "number" and max > 0) and (count .. " / " .. max) or tostring(count)
	end
	refreshPlayers()
	tab.window:connect(Players.PlayerAdded, refreshPlayers)
	tab.window:connect(Players.PlayerRemoving, function()
		task.defer(refreshPlayers)
	end)

	Games.info(game.PlaceId, function(product)
		if not card.Parent then
			return
		end
		title.Text = product and product.Name or tostring(game.PlaceId)
		creator.Text = Games.creator(product) or "--"
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

modules["Widgets/GamesList"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local Games = require("Games")

local GamesList = {}

local ROW = 64
local THUMB = 44

function GamesList.create(tab, config)
	local ids = Games.list(config.supportedGames)
	local card = Ui.box(tab.page, tab:nextOrder())
	card.Name = "Games"
	Ui.padding(card, 16)
	Ui.list(card, 8)

	local header = Ui.sectionHeader(card, "gamepad-2", config.title or "Supported Games", { LayoutOrder = 0 })
	header.Size = UDim2.new(1, 0, 0, 30)
	Ui.chip(header, tostring(#ids), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		token = "accent",
	})

	if #ids == 0 then
		Ui.note(card, "No supported games yet.", 1)
	end

	for index, id in ipairs(ids) do
		local current = id == game.PlaceId or id == game.GameId
		local row = Ui.inst("Frame", {
			Name = tostring(id),
			Size = UDim2.new(1, 0, 0, ROW),
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = card,
		})
		Ui.glass(row, "row", current and 0.25 or 0.55, current and 0.45 or 0.8)
		Ui.corner(row, 10)

		local thumb = Ui.inst("ImageLabel", {
			Name = "Thumb",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(THUMB, THUMB),
			BorderSizePixel = 0,
			ScaleType = Enum.ScaleType.Crop,
			Image = id == game.PlaceId and ("rbxthumb://type=GameIcon&id=" .. game.GameId .. "&w=150&h=150")
				or ("rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150"),
			Parent = row,
		})
		Theme.paint(thumb, "BackgroundColor3", "window")
		Ui.corner(thumb, 8)

		local left = 10 + THUMB + 12
		local right = current and 96 or 16
		local name = Ui.label({
			Text = tostring(id),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(left, 13),
			Size = UDim2.new(1, -(left + right), 0, 18),
			Parent = row,
		})
		Theme.paint(name, "TextColor3", "text")
		local sub = Ui.label({
			Text = "PlaceId " .. id,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(left, 34),
			Size = UDim2.new(1, -(left + right), 0, 14),
			Parent = row,
		})
		Theme.paint(sub, "TextColor3", "muted")

		if current then
			Ui.chip(row, "Playing", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				token = "success",
				dot = true,
			})
		end

		Games.info(id, function(product)
			if product and row.Parent then
				name.Text = product.Name
				local by = Games.creator(product)
				sub.Text = by and ("by " .. by) or ("PlaceId " .. id)
			end
		end)
	end

	return {
		type = "games",
		set = function() end,
		get = function()
			return ids
		end,
		encode = function() end,
	}
end

return GamesList
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

local AVATAR = 84
local HEIGHT = 124
local BADGE_WIDTH = 112

local function round(frame)
	Ui.inst("UICorner", {
		CornerRadius = UDim.new(0.5, 0),
		Parent = frame,
	})
end

local function waves(row)
	for index, spec in ipairs({ { 0.62, -160, 420, 0.86 }, { 0.72, -120, 360, 0.9 }, { 0.84, -40, 300, 0.93 } }) do
		local wave = Ui.inst("Frame", {
			Name = "Wave" .. index,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(spec[1], 0, 0, spec[2]),
			Size = UDim2.fromOffset(spec[3], spec[3]),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = row,
		})
		round(wave)
		Ui.stroke(wave, "accent2", spec[4], 18)
	end
end

local function badgeCard(row, badge)
	local card = Ui.inst("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(BADGE_WIDTH, 48),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = row,
	})
	Theme.paint(card, "BackgroundColor3", "premium")
	Ui.corner(card, 10)
	Ui.stroke(card, "premium", 0.35, 1)
	Ui.icon(card, "crown", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		token = "premium",
		ZIndex = 2,
	})
	local title = Ui.label({
		Text = tostring(badge.title or "Premium"),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(38, badge.subtitle and 8 or 0),
		Size = UDim2.new(1, -44, 0, badge.subtitle and 18 or 48),
		ZIndex = 2,
		Parent = card,
	})
	Theme.paint(title, "TextColor3", "text")
	if badge.subtitle then
		local subtitle = Ui.label({
			Text = tostring(badge.subtitle),
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(38, 26),
			Size = UDim2.new(1, -44, 0, 14),
			ZIndex = 2,
			Parent = card,
		})
		Theme.paint(subtitle, "TextColor3", "premium")
	end
	return card
end

function Profile.create(tab, config)
	local player = Players.LocalPlayer
	local row = Ui.box(tab.page, tab:nextOrder(), HEIGHT)
	row.Name = "Profile"

	local tint = Ui.inst("Frame", {
		Name = "Tint",
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = row,
	})
	Ui.corner(tint, 12)
	Theme.paint(tint, "BackgroundColor3", "accent2")
	Ui.inst("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.55, 0.9),
			NumberSequenceKeypoint.new(1, 0.7),
		}),
		Parent = tint,
	})
	waves(row)

	local halo = Ui.inst("Frame", {
		Name = "Halo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.fromOffset(AVATAR, AVATAR),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = row,
	})
	Theme.paint(halo, "BackgroundColor3", "window")
	round(halo)
	Ui.stroke(halo, "accent", 0.05, 2)
	local ring = Ui.inst("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 10, 1, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = halo,
	})
	round(ring)
	Ui.stroke(ring, "accent2", 0.55, 3)
	local headshot = Ui.inst("ImageLabel", {
		Name = "Headshot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = player and ("rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150") or "",
		ZIndex = 2,
		Parent = halo,
	})
	round(headshot)

	local badge = type(config.badge) == "table" and badgeCard(row, config.badge)
	local left = 22 + AVATAR + 22
	local right = badge and (BADGE_WIDTH + 28) or 16
	local info = Ui.inst("Frame", {
		Name = "Info",
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + right), 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = row,
	})
	local nameRow = Ui.inst("Frame", {
		Name = "NameRow",
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = info,
	})
	local nameLayout = Ui.list(nameRow, 8, Enum.FillDirection.Horizontal)
	nameLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local name = Ui.label({
		Text = player and player.DisplayName or "Player",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		ZIndex = 2,
		Parent = nameRow,
	})
	Theme.paint(name, "TextColor3", "text")
	local verified = false
	pcall(function()
		verified = player.HasVerifiedBadge == true
	end)
	if verified then
		Ui.icon(nameRow, "badge-check", {
			Size = UDim2.fromOffset(20, 20),
			LayoutOrder = 2,
			token = "accent",
			ZIndex = 2,
		})
	end

	local handle = Ui.label({
		Text = player and ("@" .. player.Name) or "",
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 2,
		Parent = info,
	})
	Theme.paint(handle, "TextColor3", "muted")
	local meta = Ui.label({
		Text = player and string.format("UserId  %d    •    %d days old", player.UserId, player.AccountAge) or "",
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = 2,
		Parent = info,
	})
	Theme.paint(meta, "TextColor3", "muted")
	local tagline = Ui.label({
		Text = tostring(config.tagline or ""),
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 2,
		Parent = info,
	})
	Theme.paint(tagline, "TextColor3", "muted")
	tagline.TextTransparency = 0.25

	local control = { type = "profile" }
	function control:set(text)
		tagline.Text = tostring(text or "")
	end
	function control:get()
		return tagline.Text
	end
	function control:encode() end
	return control
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

local CELL_HEIGHT = 84
local GAP = 10
local MIN_WIDE_CELL = 118

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
		grid.CellSize = UDim2.new(1 / columns, -math.ceil(GAP * (columns - 1) / columns) - 1, 0, CELL_HEIGHT)
		holder.Size = UDim2.new(1, 0, 0, (rows * CELL_HEIGHT) + ((rows - 1) * GAP))
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	local function card(order, title, iconName, token, chevron)
		local cell = Ui.inst("Frame", {
			Name = title,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = order,
			Parent = holder,
		})
		Ui.glass(cell, "row", 0.45, 0.72)
		Ui.corner(cell, 12)
		Ui.icon(cell, iconName, {
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.fromOffset(18, 18),
			token = token,
		})
		local name = Ui.label({
			Text = title,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			Position = UDim2.fromOffset(40, 14),
			Size = UDim2.new(1, -54, 0, 18),
			Parent = cell,
		})
		Theme.paint(name, "TextColor3", "muted")
		if chevron then
			Ui.icon(cell, "chevron-right", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 40),
				Size = UDim2.fromOffset(14, 14),
				token = "muted",
			})
		end
		local _, push = Ui.sparkline(cell, token, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -10),
			Size = UDim2.new(0.55, 0, 0, 24),
		})
		local value = Ui.label({
			Text = "--",
			Font = Enum.Font.GothamBold,
			TextSize = 22,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(14, 40),
			Size = UDim2.new(1, -28, 0, 26),
			ZIndex = 2,
			Parent = cell,
		})
		Theme.paint(value, "TextColor3", "text")
		return value, push
	end

	local maps, pushMaps = card(1, "Maps", "map", "accent", true)
	local session, pushSession = card(2, "Session", "clock", "purple")
	local fps, pushFps = card(3, "FPS", "monitor", "teal")
	local ping, pushPing = card(4, "Ping", "signal", "success")
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
			local rate = math.floor((frames / math.max(now - last, 1e-3)) + 0.5)
			fps.Text = tostring(rate)
			pushFps(rate)
			frames = 0
			last = now
			local elapsed = now - window.startedAt
			session.Text = clock(elapsed)
			pushSession(elapsed)
			pushMaps(tonumber(maps.Text) or 0)
			local ms = player and readPing(player)
			ping.Text = ms and (tostring(math.floor(ms + 0.5)) .. " ms") or "--"
			if ms then
				pushPing(ms)
			end
		end
	end)

	return control
end

return Stats
end

modules["Widgets/SystemStatus"] = function(require)
local Ui = require("Ui")
local Theme = require("Theme")
local TextService = game:GetService("TextService")

local SystemStatus = {}

local PAD = 14
local SUMMARY_WIDTH = 168
local SUMMARY_HEIGHT = 48
local MIN_ITEM = 92
local ITEM_HEIGHT = 36
local GAP = 12

function SystemStatus.create(tab, config)
	local card = Ui.box(tab.page, tab:nextOrder(), SUMMARY_HEIGHT + PAD * 2)
	card.Name = "SystemStatus"

	local summaryBlock = Ui.inst("Frame", {
		Name = "Summary",
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.fromOffset(SUMMARY_WIDTH, SUMMARY_HEIGHT),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local shield = Ui.inst("Frame", {
		Name = "Shield",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(42, 42),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Parent = summaryBlock,
	})
	Ui.inst("UICorner", {
		CornerRadius = UDim.new(0.5, 0),
		Parent = shield,
	})
	Theme.paint(shield, "BackgroundColor3", "accent")
	Ui.stroke(shield, "accent", 0.6, 1)
	Ui.icon(shield, "shield-check", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(22, 22),
		token = "accent",
	})
	local heading = Ui.label({
		Text = config.title or "System Status",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(52, 4),
		Size = UDim2.new(1, -52, 0, 18),
		Parent = summaryBlock,
	})
	Theme.paint(heading, "TextColor3", "text")
	local summary = Ui.label({
		Text = "",
		TextSize = 11,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(52, 24),
		Size = UDim2.new(1, -52, 0, 26),
		Parent = summaryBlock,
	})

	local divider = Ui.inst("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(1, 36),
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = card,
	})
	Theme.paint(divider, "BackgroundColor3", "glow")

	local chip
	if config.version then
		chip = Ui.chip(card, tostring(config.version), {
			AnchorPoint = Vector2.new(1, 0.5),
			token = "muted",
			height = 26,
			textSize = 12,
		})
	end

	local items = {}

	local function layout()
		local width = card.AbsoluteSize.X - PAD * 2
		if width <= 0 then
			return
		end
		local count = #items
		local chipWidth = chip and (chip.AbsoluteSize.X + GAP) or 0
		local start = PAD + SUMMARY_WIDTH + GAP * 2 + 1
		local area = width - (start - PAD) - chipWidth
		local middle = PAD + SUMMARY_HEIGHT / 2
		if chip then
			chip.Position = UDim2.fromOffset(PAD + width, middle)
		end
		local needed = 0
		for _, item in ipairs(items) do
			needed += item.width()
		end
		if count == 0 or needed + (count - 1) * GAP <= area then
			divider.Visible = count > 0
			divider.Position = UDim2.fromOffset(PAD + SUMMARY_WIDTH + GAP, middle)
			local extra = count > 0 and (area - needed - (count - 1) * GAP) / count or 0
			local x = start
			for _, item in ipairs(items) do
				local each = item.width() + extra
				item.frame.Position = UDim2.fromOffset(x, middle - ITEM_HEIGHT / 2)
				item.frame.Size = UDim2.fromOffset(each, ITEM_HEIGHT)
				x += each + GAP
			end
			card.Size = UDim2.new(1, 0, 0, SUMMARY_HEIGHT + PAD * 2)
		else
			divider.Visible = false
			local columns = math.max(1, math.min(count, math.floor(width / MIN_ITEM)))
			local each = width / columns
			local top = PAD + SUMMARY_HEIGHT + 10
			for index, item in ipairs(items) do
				local column = (index - 1) % columns
				local rowIndex = (index - 1) // columns
				item.frame.Position = UDim2.fromOffset(PAD + column * each, top + rowIndex * (ITEM_HEIGHT + 6))
				item.frame.Size = UDim2.fromOffset(each - 6, ITEM_HEIGHT)
			end
			local rows = math.ceil(count / columns)
			card.Size = UDim2.new(1, 0, 0, top + rows * (ITEM_HEIGHT + 6) - 6 + PAD)
		end
	end

	local function refreshSummary()
		local issues = 0
		for _, item in ipairs(items) do
			if not item.ok then
				issues += 1
			end
		end
		if issues == 0 then
			summary.Text = config.okText or "Everything is running smoothly"
			summary.TextColor3 = Theme.color("muted")
		else
			summary.Text = issues == 1 and "1 item needs attention" or (issues .. " items need attention")
			summary.TextColor3 = Theme.color("warning")
		end
	end

	local function paintItem(item)
		item.icon.frame.Visible = item.ok
		item.alert.frame.Visible = not item.ok
		item.titleLabel.Text = item.title
		item.statusLabel.Text = item.status
		item.statusLabel.TextColor3 = Theme.color(item.ok and "success" or "warning")
	end

	local function addItem(spec)
		local holder = Ui.inst("Frame", {
			Name = tostring(spec.title),
			Size = UDim2.fromOffset(MIN_ITEM, ITEM_HEIGHT),
			BackgroundTransparency = 1,
			Parent = card,
		})
		local item = {
			frame = holder,
			title = tostring(spec.title or "Item"),
			status = tostring(spec.status or ""),
			ok = spec.ok ~= false,
		}
		item.icon = Ui.icon(holder, "circle-check", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(18, 18),
			token = "success",
		})
		item.alert = Ui.icon(holder, "circle-alert", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(18, 18),
			token = "warning",
		})
		item.titleLabel = Ui.label({
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(25, 2),
			Size = UDim2.new(1, -25, 0, 16),
			Parent = holder,
		})
		Theme.paint(item.titleLabel, "TextColor3", "text")
		item.statusLabel = Ui.label({
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(25, 19),
			Size = UDim2.new(1, -25, 0, 14),
			Parent = holder,
		})
		function item.width()
			local limit = Vector2.new(1000, 100)
			local titleWidth = TextService:GetTextSize(item.title, 12, Enum.Font.GothamMedium, limit).X
			local statusWidth = TextService:GetTextSize(item.status, 11, Enum.Font.Gotham, limit).X
			return 27 + math.max(titleWidth, statusWidth)
		end
		table.insert(items, item)
		paintItem(item)
		return item
	end

	for _, spec in ipairs(type(config.items) == "table" and config.items or {}) do
		if type(spec) == "table" then
			addItem(spec)
		end
	end
	refreshSummary()
	card:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	if chip then
		chip:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	end
	layout()

	Theme.onChange(function()
		if card.Parent then
			for _, item in ipairs(items) do
				paintItem(item)
			end
			refreshSummary()
		end
	end)

	local control = { type = "systemStatus" }
	function control:update(title, status, ok)
		title = tostring(title)
		local target
		for _, item in ipairs(items) do
			if item.title == title then
				target = item
				break
			end
		end
		if target then
			if status ~= nil then
				target.status = tostring(status)
			end
			if ok ~= nil then
				target.ok = ok ~= false
			end
			paintItem(target)
		else
			addItem({ title = title, status = status, ok = ok })
			layout()
		end
		refreshSummary()
	end
	function control:set() end
	function control:get()
		local states = {}
		for _, item in ipairs(items) do
			states[item.title] = { status = item.status, ok = item.ok }
		end
		return states
	end
	function control:encode() end
	return control
end

return SystemStatus
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
local Icons = require("Icons")
local Notify = require("Notify")
local Tab = require("Tab")
local Theme = require("Theme")
local Ui = require("Ui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Window = {}

local SIDEBAR_WIDTH = 176
local COMPACT_WIDTH = 60
local COMPACT_BELOW = 700
local HEADER_HEIGHT = 72
local TOP_HEIGHT = 40
local FOOTER_HEIGHT = 30
local AVATAR_HEIGHT = 66
local AVATAR_SIZE = 40

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
	local size = config.size or UDim2.fromOffset(1020, 640)
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

local function ago(timestamp)
	local seconds = math.max(0, os.time() - timestamp)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return (seconds // 60) .. " min ago"
	elseif seconds < 86400 then
		return (seconds // 3600) .. " h ago"
	end
	return (seconds // 86400) .. " d ago"
end

local function round(frame)
	Ui.inst("UICorner", {
		CornerRadius = UDim.new(0.5, 0),
		Parent = frame,
	})
end

local function avatarCard(sidebar)
	local player = Players.LocalPlayer
	local card = Ui.inst("Frame", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, AVATAR_HEIGHT),
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	Ui.glass(card, "row", 0.45, 0.72)
	Ui.corner(card, 12)

	local halo = Ui.inst("Frame", {
		Name = "Portrait",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE),
		BorderSizePixel = 0,
		Parent = card,
	})
	Theme.paint(halo, "BackgroundColor3", "window")
	round(halo)
	Ui.stroke(halo, "glow", 0.2, 2)
	local image = Ui.inst("ImageLabel", {
		Name = "Image",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = player and ("rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150") or "",
		Parent = halo,
	})
	round(image)

	local left = 12 + AVATAR_SIZE + 10
	local info = Ui.inst("Frame", {
		Name = "Info",
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(1, -(left + 8), 1, 0),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local name = Ui.label({
		Text = player and player.DisplayName or "Player",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = info,
	})
	Theme.paint(name, "TextColor3", "text")
	local handle = Ui.label({
		Text = player and ("@" .. player.Name) or "",
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = info,
	})
	Theme.paint(handle, "TextColor3", "muted")
	local dot = Ui.inst("Frame", {
		Name = "Online",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.fromOffset(7, 7),
		BorderSizePixel = 0,
		Parent = info,
	})
	round(dot)
	Theme.paint(dot, "BackgroundColor3", "success")
	local online = Ui.label({
		Text = "Online",
		TextSize = 11,
		Position = UDim2.fromOffset(12, 42),
		Size = UDim2.new(1, -12, 0, 14),
		Parent = info,
	})
	Theme.paint(online, "TextColor3", "muted")

	return function(compact)
		info.Visible = not compact
		if compact then
			halo.AnchorPoint = Vector2.new(0.5, 0.5)
			halo.Position = UDim2.fromScale(0.5, 0.5)
			card.Size = UDim2.new(1, -12, 0, AVATAR_HEIGHT)
		else
			halo.AnchorPoint = Vector2.new(0, 0.5)
			halo.Position = UDim2.new(0, 12, 0.5, 0)
			card.Size = UDim2.new(1, -20, 0, AVATAR_HEIGHT)
		end
	end
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

local function barButton(parent, iconName, order, hoverToken)
	local button = Ui.inst("TextButton", {
		Name = iconName,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	Ui.corner(button, 8)
	Theme.paint(button, "BackgroundColor3", hoverToken or "row")
	local icon = Ui.icon(button, iconName, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		token = "muted",
	})
	button.MouseEnter:Connect(function()
		Ui.tween(button, { BackgroundTransparency = hoverToken and 0.2 or 0.4 }, 0.12)
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(button, { BackgroundTransparency = 1 }, 0.12)
	end)
	return button, icon
end

function Window.create(config, version)
	config = config or {}
	if config.theme then
		Theme.set(config.theme)
	end
	if type(config.assetBase) == "string" and config.assetBase ~= "" then
		Icons.base = string.sub(config.assetBase, -1) == "/" and config.assetBase or (config.assetBase .. "/")
	end
	local minSize = asVector(config.minSize, Vector2.new(460, 320))
	local title = config.title or "TheX"

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
		Ui.corner(glow, 14)
		Ui.stroke(glow, "glow", layer[2], layer[1])
	end

	local frame = Ui.inst("Frame", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		ZIndex = 1,
		Parent = shell,
	})
	Ui.gradient(frame, "bar", "window", 90)
	Ui.corner(frame, 14)
	Ui.stroke(frame, "glow", 0.35, 1)

	local sidebar = Ui.inst("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame,
	})
	local backdrop = Ui.inst("Frame", {
		Name = "Backdrop",
		Size = UDim2.new(1, 16, 1, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	Ui.corner(backdrop, 14)
	Theme.paint(backdrop, "BackgroundColor3", "rail")
	local edge = Ui.inst("Frame", {
		Name = "Edge",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	Theme.paint(edge, "BackgroundColor3", "glow")

	local header = Ui.inst("TextButton", {
		Name = "Header",
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = sidebar,
	})
	local logo = Ui.icon(header, "logo", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
	})
	local brand = Ui.inst("Frame", {
		Name = "Brand",
		Position = UDim2.fromOffset(58, 0),
		Size = UDim2.new(1, -62, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	})
	local titleLabel = Ui.label({
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = brand,
	})
	Theme.paint(titleLabel, "TextColor3", "text")
	local subtitle = Ui.label({
		Text = config.subtitle or "",
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 39),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = brand,
	})
	Theme.paint(subtitle, "TextColor3", "muted")

	local showAvatar = config.showAvatar ~= false
	local rail = Ui.inst("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + (showAvatar and (AVATAR_HEIGHT + 20) or 0))),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	})
	Theme.paint(rail, "ScrollBarImageColor3", "accent")
	local railLayout = Ui.list(rail, 6)
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Ui.inst("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 8),
		Parent = rail,
	})
	local layoutAvatar = showAvatar and avatarCard(sidebar)

	local content = Ui.inst("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(SIDEBAR_WIDTH, 0),
		Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = frame,
	})
	local topBar = Ui.inst("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, TOP_HEIGHT),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local drag = Ui.inst("TextButton", {
		Name = "Drag",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -150, 1, 0),
		Parent = topBar,
	})
	local buttons = Ui.inst("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.new(0, 140, 1, 0),
		BackgroundTransparency = 1,
		Parent = topBar,
	})
	local buttonLayout = Ui.list(buttons, 4, Enum.FillDirection.Horizontal)
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local bell = barButton(buttons, "bell", 1)
	local minimize = barButton(buttons, "minus", 2)
	local maximize, growIcon = barButton(buttons, "square", 3)
	local shrinkIcon = Ui.icon(maximize, "copy", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(15, 15),
		token = "muted",
	})
	shrinkIcon.frame.Visible = false
	local close = barButton(buttons, "x", 4, "danger")

	local pages = Ui.inst("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(0, TOP_HEIGHT),
		Size = UDim2.new(1, 0, 1, -(TOP_HEIGHT + FOOTER_HEIGHT)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = content,
	})

	local footerConfig = type(config.footer) == "table" and config.footer or {}
	local footer = Ui.inst("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = content,
	})
	local footerLine = Ui.inst("Frame", {
		Name = "Line",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Parent = footer,
	})
	Theme.paint(footerLine, "BackgroundColor3", "glow")
	local footerLeft = Ui.label({
		Name = "Left",
		Text = footerConfig.left or string.format("%s Hub   v%s", title, tostring(version or "")),
		TextSize = 11,
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0.5, -16, 1, 0),
		Parent = footer,
	})
	Theme.paint(footerLeft, "TextColor3", "muted")
	local footerRight = Ui.label({
		Name = "Right",
		Text = footerConfig.right or 'Made with <font color="#FF4D6D">♥</font> for the community',
		TextSize = 11,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 0),
		Size = UDim2.new(0.5, -24, 1, 0),
		Parent = footer,
	})
	Theme.paint(footerRight, "TextColor3", "muted")

	local resize = grip(frame)

	local pill = Ui.inst("TextButton", {
		Name = "Restore",
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	})
	Ui.glass(pill, "bar", 0.08, 0.35)
	Ui.corner(pill, 18)
	Ui.inst("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 14),
		Parent = pill,
	})
	local pillLayout = Ui.list(pill, 8, Enum.FillDirection.Horizontal)
	pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	Ui.icon(pill, "logo", {
		Size = UDim2.fromOffset(20, 20),
		LayoutOrder = 1,
	})
	local pillLabel = Ui.label({
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = pill,
	})
	Theme.paint(pillLabel, "TextColor3", "text")

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
		compact = false,
		maximized = false,
		minimized = false,
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

	function window:setVisible(visible)
		if self.dead then
			return
		end
		self:closePopup()
		shell.Visible = visible == true
		pill.Visible = false
		self.minimized = false
	end

	function window:minimize()
		if self.dead then
			return
		end
		self:closePopup()
		shell.Visible = false
		pill.Visible = true
		self.minimized = true
	end

	local restore = nil
	function window:setMaximized(state)
		if self.dead or (state == true) == self.maximized then
			return
		end
		self:closePopup()
		self.maximized = state == true
		if self.maximized then
			restore = { anchor = shell.AnchorPoint, position = shell.Position, size = shell.Size }
			shell.AnchorPoint = Vector2.zero
			shell.Position = UDim2.new()
			shell.Size = UDim2.fromScale(1, 1)
		elseif restore then
			shell.AnchorPoint = restore.anchor
			shell.Position = restore.position
			shell.Size = restore.size
			restore = nil
		end
		resize.Visible = not self.maximized
		growIcon.frame.Visible = not self.maximized
		shrinkIcon.frame.Visible = self.maximized
	end

	function window:showNotifications()
		if self.dead then
			return
		end
		local width = 290
		local origin = gui.AbsolutePosition
		local anchor = bell.AbsolutePosition - origin
		local panel = Ui.inst("Frame", {
			Name = "Notifications",
			Position = UDim2.fromOffset(
				math.max(8, anchor.X + bell.AbsoluteSize.X - width),
				anchor.Y + bell.AbsoluteSize.Y + 6
			),
			Size = UDim2.fromOffset(width, 60),
			BorderSizePixel = 0,
		})
		Ui.panel(panel)
		local scroller = Ui.inst("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = panel,
		})
		Theme.paint(scroller, "ScrollBarImageColor3", "accent")
		Ui.padding(scroller, 10)
		local list = Ui.list(scroller, 6)

		Ui.sectionHeader(scroller, "bell", "Notifications", { LayoutOrder = 0, textSize = 14 })
		if #Notify.history == 0 then
			Ui.note(scroller, "No notifications yet.", 1)
		end
		for index, entry in ipairs(Notify.history) do
			local item = Ui.inst("Frame", {
				Name = "Entry",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Parent = scroller,
			})
			Ui.glass(item, "row", 0.4, 0.8)
			Ui.corner(item, 8)
			Ui.padding(item, 8)
			Ui.list(item, 2)
			local itemTitle = Ui.label({
				Text = entry.title,
				Font = Enum.Font.GothamMedium,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 1,
				Parent = item,
			})
			Theme.paint(itemTitle, "TextColor3", "text")
			if entry.content ~= "" then
				Ui.note(item, entry.content, 2)
			end
			local when = Ui.label({
				Text = ago(entry.time),
				TextSize = 10,
				Size = UDim2.new(1, 0, 0, 13),
				LayoutOrder = 3,
				Parent = item,
			})
			Theme.paint(when, "TextColor3", "accent")
		end

		local function fit()
			local maxHeight = math.max(120, gui.AbsoluteSize.Y - panel.Position.Y.Offset - 12)
			panel.Size = UDim2.fromOffset(width, math.min(list.AbsoluteContentSize.Y + 20, 380, maxHeight))
		end
		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
		self:showPopup(panel)
		fit()
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

	local laidOut = false
	local function layout()
		local width = frame.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local compact = width < COMPACT_BELOW
		if laidOut and compact == window.compact then
			return
		end
		laidOut = true
		window.compact = compact
		local railWidth = compact and COMPACT_WIDTH or SIDEBAR_WIDTH
		sidebar.Size = UDim2.new(0, railWidth, 1, 0)
		content.Position = UDim2.fromOffset(railWidth, 0)
		content.Size = UDim2.new(1, -railWidth, 1, 0)
		brand.Visible = not compact
		if compact then
			logo.frame.AnchorPoint = Vector2.new(0.5, 0.5)
			logo.frame.Position = UDim2.fromScale(0.5, 0.5)
		else
			logo.frame.AnchorPoint = Vector2.new(0, 0.5)
			logo.frame.Position = UDim2.new(0, 16, 0.5, 0)
		end
		if layoutAvatar then
			layoutAvatar(compact)
		end
		for _, tab in ipairs(window.tabs) do
			tab:layout(compact)
		end
	end
	window:connect(frame:GetPropertyChangedSignal("AbsoluteSize"), layout)
	layout()

	local toggleKey = asKey(config.toggleKey)
	local dragging = false
	local resizing = false
	local pressStart
	local startPos
	local startDims

	local function beginDrag(input)
		if not isPress(input) or window.maximized then
			return
		end
		dragging = true
		pressStart = input.Position
		startPos = shell.Position
	end
	drag.InputBegan:Connect(beginDrag)
	header.InputBegan:Connect(beginDrag)
	resize.InputBegan:Connect(function(input)
		if not isPress(input) or window.maximized then
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
			window:setVisible(not shell.Visible)
		end
	end)

	bell.MouseButton1Click:Connect(function()
		window:showNotifications()
	end)
	minimize.MouseButton1Click:Connect(function()
		window:minimize()
	end)
	maximize.MouseButton1Click:Connect(function()
		window:setMaximized(not window.maximized)
	end)
	pill.MouseButton1Click:Connect(function()
		window:setVisible(true)
	end)
	close.MouseButton1Click:Connect(function()
		window:destroy()
	end)

	return window
end

return Window
end

return require("")
