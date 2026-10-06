--============================================================
-- UTILITY PANEL V18 — SAKURA / SMOOTH NAV
-- LocalScript for your own Roblox game
-- Password: HUB UTILITY | Toggle: K
--
-- Rebuilt from V7 functionality with:
-- • Completely redesigned dashboard UI
-- • One runtime/state system
-- • Central cleanup and safe callbacks
-- • Responsive desktop/mobile layout
--============================================================

--============================================================
-- SERVICES
--============================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--============================================================
-- CONFIG
--============================================================
local CONFIG = {
	PASSWORD = "HUB UTILITY",
	TOGGLE_KEY = Enum.KeyCode.K,

	UI = {
		DesktopSize = Vector2.new(900, 590),
		MobileMin = Vector2.new(320, 400),
		MobileMax = Vector2.new(520, 760),
	},

	Colors = {
		Background = Color3.fromRGB(10, 13, 18),
		Panel = Color3.fromRGB(15, 19, 27),
		Panel2 = Color3.fromRGB(20, 25, 34),
		Card = Color3.fromRGB(24, 30, 41),
		CardHover = Color3.fromRGB(30, 37, 51),
		Border = Color3.fromRGB(48, 58, 76),
		Accent = Color3.fromRGB(91, 159, 255),
		Accent2 = Color3.fromRGB(53, 112, 224),
		Success = Color3.fromRGB(74, 211, 126),
		Warning = Color3.fromRGB(247, 184, 70),
		Danger = Color3.fromRGB(239, 86, 100),
		Text = Color3.fromRGB(242, 246, 252),
		Muted = Color3.fromRGB(145, 156, 174),
		Dark = Color3.fromRGB(8, 11, 16),
	},

	Defaults = {
		FlightSpeed = 55,
		WalkSpeed = 24,
		JumpPower = 60,
	},
}

--============================================================
-- RUNTIME
--============================================================
local unloadScript
local touchFlight

local Runtime = {
	destroyed = false,
	unlocked = false,
	panelOpen = false,
	currentPage = "",
	language = "EN",
	compact = false,
	pageTransitionToken = 0,
	selectedNavScale = {},
	device = "PC",

	connections = {},
	featureConnections = {},
	renderNames = {
		Flight = "UtilityV11_Flight",
		Noclip = "UtilityV11_Noclip",
		ESP = "UtilityV11_ESP",
	},

	settings = {
		walkSpeed = CONFIG.Defaults.WalkSpeed,
		jumpPower = CONFIG.Defaults.JumpPower,
		flightSpeed = CONFIG.Defaults.FlightSpeed,
		infiniteJump = false,
		noclip = false,
		antiAfk = true,
		flight = false,
		fullbright = false,
		removeFog = false,
		esp = false,
		autoRotate = true,
		accessoriesHidden = false,
		particlesHidden = false,
		cameraLock = false,
		gravity = nil,
		smoothAnimations = true,
		compactSidebar = false,
		showLauncher = true,
		fakeHeadless = false,
		fakeKorblox = false,
		platformStand = false,
		freezeSelf = false,
		hideBillboards = false,
		hideSurfaceUI = false,
		lowDetail = false,
		muteSounds = false,
		mouseIcon = true,
		selfHighlight = false,
		hideNameplate = false,
		localTransparency = false,
	},

	baseline = {
		walkSpeed = nil,
		jumpPower = nil,
		useJumpPower = nil,
		hipHeight = nil,
		autoRotate = nil,
		fov = nil,
		gravity = nil,
		lighting = {},
	},

	savedPosition = nil,
}

--============================================================
-- SAFE RUNTIME HELPERS
--============================================================
local function connect(signal, name, callback)
	local connection = signal:Connect(function(...)
		if Runtime.destroyed then
			return
		end

		local ok, err = xpcall(function(...)
			callback(...)
		end, debug.traceback, ...)

		if not ok then
			warn("[UtilityPanel V11][" .. tostring(name) .. "] " .. tostring(err))
		end
	end)

	table.insert(Runtime.connections, connection)
	return connection
end

local function bindFeature(name, signal, callback)
	if Runtime.featureConnections[name] then
		pcall(function()
			Runtime.featureConnections[name]:Disconnect()
		end)
	end

	local connection = signal:Connect(function(...)
		if Runtime.destroyed then
			return
		end

		local ok, err = xpcall(function(...)
			callback(...)
		end, debug.traceback, ...)

		if not ok then
			warn("[UtilityPanel V11][" .. tostring(name) .. "] " .. tostring(err))
		end
	end)

	Runtime.featureConnections[name] = connection
	return connection
end

local function unbindFeature(name)
	local connection = Runtime.featureConnections[name]
	if connection then
		pcall(function()
			connection:Disconnect()
		end)
		Runtime.featureConnections[name] = nil
	end
end

local function safeCall(label, callback, ...)
	local ok, result = xpcall(callback, debug.traceback, ...)
	if not ok then
		warn("[UtilityPanel V11][" .. tostring(label) .. "] " .. tostring(result))
		return false, result
	end
	return true, result
end

local function disconnectAll()
	for _, connection in ipairs(Runtime.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(Runtime.connections)

	for name in pairs(Runtime.featureConnections) do
		unbindFeature(name)
	end

	for _, renderName in pairs(Runtime.renderNames) do
		pcall(function()
			RunService:UnbindFromRenderStep(renderName)
		end)
	end
end

--============================================================
-- DEVICE / CHARACTER
--============================================================
local function getCamera()
	return Workspace.CurrentCamera
end

local function detectDevice()
	local camera = getCamera()
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)

	-- Prefer Roblox's own ten-foot interface signal for console/TV UI, then
	-- combine input capabilities with viewport size for touch devices.
	if GuiService:IsTenFootInterface() or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled) then
		Runtime.device = "Console"
	elseif UserInputService.TouchEnabled then
		local shortest = math.min(vp.X, vp.Y)
		Runtime.device = shortest <= 600 and "Mobile" or "Tablet"
	else
		Runtime.device = "PC"
	end

	return Runtime.device
end

local function getCharacter()
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	return character,
		character:FindFirstChildOfClass("Humanoid"),
		character:FindFirstChild("HumanoidRootPart")
end

local function captureBaseline()
	local _, humanoid = getCharacter()
	local camera = getCamera()

	if humanoid then
		Runtime.baseline.walkSpeed = humanoid.WalkSpeed
		Runtime.baseline.jumpPower = humanoid.JumpPower
		Runtime.baseline.useJumpPower = humanoid.UseJumpPower
		Runtime.baseline.hipHeight = humanoid.HipHeight
		Runtime.baseline.autoRotate = humanoid.AutoRotate
	end

	if camera then
		Runtime.baseline.fov = camera.FieldOfView
	end

	Runtime.baseline.gravity = Workspace.Gravity
	Runtime.baseline.lighting = {
		Brightness = Lighting.Brightness,
		ClockTime = Lighting.ClockTime,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		GlobalShadows = Lighting.GlobalShadows,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}
end

local function humanoid()
	local _, h = getCharacter()
	return h
end

local function rootPart()
	local _, _, root = getCharacter()
	return root
end

local function restoreBaselineMovement()
	local h = humanoid()
	if not h then return end

	if Runtime.baseline.walkSpeed ~= nil then
		h.WalkSpeed = Runtime.baseline.walkSpeed
	end
	if Runtime.baseline.jumpPower ~= nil then
		h.JumpPower = Runtime.baseline.jumpPower
	end
	if Runtime.baseline.useJumpPower ~= nil then
		h.UseJumpPower = Runtime.baseline.useJumpPower
	end
	if Runtime.baseline.hipHeight ~= nil then
		h.HipHeight = Runtime.baseline.hipHeight
	end
	if Runtime.baseline.autoRotate ~= nil then
		h.AutoRotate = Runtime.baseline.autoRotate
	end
end

--============================================================
-- UI HELPERS
--============================================================
--============================================================
-- LOCALIZATION
--============================================================
local pages = {}
local navButtons = {}
local navigation = {}
local launcher
local updateLayout
local languageRU
local languageEN
local statusPill
local passcode
local TRANSLATIONS = {
	RU = {
		["UTILITY HUB"] = "UTILITY HUB", ["Modern controls • smooth animations"] = "Современное управление • плавные анимации",
		["Enter the access code to open the panel"] = "Введите код доступа для открытия панели", ["Access code"] = "Код доступа", ["UNLOCK"] = "ОТКРЫТЬ", ["READY"] = "ГОТОВО", ["Incorrect access code."] = "Неверный код доступа.",
		["Dashboard"] = "Главная", ["Movement"] = "Движение", ["Flight"] = "Полёт", ["Teleport"] = "Телепорт",
		["Visuals"] = "Визуал", ["Character"] = "Персонаж", ["Camera"] = "Камера", ["Player"] = "Игрок",
		["Environment"] = "Окружение", ["Server"] = "Сервер", ["Interface"] = "Интерфейс", ["Presets"] = "Профили",
		["About"] = "О панели", ["Safety"] = "Безопасность",
		["Quick controls and live status"] = "Быстрые функции и состояние",
		["OVERVIEW"] = "ОБЗОР", ["PERFORMANCE"] = "ПРОИЗВОДИТЕЛЬНОСТЬ", ["STATUS"] = "СТАТУС", ["CHARACTER"] = "ПЕРСОНАЖ", ["DEVICE"] = "УСТРОЙСТВО", ["POSITION"] = "ПОЗИЦИЯ",
		["No character"] = "Нет персонажа", ["Not loaded"] = "Не загружен", ["Loading…"] = "Загрузка…", ["Detecting…"] = "Определение…",
		["Visual tools ready"] = "Визуальные функции готовы",

		["Speed, jump and movement settings"] = "Скорость, прыжок и настройки движения",
		["Controlled local flight system"] = "Управляемая система локального полёта",
		["Coordinate and utility teleports"] = "Телепорты по координатам и точки",
		["ESP and local visual tools"] = "ESP и локальные визуальные функции",
		["Position, accessories and character actions"] = "Позиция, аксессуары и действия персонажа",
		["FOV, zoom and camera modes"] = "FOV, зум и режимы камеры",
		["Quick player actions and server controls"] = "Быстрые действия игрока и сервер",
		["Time, lighting and physics"] = "Время, освещение и физика",
		["Server information and session actions"] = "Информация о сервере и действия сессии",
		["Interface, language and animation settings"] = "Интерфейс, язык и анимации",
		["One-tap control profiles"] = "Профили управления в одно нажатие",
		["Panel information and controls"] = "Информация о панели и управление",
		["One-click restore and diagnostics"] = "Восстановление и диагностика",
		["QUICK ACTIONS"] = "БЫСТРЫЕ ДЕЙСТВИЯ", ["LIVE"] = "СОСТОЯНИЕ", ["MOVEMENT MODIFIERS"] = "ДВИЖЕНИЕ", ["RESET"] = "СБРОС",
		["FLIGHT CONTROLLER"] = "УПРАВЛЕНИЕ ПОЛЁТОМ", ["COORDINATES"] = "КООРДИНАТЫ", ["VISUAL"] = "ВИЗУАЛ", ["CAMERA"] = "КАМЕРА",
		["POSITION"] = "ПОЗИЦИЯ", ["UTILITY"] = "ФУНКЦИИ", ["SERVER INFO"] = "ИНФОРМАЦИЯ О СЕРВЕРЕ", ["PLAYER STATUS"] = "СТАТУС ИГРОКА",
		["INTERFACE"] = "ИНТЕРФЕЙС", ["LANGUAGE"] = "ЯЗЫК", ["ANIMATIONS"] = "АНИМАЦИИ", ["LAYOUT"] = "РАЗМЕТКА",
		["ONE-TAP PROFILES"] = "ПРОФИЛИ", ["TIP"] = "СОВЕТ", ["UTILITY HUB"] = "UTILITY HUB", ["CONTROLS"] = "УПРАВЛЕНИЕ",
		["RESTORE"] = "ВОССТАНОВЛЕНИЕ", ["DIAGNOSTICS"] = "ДИАГНОСТИКА",
		["Walk Speed"] = "Скорость", ["Jump Power"] = "Сила прыжка", ["Flight Speed"] = "Скорость полёта", ["Field of View"] = "Поле зрения",
		["Brightness"] = "Яркость", ["Gravity"] = "Гравитация",
		["Infinite Jump"] = "Бесконечный прыжок", ["Noclip"] = "Ноклип", ["Anti-AFK"] = "Анти-AFK", ["Enable Flight"] = "Включить полёт",
		["Fullbright"] = "Полная яркость", ["Remove Fog"] = "Убрать туман", ["ESP Player Names"] = "Имена игроков ESP", ["Hide Particles"] = "Скрыть частицы",
		["Hide Accessories"] = "Скрыть аксессуары", ["Auto Rotate"] = "Автоповорот", ["Camera Lock"] = "Блокировка камеры",
		["Avatar"] = "Аватар", ["Avatar appearance and local avatar effects"] = "Внешность аватара и локальные эффекты",
		["FAKE AVATAR"] = "ФЕЙК-АВАТАР", ["Fake Headless"] = "Фейк Headless", ["Fake Korblox"] = "Фейк Korblox",
		["Fake Headless hides your head locally."] = "Фейк Headless скрывает голову только локально.", ["Fake Korblox hides the right leg locally."] = "Фейк Korblox скрывает правую ногу только локально.",
		["RESET AVATAR EFFECTS"] = "СБРОСИТЬ ЭФФЕКТЫ АВАТАРА", ["UNLOAD SCRIPT"] = "ВЫГРУЗИТЬ СКРИПТ",
		["Script unloaded."] = "Скрипт выгружен.", ["Avatar effects reset."] = "Эффекты аватара сброшены.",
		["Smooth Animations"] = "Плавные анимации", ["Compact Sidebar"] = "Компактная боковая панель", ["Show Floating Launcher"] = "Показывать плавающую кнопку",
		["Reset Everything"] = "Сбросить всё",
		["RESET MOVEMENT"] = "СБРОСИТЬ ДВИЖЕНИЕ", ["RESET CAMERA"] = "СБРОСИТЬ КАМЕРУ", ["SAVE POSITION"] = "СОХРАНИТЬ ПОЗИЦИЮ",
		["RESET CHARACTER"] = "СБРОСИТЬ ПЕРСОНАЖА", ["FULL SAFE RESET"] = "ПОЛНЫЙ БЕЗОПАСНЫЙ СБРОС",
		["SAVE CURRENT POSITION"] = "СОХРАНИТЬ ТЕКУЩУЮ ПОЗИЦИЮ", ["RETURN TO SAVED POSITION"] = "ВЕРНУТЬСЯ К СОХРАНЁННОЙ ПОЗИЦИИ",
		["STOP VELOCITY"] = "ОСТАНОВИТЬ СКОРОСТЬ", ["FACE CAMERA"] = "ПОВЕРНУТЬ К КАМЕРЕ", ["RESET CHARACTER MOTION"] = "СБРОСИТЬ ДВИЖЕНИЕ ПЕРСОНАЖА",
		["RESTORE SAVED MOVEMENT"] = "ВОССТАНОВИТЬ ДВИЖЕНИЕ", ["TELEPORT TO COORDINATES"] = "ТЕЛЕПОРТ ПО КООРДИНАТАМ",
		["MOVE UP +500"] = "ПОДНЯТЬСЯ +500", ["MOVE UP +1000"] = "ПОДНЯТЬСЯ +1000", ["HIGHEST SOLID PART"] = "НА ВЫСШУЮ ТОЧКУ",
		["RESET FOV"] = "СБРОСИТЬ FOV", ["FIRST PERSON"] = "ПЕРВОЕ ЛИЦО", ["THIRD PERSON"] = "ТРЕТЬЕ ЛИЦО", ["RESET ZOOM"] = "СБРОСИТЬ ЗУМ",
		["CUSTOM CAMERA"] = "ОБЫЧНАЯ КАМЕРА", ["SCRIPTABLE CAMERA"] = "УПРАВЛЯЕМАЯ КАМЕРА", ["SIT"] = "СЕСТЬ", ["STAND"] = "ВСТАТЬ",
		["REJOIN SERVER"] = "ПЕРЕЗАЙТИ НА СЕРВЕР", ["DAY"] = "ДЕНЬ", ["SUNSET"] = "ЗАКАТ", ["NIGHT"] = "НОЧЬ",
		["BRIGHTNESS DEFAULT"] = "ЯРКОСТЬ ПО УМОЛЧАНИЮ", ["SHADOWS ON"] = "ТЕНИ ВКЛ", ["SHADOWS OFF"] = "ТЕНИ ВЫКЛ",
		["GRAVITY DEFAULT"] = "ГРАВИТАЦИЯ ПО УМОЛЧАНИЮ", ["GRAVITY LOW"] = "НИЗКАЯ ГРАВИТАЦИЯ", ["GRAVITY NORMAL"] = "НОРМАЛЬНАЯ ГРАВИТАЦИЯ",
		["RESTORE MOVEMENT"] = "ВОССТАНОВИТЬ ДВИЖЕНИЕ", ["RESTORE CAMERA"] = "ВОССТАНОВИТЬ КАМЕРУ", ["RESTORE WORLD"] = "ВОССТАНОВИТЬ ОКРУЖЕНИЕ",
		["DEFAULT"] = "ПО УМОЛЧАНИЮ", ["SPEED"] = "СКОРОСТЬ", ["LOW GRAVITY"] = "НИЗКАЯ ГРАВИТАЦИЯ", ["BRIGHT"] = "ЯРКИЙ РЕЖИМ",
		["RESET EVERYTHING"] = "СБРОСИТЬ ВСЁ", ["RUSSIAN"] = "РУССКИЙ", ["ENGLISH"] = "АНГЛИЙСКИЙ", ["EXPAND"] = "РАЗВЕРНУТЬ",
		["VERSION"] = "ВЕРСИЯ", ["DEVICE"] = "УСТРОЙСТВО", ["PAGES"] = "ВКЛАДОК", ["RUNTIME"] = "РАБОТА",
		["STATUS"] = "СТАТУС", ["FPS"] = "FPS", ["Ready"] = "Готов", ["PLAYERS"] = "ИГРОКИ", ["PLACE ID"] = "ID МЕСТА", ["SERVER ID"] = "ID СЕРВЕРА", ["DEVICE"] = "УСТРОЙСТВО", ["CHARACTER"] = "ПЕРСОНАЖ", ["VELOCITY"] = "СКОРОСТЬ", ["PAGE"] = "ВКЛАДКА",
		["Refresh Server Info"] = "Обновить данные сервера",
		["Modern controls • smooth animations"] = "Современное управление • плавные анимации",
		["Stable local utility controls"] = "Стабильные локальные функции", ["Ready."] = "Готово.",
		["Visual tools ready"] = "Визуальные функции готовы", ["Healthy"] = "Исправно", ["Studio"] = "Студия",
		["The panel uses centralized connections and pcall/xpcall guards for feature callbacks."] = "Панель использует централизованные соединения и защиту обработчиков функций.",
		["Profiles are local and can be changed at any time. Use Default to return to the captured baseline."] = "Профили локальные. Используйте режим по умолчанию для возврата к исходным значениям.",
		["Keyboard: W/A/S/D to move • Space up • Left Ctrl down\nOn touch devices, use the virtual controls shown below."] = "W/A/S/D — движение • Space — вверх • Left Ctrl — вниз\nНа сенсорных устройствах используйте виртуальные кнопки.",
		["Tools"] = "Инструменты", ["Personal tools and character utilities"] = "Личные инструменты и функции персонажа",
		["HUD"] = "HUD", ["Core interface visibility controls"] = "Управление элементами интерфейса",
		["PostFX"] = "Эффекты", ["Local post-processing controls"] = "Локальное управление пост-эффектами",
		["Audio"] = "Звук", ["Local audio controls"] = "Локальное управление звуком",
		["Performance"] = "Производительность", ["Local visual optimizations"] = "Локальная оптимизация визуала",
		["Input"] = "Ввод", ["Mouse and input preferences"] = "Настройки мыши и ввода",
		["Appearance"] = "Оформление", ["Local character presentation"] = "Локальное оформление персонажа",
		["EXTRA TOOLS"] = "ДОПОЛНИТЕЛЬНЫЕ ИНСТРУМЕНТЫ", ["CORE HUD"] = "ОСНОВНОЙ HUD", ["POST PROCESSING"] = "ПОСТ-ЭФФЕКТЫ", ["AUDIO CONTROLS"] = "ЗВУК", ["OPTIMIZATION"] = "ОПТИМИЗАЦИЯ", ["INPUT SETTINGS"] = "ВВОД", ["CHARACTER PRESENTATION"] = "ОФОРМЛЕНИЕ ПЕРСОНАЖА",
		["Unequip All Tools"] = "Убрать все инструменты", ["Jump Now"] = "Прыгнуть сейчас", ["Reset Humanoid State"] = "Сбросить состояние", ["Platform Stand"] = "Platform Stand", ["Freeze Self"] = "Заморозить себя", ["Teleport to Spawn"] = "Телепорт на спавн", ["Face Spawn"] = "Повернуться к спавну", ["Restore Tool State"] = "Восстановить инструменты",
		["Hide Backpack"] = "Скрыть рюкзак", ["Hide Chat"] = "Скрыть чат", ["Hide Player List"] = "Скрыть список игроков", ["Hide Emotes"] = "Скрыть эмоции", ["Hide Topbar"] = "Скрыть верхнюю панель", ["Restore Core HUD"] = "Восстановить HUD",
		["Disable Bloom"] = "Отключить Bloom", ["Disable Color Correction"] = "Отключить Color Correction", ["Disable Sun Rays"] = "Отключить Sun Rays", ["Disable Depth Of Field"] = "Отключить Depth Of Field", ["Disable Atmosphere"] = "Отключить Atmosphere", ["Restore Post Effects"] = "Восстановить эффекты",
		["Master Volume"] = "Громкость", ["Mute Game Sounds"] = "Заглушить звук игры", ["Restore Sound"] = "Восстановить звук",
		["Hide Billboards"] = "Скрыть BillboardGui", ["Hide Surface UI"] = "Скрыть SurfaceGui", ["Low Detail Mode"] = "Режим низкой детализации", ["Local Shadows Off"] = "Выключить локальные тени", ["Restore Visual Quality"] = "Восстановить качество",
		["Mouse Icon"] = "Курсор мыши", ["Reset Input Preferences"] = "Сбросить ввод",
		["Self Highlight"] = "Подсветка себя", ["Hide Nameplate"] = "Скрыть имя над головой", ["Local Transparency"] = "Сделать персонажа прозрачнее", ["Restore Character Look"] = "Восстановить вид персонажа", ["Refresh Appearance"] = "Обновить оформление",
		["ON"] = "ВКЛ", ["OFF"] = "ВЫКЛ", ["Tools unequipped."] = "Инструменты убраны.", ["Humanoid state reset."] = "Состояние сброшено.", ["Teleported to spawn."] = "Телепортировано на спавн.", ["Spawn not found."] = "Спавн не найден.",
	},
}

local TEXT_REFS = {}
local function tr(key)
	if Runtime.language == "RU" then
		return TRANSLATIONS.RU[key] or key
	end
	return key
end

local function registerText(object, key)
	if not object then return object end
	object:SetAttribute("I18NKey", key)
	table.insert(TEXT_REFS, object)
	return object
end

local languageOverlay, languageCard, languageMessage, languageBar, languageBarFill, languageTitle
local languageApplyToken = 0

local function showLanguageApplying()
	if not languageOverlay or not languageOverlay.Parent then return end
	languageApplyToken += 1
	local token = languageApplyToken
	languageTitle.Text = Runtime.language == "RU" and "Применение языка" or "Applying language"
	languageMessage.Text = Runtime.language == "RU" and "Пожалуйста, подождите…" or "Please wait…"
	languageOverlay.Visible = true
	languageOverlay.BackgroundTransparency = 0.55
	languageCard.Position = UDim2.fromScale(0.5, 0.5)
	languageBarFill.Size = UDim2.new(0, 0, 1, 0)
	-- Use a simple timed fill. No TweenService dependency and no stacked tweens.
	task.spawn(function()
		local started = os.clock()
		local duration = 5
		while not Runtime.destroyed and languageOverlay.Parent and languageApplyToken == token do
			local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
			languageBarFill.Size = UDim2.new(alpha, 0, 1, 0)
			if alpha >= 1 then break end
			task.wait(0.05)
		end
		if Runtime.destroyed or languageApplyToken ~= token or not languageOverlay.Parent then return end
		languageBarFill.Size = UDim2.new(1, 0, 1, 0)
		languageOverlay.Visible = false
		launcher.Visible = Runtime.settings.showLauncher
		if Runtime.unlocked then
			Runtime.panelOpen = true
			main.Visible = true
			launcher.Visible = false
		end
	end)
end

local function applyLanguage()
	for _, object in ipairs(TEXT_REFS) do
		if object and object.Parent then
			local key = object:GetAttribute("I18NKey")
			local navIcon = object:GetAttribute("NavIcon")
			local buttonIcon = object:GetAttribute("ButtonIcon")
			if key then
				if navIcon then
					object.Text = Runtime.compact and navIcon or (navIcon .. "   " .. tr(key))
				elseif buttonIcon then
					object.Text = buttonIcon .. "  " .. tr(key)
				else
					object.Text = tr(key)
				end
			end
		end
	end

	if passcode and passcode.Parent then
		passcode.PlaceholderText = tr("Access code")
	end

	if statusPill then
		statusPill.Text = "🟢  " .. tr("READY")
	end
	if languageRU and languageEN then
		languageRU.BackgroundColor3 = Runtime.language == "RU" and CONFIG.Colors.Accent2 or CONFIG.Colors.Card
		languageEN.BackgroundColor3 = Runtime.language == "EN" and CONFIG.Colors.Accent2 or CONFIG.Colors.Card
		languageRU.TextColor3 = Runtime.language == "RU" and CONFIG.Colors.Text or CONFIG.Colors.Muted
		languageEN.TextColor3 = Runtime.language == "EN" and CONFIG.Colors.Text or CONFIG.Colors.Muted
	end

	for _, item in ipairs(navigation or {}) do
		local btn = navButtons and navButtons[item[1]]
		if btn then
			btn.Text = Runtime.compact and item[2] or (item[2] .. "   " .. tr(item[1]))
		end
	end
end

local function corner(object, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = object
	return c
end

local function stroke(object, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or CONFIG.Colors.Border
	s.Thickness = thickness or 1
	s.Transparency = transparency == nil and 0.2 or transparency
	s.Parent = object
	return s
end

local function padding(object, left, right, top, bottom)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, left or 10)
	p.PaddingRight = UDim.new(0, right or 10)
	p.PaddingTop = UDim.new(0, top or 10)
	p.PaddingBottom = UDim.new(0, bottom or 10)
	p.Parent = object
	return p
end

local function list(object, gap, direction)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = direction or Enum.FillDirection.Vertical
	l.Parent = object
	return l
end

local function gradient(object, a, b, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = object
	return g
end

local function tween(object, duration, goal, style, direction)
	if not object or not object.Parent then
		return nil
	end

	local info = TweenInfo.new(
		(Runtime.settings.smoothAnimations and (duration or 0.22) or 0.08),
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)

	local animation = TweenService:Create(object, info, goal)
	animation:Play()
	return animation
end

local function setVisible(object, visible)
	if object then
		object.Visible = visible
	end
end

local function addPress(button)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	connect(button.InputBegan, "ButtonPress", function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			tween(scale, 0.06, {Scale = 0.96})
		end
	end)

	connect(button.InputEnded, "ButtonRelease", function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			tween(scale, 0.14, {Scale = 1}, Enum.EasingStyle.Back)
		end
	end)
end

--============================================================
-- GUI ROOT
--============================================================
pcall(function()
	local old = playerGui:FindFirstChild("UtilityPanelV11")
	if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "UtilityPanelV11"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10000
gui.IgnoreGuiInset = false
gui.Parent = playerGui

--============================================================
-- TOASTS
--============================================================
local toastHolder = Instance.new("Frame")
toastHolder.AnchorPoint = Vector2.new(1, 0)
toastHolder.Position = UDim2.new(1, -18, 0, 18)
toastHolder.Size = UDim2.new(0, 310, 1, -36)
toastHolder.BackgroundTransparency = 1
toastHolder.ZIndex = 500
toastHolder.Parent = gui

local toastLayout = list(toastHolder, 8)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

local function toast(title, message, tone, duration)
	if Runtime.destroyed then return end

	local accent = CONFIG.Colors.Accent
	if tone == "success" then accent = CONFIG.Colors.Success end
	if tone == "warn" then accent = CONFIG.Colors.Warning end
	if tone == "error" then accent = CONFIG.Colors.Danger end

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 66)
	card.BackgroundColor3 = CONFIG.Colors.Card
	card.BackgroundTransparency = 0.04
	card.ZIndex = 501
	card.Parent = toastHolder
	corner(card, 12)
	stroke(card, accent, 1.2, 0.3)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 4, 1, -18)
	bar.Position = UDim2.new(0, 8, 0, 9)
	bar.BackgroundColor3 = accent
	bar.ZIndex = 502
	bar.Parent = card
	corner(bar, 2)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -38, 0, 20)
	titleLabel.Position = UDim2.new(0, 20, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = tostring(title)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextColor3 = CONFIG.Colors.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 502
	titleLabel.Parent = card

	local msgLabel = Instance.new("TextLabel")
	msgLabel.Size = UDim2.new(1, -38, 0, 30)
	msgLabel.Position = UDim2.new(0, 20, 0, 28)
	msgLabel.BackgroundTransparency = 1
	msgLabel.Text = tostring(message)
	msgLabel.Font = Enum.Font.Gotham
	msgLabel.TextSize = 11
	msgLabel.TextColor3 = CONFIG.Colors.Muted
	msgLabel.TextWrapped = true
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.ZIndex = 502
	msgLabel.Parent = card

	task.delay(duration or 2.8, function()
		if not card.Parent then return end
		tween(card, 0.2, {BackgroundTransparency = 1})
		task.wait(0.2)
		if card.Parent then card:Destroy() end
	end)
end

--============================================================
-- LOCK SCREEN
--============================================================
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting

local lockOverlay = Instance.new("Frame")
lockOverlay.Size = UDim2.fromScale(1, 1)
lockOverlay.BackgroundColor3 = Color3.fromRGB(4, 6, 10)
lockOverlay.BackgroundTransparency = 0.2
lockOverlay.Visible = false
lockOverlay.ZIndex = 900
lockOverlay.Parent = gui

local lockCard = Instance.new("Frame")
lockCard.AnchorPoint = Vector2.new(0.5, 0.5)
lockCard.Position = UDim2.fromScale(0.5, 0.52)
lockCard.Size = UDim2.new(0.88, 0, 0, 300)
lockCard.BackgroundColor3 = CONFIG.Colors.Panel
lockCard.ZIndex = 901
lockCard.Parent = lockOverlay
corner(lockCard, 18)
stroke(lockCard, CONFIG.Colors.Border, 1.5, 0.05)

local lockLimit = Instance.new("UISizeConstraint")
lockLimit.MinSize = Vector2.new(300, 300)
lockLimit.MaxSize = Vector2.new(390, 300)
lockLimit.Parent = lockCard

local lockAccent = Instance.new("Frame")
lockAccent.Size = UDim2.new(1, 0, 0, 5)
lockAccent.BackgroundColor3 = CONFIG.Colors.Accent
lockAccent.BorderSizePixel = 0
lockAccent.ZIndex = 902
lockAccent.Parent = lockCard
corner(lockAccent, 18)
gradient(lockAccent, CONFIG.Colors.Accent, CONFIG.Colors.Success, 0)

local lockTitle = Instance.new("TextLabel")
lockTitle.Size = UDim2.new(1, -40, 0, 32)
lockTitle.Position = UDim2.new(0, 20, 0, 30)
lockTitle.BackgroundTransparency = 1
registerText(lockTitle, "UTILITY HUB")
lockTitle.Text = tr("UTILITY HUB")
lockTitle.Font = Enum.Font.GothamBold
lockTitle.TextSize = 24
lockTitle.TextColor3 = CONFIG.Colors.Text
lockTitle.Parent = lockCard

local lockSub = Instance.new("TextLabel")
lockSub.Size = UDim2.new(1, -40, 0, 24)
lockSub.Position = UDim2.new(0, 20, 0, 64)
lockSub.BackgroundTransparency = 1
registerText(lockSub, "Enter the access code to open the panel")
lockSub.Text = tr("Enter the access code to open the panel")
lockSub.Font = Enum.Font.Gotham
lockSub.TextSize = 12
lockSub.TextColor3 = CONFIG.Colors.Muted
lockSub.Parent = lockCard

passcode = Instance.new("TextBox")
passcode.Size = UDim2.new(1, -48, 0, 48)
passcode.Position = UDim2.new(0, 24, 0, 102)
passcode.BackgroundColor3 = CONFIG.Colors.Card
passcode.Text = ""
passcode:SetAttribute("PlaceholderI18NKey", "Access code")
passcode.PlaceholderText = tr("Access code")
passcode.ClearTextOnFocus = false
passcode.Font = Enum.Font.GothamBold
passcode.TextSize = 18
passcode.TextColor3 = CONFIG.Colors.Text
passcode.PlaceholderColor3 = CONFIG.Colors.Muted
passcode.ZIndex = 902
passcode.Parent = lockCard
corner(passcode, 10)
stroke(passcode, CONFIG.Colors.Border, 1, 0.15)

local passError = Instance.new("TextLabel")
passError.Size = UDim2.new(1, -48, 0, 20)
passError.Position = UDim2.new(0, 24, 0, 154)
passError.BackgroundTransparency = 1
passError.Text = ""
passError.Font = Enum.Font.Gotham
passError.TextSize = 11
passError.TextColor3 = CONFIG.Colors.Danger
passError.TextXAlignment = Enum.TextXAlignment.Left
passError.Parent = lockCard

local unlock = Instance.new("TextButton")
unlock.Size = UDim2.new(1, -48, 0, 46)
unlock.Position = UDim2.new(0, 24, 1, -68)
unlock.BackgroundColor3 = CONFIG.Colors.Accent2
registerText(unlock, "UNLOCK")
unlock.Text = tr("UNLOCK")
unlock.Font = Enum.Font.GothamBold
unlock.TextSize = 14
unlock.TextColor3 = Color3.fromRGB(255, 255, 255)
unlock.Parent = lockCard
corner(unlock, 10)
gradient(unlock, CONFIG.Colors.Accent, CONFIG.Colors.Accent2, 90)
addPress(unlock)

--============================================================
-- MAIN WINDOW
--============================================================
local main = Instance.new("Frame")
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromScale(0.8, 0.82)
main.BackgroundColor3 = CONFIG.Colors.Panel
main.Visible = false
main.ZIndex = 100
main.Parent = gui
corner(main, 18)
stroke(main, CONFIG.Colors.Border, 1.4, 0.05)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = CONFIG.UI.MobileMin
sizeConstraint.MaxSize = CONFIG.UI.DesktopSize
sizeConstraint.Parent = main

local mainScale = Instance.new("UIScale")
mainScale.Scale = 1
mainScale.Parent = main

--============================================================
-- HEADER
--============================================================
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 64)
header.BackgroundTransparency = 1
header.ZIndex = 101
header.Parent = main

local headerTitle = Instance.new("TextLabel")
headerTitle.Position = UDim2.new(0, 20, 0, 11)
headerTitle.Size = UDim2.new(0, 320, 0, 26)
headerTitle.BackgroundTransparency = 1
registerText(headerTitle, "UTILITY HUB")
headerTitle.Text = tr("UTILITY HUB")
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 21
headerTitle.TextColor3 = CONFIG.Colors.Text
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.ZIndex = 102
headerTitle.Parent = header

local headerSub = Instance.new("TextLabel")
headerSub.Position = UDim2.new(0, 20, 0, 37)
headerSub.Size = UDim2.new(0, 360, 0, 18)
headerSub.BackgroundTransparency = 1
registerText(headerSub, "Modern controls • smooth animations")
headerSub.Text = tr("Modern controls • smooth animations")
headerSub.Font = Enum.Font.Gotham
headerSub.TextSize = 11
headerSub.TextColor3 = CONFIG.Colors.Muted
headerSub.TextXAlignment = Enum.TextXAlignment.Left
headerSub.ZIndex = 102
headerSub.Parent = header

statusPill = Instance.new("TextLabel")
statusPill.AnchorPoint = Vector2.new(1, 0)
statusPill.Position = UDim2.new(1, -286, 0, 16)
statusPill.Size = UDim2.new(0, 110, 0, 28)
statusPill.BackgroundColor3 = CONFIG.Colors.Card
statusPill.Text = "🟢  " .. tr("READY")
statusPill.Font = Enum.Font.GothamBold
statusPill.TextSize = 10
statusPill.TextColor3 = CONFIG.Colors.Success
statusPill.Parent = header
corner(statusPill, 14)
stroke(statusPill, CONFIG.Colors.Success, 1, 0.55)

languageRU = Instance.new("TextButton")
languageRU.Size = UDim2.new(0, 38, 0, 28)
languageRU.Position = UDim2.new(1, -138, 0, 16)
languageRU.BackgroundColor3 = CONFIG.Colors.Card
languageRU.Text = "RU"
languageRU.Font = Enum.Font.GothamBold
languageRU.TextSize = 10
languageRU.TextColor3 = CONFIG.Colors.Muted
languageRU.AutoButtonColor = false
languageRU.Parent = header
corner(languageRU, 9)
stroke(languageRU, CONFIG.Colors.Border, 1, 0.35)

languageEN = Instance.new("TextButton")
languageEN.Size = UDim2.new(0, 38, 0, 28)
languageEN.Position = UDim2.new(1, -96, 0, 16)
languageEN.BackgroundColor3 = CONFIG.Colors.Card
languageEN.Text = "EN"
languageEN.Font = Enum.Font.GothamBold
languageEN.TextSize = 10
languageEN.TextColor3 = CONFIG.Colors.Text
languageEN.AutoButtonColor = false
languageEN.Parent = header
corner(languageEN, 9)
stroke(languageEN, CONFIG.Colors.Accent, 1, 0.25)

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 13)
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.BackgroundColor3 = CONFIG.Colors.Card
closeButton.Text = "×"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.TextColor3 = CONFIG.Colors.Muted
closeButton.ZIndex = 103
closeButton.Parent = header
corner(closeButton, 9)
addPress(closeButton)

--============================================================
-- NAV + CONTENT
--============================================================
local nav = Instance.new("ScrollingFrame")
nav.Position = UDim2.new(0, 12, 0, 74)
nav.Size = UDim2.new(0, 176, 1, -86)
nav.BackgroundColor3 = CONFIG.Colors.Dark
nav.ZIndex = 101
nav.Parent = main
nav.BorderSizePixel = 0
nav.ScrollBarThickness = 4
nav.ScrollBarImageColor3 = CONFIG.Colors.Accent
nav.ScrollBarImageTransparency = 0.2
nav.ScrollingDirection = Enum.ScrollingDirection.Y
nav.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
nav.CanvasSize = UDim2.new(0, 0, 0, 0)
nav.AutomaticCanvasSize = Enum.AutomaticSize.Y
corner(nav, 14)
stroke(nav, CONFIG.Colors.Border, 1, 0.2)
padding(nav, 10, 10, 10, 10)

-- Fixed fade masks stay over the viewport while the navigation list scrolls.
local navTopFade = Instance.new("Frame")
navTopFade.Name = "TopFade"
navTopFade.BackgroundColor3 = CONFIG.Colors.Dark
navTopFade.BorderSizePixel = 0
navTopFade.ZIndex = 120
navTopFade.Active = false
navTopFade.Parent = main
local topGradient = Instance.new("UIGradient")
topGradient.Rotation = 90
topGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.02), NumberSequenceKeypoint.new(0.7, 0.34), NumberSequenceKeypoint.new(1, 1),
})
topGradient.Parent = navTopFade

local navBottomFade = Instance.new("Frame")
navBottomFade.Name = "BottomFade"
navBottomFade.BackgroundColor3 = CONFIG.Colors.Dark
navBottomFade.BorderSizePixel = 0
navBottomFade.ZIndex = 120
navBottomFade.Active = false
navBottomFade.Parent = main
local bottomGradient = Instance.new("UIGradient")
bottomGradient.Rotation = 270
bottomGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.02), NumberSequenceKeypoint.new(0.7, 0.34), NumberSequenceKeypoint.new(1, 1),
})
bottomGradient.Parent = navBottomFade

local function updateNavFadeLayout()
    navTopFade.Position = nav.Position
    navTopFade.Size = UDim2.new(nav.Size.X.Scale, nav.Size.X.Offset, 0, 30)
    navBottomFade.Position = UDim2.new(nav.Position.X.Scale, nav.Position.X.Offset, nav.Position.Y.Scale, nav.Position.Y.Offset + nav.Size.Y.Offset - 30)
    navBottomFade.Size = UDim2.new(nav.Size.X.Scale, nav.Size.X.Offset, 0, 30)
end

local function updateNavScales()
    if Runtime.destroyed or not nav.Parent then return end
    local center = nav.AbsolutePosition.Y + nav.AbsoluteSize.Y * 0.5
    local half = math.max(nav.AbsoluteSize.Y * 0.58, 1)
    for key, btn in pairs(navButtons) do
        if btn and btn.Parent then
            local scaleObject = btn:FindFirstChild("NavScale")
            if scaleObject then
                local btnCenter = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y * 0.5
                local distance = math.clamp(math.abs(btnCenter - center) / half, 0, 1)
                scaleObject.Scale = 1.08 - (distance * 0.16)
            end
        end
    end
end

connect(nav:GetPropertyChangedSignal("CanvasPosition"), "NavScrollScale", updateNavScales)
connect(navList:GetPropertyChangedSignal("AbsoluteContentSize"), "NavContentScale", updateNavScales)

local content = Instance.new("Frame")
content.Position = UDim2.new(0, 198, 0, 74)
content.Size = UDim2.new(1, -210, 1, -86)
content.BackgroundColor3 = CONFIG.Colors.Dark
content.ZIndex = 101
content.Parent = main
corner(content, 14)
stroke(content, CONFIG.Colors.Border, 1, 0.2)

local contentPadding = padding(content, 14, 14, 14, 14)

local function createPage(key, title, subtitle)
	local page = Instance.new("ScrollingFrame")
	page.Name = key
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = CONFIG.Colors.Accent
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Visible = false
	page.Position = UDim2.new(0, 0, 0, 0)
	page.ZIndex = 102
	page.Parent = content

	local pageScale = Instance.new("UIScale")
	pageScale.Scale = 1
	pageScale.Parent = page
	page:SetAttribute("PageScaleReady", true)

	padding(page, 4, 6, 2, 8)
	local pageList = list(page, 10)
	pageList.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 26)
	titleLabel.BackgroundTransparency = 1
	registerText(titleLabel, title)
	titleLabel.Text = tr(title)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 17
	titleLabel.TextColor3 = CONFIG.Colors.Text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = page

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Size = UDim2.new(1, 0, 0, 18)
	subtitleLabel.BackgroundTransparency = 1
	registerText(subtitleLabel, subtitle)
	subtitleLabel.Text = tr(subtitle)
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextSize = 11
	subtitleLabel.TextColor3 = CONFIG.Colors.Muted
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = page

	pages[key] = page
	return page
end

local function navButton(key, title, icon, order)
	local button = Instance.new("TextButton")
	button.Name = key .. "Nav"
	button.Size = UDim2.new(1, -2, 0, 40)
	button.LayoutOrder = order
	button.BackgroundColor3 = CONFIG.Colors.Dark
	button:SetAttribute("NavTitle", title)
	button:SetAttribute("NavIcon", icon)
	registerText(button, title)
	button.Text = icon .. "   " .. tr(title)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = CONFIG.Colors.Muted
	button.TextXAlignment = Enum.TextXAlignment.Left
	button.AutoButtonColor = false
	button.Parent = nav
	corner(button, 9)
	local navScale = Instance.new("UIScale")
	navScale.Name = "NavScale"
	navScale.Scale = 1
	navScale.Parent = button

	navButtons[key] = button
	return button
end

--============================================================
-- CONTROLS
--============================================================
local function section(page, text)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	registerText(label, text)
	label.Text = tr(text)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	label.TextColor3 = CONFIG.Colors.Accent
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = page
	return label
end

local function infoCard(page, title, value, accent)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 58)
	card.BackgroundColor3 = CONFIG.Colors.Card
	card.Parent = page
	corner(card, 10)
	stroke(card, accent or CONFIG.Colors.Border, 1, 0.35)

	local t = Instance.new("TextLabel")
	t.Position = UDim2.new(0, 12, 0, 8)
	t.Size = UDim2.new(1, -24, 0, 16)
	t.BackgroundTransparency = 1
	registerText(t, title)
	t.Text = tr(title)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 10
	t.TextColor3 = CONFIG.Colors.Muted
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = card

	local v = Instance.new("TextLabel")
	v.Position = UDim2.new(0, 12, 0, 24)
	v.Size = UDim2.new(1, -24, 0, 24)
	v.BackgroundTransparency = 1
	v.Text = value
	v.Font = Enum.Font.GothamBold
	v.TextSize = 16
	v.TextColor3 = CONFIG.Colors.Text
	v.TextXAlignment = Enum.TextXAlignment.Left
	v.Parent = card

	return v
end


local BUTTON_ICONS_V18 = {
    ["Unequip All Tools"] = "🧰", ["Jump Now"] = "🦘", ["Reset Humanoid State"] = "🔄", ["Teleport to Spawn"] = "🏠", ["Face Spawn"] = "🧭", ["Restore Tool State"] = "♻️",
    ["Hide Backpack"] = "🎒", ["Hide Chat"] = "💬", ["Hide Player List"] = "👥", ["Hide Emotes"] = "😊", ["Hide Topbar"] = "📶", ["Restore Core HUD"] = "🖥️",
    ["Disable Bloom"] = "✨", ["Disable Color Correction"] = "🎨", ["Disable Sun Rays"] = "☀️", ["Disable Depth Of Field"] = "🔎", ["Disable Atmosphere"] = "🌫️", ["Restore Post Effects"] = "♻️",
    ["Mute Game Sounds"] = "🔇", ["Restore Sound"] = "🔊", ["Hide Billboards"] = "🏷️", ["Hide Surface UI"] = "🪟", ["Low Detail Mode"] = "⚡", ["Local Shadows Off"] = "🌑", ["Restore Visual Quality"] = "🌟",
    ["Reset Input Preferences"] = "🎮", ["Self Highlight"] = "💠", ["Hide Nameplate"] = "🙈", ["Local Transparency"] = "👻", ["Restore Character Look"] = "🧑‍🎨", ["Refresh Appearance"] = "🔃",
}

local BUTTON_ICONS = {
	["RESET MOVEMENT"] = "🔄", ["RESET CAMERA"] = "📷", ["SAVE POSITION"] = "💾", ["FULL SAFE RESET"] = "🧹",
	["RESTORE SAVED MOVEMENT"] = "↩️", ["TELEPORT TO COORDINATES"] = "📍", ["MOVE UP +500"] = "⬆️", ["MOVE UP +1000"] = "🚀",
	["HIGHEST SOLID PART"] = "🗼", ["RESET FOV"] = "🎯", ["SAVE CURRENT POSITION"] = "💾", ["RETURN TO SAVED POSITION"] = "📍",
	["STOP VELOCITY"] = "🛑", ["FACE CAMERA"] = "👀", ["RESET CHARACTER MOTION"] = "🔄", ["GRAVITY DEFAULT"] = "⚖️",
	["GRAVITY LOW"] = "🪶", ["GRAVITY NORMAL"] = "🌐", ["DAY"] = "☀️", ["NIGHT"] = "🌙", ["SUNSET"] = "🌇",
	["BRIGHTNESS DEFAULT"] = "💡", ["SHADOWS ON"] = "🌑", ["SHADOWS OFF"] = "🔆", ["CUSTOM CAMERA"] = "📷", ["SCRIPTABLE CAMERA"] = "🎥",
	["RESTORE MOVEMENT"] = "↩️", ["REJOIN SERVER"] = "🔁", ["RESET CHARACTER"] = "♻️", ["SIT"] = "🪑", ["STAND"] = "🧍",
	["FIRST PERSON"] = "👁️", ["THIRD PERSON"] = "👤", ["RESET ZOOM"] = "🔎", ["DEFAULT"] = "🏠", ["SPEED"] = "⚡",
	["LOW GRAVITY"] = "🪶", ["BRIGHT"] = "☀️", ["RESET EVERYTHING"] = "🧹", ["REFRESH CHARACTER"] = "🔃", ["REFRESH SERVER INFO"] = "🔄",
	["RUSSIAN"] = "🇷🇺", ["ENGLISH"] = "🇬🇧", ["SMOOTH ANIMATIONS"] = "🎞️", ["COMPACT SIDEBAR"] = "📐", ["SHOW FLOATING LAUNCHER"] = "🚀",
	["UNLOAD SCRIPT"] = "📤", ["FULL SAFE RESET"] = "🛡️",
}

local function button(page, text, callback, tone)
	local color = CONFIG.Colors.Accent2
	if tone == "success" then color = CONFIG.Colors.Success end
	if tone == "warn" then color = CONFIG.Colors.Warning end
	if tone == "danger" then color = CONFIG.Colors.Danger end

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 42)
	b.BackgroundColor3 = CONFIG.Colors.Card
	local icon = BUTTON_ICONS_V18[text] or BUTTON_ICONS[text] or "✨"
	registerText(b, text)
	b:SetAttribute("ButtonIcon", icon)
	b.Text = icon .. "  " .. tr(text)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = CONFIG.Colors.Text
	b.AutoButtonColor = false
	b.Parent = page
	corner(b, 10)
	stroke(b, color, 1, 0.45)
	addPress(b)

	connect(b.MouseEnter, "ButtonHover", function()
		tween(b, 0.12, {BackgroundColor3 = CONFIG.Colors.CardHover})
	end)

	connect(b.MouseLeave, "ButtonLeave", function()
		tween(b, 0.12, {BackgroundColor3 = CONFIG.Colors.Card})
	end)

	connect(b.Activated, "ButtonActivate", function()
		safeCall(text, callback)
	end)

	return b
end

local function toggle(page, title, defaultValue, callback)
	local state = defaultValue

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 46)
	card.BackgroundColor3 = CONFIG.Colors.Card
	card.Parent = page
	corner(card, 10)
	stroke(card, CONFIG.Colors.Border, 1, 0.35)

	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 12, 0, 0)
	label.Size = UDim2.new(1, -86, 1, 0)
	label.BackgroundTransparency = 1
	registerText(label, title)
	label.Text = tr(title)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = CONFIG.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = card

	local switch = Instance.new("TextButton")
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.new(1, -10, 0.5, 0)
	switch.Size = UDim2.new(0, 52, 0, 26)
	switch.BackgroundColor3 = state and CONFIG.Colors.Success or CONFIG.Colors.Dark
	switch.Text = state and "🟢" or "⚪"
	switch.Font = Enum.Font.GothamBold
	switch.TextSize = 9
	switch.TextColor3 = Color3.fromRGB(255, 255, 255)
	switch.AutoButtonColor = false
	switch.Parent = card
	corner(switch, 13)
	addPress(switch)

	local function render(newState)
		state = newState
		switch.Text = state and "🟢" or "⚪"
		tween(switch, 0.16, {
			BackgroundColor3 = state and CONFIG.Colors.Success or CONFIG.Colors.Dark
		})
	end

	connect(switch.Activated, "ToggleActivate", function()
		render(not state)
		safeCall(title, callback, state)
	end)

	return {
		card = card,
		set = function(value)
			render(value)
			safeCall(title, callback, value)
		end,
		get = function()
			return state
		end,
	}
end

local function slider(page, title, minValue, maxValue, defaultValue, callback)
	local value = math.clamp(defaultValue, minValue, maxValue)

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 70)
	card.BackgroundColor3 = CONFIG.Colors.Card
	card.Parent = page
	corner(card, 10)
	stroke(card, CONFIG.Colors.Border, 1, 0.35)

	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 12, 0, 8)
	label.Size = UDim2.new(1, -24, 0, 18)
	label.BackgroundTransparency = 1
	registerText(label, title)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = CONFIG.Colors.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = card

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 12, 0, 39)
	track.Size = UDim2.new(1, -24, 0, 6)
	track.BackgroundColor3 = CONFIG.Colors.Dark
	track.Parent = card
	corner(track, 3)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = CONFIG.Colors.Accent
	fill.Parent = track
	corner(fill, 3)
	gradient(fill, CONFIG.Colors.Accent, CONFIG.Colors.Success, 0)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.BackgroundColor3 = CONFIG.Colors.Text
	knob.Parent = track
	corner(knob, 7)

	local dragging = false

	local function setValue(newValue, fire)
		value = math.clamp(math.floor(newValue + 0.5), minValue, maxValue)
		local alpha = (value - minValue) / math.max(maxValue - minValue, 1)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		label.Text = string.format("%s: %d", tr(title), value)

		if fire then
			safeCall(title, callback, value)
		end
	end

	local function updateFromInput(input)
		local x = input.Position.X
		local left = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		local alpha = math.clamp((x - left) / width, 0, 1)
		setValue(minValue + alpha * (maxValue - minValue), true)
	end

	connect(track.InputBegan, title .. "SliderStart", function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(input)
		end
	end)

	connect(UserInputService.InputChanged, title .. "SliderMove", function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			updateFromInput(input)
		end
	end)

	connect(UserInputService.InputEnded, title .. "SliderEnd", function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	setValue(value, false)

	return {
		set = function(newValue)
			setValue(newValue, true)
		end,
		get = function()
			return value
		end,
	}
end

--============================================================
-- EXTRA QUALITY-OF-LIFE FEATURES
--============================================================
local function setCameraZoom(minZoom, maxZoom)
	player.CameraMinZoomDistance = minZoom
	player.CameraMaxZoomDistance = math.max(maxZoom, minZoom)
end

local function resetCameraZoom()
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 128
end

local function sitPlayer()
	local h = humanoid()
	if h then h.Sit = true end
end

local function standPlayer()
	local h = humanoid()
	if h then h.Sit = false end
end

local function resetCharacterNow()
	local h = humanoid()
	if h then
		h.Health = 0
		return
	end
	player:LoadCharacter()
end

local function setLocalTime(clockTime)
	Lighting.ClockTime = math.clamp(clockTime, 0, 24)
end

local function setLocalBrightness(value)
	Lighting.Brightness = math.clamp(value, 0, 5)
end

local function setLocalGravity(value)
	Workspace.Gravity = math.clamp(value, 0, 300)
end

--============================================================
-- LOCAL AVATAR EFFECTS
--============================================================
local avatarOriginal = {}

local function setLocalPartHidden(part, hidden)
	if not part or not part:IsA("BasePart") then return end
	if avatarOriginal[part] == nil then avatarOriginal[part] = part.LocalTransparencyModifier end
	part.LocalTransparencyModifier = hidden and 1 or avatarOriginal[part]
end

local function setFakeHeadless(enabled)
	Runtime.settings.fakeHeadless = enabled
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		setLocalPartHidden(head, enabled)
		for _, child in ipairs(head:GetDescendants()) do
			if child:IsA("Decal") or child:IsA("Texture") then
				if avatarOriginal[child] == nil then avatarOriginal[child] = child.Transparency end
				child.Transparency = enabled and 1 or avatarOriginal[child]
			end
		end
	end
end

local function findRightLeg(character)
	return character:FindFirstChild("RightLowerLeg") or character:FindFirstChild("Right Leg")
end

local function setFakeKorblox(enabled)
	Runtime.settings.fakeKorblox = enabled
	local character = player.Character
	if not character then return end
	local leg = findRightLeg(character)
	if leg then setLocalPartHidden(leg, enabled) end
	local foot = character:FindFirstChild("RightFoot")
	if foot then setLocalPartHidden(foot, enabled) end
end

local function resetAvatarEffects()
	Runtime.settings.fakeHeadless = false
	Runtime.settings.fakeKorblox = false
	for object, original in pairs(avatarOriginal) do
		if object and object.Parent then
			if object:IsA("BasePart") then
				object.LocalTransparencyModifier = original
			elseif object:IsA("Decal") or object:IsA("Texture") then
				object.Transparency = original
			end
		end
	end
	table.clear(avatarOriginal)
end

connect(player.CharacterAdded, "AvatarEffectsRespawn", function()
	task.wait(0.5)
	if Runtime.settings.fakeHeadless then setFakeHeadless(true) end
	if Runtime.settings.fakeKorblox then setFakeKorblox(true) end
end)

--============================================================
-- SAKURA DECOR + EXTRA UTILITIES
--============================================================
local sakuraEnabled = true
local sakuraFolder = Instance.new("Folder")
sakuraFolder.Name = "SakuraDecor"
sakuraFolder.Parent = main

local function createSakuraPetal(i)
    local petal = Instance.new("TextLabel")
    petal.Name = "SakuraPetal" .. i
    petal.BackgroundTransparency = 1
    petal.Text = (i % 3 == 0) and "🌸" or "✿"
    petal.TextSize = 16 + (i % 3) * 3
    petal.TextColor3 = Color3.fromRGB(255, 170, 205)
    petal.Size = UDim2.fromOffset(28, 28)
    petal.Position = UDim2.new((i * 0.137) % 0.92, 0, 0.08 + ((i * 0.071) % 0.78), 0)
    petal.ZIndex = 104
    petal.Parent = sakuraFolder
end
for i = 1, 12 do createSakuraPetal(i) end

local function setSakura(enabled)
    sakuraEnabled = enabled
    sakuraFolder.Visible = enabled
end

local function restoreDefaults()
    if setFullbright then setFullbright(false) end
    if setFog then setFog(false) end
    if setEsp then setEsp(false) end
    setSakura(true)
end

--============================================================
-- V18 EXTRA FUNCTIONS
--============================================================
local toolOriginal = {}
local coreGuiBaseline = {}
local postFxBaseline = {}
local atmosphereBaseline = {}
local worldGuiBaseline = {}
local selfHighlight = nil
local localTransparencyBaseline = {}
local nameplateHidden = false

local function captureCoreGuiBaseline()
    local types = {
        Enum.CoreGuiType.Backpack,
        Enum.CoreGuiType.Chat,
        Enum.CoreGuiType.PlayerList,
        Enum.CoreGuiType.EmotesMenu,
    }
    for _, coreType in ipairs(types) do
        local ok, value = pcall(function() return StarterGui:GetCoreGuiEnabled(coreType) end)
        if ok then coreGuiBaseline[coreType] = value end
    end
end
captureCoreGuiBaseline()

local function setCoreGuiVisible(coreType, visible)
    pcall(function() StarterGui:SetCoreGuiEnabled(coreType, visible) end)
end

local function restoreCoreGui()
    for coreType, value in pairs(coreGuiBaseline) do
        pcall(function() StarterGui:SetCoreGuiEnabled(coreType, value) end)
    end
    pcall(function() StarterGui:SetCore("TopbarEnabled", true) end)
end

local function setTopbarVisible(visible)
    pcall(function() StarterGui:SetCore("TopbarEnabled", visible) end)
end

local function unequipAllTools()
    local h = humanoid()
    if h then h:UnequipTools(); toast("Tools", "Tools unequipped.", "success") end
end

local function jumpNow()
    local h = humanoid()
    if h then h.Jump = true; h:ChangeState(Enum.HumanoidStateType.Jumping) end
end

local function resetHumanoidState()
    local h = humanoid()
    if h then
        pcall(function() h.PlatformStand = false end)
        pcall(function() h.Sit = false end)
        pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        toast("Character", "Humanoid state reset.", "success")
    end
end

local function setPlatformStand(enabled)
    Runtime.settings.platformStand = enabled
    local h = humanoid()
    if h then h.PlatformStand = enabled end
end

local function setFreezeSelf(enabled)
    Runtime.settings.freezeSelf = enabled
    local root = rootPart()
    if root then root.Anchored = enabled end
end

local function findSpawn()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then return obj end
    end
    return nil
end

local function teleportToSpawn()
    local spawn = findSpawn()
    local root = rootPart()
    if not spawn or not root then toast("Teleport", "Spawn not found.", "warn"); return end
    root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
    toast("Teleport", "Teleported to spawn.", "success")
end

local function faceSpawn()
    local spawn, root = findSpawn(), rootPart()
    if not spawn or not root then toast("Teleport", "Spawn not found.", "warn"); return end
    local p, s = root.Position, spawn.Position
    root.CFrame = CFrame.lookAt(p, Vector3.new(s.X, p.Y, s.Z))
end

local function restoreToolState()
    for tool, state in pairs(toolOriginal) do
        if tool and tool.Parent and tool:IsA("Tool") then tool.Enabled = state end
    end
    table.clear(toolOriginal)
end

local function setPostEffectEnabled(className, enabled)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj.ClassName == className then
            if postFxBaseline[obj] == nil then postFxBaseline[obj] = obj.Enabled end
            obj.Enabled = enabled
        end
    end
end

local function setAtmosphereEnabled(enabled)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            if atmosphereBaseline[obj] == nil then atmosphereBaseline[obj] = {Density=obj.Density,Haze=obj.Haze,Glare=obj.Glare} end
            if enabled then
                local d = atmosphereBaseline[obj]; obj.Density=d.Density; obj.Haze=d.Haze; obj.Glare=d.Glare
            else
                obj.Density=0; obj.Haze=0; obj.Glare=0
            end
        end
    end
end

local function restorePostEffects()
    for obj, value in pairs(postFxBaseline) do
        if obj and obj.Parent then obj.Enabled = value end
    end
    table.clear(postFxBaseline)
    for obj, data in pairs(atmosphereBaseline) do
        if obj and obj.Parent then obj.Density=data.Density; obj.Haze=data.Haze; obj.Glare=data.Glare end
    end
    table.clear(atmosphereBaseline)
end

local function setWorldGuiHidden(kind, hidden)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if (kind == "Billboard" and obj:IsA("BillboardGui")) or (kind == "Surface" and obj:IsA("SurfaceGui")) then
            if worldGuiBaseline[obj] == nil then worldGuiBaseline[obj] = obj.Enabled end
            obj.Enabled = not hidden
        end
    end
    local featureName = kind == "Billboard" and "Billboards" or "SurfaceUI"
    unbindFeature(featureName)
    if hidden then
        bindFeature(featureName, workspace.DescendantAdded, function(obj)
            if kind == "Billboard" and obj:IsA("BillboardGui") then obj.Enabled = false end
            if kind == "Surface" and obj:IsA("SurfaceGui") then obj.Enabled = false end
        end)
    end
end

local function restoreWorldGui()
    for obj, value in pairs(worldGuiBaseline) do if obj and obj.Parent then obj.Enabled = value end end
    table.clear(worldGuiBaseline)
    unbindFeature("Billboards"); unbindFeature("SurfaceUI")
    Runtime.settings.hideBillboards=false; Runtime.settings.hideSurfaceUI=false
end

local function setLowDetail(enabled)
    Runtime.settings.lowDetail = enabled
    if enabled then
        Lighting.GlobalShadows = false
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        setPostEffectEnabled("BloomEffect", false)
        setPostEffectEnabled("SunRaysEffect", false)
        setPostEffectEnabled("DepthOfFieldEffect", false)
    else
        restorePostEffects()
        Lighting.GlobalShadows = Runtime.baseline.lighting.GlobalShadows
        Lighting.EnvironmentDiffuseScale = Runtime.baseline.lighting.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = Runtime.baseline.lighting.EnvironmentSpecularScale
    end
end

local savedSoundVolume = nil
local function setMasterVolume(value)
    savedSoundVolume = savedSoundVolume or SoundService.Volume
    SoundService.Volume = math.clamp(value, 0, 1)
end

local function setMuteGameSounds(muted)
    Runtime.settings.muteSounds = muted
    if muted then
        savedSoundVolume = savedSoundVolume or SoundService.Volume
        SoundService.Volume = 0
    elseif savedSoundVolume ~= nil then
        SoundService.Volume = savedSoundVolume
    end
end

local function restoreSound()
    if savedSoundVolume ~= nil then SoundService.Volume = savedSoundVolume end
    Runtime.settings.muteSounds = false
end

local function setMouseIconEnabled(enabled)
    UserInputService.MouseIconEnabled = enabled
    Runtime.settings.mouseIcon = enabled
end

local function resetInputPreferences()
    UserInputService.MouseIconEnabled = true
    Runtime.settings.mouseIcon = true
    toast("Input", "Input preferences restored.", "success")
end

local function setSelfHighlight(enabled)
    if not enabled then
        if selfHighlight then selfHighlight:Destroy(); selfHighlight=nil end
    elseif not selfHighlight then
        local character = player.Character
        if character then
            selfHighlight = Instance.new("Highlight")
            selfHighlight.Name = "UtilitySelfHighlight"
            selfHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            selfHighlight.FillTransparency = 0.72
            selfHighlight.OutlineTransparency = 0.05
            selfHighlight.Parent = character
        end
    end
    Runtime.settings.selfHighlight = enabled
end

local function setNameplateHidden(hidden)
    nameplateHidden = hidden
    local character = player.Character
    if character then
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BillboardGui") then obj.Enabled = not hidden end
        end
    end
    unbindFeature("Nameplate")
    if hidden and character then
        bindFeature("Nameplate", character.DescendantAdded, function(obj)
            if obj:IsA("BillboardGui") then obj.Enabled = false end
        end)
    end
    Runtime.settings.hideNameplate = hidden
end

local function setLocalTransparency(enabled)
    local character = player.Character
    if not character then return end
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BasePart") then
            if localTransparencyBaseline[obj] == nil then localTransparencyBaseline[obj] = obj.LocalTransparencyModifier end
            obj.LocalTransparencyModifier = enabled and math.max(obj.LocalTransparencyModifier, 0.45) or localTransparencyBaseline[obj]
        end
    end
    Runtime.settings.localTransparency = enabled
end

local function restoreCharacterLook()
    for obj, value in pairs(localTransparencyBaseline) do if obj and obj.Parent then obj.LocalTransparencyModifier=value end end
    table.clear(localTransparencyBaseline)
    setSelfHighlight(false)
    setNameplateHidden(false)
    resetAvatarEffects()
    Runtime.settings.localTransparency=false
end

local function refreshAppearance()
    if Runtime.settings.selfHighlight then setSelfHighlight(false); setSelfHighlight(true) end
    if Runtime.settings.hideNameplate then setNameplateHidden(false); setNameplateHidden(true) end
    if Runtime.settings.localTransparency then setLocalTransparency(true) end
    if Runtime.settings.fakeHeadless then setFakeHeadless(true) end
    if Runtime.settings.fakeKorblox then setFakeKorblox(true) end
end

--============================================================
-- PAGES
--============================================================
local dashboard = createPage("Dashboard", "Dashboard", "Quick controls and live status")
local movement = createPage("Movement", "Movement", "Speed, jump and movement settings")
local flight = createPage("Flight", "Flight", "Controlled local flight system")
local teleport = createPage("Teleport", "Teleport", "Coordinate and utility teleports")
local visuals = createPage("Visuals", "Visuals", "ESP and local visual tools")
local characterPage = createPage("Character", "Character", "Position, accessories and character actions")
local avatarPage = createPage("Avatar", "Avatar", "Avatar appearance and local avatar effects")
local cameraPage = createPage("Camera", "Camera", "FOV, zoom and camera modes")
local playerPage = createPage("Player", "Player", "Quick player actions and server controls")
local playersPage = createPage("Players", "Players", "Live server player list")

local environment = createPage("Environment", "Environment", "Time, lighting and physics")
local serverPage = createPage("Server", "Server", "Server information and session actions")
local interfacePage = createPage("Interface", "Interface", "Interface, language and animation settings")
local presets = createPage("Presets", "Presets", "One-tap control profiles")
local about = createPage("About", "About", "Panel information and controls")
local safety = createPage("Safety", "Safety", "One-click restore and diagnostics")
local toolsPage = createPage("Tools", "Tools", "Personal tools and character utilities")
local hudPage = createPage("HUD", "HUD", "Core interface visibility controls")
local postFxPage = createPage("PostFX", "PostFX", "Local post-processing controls")
local audioPage = createPage("Audio", "Audio", "Local audio controls")
local performancePage = createPage("Performance", "Performance", "Local visual optimizations")
local inputPage = createPage("Input", "Input", "Mouse and input preferences")
local appearancePage = createPage("Appearance", "Appearance", "Local character presentation")

-- Sakura and extra utility controls
section(interfacePage, "🌸 Sakura — Clean decorative theme")
toggle(interfacePage, "🌸 Sakura petals", sakuraEnabled, function(v) setSakura(v) end)
button(interfacePage, "✨ Restore visuals", function() restoreDefaults() end)

section(playerPage, "🧰 Extra Tools — Additional local utilities")
toggle(playerPage, "🛌 Anti-AFK", Runtime.settings.antiAfk, function(v) setAntiAfk(v) end)
button(playerPage, "🎯 Reset camera", function()
    local cam = Workspace.CurrentCamera
    if cam then cam.FieldOfView = 70; cam.CameraType = Enum.CameraType.Custom end
end)


--============================================================
-- V18 EXTRA PAGES
--============================================================
section(toolsPage, "EXTRA TOOLS")
button(toolsPage, "Unequip All Tools", unequipAllTools, "success")
button(toolsPage, "Jump Now", jumpNow)
button(toolsPage, "Reset Humanoid State", resetHumanoidState, "success")
toggle(toolsPage, "Platform Stand", false, setPlatformStand)
toggle(toolsPage, "Freeze Self", false, setFreezeSelf)
button(toolsPage, "Teleport to Spawn", teleportToSpawn)
button(toolsPage, "Face Spawn", faceSpawn)
button(toolsPage, "Restore Tool State", restoreToolState, "success")

section(hudPage, "CORE HUD")
toggle(hudPage, "Hide Backpack", false, function(v) setCoreGuiVisible(Enum.CoreGuiType.Backpack, not v) end)
toggle(hudPage, "Hide Chat", false, function(v) setCoreGuiVisible(Enum.CoreGuiType.Chat, not v) end)
toggle(hudPage, "Hide Player List", false, function(v) setCoreGuiVisible(Enum.CoreGuiType.PlayerList, not v) end)
toggle(hudPage, "Hide Emotes", false, function(v) setCoreGuiVisible(Enum.CoreGuiType.EmotesMenu, not v) end)
toggle(hudPage, "Hide Topbar", false, function(v) setTopbarVisible(not v) end)
button(hudPage, "Restore Core HUD", restoreCoreGui, "success")

section(postFxPage, "POST PROCESSING")
toggle(postFxPage, "Disable Bloom", false, function(v) setPostEffectEnabled("BloomEffect", not v) end)
toggle(postFxPage, "Disable Color Correction", false, function(v) setPostEffectEnabled("ColorCorrectionEffect", not v) end)
toggle(postFxPage, "Disable Sun Rays", false, function(v) setPostEffectEnabled("SunRaysEffect", not v) end)
toggle(postFxPage, "Disable Depth Of Field", false, function(v) setPostEffectEnabled("DepthOfFieldEffect", not v) end)
toggle(postFxPage, "Disable Atmosphere", false, function(v) setAtmosphereEnabled(not v) end)
button(postFxPage, "Restore Post Effects", restorePostEffects, "success")

section(audioPage, "AUDIO CONTROLS")
slider(audioPage, "Master Volume", 0, 100, math.floor(SoundService.Volume * 100 + 0.5), function(v) setMasterVolume(v / 100) end)
toggle(audioPage, "Mute Game Sounds", false, setMuteGameSounds)
button(audioPage, "Restore Sound", restoreSound, "success")

section(performancePage, "OPTIMIZATION")
toggle(performancePage, "Hide Billboards", false, function(v) Runtime.settings.hideBillboards=v; setWorldGuiHidden("Billboard", v) end)
toggle(performancePage, "Hide Surface UI", false, function(v) Runtime.settings.hideSurfaceUI=v; setWorldGuiHidden("Surface", v) end)
toggle(performancePage, "Low Detail Mode", false, setLowDetail)
toggle(performancePage, "Local Shadows Off", false, function(v) Lighting.GlobalShadows = not v end)
button(performancePage, "Restore Visual Quality", function()
    restoreWorldGui()
    restorePostEffects()
    Lighting.GlobalShadows = Runtime.baseline.lighting.GlobalShadows
    Lighting.EnvironmentDiffuseScale = Runtime.baseline.lighting.EnvironmentDiffuseScale
    Lighting.EnvironmentSpecularScale = Runtime.baseline.lighting.EnvironmentSpecularScale
    Runtime.settings.lowDetail = false
end, "success")

section(inputPage, "INPUT SETTINGS")
toggle(inputPage, "Mouse Icon", true, setMouseIconEnabled)
button(inputPage, "Reset Input Preferences", resetInputPreferences, "success")
infoCard(inputPage, "DEVICE", Runtime.device, CONFIG.Colors.Accent)
infoCard(inputPage, "TOUCH", UserInputService.TouchEnabled and "Available" or "Unavailable", CONFIG.Colors.Success)
infoCard(inputPage, "GAMEPAD", UserInputService.GamepadEnabled and "Available" or "Unavailable", CONFIG.Colors.Warning)

section(appearancePage, "CHARACTER PRESENTATION")
toggle(appearancePage, "Self Highlight", false, setSelfHighlight)
toggle(appearancePage, "Hide Nameplate", false, setNameplateHidden)
toggle(appearancePage, "Local Transparency", false, setLocalTransparency)
button(appearancePage, "Restore Character Look", restoreCharacterLook, "success")
button(appearancePage, "Refresh Appearance", refreshAppearance, "success")

--============================================================
-- NAVIGATION
--============================================================
navigation = {
	{"Dashboard", "🏠", 1},
	{"Movement", "🏃", 2},
	{"Flight", "🪽", 3},
	{"Teleport", "📍", 4},
	{"Visuals", "👁️", 5},
	{"Character", "👤", 6},
	{"Avatar", "🧑‍🎨", 7},
	{"Camera", "📷", 8},
	{"Player", "🧑", 9},
	{"Players", "👥", 10},
	{"Environment", "🌍", 11},
	{"Server", "🖥️", 12},
	{"Interface", "🎨", 13},
	{"Presets", "🎛️", 14},
	{"Tools", "🧰", 15},
	{"HUD", "🖥️", 16},
	{"PostFX", "✨", 17},
	{"Audio", "🔊", 18},
	{"Performance", "⚡", 19},
	{"Input", "🎮", 20},
	{"Appearance", "🌸", 21},
	{"About", "ℹ️", 22},
	{"Safety", "🛡️", 23},
}

for _, item in ipairs(navigation) do
	navButton(item[1], item[1], item[2], item[3])
end
for _, obj in ipairs(about:GetDescendants()) do
    if obj:IsA("TextLabel") and obj:GetAttribute("I18NKey") == "PAGES" then
        if obj.Parent and obj.Parent:IsA("Frame") then obj.Text = tostring(#navigation) end
    end
end

local function switchPage(name)
    local page = pages[name]
    if not page or Runtime.destroyed then return end
    if Runtime.currentPage == name and page.Visible then return end

    for key, btn in pairs(navButtons) do
        local active = key == name
        btn.BackgroundColor3 = active and CONFIG.Colors.Accent2 or CONFIG.Colors.Dark
        btn.TextColor3 = active and CONFIG.Colors.Text or CONFIG.Colors.Muted
    end

    for _, otherPage in pairs(pages) do
        otherPage.Visible = (otherPage == page)
        otherPage.Position = UDim2.fromScale(0, 0)
    end
    page.CanvasPosition = Vector2.new(0, 0)
    Runtime.currentPage = name
    updateNavScales()
end

for key, btn in pairs(navButtons) do
    connect(btn.Activated, "Navigation", function()
        switchPage(key)
    end)
end

--============================================================
-- MOVEMENT FEATURES
--============================================================
local function setWalkSpeed(value)
	Runtime.settings.walkSpeed = value
	local h = humanoid()
	if h then h.WalkSpeed = value end
end

local function setJumpPower(value)
	Runtime.settings.jumpPower = value
	local h = humanoid()
	if h then
		h.UseJumpPower = true
		h.JumpPower = value
	end
end

local function setNoclip(enabled)
	Runtime.settings.noclip = enabled
	if not enabled then
		RunService:UnbindFromRenderStep(Runtime.renderNames.Noclip)
		return
	end

	RunService:UnbindFromRenderStep(Runtime.renderNames.Noclip)
	RunService:BindToRenderStep(
		Runtime.renderNames.Noclip,
		Enum.RenderPriority.Character.Value + 1,
		function()
			local character = player.Character
			if not character then return end

			for _, object in ipairs(character:GetDescendants()) do
				if object:IsA("BasePart") then
					object.CanCollide = false
				end
			end
		end
	)
end

local function setInfiniteJump(enabled)
	Runtime.settings.infiniteJump = enabled
	unbindFeature("InfiniteJump")

	if enabled then
		bindFeature("InfiniteJump", UserInputService.JumpRequest, function()
			local h = humanoid()
			if h then
				h:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end
end

local function setAntiAfk(enabled)
	Runtime.settings.antiAfk = enabled
	unbindFeature("AntiAFK")

	if enabled then
		local virtualUser = game:GetService("VirtualUser")
		bindFeature("AntiAFK", player.Idled, function()
			virtualUser:CaptureController()
			virtualUser:ClickButton2(Vector2.new())
		end)
	end
end

--============================================================
-- FLIGHT
--============================================================
local flightVelocity = nil

local function clearFlightBody()
	if flightVelocity then
		pcall(function()
			flightVelocity:Destroy()
		end)
		flightVelocity = nil
	end

	local root = rootPart()
	if root then
		local old = root:FindFirstChild("UtilityV11_FlightVelocity")
		if old then old:Destroy() end
	end
end

local function setFlight(enabled)
	Runtime.settings.flight = enabled
	RunService:UnbindFromRenderStep(Runtime.renderNames.Flight)
	clearFlightBody()

	if not enabled then
		local h = humanoid()
		if h then h.PlatformStand = false end
		return
	end

	local root = rootPart()
	if not root then
		Runtime.settings.flight = false
		toast("Flight", "Character is not ready.", "warn")
		return
	end

	local body = Instance.new("BodyVelocity")
	body.Name = "UtilityV11_FlightVelocity"
	body.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	body.P = 2e4
	body.Velocity = Vector3.zero
	body.Parent = root
	flightVelocity = body

	RunService:BindToRenderStep(
		Runtime.renderNames.Flight,
		Enum.RenderPriority.Character.Value + 2,
		function()
			if not Runtime.settings.flight then return end

			local currentRoot = rootPart()
			local camera = getCamera()
			if not currentRoot or not camera then return end

			if body.Parent ~= currentRoot then
				body.Parent = currentRoot
			end

			local direction = Vector3.zero
			local up = Vector3.zero

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				direction += camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				direction -= camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				direction -= camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				direction += camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				up += Vector3.yAxis
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				up -= Vector3.yAxis
			end

			local touch = Runtime.touchState
			if touch then
				if touch.W then direction += camera.CFrame.LookVector end
				if touch.S then direction -= camera.CFrame.LookVector end
				if touch.A then direction -= camera.CFrame.RightVector end
				if touch.D then direction += camera.CFrame.RightVector end
				if touch.Up then up += Vector3.yAxis end
				if touch.Down then up -= Vector3.yAxis end
			end

			local final = direction + up
			if final.Magnitude > 0 then
				final = final.Unit * Runtime.settings.flightSpeed
			end

			body.Velocity = final
		end
	)
end

--============================================================
-- TELEPORT
--============================================================
local function teleportTo(cframe)
	local root = rootPart()
	if not root then
		toast("Teleport", "Character is not ready.", "warn")
		return
	end

	root.CFrame = cframe
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function parseCoordinates(text)
	local numbers = {}
	for token in string.gmatch(text or "", "[-+]?%d*%.?%d+") do
		table.insert(numbers, tonumber(token))
	end

	if #numbers < 3 then
		return nil
	end

	return numbers[1], numbers[2], numbers[3]
end

local function teleportToHighestPart()
	local character = player.Character
	local bestPart = nil
	local bestY = -math.huge

	for _, object in ipairs(Workspace:GetDescendants()) do
		if object:IsA("BasePart")
			and object ~= character
			and object.Name ~= "Baseplate"
			and not object:IsDescendantOf(character)
			and object.Transparency < 1
			and object.CanCollide then

			if object.Position.Y > bestY then
				bestY = object.Position.Y
				bestPart = object
			end
		end
	end

	if bestPart then
		teleportTo(bestPart.CFrame + Vector3.new(0, 5, 0))
		toast("Teleport", "Moved to highest solid part.", "success")
	else
		toast("Teleport", "No suitable part found.", "warn")
	end
end

--============================================================
-- VISUALS
--============================================================
local savedFullbright = nil
local savedParticleState = {}

local function setFullbright(enabled)
	Runtime.settings.fullbright = enabled

	if enabled then
		if not savedFullbright then
			savedFullbright = {
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
				GlobalShadows = Lighting.GlobalShadows,
				EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
				EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
			}
		end

		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.EnvironmentDiffuseScale = 1
		Lighting.EnvironmentSpecularScale = 1
	else
		if savedFullbright then
			for key, value in pairs(savedFullbright) do
				pcall(function()
					Lighting[key] = value
				end)
			end
		else
			local base = Runtime.baseline.lighting
			Lighting.Brightness = base.Brightness
			Lighting.ClockTime = base.ClockTime
			Lighting.GlobalShadows = base.GlobalShadows
			Lighting.EnvironmentDiffuseScale = base.EnvironmentDiffuseScale
			Lighting.EnvironmentSpecularScale = base.EnvironmentSpecularScale
		end
		savedFullbright = nil
	end
end

local function setFog(enabled)
	Runtime.settings.removeFog = enabled
	if enabled then
		Lighting.FogStart = 1e6
		Lighting.FogEnd = 1e6
	else
		Lighting.FogStart = Runtime.baseline.lighting.FogStart
		Lighting.FogEnd = Runtime.baseline.lighting.FogEnd
	end
end

local function removeAllEsp()
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local character = otherPlayer.Character
		if character then
			local head = character:FindFirstChild("Head")
			if head then
				local existing = head:FindFirstChild("UtilityV11_ESP")
				if existing then existing:Destroy() end
			end
		end
	end
end

local function setEsp(enabled)
	Runtime.settings.esp = enabled
	RunService:UnbindFromRenderStep(Runtime.renderNames.ESP)

	if not enabled then
		removeAllEsp()
		return
	end

	RunService:BindToRenderStep(Runtime.renderNames.ESP, Enum.RenderPriority.Last.Value, function()
		for _, otherPlayer in ipairs(Players:GetPlayers()) do
			if otherPlayer ~= player then
				local character = otherPlayer.Character
				local head = character and character:FindFirstChild("Head")

				if head and not head:FindFirstChild("UtilityV11_ESP") then
					local billboard = Instance.new("BillboardGui")
					billboard.Name = "UtilityV11_ESP"
					billboard.Size = UDim2.new(0, 180, 0, 28)
					billboard.StudsOffset = Vector3.new(0, 2.6, 0)
					billboard.AlwaysOnTop = true
					billboard.Parent = head

					local label = Instance.new("TextLabel")
					label.Size = UDim2.fromScale(1, 1)
					label.BackgroundTransparency = 1
					label.Text = otherPlayer.DisplayName .. "  @" .. otherPlayer.Name
					label.Font = Enum.Font.GothamBold
					label.TextSize = 11
					label.TextStrokeTransparency = 0.5
					label.TextColor3 = CONFIG.Colors.Accent
					label.Parent = billboard
				end
			end
		end
	end)
end

local function setFov(value)
	local camera = getCamera()
	if camera then
		camera.FieldOfView = math.clamp(value, 40, 120)
	end
end

local function resetFov()
	setFov(Runtime.baseline.fov or 70)
end

--============================================================
-- CHARACTER / WORLD
--============================================================
local function savePosition()
	local root = rootPart()
	if root then
		Runtime.savedPosition = root.CFrame
		toast("Character", "Position saved.", "success")
	else
		toast("Character", "Character is not ready.", "warn")
	end
end

local function returnToSavedPosition()
	if Runtime.savedPosition then
		teleportTo(Runtime.savedPosition)
		toast("Character", "Returned to saved position.", "success")
	else
		toast("Character", "No saved position.", "warn")
	end
end

local function stopVelocity()
	local root = rootPart()
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function faceCamera()
	local root = rootPart()
	local camera = getCamera()
	if not root or not camera then return end

	local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if flatLook.Magnitude > 0 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
	end
end

local function resetCamera()
	local camera = getCamera()
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = Runtime.baseline.fov or 70
	end

	Runtime.settings.cameraLock = false
end

local function restoreWorld()
	Workspace.Gravity = Runtime.baseline.gravity or 196.2

	local base = Runtime.baseline.lighting
	for key, value in pairs(base) do
		pcall(function()
			Lighting[key] = value
		end)
	end

	resetFov()
	Runtime.settings.fullbright = false
	Runtime.settings.removeFog = false
	savedFullbright = nil
end

local function hideAccessories(hidden)
	Runtime.settings.accessoriesHidden = hidden

	local character = player.Character
	if not character then return end

	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BasePart") then
			local accessory = object:FindFirstAncestorOfClass("Accessory")
			if accessory then
				object.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
end

local function hideParticles(hidden)
	Runtime.settings.particlesHidden = hidden

	local character = player.Character
	if not character then return end

	if hidden then
		for _, object in ipairs(character:GetDescendants()) do
			if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
				if savedParticleState[object] == nil then
					savedParticleState[object] = object.Enabled
				end
				object.Enabled = false
			end
		end
	else
		for object, wasEnabled in pairs(savedParticleState) do
			if object and object.Parent then
				object.Enabled = wasEnabled
			end
		end
		table.clear(savedParticleState)
	end
end

local function applyCharacterSettings()
	local h = humanoid()
	if not h then return end

	h.WalkSpeed = Runtime.settings.walkSpeed
	h.UseJumpPower = true
	h.JumpPower = Runtime.settings.jumpPower
	h.AutoRotate = Runtime.settings.autoRotate
end

local function disableMovementFeatures()
	setFlight(false)
	setNoclip(false)
	setInfiniteJump(false)

	local h = humanoid()
	if h then
		h.PlatformStand = false
	end

	restoreBaselineMovement()
end

local function fullSafeReset()
	disableMovementFeatures()
	setAntiAfk(true)
	Runtime.settings.walkSpeed = Runtime.baseline.walkSpeed or 16
	Runtime.settings.jumpPower = Runtime.baseline.jumpPower or 50
	Runtime.settings.autoRotate = Runtime.baseline.autoRotate ~= false
	Runtime.settings.accessoriesHidden = false
	Runtime.settings.particlesHidden = false

	hideAccessories(false)
	hideParticles(false)
	removeAllEsp()
	setEsp(false)
	restoreWorld()
	resetCamera()
	setPlatformStand(false)
	setFreezeSelf(false)
	restoreCoreGui()
	restorePostEffects()
	restoreWorldGui()
	restoreSound()
	setMouseIconEnabled(true)
	restoreCharacterLook()
	setLowDetail(false)

	toast("Safety", "Everything restored to the saved baseline.", "success", 3)
end

--============================================================
-- DASHBOARD
--============================================================
section(dashboard, "OVERVIEW")

local deviceValue = infoCard(dashboard, "DEVICE", "Detecting…", CONFIG.Colors.Accent)
local characterValue = infoCard(dashboard, "CHARACTER", "Loading…", CONFIG.Colors.Success)
local positionValue = infoCard(dashboard, "POSITION", "—", CONFIG.Colors.Accent)
local fpsValue = infoCard(dashboard, "PERFORMANCE", "FPS: —", CONFIG.Colors.Warning)

section(dashboard, "QUICK ACTIONS")
button(dashboard, "RESET MOVEMENT", function()
	disableMovementFeatures()
	toast("Movement", "Baseline movement restored.", "success")
end, "success")
button(dashboard, "RESET CAMERA", function()
	resetCamera()
	toast("Camera", "Camera restored.", "success")
end)
button(dashboard, "SAVE POSITION", savePosition, "success")
button(dashboard, "RESET CHARACTER", function()
	local h = humanoid()
	if h then
		h.Health = 0
		toast("Character", "Character reset.", "warn")
	end
end, "warn")
button(dashboard, "REJOIN SERVER", function()
	local TeleportService = game:GetService("TeleportService")
	safeCall("RejoinServer", function()
		TeleportService:Teleport(game.PlaceId, player)
	end)
end, "warn")
button(dashboard, "FULL SAFE RESET", fullSafeReset, "danger")

section(dashboard, "LIVE")

local dashboardStatus = Instance.new("TextLabel")
dashboardStatus.Size = UDim2.new(1, 0, 0, 74)
dashboardStatus.BackgroundColor3 = CONFIG.Colors.Card
dashboardStatus.Text = tr("Ready.")
dashboardStatus.Font = Enum.Font.Gotham
dashboardStatus.TextSize = 11
dashboardStatus.TextColor3 = CONFIG.Colors.Muted
dashboardStatus.TextWrapped = true
dashboardStatus.TextXAlignment = Enum.TextXAlignment.Left
dashboardStatus.TextYAlignment = Enum.TextYAlignment.Top
dashboardStatus.Parent = dashboard
corner(dashboardStatus, 10)
stroke(dashboardStatus, CONFIG.Colors.Border, 1, 0.35)
padding(dashboardStatus, 12, 12, 10, 10)

--============================================================
-- MOVEMENT PAGE
--============================================================
section(movement, "MOVEMENT MODIFIERS")

local walkSlider = slider(movement, "Walk Speed", 16, 100, Runtime.settings.walkSpeed, setWalkSpeed)
local jumpSlider = slider(movement, "Jump Power", 50, 200, Runtime.settings.jumpPower, setJumpPower)

toggle(movement, "Infinite Jump", Runtime.settings.infiniteJump, setInfiniteJump)
toggle(movement, "Noclip", Runtime.settings.noclip, setNoclip)
toggle(movement, "Anti-AFK", Runtime.settings.antiAfk, setAntiAfk)

section(movement, "RESET")
button(movement, "RESTORE SAVED MOVEMENT", function()
	setNoclip(false)
	setInfiniteJump(false)
	setFlight(false)
	restoreBaselineMovement()
	Runtime.settings.walkSpeed = Runtime.baseline.walkSpeed or 16
	Runtime.settings.jumpPower = Runtime.baseline.jumpPower or 50
	toast("Movement", "Saved movement state restored.", "success")
end, "success")

--============================================================
-- FLIGHT PAGE
--============================================================
section(flight, "FLIGHT CONTROLLER")
slider(flight, "Flight Speed", 20, 150, Runtime.settings.flightSpeed, function(value)
	Runtime.settings.flightSpeed = value
end)
toggle(flight, "Enable Flight", false, setFlight)

local flightInfo = Instance.new("TextLabel")
flightInfo.Size = UDim2.new(1, 0, 0, 72)
flightInfo.BackgroundColor3 = CONFIG.Colors.Card
registerText(flightInfo, "Keyboard: W/A/S/D to move • Space up • Left Ctrl down\nOn touch devices, use the virtual controls shown below.")
flightInfo.Text = tr("Keyboard: W/A/S/D to move • Space up • Left Ctrl down\nOn touch devices, use the virtual controls shown below.")
flightInfo.Font = Enum.Font.Gotham
flightInfo.TextSize = 11
flightInfo.TextColor3 = CONFIG.Colors.Muted
flightInfo.TextWrapped = true
flightInfo.TextXAlignment = Enum.TextXAlignment.Left
flightInfo.TextYAlignment = Enum.TextYAlignment.Center
flightInfo.Parent = flight
corner(flightInfo, 10)
stroke(flightInfo, CONFIG.Colors.Border, 1, 0.35)
padding(flightInfo, 12, 12, 8, 8)

--============================================================
-- TELEPORT PAGE
--============================================================
section(teleport, "COORDINATES")

local coordBox = Instance.new("TextBox")
coordBox.Size = UDim2.new(1, 0, 0, 44)
coordBox.BackgroundColor3 = CONFIG.Colors.Card
coordBox.Text = "0, 0, 0"
coordBox.PlaceholderText = "X, Y, Z"
coordBox.Font = Enum.Font.Gotham
coordBox.TextSize = 12
coordBox.TextColor3 = CONFIG.Colors.Text
coordBox.PlaceholderColor3 = CONFIG.Colors.Muted
coordBox.ClearTextOnFocus = false
coordBox.Parent = teleport
corner(coordBox, 10)
stroke(coordBox, CONFIG.Colors.Border, 1, 0.2)
padding(coordBox, 12, 12, 0, 0)

button(teleport, "TELEPORT TO COORDINATES", function()
	local x, y, z = parseCoordinates(coordBox.Text)
	if not x then
		toast("Teleport", "Use three numbers: X, Y, Z.", "error")
		return
	end

	teleportTo(CFrame.new(x, y, z))
	toast("Teleport", string.format("Moved to %.1f, %.1f, %.1f", x, y, z), "success")
end)

button(teleport, "MOVE UP +500", function()
	local root = rootPart()
	if root then
		teleportTo(root.CFrame + Vector3.new(0, 500, 0))
	end
end, "success")

button(teleport, "MOVE UP +1000", function()
	local root = rootPart()
	if root then
		teleportTo(root.CFrame + Vector3.new(0, 1000, 0))
	end
end, "warn")

button(teleport, "HIGHEST SOLID PART", teleportToHighestPart, "warn")

--============================================================
-- VISUALS PAGE
--============================================================
section(visuals, "VISUAL")
toggle(visuals, "ESP Player Names", false, setEsp)
toggle(visuals, "Hide Particles", Runtime.settings.particlesHidden, hideParticles)

section(visuals, "STATUS")
infoCard(visuals, "STATUS", "Visual tools ready", CONFIG.Colors.Accent)

--============================================================
-- CHARACTER PAGE
--============================================================
section(characterPage, "POSITION")
button(characterPage, "SAVE CURRENT POSITION", savePosition, "success")
button(characterPage, "RETURN TO SAVED POSITION", returnToSavedPosition)

section(characterPage, "UTILITY")
button(characterPage, "STOP VELOCITY", stopVelocity)
button(characterPage, "FACE CAMERA", faceCamera)
button(characterPage, "RESET CHARACTER MOTION", function()
	stopVelocity()
	disableMovementFeatures()
end, "success")

toggle(characterPage, "Hide Accessories", Runtime.settings.accessoriesHidden, hideAccessories)
toggle(characterPage, "Auto Rotate", Runtime.settings.autoRotate, function(enabled)
	Runtime.settings.autoRotate = enabled
	local h = humanoid()
	if h then h.AutoRotate = enabled end
end)

--============================================================
-- SERVER PAGE
--============================================================
section(serverPage, "SERVER INFO")
local serverIdInfo = infoCard(serverPage, "SERVER ID", game.JobId ~= "" and game.JobId or "Studio", CONFIG.Colors.Accent)
local placeIdInfo = infoCard(serverPage, "PLACE ID", tostring(game.PlaceId), CONFIG.Colors.Success)
local playersInfo = infoCard(serverPage, "PLAYERS", tostring(#Players:GetPlayers()), CONFIG.Colors.Warning)

button(serverPage, "REFRESH SERVER INFO", function()
	serverIdInfo.Text = game.JobId ~= "" and game.JobId or "Studio"
	placeIdInfo.Text = tostring(game.PlaceId)
	playersInfo.Text = tostring(#Players:GetPlayers())
	toast("Server", "Server information refreshed.", "success")
end, "success")
button(serverPage, "REJOIN SERVER", function()
	local TeleportService = game:GetService("TeleportService")
	safeCall("RejoinServer", function()
		TeleportService:Teleport(game.PlaceId, player)
	end)
end, "warn")

--============================================================
-- SAFETY PAGE
--============================================================
section(safety, "RESTORE")
button(safety, "RESTORE MOVEMENT", function()
	disableMovementFeatures()
	toast("Safety", "Movement restored.", "success")
end, "success")

button(safety, "RESTORE CAMERA", function()
	resetCamera()
	toast("Safety", "Camera restored.", "success")
end, "success")

button(safety, "RESTORE WORLD", function()
	restoreWorld()
	toast("Safety", "World values restored.", "success")
end, "success")

button(safety, "FULL SAFE RESET", fullSafeReset, "danger")

section(safety, "DIAGNOSTICS")
button(safety, "UNLOAD SCRIPT", function()
	task.delay(0.15, unloadScript)
end, "danger")
local diagnostics = infoCard(safety, "RUNTIME", "Healthy", CONFIG.Colors.Success)
local diagnostics2 = Instance.new("TextLabel")
diagnostics2.Size = UDim2.new(1, 0, 0, 74)
diagnostics2.BackgroundColor3 = CONFIG.Colors.Card
registerText(diagnostics2, "The panel uses centralized connections and pcall/xpcall guards for feature callbacks.")
diagnostics2.Text = tr("The panel uses centralized connections and pcall/xpcall guards for feature callbacks.")
diagnostics2.Font = Enum.Font.Gotham
diagnostics2.TextSize = 11
diagnostics2.TextColor3 = CONFIG.Colors.Muted
diagnostics2.TextWrapped = true
diagnostics2.TextXAlignment = Enum.TextXAlignment.Left
diagnostics2.TextYAlignment = Enum.TextYAlignment.Center
diagnostics2.Parent = safety
corner(diagnostics2, 10)
stroke(diagnostics2, CONFIG.Colors.Border, 1, 0.35)
padding(diagnostics2, 12, 12, 8, 8)

--============================================================
-- AVATAR PAGE
--============================================================
section(avatarPage, "FAKE AVATAR")
toggle(avatarPage, "Fake Headless", Runtime.settings.fakeHeadless, function(enabled)
	setFakeHeadless(enabled)
	toast("Avatar", enabled and "Fake Headless enabled locally." or "Fake Headless disabled.", enabled and "success" or "warn")
end)

local headlessInfo = Instance.new("TextLabel")
headlessInfo.Size = UDim2.new(1, 0, 0, 48)
headlessInfo.BackgroundColor3 = CONFIG.Colors.Card
registerText(headlessInfo, "Fake Headless hides your head locally.")
headlessInfo.Text = tr("Fake Headless hides your head locally.")
headlessInfo.Font = Enum.Font.Gotham
headlessInfo.TextSize = 11
headlessInfo.TextColor3 = CONFIG.Colors.Muted
headlessInfo.TextWrapped = true
headlessInfo.TextXAlignment = Enum.TextXAlignment.Left
headlessInfo.TextYAlignment = Enum.TextYAlignment.Center
headlessInfo.Parent = avatarPage
corner(headlessInfo, 10)
padding(headlessInfo, 12, 12, 8, 8)

toggle(avatarPage, "Fake Korblox", Runtime.settings.fakeKorblox, function(enabled)
	setFakeKorblox(enabled)
	toast("Avatar", enabled and "Fake Korblox enabled locally." or "Fake Korblox disabled.", enabled and "success" or "warn")
end)

local korbloxInfo = Instance.new("TextLabel")
korbloxInfo.Size = UDim2.new(1, 0, 0, 48)
korbloxInfo.BackgroundColor3 = CONFIG.Colors.Card
registerText(korbloxInfo, "Fake Korblox hides the right leg locally.")
korbloxInfo.Text = tr("Fake Korblox hides the right leg locally.")
korbloxInfo.Font = Enum.Font.Gotham
korbloxInfo.TextSize = 11
korbloxInfo.TextColor3 = CONFIG.Colors.Muted
korbloxInfo.TextWrapped = true
korbloxInfo.TextXAlignment = Enum.TextXAlignment.Left
korbloxInfo.TextYAlignment = Enum.TextYAlignment.Center
korbloxInfo.Parent = avatarPage
corner(korbloxInfo, 10)
padding(korbloxInfo, 12, 12, 8, 8)

button(avatarPage, "RESET AVATAR EFFECTS", function()
	resetAvatarEffects()
	toast("Avatar", "Avatar effects reset.", "success")
end, "success")

--============================================================
-- CAMERA PAGE
--============================================================
section(cameraPage, "CAMERA")
slider(cameraPage, "Field of View", 40, 120, Runtime.baseline.fov or 70, setFov)
button(cameraPage, "RESET FOV", resetFov, "success")
button(cameraPage, "FIRST PERSON", function()
	setCameraZoom(0.5, 0.5)
end)
button(cameraPage, "THIRD PERSON", function()
	setCameraZoom(8, 128)
end, "success")
button(cameraPage, "RESET ZOOM", resetCameraZoom, "success")
button(cameraPage, "CUSTOM CAMERA", function()
	local camera = getCamera()
	if camera then camera.CameraType = Enum.CameraType.Custom end
end)

section(cameraPage, "CAMERA STATUS")
local cameraInfo = infoCard(cameraPage, "FOV", tostring(math.floor((getCamera() and getCamera().FieldOfView) or 70)), CONFIG.Colors.Accent)

--============================================================
-- PLAYER PAGE
--============================================================
section(playerPage, "QUICK ACTIONS")
button(playerPage, "SIT", sitPlayer)
button(playerPage, "STAND", standPlayer, "success")
button(playerPage, "RESET CHARACTER", resetCharacterNow, "danger")

section(playerPage, "PLAYER STATUS")
infoCard(playerPage, "STATUS", "Ready", CONFIG.Colors.Success)

--============================================================
-- ADMIN PLAYER ACTIONS
-- Server-authorized actions for your own game.
-- The server script must be installed in ServerScriptService.
--============================================================
local adminRemote = ReplicatedStorage:WaitForChild("UtilityAdminRemote", 10)
local selectedTarget = nil

local function adminAction(action, target)
    if not adminRemote then
        toast("Admin", "UtilityAdminRemote is missing. Install the server script.", "warn")
        return
    end
    if not target or target == player then
        toast("Admin", "Select another player first.", "warn")
        return
    end
    adminRemote:FireServer(action, target.UserId)
end

--============================================================
-- PLAYERS PAGE
--============================================================
section(playersPage, "LIVE PLAYERS")
local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(1, 0, 0, 30)
selectedLabel.BackgroundColor3 = CONFIG.Colors.Card
selectedLabel.TextColor3 = CONFIG.Colors.Muted
selectedLabel.Font = Enum.Font.GothamMedium
selectedLabel.TextSize = 12
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.Text = "👤  No player selected"
selectedLabel.Parent = playersPage
corner(selectedLabel, 9)

section(playersPage, "ADMIN ACTIONS")
button(playersPage, "☠️  KILL SELECTED", function()
    adminAction("Kill", selectedTarget)
end, "danger")
button(playersPage, "🚪  KICK SELECTED", function()
    adminAction("Kick", selectedTarget)
end, "warn")

local playersListFrame = Instance.new("Frame")
playersListFrame.Size = UDim2.new(1, 0, 0, 0)
playersListFrame.AutomaticSize = Enum.AutomaticSize.Y
playersListFrame.BackgroundTransparency = 1
playersListFrame.Parent = playersPage
local playersList = list(playersListFrame, 6)

local function setSelectedTarget(plr)
    selectedTarget = plr
    if plr then
        selectedLabel.Text = "👤  Selected: " .. plr.DisplayName .. "  @" .. plr.Name
        selectedLabel.TextColor3 = CONFIG.Colors.Text
    else
        selectedLabel.Text = "👤  No player selected"
        selectedLabel.TextColor3 = CONFIG.Colors.Muted
    end
end

local function rebuildPlayersList()
    for _, child in ipairs(playersListFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then child:Destroy() end
    end
    local roster = Players:GetPlayers()
    table.sort(roster, function(a,b) return a.DisplayName:lower() < b.DisplayName:lower() end)
    local stillExists = false
    for _, plr in ipairs(roster) do
        if selectedTarget == plr then stillExists = true end
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 40)
        b.BackgroundColor3 = (selectedTarget == plr) and CONFIG.Colors.Accent2 or CONFIG.Colors.Dark
        b.TextColor3 = CONFIG.Colors.Text
        b.Font = Enum.Font.Gotham
        b.TextSize = 12
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.AutoButtonColor = false
        b.Text = "👤  " .. plr.DisplayName .. "  @" .. plr.Name
        b.Parent = playersListFrame
        corner(b, 9)
        addPress(b)
        connect(b.Activated, "SelectPlayer", function()
            setSelectedTarget(plr)
            rebuildPlayersList()
        end)
    end
    if selectedTarget and not stillExists then
        setSelectedTarget(nil)
    end
    if #roster == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1,0,0,30)
        empty.BackgroundTransparency = 1
        empty.Text = tr("No players")
        empty.TextColor3 = CONFIG.Colors.Muted
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.Parent = playersListFrame
    end
end
rebuildPlayersList()
button(playersPage, "🔄  REFRESH PLAYER LIST", rebuildPlayersList, "success")
infoCard(playersPage, "STATUS", "Live — updates automatically", CONFIG.Colors.Success)

--============================================================
-- ENVIRONMENT PAGE
--============================================================
section(environment, "TIME")
button(environment, "DAY", function() setLocalTime(14) end)
button(environment, "SUNSET", function() setLocalTime(18.5) end)
button(environment, "NIGHT", function() setLocalTime(0) end)
slider(environment, "Brightness", 0, 5, Lighting.Brightness, setLocalBrightness)

section(environment, "LIGHTING")
button(environment, "BRIGHTNESS DEFAULT", function()
	Lighting.Brightness = Runtime.baseline.lighting.Brightness
end, "success")
button(environment, "SHADOWS ON", function() Lighting.GlobalShadows = true end)
button(environment, "SHADOWS OFF", function() Lighting.GlobalShadows = false end, "warn")
toggle(environment, "Fullbright", Runtime.settings.fullbright, setFullbright)
toggle(environment, "Remove Fog", Runtime.settings.removeFog, setFog)

section(environment, "PHYSICS")
slider(environment, "Gravity", 0, 300, Workspace.Gravity, setLocalGravity)
button(environment, "GRAVITY DEFAULT", function()
	Workspace.Gravity = Runtime.baseline.gravity or 196.2
end, "success")

--============================================================
-- INTERFACE PAGE
--============================================================
section(interfacePage, "LANGUAGE")
button(interfacePage, "RUSSIAN", function() changeLanguage("RU") end, "success")
button(interfacePage, "ENGLISH", function() changeLanguage("EN") end)

section(interfacePage, "STYLE")
infoCard(interfacePage, "STYLE", "Clean • No tab transition", CONFIG.Colors.Accent)

section(interfacePage, "LAYOUT")
toggle(interfacePage, "Compact Sidebar", Runtime.settings.compactSidebar, function(enabled)
	Runtime.settings.compactSidebar = enabled
	Runtime.compact = enabled
	updateLayout()
	applyLanguage()
end)
toggle(interfacePage, "Show Floating Launcher", Runtime.settings.showLauncher, function(enabled)
	Runtime.settings.showLauncher = enabled
	if launcher then launcher.Visible = enabled and not Runtime.panelOpen end
end)

section(interfacePage, "EXTRA")
button(interfacePage, "REFRESH CHARACTER", function()
	captureBaseline()
	applyCharacterSettings()
	toast("Character", "Character settings refreshed.", "success")
end, "success")

--============================================================
-- PRESETS PAGE
--============================================================
section(presets, "ONE-TAP PROFILES")
button(presets, "DEFAULT", function()
	disableMovementFeatures()
	restoreBaselineMovement()
	restoreWorld()
	resetCameraZoom()
	resetCamera()
	toast("Preset", "Default profile applied.", "success")
end, "success")
button(presets, "SPEED", function()
	setWalkSpeed(50)
	setJumpPower(90)
	toast("Preset", "Speed profile applied.", "success")
end)
button(presets, "LOW GRAVITY", function()
	setLocalGravity(50)
	setJumpPower(90)
	toast("Preset", "Low-gravity profile applied.", "success")
end)
button(presets, "BRIGHT", function()
	setFullbright(true)
	setFog(true)
	setFov(85)
	toast("Preset", "Bright profile applied.", "success")
end)
button(presets, "RESET EVERYTHING", fullSafeReset, "danger")

section(presets, "TIP")
local presetTip = Instance.new("TextLabel")
presetTip.Size = UDim2.new(1, 0, 0, 62)
presetTip.BackgroundColor3 = CONFIG.Colors.Card
registerText(presetTip, "Profiles are local and can be changed at any time. Use Default to return to the captured baseline.")
presetTip.Text = tr("Profiles are local and can be changed at any time. Use Default to return to the captured baseline.")
presetTip.Font = Enum.Font.Gotham
presetTip.TextSize = 11
presetTip.TextColor3 = CONFIG.Colors.Muted
presetTip.TextWrapped = true
presetTip.TextXAlignment = Enum.TextXAlignment.Left
presetTip.TextYAlignment = Enum.TextYAlignment.Center
presetTip.Parent = presets
corner(presetTip, 10)
stroke(presetTip, CONFIG.Colors.Border, 1, 0.35)
padding(presetTip, 12, 12, 8, 8)

--============================================================
-- ABOUT PAGE
--============================================================
section(about, "UTILITY HUB")
infoCard(about, "VERSION", "V18 SAKURA SMOOTH", CONFIG.Colors.Accent)
infoCard(about, "DEVICE", Runtime.device, CONFIG.Colors.Success)
infoCard(about, "PAGES", tostring(#navigation), CONFIG.Colors.Accent)
section(about, "CONTROLS")
local controlsInfo = Instance.new("TextLabel")
controlsInfo.Size = UDim2.new(1, 0, 0, 92)
controlsInfo.BackgroundColor3 = CONFIG.Colors.Card
registerText(controlsInfo, "K  —  show / hide panel\nMouse / touch  —  buttons, sliders and scrolling\nUse the left sidebar to switch pages. There are no page-slide transitions; the sidebar uses fixed top/bottom fades.")
controlsInfo.Text = tr("K  —  show / hide panel\nMouse / touch  —  buttons, sliders and scrolling\nUse the left sidebar to switch pages. The sidebar now scrolls when there are many tabs.")
controlsInfo.Font = Enum.Font.Gotham
controlsInfo.TextSize = 11
controlsInfo.TextColor3 = CONFIG.Colors.Muted
controlsInfo.TextWrapped = true
controlsInfo.TextXAlignment = Enum.TextXAlignment.Left
controlsInfo.TextYAlignment = Enum.TextYAlignment.Center
controlsInfo.Parent = about
corner(controlsInfo, 10)
stroke(controlsInfo, CONFIG.Colors.Border, 1, 0.35)
padding(controlsInfo, 12, 12, 8, 8)

--============================================================
-- MOBILE TOUCH FLIGHT
--============================================================
local function createTouchFlight()
	if touchFlight then
		touchFlight:Destroy()
		touchFlight = nil
	end

	if Runtime.device ~= "Mobile" and Runtime.device ~= "Tablet" then
		return
	end

	touchFlight = Instance.new("Frame")
	touchFlight.Name = "TouchFlight"
	touchFlight.AnchorPoint = Vector2.new(1, 1)
	touchFlight.Position = UDim2.new(1, -18, 1, -18)
	touchFlight.Size = UDim2.new(0, 250, 0, 150)
	touchFlight.BackgroundTransparency = 1
	touchFlight.ZIndex = 350
	touchFlight.Visible = false
	touchFlight.Parent = gui

	local state = {
		W = false, A = false, S = false, D = false, Up = false, Down = false
	}

	local function makeTouch(text, x, y, key)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 58, 0, 42)
		b.Position = UDim2.new(0, x, 0, y)
		b.BackgroundColor3 = CONFIG.Colors.Card
		b.Text = text
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.TextColor3 = CONFIG.Colors.Text
		b.AutoButtonColor = false
		b.Parent = touchFlight
		corner(b, 11)
		stroke(b, CONFIG.Colors.Accent, 1, 0.35)
		addPress(b)

		connect(b.InputBegan, "TouchFlightDown", function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1 then
				state[key] = true
			end
		end)

		connect(b.InputEnded, "TouchFlightUp", function(input)
			if input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1 then
				state[key] = false
			end
		end)

		return b
	end

	makeTouch("▲", 96, 0, "Up")
	makeTouch("◀", 16, 52, "A")
	makeTouch("W", 96, 52, "W")
	makeTouch("▶", 176, 52, "D")
	makeTouch("S", 96, 104, "S")
	makeTouch("▼", 176, 104, "Down")

	Runtime.touchState = state

	-- Flight render reads this optional state.
	-- Keyboard remains available too.
end

--============================================================
-- DRAG WINDOW
--============================================================
local function makeDraggable(handle, target)
	local dragging = false
	local dragStart = nil
	local startPosition = nil

	connect(handle.InputBegan, "WindowDragBegin", function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = target.Position
		end
	end)

	connect(UserInputService.InputChanged, "WindowDragMove", function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - dragStart
		target.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end)

	connect(UserInputService.InputEnded, "WindowDragEnd", function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

makeDraggable(header, main)

local function refreshPlayersSafely()
    if Runtime.destroyed then return end
    if playersPage and playersPage.Parent then rebuildPlayersList() end
end
connect(Players.PlayerAdded, "PlayersAdded", refreshPlayersSafely)
connect(Players.PlayerRemoving, "PlayersRemoving", function(leaving)
    if selectedTarget == leaving then setSelectedTarget(nil) end
    refreshPlayersSafely()
end)

--============================================================
-- UNLOAD / CLEANUP
--============================================================
unloadScript = function()
	if Runtime.destroyed then return end
	Runtime.destroyed = true
	Runtime.panelOpen = false
	pcall(resetAvatarEffects)
	pcall(disableMovementFeatures)
	pcall(restoreBaselineMovement)
	pcall(restoreWorld)
	pcall(resetCamera)
	pcall(hideAccessories, false)
	pcall(hideParticles, false)
	pcall(setEsp, false)
	pcall(restoreCoreGui)
	pcall(restorePostEffects)
	pcall(restoreWorldGui)
	pcall(restoreSound)
	pcall(setMouseIconEnabled, true)
	pcall(restoreCharacterLook)
	disconnectAll()
	if gui and gui.Parent then gui:Destroy() end
	if touchFlight and touchFlight.Parent then touchFlight:Destroy() end
end

--============================================================
-- LANGUAGE APPLY OVERLAY
--============================================================
languageOverlay = Instance.new("Frame")
languageOverlay.Name = "LanguageApplying"
languageOverlay.Size = UDim2.fromScale(1, 1)
languageOverlay.BackgroundColor3 = CONFIG.Colors.Background
languageOverlay.BackgroundTransparency = 0.42
languageOverlay.Visible = false
languageOverlay.ZIndex = 900
languageOverlay.Parent = gui

languageCard = Instance.new("Frame")
languageCard.AnchorPoint = Vector2.new(0.5, 0.5)
languageCard.Position = UDim2.fromScale(0.5, 0.5)
languageCard.Size = UDim2.new(0, 300, 0, 86)
languageCard.BackgroundColor3 = CONFIG.Colors.Panel2
languageCard.ZIndex = 901
languageCard.Parent = languageOverlay
corner(languageCard, 14)
stroke(languageCard, CONFIG.Colors.Border, 1, 0.1)
padding(languageCard, 14, 14, 12, 12)

languageTitle = Instance.new("TextLabel")
languageTitle.Size = UDim2.new(1, 0, 0, 22)
languageTitle.BackgroundTransparency = 1
languageTitle.Text = "Applying language"
languageTitle.Font = Enum.Font.GothamSemibold
languageTitle.TextSize = 14
languageTitle.TextColor3 = CONFIG.Colors.Text
languageTitle.TextXAlignment = Enum.TextXAlignment.Left
languageTitle.ZIndex = 902
languageTitle.Parent = languageCard

languageMessage = Instance.new("TextLabel")
languageMessage.Position = UDim2.new(0, 0, 0, 23)
languageMessage.Size = UDim2.new(1, 0, 0, 20)
languageMessage.BackgroundTransparency = 1
languageMessage.Text = "Please wait…"
languageMessage.Font = Enum.Font.Gotham
languageMessage.TextSize = 11
languageMessage.TextColor3 = CONFIG.Colors.Muted
languageMessage.TextXAlignment = Enum.TextXAlignment.Left
languageMessage.ZIndex = 902
languageMessage.Parent = languageCard

languageBar = Instance.new("Frame")
languageBar.Position = UDim2.new(0, 0, 1, -9)
languageBar.Size = UDim2.new(1, 0, 0, 4)
languageBar.BackgroundColor3 = CONFIG.Colors.Card
languageBar.ZIndex = 902
languageBar.Parent = languageCard
corner(languageBar, 3)

languageBarFill = Instance.new("Frame")
languageBarFill.Size = UDim2.new(0, 0, 1, 0)
languageBarFill.BackgroundColor3 = CONFIG.Colors.Accent
languageBarFill.ZIndex = 903
languageBarFill.Parent = languageBar
corner(languageBarFill, 3)
gradient(languageBarFill, CONFIG.Colors.Accent, CONFIG.Colors.Accent2, 0)

--============================================================
-- PANEL OPEN / CLOSE
--============================================================
launcher = Instance.new("TextButton")
launcher.AnchorPoint = Vector2.new(1, 1)
launcher.Position = UDim2.new(1, -18, 1, -18)
launcher.Size = UDim2.new(0, 58, 0, 58)
launcher.BackgroundColor3 = CONFIG.Colors.Accent2
launcher.Text = "🚀"
launcher.Font = Enum.Font.GothamBold
launcher.TextSize = 24
launcher.TextColor3 = CONFIG.Colors.Text
launcher.AutoButtonColor = false
launcher.ZIndex = 400
launcher.Parent = gui
corner(launcher, 18)
stroke(launcher, CONFIG.Colors.Accent, 1.5, 0.15)
gradient(launcher, CONFIG.Colors.Accent, CONFIG.Colors.Accent2, 135)
addPress(launcher)

-- Gentle floating animation for the launcher.
task.spawn(function()
	while not Runtime.destroyed and launcher.Parent do
		if not Runtime.panelOpen then
			tween(launcher, 0.9, {Rotation = 3}, Enum.EasingStyle.Sine)
			task.wait(0.9)
			if Runtime.destroyed then break end
			tween(launcher, 0.9, {Rotation = -3}, Enum.EasingStyle.Sine)
			task.wait(0.9)
		else
			task.wait(0.5)
		end
	end
end)

local function showPanel()
	Runtime.panelOpen = true
	main.Visible = true
	main.BackgroundTransparency = 1
	mainScale.Scale = 0.96
	tween(main, 0.25, {BackgroundTransparency = 0}, Enum.EasingStyle.Quad)
	tween(mainScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
	launcher.Visible = false

	if touchFlight then
		touchFlight.Visible = Runtime.device == "Mobile" or Runtime.device == "Tablet"
	end
end

local function hidePanel()
	Runtime.panelOpen = false
	tween(mainScale, 0.18, {Scale = 0.96})
	tween(main, 0.18, {BackgroundTransparency = 1})
	task.delay(0.19, function()
		if Runtime.panelOpen or Runtime.destroyed then return end
		main.Visible = false
	end)

	launcher.Visible = Runtime.settings.showLauncher
	if touchFlight then touchFlight.Visible = false end
end

local function showLock()
	lockOverlay.Visible = true
	lockCard.Position = UDim2.fromScale(0.5, 0.54)
	tween(lockCard, 0.25, {Position = UDim2.fromScale(0.5, 0.5)}, Enum.EasingStyle.Back)
	tween(blur, 0.2, {Size = 12})
	task.delay(0.05, function()
		if lockOverlay.Visible then passcode:CaptureFocus() end
	end)
end

local function hideLock()
	tween(blur, 0.18, {Size = 0})
	tween(lockCard, 0.18, {Position = UDim2.fromScale(0.5, 0.54)})
	task.delay(0.19, function()
		if Runtime.unlocked then
			lockOverlay.Visible = false
		end
	end)
end

connect(closeButton.Activated, "ClosePanel", hidePanel)
local function changeLanguage(lang)
	if Runtime.destroyed or not Runtime.unlocked then return end
	if Runtime.language == lang then
		-- Same language: do nothing instead of opening a fake loading state.
		applyLanguage()
		return
	end
	Runtime.language = lang
	Runtime.panelOpen = false
	main.Visible = false
	launcher.Visible = false
	applyLanguage()
	showLanguageApplying()
end

connect(languageRU.Activated, "LangRU", function() changeLanguage("RU") end)
connect(languageEN.Activated, "LangEN", function() changeLanguage("EN") end)
connect(launcher.Activated, "Launcher", function()
	if Runtime.unlocked then
		if Runtime.panelOpen then hidePanel() else showPanel() end
	else
		showLock()
	end
end)

local function tryUnlock()
	if passcode.Text == CONFIG.PASSWORD then
		Runtime.unlocked = true
		passError.Text = ""
		hideLock()
		showPanel()
		toast("Access", "Panel unlocked.", "success")
	else
		passError.Text = tr("Incorrect access code.")
		passcode.Text = ""
		tween(lockCard, 0.05, {Position = UDim2.fromScale(0.505, 0.5)})
		task.wait(0.05)
		tween(lockCard, 0.05, {Position = UDim2.fromScale(0.495, 0.5)})
		task.wait(0.05)
		tween(lockCard, 0.08, {Position = UDim2.fromScale(0.5, 0.5)})
	end
end

connect(unlock.Activated, "Unlock", tryUnlock)
connect(passcode.FocusLost, "UnlockEnter", function(enterPressed)
	if enterPressed then tryUnlock() end
end)

--============================================================
-- KEYBINDS
--============================================================
connect(UserInputService.InputBegan, "ToggleKey", function(input, processed)
	if processed then return end
	if input.KeyCode ~= CONFIG.TOGGLE_KEY then return end

	if not Runtime.unlocked then
		showLock()
	elseif Runtime.panelOpen then
		hidePanel()
	else
		showPanel()
	end
end)

--============================================================
-- STATUS / FPS
--============================================================
local frameTime = 0
local frameCount = 0
local fps = 0

connect(RunService.RenderStepped, "FpsCounter", function(dt)
	frameTime += dt
	frameCount += 1

	if frameTime >= 0.5 then
		fps = math.floor(frameCount / frameTime + 0.5)
		frameTime = 0
		frameCount = 0
	end
end)

task.spawn(function()
	while not Runtime.destroyed do
		local camera = getCamera()
		local root = rootPart()
		local h = humanoid()

		deviceValue.Text = detectDevice()
		characterValue.Text = h and ("Ready • " .. h:GetState().Name) or "Not loaded"

		if root then
			local p = root.Position
			positionValue.Text = string.format("%d, %d, %d", p.X, p.Y, p.Z)
		else
			positionValue.Text = "—"
		end

		fpsValue.Text = tr("FPS") .. ": " .. tostring(fps)

		local stateText = h and h:GetState().Name or "No character"
		local velocityText = root and string.format("%.1f", root.AssemblyLinearVelocity.Magnitude) or "0"

		dashboardStatus.Text =
			("%s: %s\n%s: %s\n%s: %s\n%s: %s"):format(
				tr("DEVICE"), Runtime.device, tr("CHARACTER"), stateText, tr("VELOCITY"), velocityText, tr("PAGE"), tr(Runtime.currentPage)
			)

		serverIdInfo.Text = game.JobId ~= "" and game.JobId or "Studio"
		placeIdInfo.Text = tostring(game.PlaceId)
		playersInfo.Text = tostring(#Players:GetPlayers())

		diagnostics.Text = Runtime.destroyed and "Stopped" or "Healthy"
		task.wait(0.35)
	end
end)

--============================================================
-- RESPONSIVE LAYOUT
--============================================================
updateLayout = function()
	local camera = getCamera()
	if not camera then return end

	detectDevice()
	local vp = camera.ViewportSize
	local mobile = Runtime.device == "Mobile" or Runtime.device == "Tablet" or Runtime.device == "Console"

	if mobile then
		statusPill.Visible = false
		local wScale = vp.X < 380 and 0.985 or 0.96
		local hScale = vp.Y < 620 and 0.92 or 0.86
		main.Size = UDim2.new(wScale, 0, hScale, 0)
		nav.Size = UDim2.new(0, vp.X < 380 and 78 or 92, 1, -86)
		content.Position = UDim2.new(0, vp.X < 380 and 90 or 104, 0, 74)
		content.Size = UDim2.new(1, vp.X < 380 and -100 or -116, 1, -86)

		for _, item in ipairs(navigation) do
			local btn = navButtons[item[1]]
			if btn then
				btn.Text = item[2]
				btn.TextXAlignment = Enum.TextXAlignment.Center
			end
		end
	else
		main.Size = UDim2.new(0.82, 0, 0.84, 0)
		local navWidth = Runtime.compact and 92 or 176
		local contentX = Runtime.compact and 114 or 198
		local contentW = Runtime.compact and -126 or -210
		nav.Size = UDim2.new(0, navWidth, 1, -86)
		content.Position = UDim2.new(0, contentX, 0, 74)
		content.Size = UDim2.new(1, contentW, 1, -86)

		for _, item in ipairs(navigation) do
			local btn = navButtons[item[1]]
			btn.Text = Runtime.compact and item[2] or (item[2] .. "   " .. tr(item[1]))
			btn.TextXAlignment = Runtime.compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
		end
	end

	local isTiny = vp.X < 420
	launcher.Size = UDim2.new(0, isTiny and 52 or 58, 0, isTiny and 52 or 58)
	updateNavFadeLayout()
	task.defer(updateNavScales)
end

applyLanguage()
switchPage("Dashboard")
updateLayout()
updateNavFadeLayout()
task.defer(updateNavScales)
createTouchFlight()
Runtime.touchState = Runtime.touchState or nil

do
	local currentCamera = getCamera()
	if currentCamera then
		connect(currentCamera:GetPropertyChangedSignal("ViewportSize"), "Viewport", updateLayout)
	end
end

connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), "CameraChanged", function()
	updateLayout()
	local currentCamera = getCamera()
	if currentCamera then
		connect(currentCamera:GetPropertyChangedSignal("ViewportSize"), "ViewportChanged", updateLayout)
	end
end)

--============================================================
-- CHARACTER LIFECYCLE
--============================================================
connect(player.CharacterAdded, "CharacterAdded", function()
	task.wait(0.25)

	-- Stop transient movement effects on respawn.
	setFlight(false)
	setNoclip(false)

	captureBaseline()
	applyCharacterSettings()

	if Runtime.settings.autoRotate then
		local h = humanoid()
		if h then h.AutoRotate = true end
	end

	if Runtime.settings.accessoriesHidden then
		hideAccessories(true)
	end
	if Runtime.settings.particlesHidden then
		hideParticles(true)
	end
	if Runtime.settings.platformStand then setPlatformStand(true) end
	if Runtime.settings.freezeSelf then setFreezeSelf(true) end
	refreshAppearance()

	toast("Character", "Character refreshed safely.", "success")
end)

connect(player.CharacterRemoving, "CharacterRemoving", function()
	setFlight(false)
	setNoclip(false)
end)

--============================================================
-- INITIALIZE
--============================================================
detectDevice()
captureBaseline()
applyCharacterSettings()
setAntiAfk(true)

-- Use saved values for controls after baseline capture.
Runtime.settings.walkSpeed = Runtime.baseline.walkSpeed or Runtime.settings.walkSpeed
Runtime.settings.jumpPower = Runtime.baseline.jumpPower or Runtime.settings.jumpPower
Runtime.settings.autoRotate = Runtime.baseline.autoRotate ~= false
Runtime.settings.gravity = Runtime.baseline.gravity
Runtime.compact = Runtime.settings.compactSidebar

-- Re-apply actual utility defaults only when the user changes them.
switchPage("Dashboard")

-- Mobile/console launcher always available.
launcher.Visible = Runtime.settings.showLauncher

-- Start locked for all devices.
showLock()

--============================================================
-- SAFE SHUTDOWN
--============================================================
connect(player.AncestryChanged, "PlayerAncestry", function(_, parent)
	if parent ~= nil then return end

	Runtime.destroyed = true

	pcall(function()
		setFlight(false)
		setNoclip(false)
		setInfiniteJump(false)
	end)

	removeAllEsp()
	restoreWorld()
	resetCamera()

	disconnectAll()

	if touchFlight then
		touchFlight:Destroy()
		touchFlight = nil
	end

	pcall(function()
		blur:Destroy()
	end)

	pcall(function()
		gui:Destroy()
	end)
end)

--============================================================
-- FINAL VALIDATION
--============================================================
task.defer(function()
	if Runtime.destroyed then return end

	local checks = {
		gui = gui.Parent ~= nil,
		main = main.Parent ~= nil,
		dashboard = pages.Dashboard ~= nil,
		movement = pages.Movement ~= nil,
		flight = pages.Flight ~= nil,
		teleport = pages.Teleport ~= nil,
		visuals = pages.Visuals ~= nil,
		camera = pages.Camera ~= nil,
		player = pages.Player ~= nil,
		environment = pages.Environment ~= nil,
		server = pages.Server ~= nil,
		interface = pages.Interface ~= nil,
		presets = pages.Presets ~= nil,
		about = pages.About ~= nil,
		safety = pages.Safety ~= nil,
		tools = pages.Tools ~= nil,
		hud = pages.HUD ~= nil,
		postfx = pages.PostFX ~= nil,
		audio = pages.Audio ~= nil,
		performance = pages.Performance ~= nil,
		input = pages.Input ~= nil,
		appearance = pages.Appearance ~= nil,
	}

	for name, ok in pairs(checks) do
		if not ok then
			warn("[UtilityPanel V11] UI check failed: " .. name)
		end
	end
end)
