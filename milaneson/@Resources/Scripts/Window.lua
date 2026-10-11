-- Ajustes de ventana de cada widget (los mismos del menú contextual de Rainmeter).
-- Lee la sección del widget en Rainmeter.ini, publica los valores como variables del Hub
-- y aplica los cambios escribiendo en Rainmeter.ini + refrescando el widget.

local DEFAULTS = {
	ClickThrough = '0', Draggable = '1', KeepOnScreen = '1', SavePosition = '1',
	SnapEdges = '1', OnHover = '0', AlwaysOnTop = '0', AlphaValue = '255', WindowX = '',
}
local ALPHAS = { 255, 217, 178, 128, 77 }   -- 100 %, 85 %, 70 %, 50 %, 30 %
local MARGIN = 16

local iniPath, root, current
local lastCorner = 'TL'

function Initialize()
	iniPath = SKIN:ReplaceVariables('#SETTINGSPATH#') .. 'Rainmeter.ini'
	root = SKIN:ReplaceVariables('#ROOTCONFIG#')
end

function Update() end

-- Rainmeter.ini está en UTF-16 LE; las claves que nos importan son ASCII.
local function readIni()
	local f = io.open(iniPath, 'rb')
	if not f then return '' end
	local s = f:read('*a')
	f:close()
	if s:byte(1) == 255 and s:byte(2) == 254 then
		local out = {}
		for i = 3, #s - 1, 2 do
			local lo, hi = s:byte(i, i + 1)
			out[#out + 1] = (hi == 0) and string.char(lo) or '?'
		end
		s = table.concat(out)
	end
	return s
end

local function readSection(name)
	local s = readIni()
	local header = '[' .. name .. ']'
	local i = s:find(header, 1, true)
	local values = {}
	if not i then return values end
	local body = s:sub(i + #header)
	local stop = body:find('\n%[')
	if stop then body = body:sub(1, stop) end
	for k, v in body:gmatch('(%w+)=([^\r\n]*)') do values[k] = v end
	return values
end

local function configName() return root .. '\\' .. current end

function Load(target)
	current = target or current
	local sec = readSection(configName())
	local function get(k)
		local v = sec[k]
		if v == nil or v == '' then return DEFAULTS[k] end
		return v
	end
	local function set(k, v) SKIN:Bang('!SetVariable', k, v) end

	for _, k in ipairs({ 'ClickThrough', 'Draggable', 'KeepOnScreen', 'SavePosition', 'SnapEdges' }) do
		set('Win' .. k, (get(k) == '1') and '1' or '0')
	end
	set('WinHoverIdx', tostring(math.max(0, math.min(3, tonumber(get('OnHover')) or 0))))
	set('WinZIdx', tostring(math.max(0, math.min(4, (tonumber(get('AlwaysOnTop')) or 0) + 2))))

	local alpha, best, bestDiff = tonumber(get('AlphaValue')) or 255, 0, 999
	for i, a in ipairs(ALPHAS) do
		if math.abs(a - alpha) < bestDiff then best, bestDiff = i - 1, math.abs(a - alpha) end
	end
	set('WinAlphaIdx', tostring(best))
	set('WinMon', get('WindowX'):match('@(%d+)') or '0')

	SKIN:Bang('!UpdateMeter', '*')
	SKIN:Bang('!Redraw')
end

local function apply(values)
	if not current then return end
	local name = configName()
	for k, v in pairs(values) do
		SKIN:Bang('!WriteKeyValue', name, k, v, iniPath)
	end
	SKIN:Bang('!Refresh', name)
	Load(current)
end

function Toggle(key)
	local v = tonumber(SKIN:GetVariable('Win' .. key, '0')) or 0
	apply({ [key] = tostring(1 - v) })
end

-- Aparecer (2) y Atenuar (3) usan AlphaValue como nivel "atenuado": con 100 % no se
-- vería ningún efecto, así que en ese caso se baja a 30 %.
function SetHover(idx)
	local v = { OnHover = tostring(idx) }
	local alphaIdx = tonumber(SKIN:GetVariable('WinAlphaIdx', '0')) or 0
	if (idx == 2 or idx == 3) and alphaIdx <= 1 then v.AlphaValue = tostring(ALPHAS[5]) end
	apply(v)
end
function SetZ(idx) apply({ AlwaysOnTop = tostring(idx - 2) }) end
function SetAlpha(idx) apply({ AlphaValue = tostring(ALPHAS[idx + 1] or 255) }) end

-- Esquinas / centro del monitor elegido (WinMon; si no hay, el 1)
function Place(corner, monitor)
	lastCorner = corner or lastCorner
	local n = tonumber(monitor) or tonumber(SKIN:GetVariable('WinMon', '0')) or 0
	if n < 1 then n = 1 end
	local m, at = MARGIN, '@' .. n
	local v = {}
	-- Código de 1-2 letras: horizontal L / (centro) / R y vertical T / (medio) / B.
	-- Ej.: TL, T, TR, L, C, R, BL, B, BR
	local code = lastCorner
	if code:find('L') then v.WindowX, v.AnchorX = m .. at, '0'
	elseif code:find('R') then v.WindowX, v.AnchorX = m .. 'R' .. at, '100%'
	else v.WindowX, v.AnchorX = '50%' .. at, '50%' end
	if code:find('T') then v.WindowY, v.AnchorY = m .. at, '0'
	elseif code:find('B') then v.WindowY, v.AnchorY = m .. 'B' .. at, '100%'
	else v.WindowY, v.AnchorY = '50%' .. at, '50%' end
	apply(v)
end

function Monitor(n) Place(lastCorner, n) end
