--
-- sgc.pixels - a small pixel canvas drawn with teletext characters
--
-- Every character cell holds 2 x 3 pixels (CC: Tweaked characters 128-159),
-- so a monitor at text scale 0.5 gives square pixels at twice the width and
-- three times the height of its character grid. A cell can show two colours.
--

local P = {}
P.__index = P

local HEX = {}
local IDX = {}
for i = 0, 15 do
    HEX[i] = ("0123456789abcdef"):sub(i + 1, i + 1)
    IDX[2 ^ i] = i
end
P.index = IDX -- colors.x -> 0..15

-- cols x rows character cells
function P.new(cols, rows, background)
    local self = setmetatable({ cols = cols, rows = rows, w = cols * 2, h = rows * 3, px = {}, cache = {} }, P)
    self:clear(background or colors.black)
    return self
end

function P:clear(color)
    local ci = IDX[color] or 15
    local px = self.px
    for i = 1, self.w * self.h do px[i] = ci end
end

function P:set(x, y, color)
    if x >= 1 and y >= 1 and x <= self.w and y <= self.h then
        self.px[(y - 1) * self.w + x] = IDX[color]
    end
end

function P:get(x, y)
    return 2 ^ self.px[(y - 1) * self.w + x]
end

function P:rect(x, y, w, h, color)
    local ci = IDX[color]
    for yy = math.max(1, y), math.min(self.h, y + h - 1) do
        local base = (yy - 1) * self.w
        for xx = math.max(1, x), math.min(self.w, x + w - 1) do
            self.px[base + xx] = ci
        end
    end
end

-- forget what was drawn so the next draw repaints everything
function P:invalidate()
    self.cache = {}
end

local char = string.char
local concat = table.concat

-- draws the canvas on terminal t with its top left cell at (ox, oy)
function P:draw(t, ox, oy)
    local px, w = self.px, self.w
    local counts = {}
    for row = 1, self.rows do
        local text, fgs, bgs = {}, {}, {}
        local rowBase = (row - 1) * 3 * w
        for col = 1, self.cols do
            local b = rowBase + (col - 1) * 2 + 1
            local p1, p2 = px[b], px[b + 1]
            local p3, p4 = px[b + w], px[b + w + 1]
            local p5, p6 = px[b + 2 * w], px[b + 2 * w + 1]
            if p1 == p2 and p1 == p3 and p1 == p4 and p1 == p5 and p1 == p6 then
                text[col], fgs[col], bgs[col] = " ", HEX[p1], HEX[p1]
            else
                -- the two most common colours
                for k in pairs(counts) do counts[k] = nil end
                counts[p1] = (counts[p1] or 0) + 1
                counts[p2] = (counts[p2] or 0) + 1
                counts[p3] = (counts[p3] or 0) + 1
                counts[p4] = (counts[p4] or 0) + 1
                counts[p5] = (counts[p5] or 0) + 1
                counts[p6] = (counts[p6] or 0) + 1
                local a, an, bb, bn = nil, -1, nil, -1
                for c, n in pairs(counts) do
                    if n > an then
                        bb, bn = a, an
                        a, an = c, n
                    elseif n > bn then
                        bb, bn = c, n
                    end
                end
                -- the bottom right pixel is always the background of a teletext character
                local bg, fg
                if p6 == bb then bg, fg = bb, a else bg, fg = a, bb end
                local code = 128
                if p1 == fg then code = code + 1 end
                if p2 == fg then code = code + 2 end
                if p3 == fg then code = code + 4 end
                if p4 == fg then code = code + 8 end
                if p5 == fg then code = code + 16 end
                text[col], fgs[col], bgs[col] = char(code), HEX[fg], HEX[bg]
            end
        end
        local s, f, g = concat(text), concat(fgs), concat(bgs)
        local key = s .. f .. g
        if self.cache[row] ~= key then
            self.cache[row] = key
            t.setCursorPos(ox, oy + row - 1)
            t.blit(s, f, g)
        end
    end
end

return P
