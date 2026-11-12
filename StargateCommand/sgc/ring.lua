--
-- sgc.ring - draws a stargate on a pixel canvas (sgc.pixels)
--
-- local ring = Ring.new(canvas, cx, cy, radius)
-- ring:draw(style, view)
--
-- view = {
--   t        = os.clock(),           animation clock
--   symbols  = 39,                   symbols on the ring
--   rotation = 0,                    inner ring rotation in degrees
--   lit      = 3, total = 7,         chevrons locked / chevrons in the address
--   glyphs   = { [26] = true },      lit symbols (Pegasus and Universe style gates)
--   chase    = 123,                  angle of the dialing light, or nil
--   openedAt = clock, closingAt = clock,   wormhole open / closing since
--   iris     = 0-100,                percent closed, nil = no iris
-- }
--

local S = require("sgc.styles")

local Ring = {}
Ring.__index = Ring

local IDX = {}
for i = 0, 15 do IDX[2 ^ i] = i end

local sin, cos, floor, sqrt, atan2, rad, abs = math.sin, math.cos, math.floor, math.sqrt, math.atan2 or math.atan, math.rad, math.abs
if not math.atan2 then atan2 = function(y, x) return math.atan(y, x) end end

-- chevron angles (clockwise from the top) in locking order; the 9th is the master chevron
Ring.CHEVRON_ANGLES = { 40, 80, 120, 240, 280, 320, 160, 200, 0 }
local POSITION_OF_ANGLE = {}
for k, a in ipairs(Ring.CHEVRON_ANGLES) do POSITION_OF_ANGLE[a / 40] = k end

-- position (1-9) of chevron number i in an address of total chevrons
function Ring.position(i, total)
    if i >= total then return 9 end
    return i
end

local Z_NONE, Z_STONE, Z_SHADE, Z_TRACK, Z_RIM, Z_HORIZON, Z_BAND = 0, 1, 2, 3, 4, 5, 6

function Ring.new(canvas, cx, cy, radius)
    local self = setmetatable({ canvas = canvas, cx = cx, cy = cy, R = radius, zones = {} }, Ring)
    local pi, prn, pang = {}, {}, {}
    local w = canvas.w
    local reach = radius * 1.09
    for y = math.max(1, floor(cy - reach)), math.min(canvas.h, floor(cy + reach) + 1) do
        for x = math.max(1, floor(cx - reach)), math.min(canvas.w, floor(cx + reach) + 1) do
            local dx, dy = (x - 0.5) - cx, (y - 0.5) - cy
            local d = sqrt(dx * dx + dy * dy) / radius
            if d <= 1.09 then
                local a = math.deg(atan2(dx, -dy)) % 360
                pi[#pi + 1] = (y - 1) * w + x
                prn[#prn + 1] = d
                pang[#pang + 1] = a
            end
        end
    end
    self.pi, self.prn, self.pang = pi, prn, pang
    return self
end

-- a fixed starfield for space backgrounds (the Ori supergate): colour or nil
function Ring.starAt(x, y)
    local h = (x * 7919 + y * 104729 + (x * y) % 131) % 1009
    if h < 3 then return colors.white end
    if h < 9 then return colors.lightGray end
    if h < 14 then return colors.gray end
    return nil
end

-- background colour of every gate pixel for styles drawn in space (cached)
function Ring:background()
    if self.bg then return self.bg end
    local bg, w = {}, self.canvas.w
    local black = IDX[colors.black]
    for j, p in ipairs(self.pi) do
        local x, y = (p - 1) % w + 1, floor((p - 1) / w) + 1
        local star = Ring.starAt(x, y)
        bg[j] = star and IDX[star] or black
    end
    self.bg = bg
    return bg
end

-- zones of a supergate: separate segments with gaps, no symbols or chevrons
--   100 + k  segment body      200 + k  glowing seam      400 + k  segment edge
--   300 + b  gap before segment b (energy arcs jump across it)
function Ring:segmentZones(style)
    local zone = {}
    local n = style.segments or 40
    local segW = 360 / n
    local inner, horizonR = style.ring.track, style.ring.horizon
    local px = 1 / self.R
    local seamIn, seamOut = inner + (1 - inner) * 0.38, inner + (1 - inner) * 0.62
    for j = 1, #self.pi do
        local d, a = self.prn[j], self.pang[j]
        local z = Z_NONE
        if d <= horizonR then
            z = Z_HORIZON
        elseif d >= inner and d <= 1 then
            local sgm = a / segW
            local k = floor(sgm)
            local f = sgm - k
            -- the gap is about 1.5 pixels wide whatever the size
            local gap = math.max(0.06, 0.75 / (d * self.R * rad(segW)))
            if f < gap then
                z = 300 + k % n
            elseif f > 1 - gap then
                z = 300 + (k + 1) % n
            elseif d > 1 - 1.2 * px or d < inner + 1.0 * px or f < gap + 0.05 or f > 1 - gap - 0.05 then
                z = 400 + k % n
            elseif d > seamIn and d < seamOut then
                z = 200 + k % n
            else
                z = 100 + k % n
            end
        end
        zone[j] = z
    end
    return zone
end

-- per pixel zone for a style (cached)
function Ring:zonesFor(style)
    local cached = self.zones[style.id]
    if cached then return cached end
    if style.shape == "segments" then
        self.zones[style.id] = self:segmentZones(style)
        return self.zones[style.id]
    end
    local zone = {}
    local R = self.R
    local ring = style.ring
    local trackR, rimR, horizonR = ring.track, ring.rim, ring.horizon
    local px = 1 / R -- one pixel in radius units
    local cw = style.chevronWidth
    local r0, r1, hwIn, hwOut
    if style.shape == "light" then
        r0, r1, hwIn, hwOut = 0.86, 0.97, 2.4, 2.4
    elseif style.shape == "slim" then
        r0, r1, hwIn, hwOut = 0.83, 1.03, 1.4, 3.4
    else
        r0, r1, hwIn, hwOut = trackR - 0.05, 1.06, 2.2 * cw, 7.5 * cw
    end
    for j = 1, #self.pi do
        local d, a = self.prn[j], self.pang[j]
        local z = Z_NONE
        if d <= horizonR then
            z = Z_HORIZON
        elseif d <= rimR then
            z = Z_RIM
        elseif d <= trackR then
            z = style.track and Z_TRACK or Z_STONE
        elseif d <= 1 then
            z = Z_STONE
            -- shading: outer edge, inner edge and the seams between chevrons
            if d > 1 - 1.2 * px or d < trackR + 1.0 * px then
                z = Z_SHADE
            else
                local seam = (a + 20) % 40
                if rad(math.min(seam, 40 - seam)) * d * R < 0.55 then z = Z_SHADE end
            end
        end
        if z == Z_STONE and not style.track and style.shape == "light" and d > rimR + 0.05 and d < 0.84 then
            z = Z_BAND
        end
        -- chevrons
        if d >= r0 and d <= r1 then
            local slot = floor(a / 40 + 0.5) % 9
            local diff = abs(a - slot * 40)
            if diff > 180 then diff = 360 - diff end
            local f = (d - r0) / (r1 - r0)
            local hw = hwIn + (hwOut - hwIn) * f
            if diff <= hw then
                local k = POSITION_OF_ANGLE[slot]
                if style.shape == "v" then
                    -- housing with a V shaped light inside
                    local light = diff <= hw * 0.62 and f > 0.12 and f < 0.86
                    local core = diff <= hw * 0.22 and f > 0.2 and f < 0.8
                    z = core and (30 + k) or light and (20 + k) or (10 + k)
                else
                    z = (diff <= hw * 0.45 and f > 0.2 and f < 0.8) and (30 + k) or (20 + k)
                end
            end
        end
        zone[j] = z
    end
    self.zones[style.id] = zone
    return zone
end

local function horizonSwirl(h, a, t)
    local ar = rad(a)
    -- rings of light rolling outwards, bent by two slow waves around the gate
    local bend = 1.3 * h * sin(ar * 2 + t * 0.6) + 0.7 * h * h * sin(ar * 5 - t * 0.9)
    return 0.24 + 0.46 * (1 - h) ^ 1.4 + 0.17 * sin(h * 15 - t * 3 + bend)
end

local function swirlColor(v)
    if v < 0.36 then return IDX[colors.blue] end
    if v < 0.56 then return IDX[colors.cyan] end
    if v < 0.8 then return IDX[colors.lightBlue] end
    return IDX[colors.white]
end

function Ring:draw(style, view)
    local zone = self:zonesFor(style)
    local px = self.canvas.px
    local pi, prn, pang = self.pi, self.prn, self.pang
    local t = view.t or 0
    local symbols = view.symbols or 39
    local segW = 360 / symbols
    local rot = view.rotation or 0
    local glyphs = view.glyphs or {}
    local horizonR = style.ring.horizon
    local trackR, rimR = style.ring.track, style.ring.rim
    local R = self.R
    local total = view.total or 7
    local lit = view.lit or 0

    -- chevron colours by position
    local chevOn = {}
    for i = 1, math.min(lit, total) do
        chevOn[Ring.position(i, total)] = IDX[S.chevronColor(style, i, total)]
    end
    local OFF, HOUSING, CORE = IDX[colors.magenta], IDX[colors.gray], IDX[colors.yellow]
    local STONE, SHADE, TRACK, GLYPH, LITGLYPH, RIM = IDX[colors.lightGray], IDX[colors.gray], IDX[colors.brown], IDX[colors.pink], IDX[colors.orange], IDX[colors.gray]
    local BLACK = IDX[colors.black]
    local IRIS_DARK, IRIS_LIGHT = IDX[colors.purple], IDX[colors.green]

    -- horizon mode
    local mode, age = nil, 0
    if view.openedAt then
        age = t - view.openedAt
        mode = age < 1.6 and "kawoosh" or "open"
    elseif view.closingAt and t - view.closingAt < 0.8 then
        mode, age = "closing", t - view.closingAt
    end
    local irisAperture = view.iris and (1 - view.iris / 100) * horizonR or nil
    local chase = view.chase and floor(((view.chase - rot) % 360) / segW + 0.5) % symbols
    local BG = style.stars and self:background() or nil

    -- supergate segments: they light one after another as the gate dials
    local segLit, arcs = {}, false
    if style.shape == "segments" then
        local n = style.segments or 40
        local count = (view.openedAt or (total > 0 and lit >= total)) and n or floor(n * lit / math.max(total, 1))
        for k = 0, count - 1 do segLit[k] = true end
        if view.chase and count < n and floor(t * 6) % 2 == 0 then segLit[count] = true end
        -- energy arcs while it dials and as the wormhole forms
        arcs = count > 0 and (not view.openedAt or t - view.openedAt < 1.6)
    end
    local LIT, HOT, ARC, WHITE = IDX[colors.orange], IDX[colors.yellow], IDX[colors.lightBlue], IDX[colors.white]

    for j = 1, #pi do
        local z = zone[j]
        local c
        if z >= 100 then
            local kind, k = floor(z / 100), z % 100
            if kind == 3 then
                local n = style.segments or 40
                if arcs and segLit[(k - 1) % n] and segLit[k] then
                    local flicker = (k * 13 + floor(t * 14) + floor(prn[j] * R)) % 5
                    c = flicker == 0 and WHITE or flicker < 3 and ARC or (BG and BG[j] or BLACK)
                else
                    c = BG and BG[j] or BLACK
                end
            elseif kind == 4 then
                c = SHADE
            elseif kind == 2 then
                c = segLit[k] and HOT or SHADE
            else
                c = segLit[k] and LIT or STONE
            end
        elseif z == Z_NONE then
            c = BG and BG[j] or nil
        elseif z == Z_STONE then
            c = STONE
        elseif z == Z_SHADE or z == Z_RIM then
            c = SHADE
        elseif z == Z_TRACK or z == Z_BAND then
            local d = prn[j]
            local s = ((pang[j] - rot) % 360) / segW + 0.5
            local seg = floor(s)
            local f = s - seg
            seg = seg % symbols
            local band = z == Z_TRACK and (d > rimR + (trackR - rimR) * 0.28 and d < trackR - (trackR - rimR) * 0.22)
                or (z == Z_BAND and d > rimR + 0.03 and d < 0.82)
            if z == Z_TRACK and (f < 0.5 / (d * R * rad(segW)) * 1.0 or f > 1 - 0.5 / (d * R * rad(segW))) then
                c = SHADE
            elseif band and f > 0.32 and f < 0.68 then
                c = (style.glyphLight and (glyphs[seg] or chase == seg)) and LITGLYPH or GLYPH
            else
                c = z == Z_TRACK and TRACK or STONE
            end
        elseif z == Z_HORIZON then
            local d = prn[j]
            if irisAperture and d >= irisAperture then
                local q = pang[j] / 360 * 20 + (d / horizonR) * 2.4
                local f = q - floor(q)
                c = (f < 0.14) and IRIS_DARK or IRIS_LIGHT
                if d > horizonR - 1.2 / R then c = IRIS_DARK end
            elseif mode then
                local h = d / horizonR
                local a = pang[j]
                if mode == "kawoosh" and age < 0.55 then
                    local burst = age / 0.55 * 1.2
                    if h < burst * 0.55 then c = IDX[colors.white]
                    elseif h < burst * 0.85 then c = IDX[colors.lightBlue]
                    elseif h < burst then c = IDX[colors.cyan]
                    else c = BG and BG[j] or BLACK end
                elseif mode == "closing" and h > 1 - age / 0.8 then
                    c = BG and BG[j] or BLACK
                elseif style.horizon == "spiral" then
                    local q = a / 360 * 12 + h * 1.3 - t * 0.15
                    local f = q - floor(q)
                    if f < 0.07 and h > 0.04 then c = IDX[colors.blue]
                    elseif h < 0.35 then c = IDX[colors.white]
                    elseif h < 0.8 then c = IDX[colors.lightBlue]
                    else c = IDX[colors.cyan] end
                else
                    local v = horizonSwirl(h, a, t)
                    if mode == "kawoosh" then v = v + (1 - (age - 0.55) / 1.05) * 0.45 end
                    if mode == "closing" then v = v + 0.2 end
                    c = swirlColor(v)
                end
            else
                c = BG and BG[j] or BLACK
            end
        elseif z >= 10 then
            local k = z % 10
            local kind = floor(z / 10)
            local on = chevOn[k]
            if kind == 1 then
                c = HOUSING
            elseif kind == 2 then
                c = on or OFF
            else
                c = on and CORE or OFF
            end
        end
        if c then px[pi[j]] = c end
    end
end

-- a small gate icon for cards: ring, nine chevron dots and a coloured horizon
function Ring.icon(canvas, cx, cy, r, ringColor, horizonColor, chevronColor)
    local px, w = canvas.px, canvas.w
    local rc, hc, cc = IDX[ringColor], horizonColor and IDX[horizonColor], IDX[chevronColor or ringColor]
    for y = math.max(1, floor(cy - r - 1)), math.min(canvas.h, floor(cy + r + 1)) do
        for x = math.max(1, floor(cx - r - 1)), math.min(canvas.w, floor(cx + r + 1)) do
            local dx, dy = (x - 0.5) - cx, (y - 0.5) - cy
            local d = sqrt(dx * dx + dy * dy)
            local c
            if d <= r + 0.2 and d >= r * 0.66 then
                c = rc
                local a = math.deg(atan2(dx, -dy)) % 360
                local slot = floor(a / 40 + 0.5) % 9
                local diff = abs(a - slot * 40)
                if diff > 180 then diff = 360 - diff end
                if d >= r * 0.8 and rad(diff) * d < 0.75 then c = cc end
            elseif d < r * 0.66 and hc then
                c = hc
            end
            if c then px[(y - 1) * w + x] = c end
        end
    end
end

return Ring
