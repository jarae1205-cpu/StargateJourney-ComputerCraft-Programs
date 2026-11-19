--
-- sgc.glyphs - a line figure for every gate symbol, drawn on a pixel canvas (sgc.pixels)
--
-- The figures are made up by this module, like constellations: four to six stars
-- joined by lines, worked out from the symbol itself, so a symbol always gets the
-- same figure and different symbols get different ones. They are not the glyphs of
-- any mod or of the show. The point of origin (symbol 0) is a pyramid under a sun.
--
-- Glyphs.draw(canvas, symbol, x, y, w, h, color, thick)   symbol: number or name
--

local Gl = {}

local IDX = {}
for i = 0, 15 do IDX[2 ^ i] = i end

local floor, abs, sqrt, sin, cos = math.floor, math.abs, math.sqrt, math.sin, math.cos
local atan2 = math.atan2 or math.atan

-- a number to start the figure from; small enough to stay exact in any Lua
local function seedOf(symbol)
    if type(symbol) == "number" then return (floor(symbol) * 7919 + 104729) % 2147483646 + 1 end
    local s = 7
    local text = tostring(symbol):lower()
    for i = 1, #text do s = (s * 31 + text:byte(i)) % 2147483646 end
    return s + 1
end

local cache = {}

-- { stars = { {x, y}, ... }, lines = { {x1, y1, x2, y2}, ... }, sun = {x, y, r} } in 0..1
function Gl.figure(symbol)
    local key = type(symbol) .. ":" .. tostring(symbol)
    if cache[key] then return cache[key] end
    local f
    if symbol == 0 then
        f = {
            stars = {},
            lines = { { 0.1, 0.94, 0.5, 0.42 }, { 0.5, 0.42, 0.9, 0.94 }, { 0.9, 0.94, 0.1, 0.94 } },
            sun = { 0.5, 0.17, 0.13 },
        }
    else
        local seed = seedOf(symbol)
        local function rnd(n)
            seed = (seed * 16807) % 2147483647
            return seed % n
        end
        -- four to six stars, each in a cell of its own on a 3 x 3 grid
        local cells = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
        for i = 9, 2, -1 do
            local j = rnd(i) + 1
            cells[i], cells[j] = cells[j], cells[i]
        end
        local k = 4 + rnd(3)
        local pts = {}
        for i = 1, k do
            local c = cells[i] - 1
            local gx, gy = c % 3, floor(c / 3)
            pts[i] = { (gx + 0.15 + rnd(70) / 100) / 3, (gy + 0.15 + rnd(70) / 100) / 3 }
        end
        -- stretch them over the whole box
        local x0, y0, x1, y1 = 1, 1, 0, 0
        for _, p in ipairs(pts) do
            x0, y0 = math.min(x0, p[1]), math.min(y0, p[2])
            x1, y1 = math.max(x1, p[1]), math.max(y1, p[2])
        end
        for _, p in ipairs(pts) do
            p[1] = 0.06 + 0.88 * (p[1] - x0) / math.max(0.01, x1 - x0)
            p[2] = 0.06 + 0.88 * (p[2] - y0) / math.max(0.01, y1 - y0)
        end
        -- join them in order around their middle, as an open path
        local mx, my = 0, 0
        for _, p in ipairs(pts) do mx, my = mx + p[1] / k, my + p[2] / k end
        table.sort(pts, function(a, b) return atan2(a[2] - my, a[1] - mx) < atan2(b[2] - my, b[1] - mx) end)
        local start = rnd(k)
        local path = {}
        for i = 0, k - 1 do path[#path + 1] = pts[(start + i) % k + 1] end
        f = { stars = path, lines = {} }
        for i = 1, k - 1 do
            local a, b = path[i], path[i + 1]
            f.lines[#f.lines + 1] = { a[1], a[2], b[1], b[2] }
        end
        -- some figures have a spur from a middle star to the middle of the box
        if k >= 5 and rnd(2) == 0 then
            local a = path[2 + rnd(k - 2)]
            f.lines[#f.lines + 1] = { a[1], a[2], 0.5 + (mx - 0.5) * 0.4, 0.5 + (my - 0.5) * 0.4 }
        end
    end
    cache[key] = f
    return f
end

local function plot(canvas, x, y, ci, thick)
    local w, h, px = canvas.w, canvas.h, canvas.px
    for dy = 0, thick - 1 do
        for dx = 0, thick - 1 do
            local xx, yy = x + dx, y + dy
            if xx >= 1 and yy >= 1 and xx <= w and yy <= h then px[(yy - 1) * w + xx] = ci end
        end
    end
end

-- a straight line of pixels from (x1, y1) to (x2, y2)
function Gl.line(canvas, x1, y1, x2, y2, color, thick)
    local ci = IDX[color]
    thick = thick or 1
    x1, y1, x2, y2 = floor(x1 + 0.5), floor(y1 + 0.5), floor(x2 + 0.5), floor(y2 + 0.5)
    local dx, dy = abs(x2 - x1), -abs(y2 - y1)
    local sx, sy = x1 < x2 and 1 or -1, y1 < y2 and 1 or -1
    local err = dx + dy
    while true do
        plot(canvas, x1, y1, ci, thick)
        if x1 == x2 and y1 == y2 then break end
        local e2 = 2 * err
        if e2 >= dy then err = err + dy x1 = x1 + sx end
        if e2 <= dx then err = err + dx y1 = y1 + sy end
    end
end

-- the figure of a symbol in the box (x, y, w, h) of canvas pixels
function Gl.draw(canvas, symbol, x, y, w, h, color, thick)
    local f = Gl.figure(symbol)
    thick = thick or 1
    local sw, sh = math.max(0, w - thick), math.max(0, h - thick)
    local function at(u, v) return x + u * sw, y + v * sh end
    for _, l in ipairs(f.lines) do
        local ax, ay = at(l[1], l[2])
        local bx, by = at(l[3], l[4])
        Gl.line(canvas, ax, ay, bx, by, color, thick)
    end
    if f.sun then
        local cx, cy = at(f.sun[1], f.sun[2])
        local r = math.max(1, f.sun[3] * math.min(sw, sh))
        local steps = math.max(8, floor(r * 6))
        local ci = IDX[color]
        for i = 0, steps - 1 do
            local a = i / steps * 2 * math.pi
            plot(canvas, floor(cx + cos(a) * r + 0.5), floor(cy + sin(a) * r + 0.5), ci, thick)
        end
    end
    -- the stars, a little bigger than the lines, when there is room for them
    if thick >= 2 then
        local ci = IDX[color]
        for _, s in ipairs(f.stars) do
            local sx, sy = at(s[1], s[2])
            plot(canvas, floor(sx + 0.5) - 1, floor(sy + 0.5) - 1, ci, thick + 2)
        end
    end
end

return Gl
