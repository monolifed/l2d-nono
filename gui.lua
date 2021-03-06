local utf8 = require "utf8"

local simpleclass = require "simpleclass"
local noop = simpleclass._noop
local class = simpleclass.class

local _floor = math.floor

local clamp = function(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

-----------------------------------------

local uiMeta = {__call = function(C, ...) return C:new(...) end}
local uiBase = setmetatable(class("uiBase"), uiMeta)
local uiFunctions = {
	"update", "mousemoved", "mousepressed", "mousereleased",
	"keypressed", "keyreleased", "textinput", --"draw",
}

for k, v in ipairs(uiFunctions) do uiBase[v] = noop end
uiBase.draw = noop

function uiBase:setEnabled(enabled)
	local disabledfns = self.disabled
	if enabled == false then
		if not disabledfns then
			disabledfns = {}
			for i, k in ipairs(uiFunctions) do
				disabledfns[k] = rawget(self, k); self[k] = noop
			end
			self.disabled = disabledfns
			if self.onEnable then self.onEnable(self, false) end
		end
	elseif disabledfns then
		for i, k in ipairs(uiFunctions) do
			self[k] = disabledfns[k]
		end
		self.disabled = nil
		if self.onEnable then self.onEnable(self, true) end
	end

	return self
end

----- GUI MODULE FUNCTION START -----
return function(theme, font)
-------------------------------------

local gui = {}
gui.theme = theme
gui.font = font

local function playclick(uiobj)
	local click = (uiobj and uiobj.clicksound) or gui.theme.sounds.click
	if click then love.audio.play(click) end
end

-----------------------------------------

local alignList = {left = "left", center = "center", right = "right"}

local Label = class("Label", uiBase)

function Label:init(x, y, limit, align, font)
	self.nodes = {}
	x, y = x and _floor(x) or 0, y and _floor(y) or 0
	self.posx, self.posy = x, y
	self.x, self.y = x, y
	self.limit = limit or 0
	self.align = alignList[align] or "left"
	if font then self.font = font end
end

local function labelDrawImage(node)
	love.graphics.draw(node.image, node.x, node.y, 0, node.sx, node.sy)
end
function Label:insertImage(image, sx, sy, color, pos)
	local node = {}
	node.drawf, node.type = labelDrawImage, "image"
	node.image = image
	node.sx = sx or 1
	node.sy = sy or node.sx
	node.color = color
	table.insert(self.nodes, pos or #self.nodes + 1, node)
	return self
end

local function labelDrawText(node)
	love.graphics.print(node.text, node.font, node.x, node.y, 0, node.sx, node.sy)
end
function Label:insertText(text, font, color, pos)
	local node = {}
	node.drawf, node.type = labelDrawText, "text"
	node.text = text
	node.font = font or self.font or gui.font
	node.color = color
	table.insert(self.nodes, pos or #self.nodes + 1, node)
	return self
end

local function labelDrawSpace(node) end
function Label:insertSpace(width, height, pos)
	local node = {}
	node.drawf, node.type = labelDrawSpace, "space"
	node.width  = width
	node.height = height or 1
	table.insert(self.nodes, pos or #self.nodes + 1, node)
	return self
end

function Label:refresh()
	local limit, align = self.limit, self.align
	local width, height = 0, 0
	local x, y = self.posx, self.posy
	
	for k, n in ipairs(self.nodes) do
		local nw, nh
		if n.drawf == labelDrawSpace then
			nw, nh = n.width, n.height
		elseif n.drawf == labelDrawText then
			nw, nh = n.font:getWidth(n.text), n.font:getHeight()
			n.width, n.height = nw, nh
		elseif n.drawf == labelDrawImage then
			nw, nh = n.image:getDimensions()
			nw, nh = _floor(nw * n.sx), _floor(nh * n.sy)
			n.width, n.height = nw, nh
		end
		
		if nw and nh then
			n.x, n.y = x, y
			width, height = width + nw, math.max(height, nh)
			x = x + nw
		end
	end
	
	local shiftx = 0
	if not limit or align == "left" then -- limit shouldn't be nil
		shiftx = 0
	elseif align == "right" then
		shiftx = _floor(limit - width)
	else -- center or nil
		shiftx = _floor((limit - width) / 2)
	end

	for k, n in ipairs(self.nodes) do
		if n.drawf then
			n.x = n.x + shiftx
			n.y = _floor(n.y + (height - n.height) / 2)
		end
	end
	self.x, self.y = self.posx + shiftx, self.posy
	self.width, self.height = width, height
	return self
end

function Label:draw()
	local r, g, b, a
	for k, v in ipairs(self.nodes) do
		if v.drawf then
			if v.color then
				r, g, b, a = love.graphics.getColor()
				love.graphics.setColor(v.color)
				v:drawf()
				love.graphics.setColor(r, g, b, a)
			else
				v:drawf()
			end
		end
	end
end

-----------------------------------------

local Button = class("Button", Label)

function Button:init(x, y, limit, align, font)
	Label.init(self, x, y, limit, align, font)
	self.hover = false
	self.selected = false
end

function Button:setImage(image, sx, sy, color)
	local imagenode = self.nodes[1]
	if imagenode and imagenode.type == "image" then
		table.remove(self.nodes, 1)
	end
	if not image then return self:refresh() end

	if self.font and not sx and not sy then
		sx = self.font:getHeight() / image:getHeight()
	end
	self:insertImage(image, sx, sy, color, 1)
	return self:refresh()
end

function Button:setText(text, font, color)
	local pos
	for k, n in ipairs(self.nodes) do
		if n.type == "text" then
			pos = k -- should be 1 or 2
			table.remove(self.nodes, pos)
		end
	end
	if not text then return self:refresh() end
	self:insertText(text, font, color, pos)
	self:refresh()
	self.text = text
	return self
end

Button.set = Button.setText

function Button:onEnable(enable)
	self.hover, self.selected = false, false
end

function Button:draw()
	local colors = gui.theme.colors
	local color = self.bgcolor or colors.bgcolor
	if color then
		love.graphics.setColor(color)
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	
	love.graphics.setFont(self.font or gui.font)
	if self.disabled then color = colors.disabled
	elseif self.hover or self.selected then color = colors.main
	else color = self.color or colors.text end
	love.graphics.setColor(color)
	
	Label.draw(self)
end

function Button:mousemoved(x, y, dx, dy)
	self.hover = x > self.x and x < self.x + self.width and
	             y > self.y and y < self.y + self.height
end

function Button:mousepressed(x, y, button)
	self.selected = self.hover
	return self.selected
end

function Button:_onclick(x, y, mbutton)
	if self.onclick then self.onclick(self, x, y, mbutton) end
	playclick(self)
end

function Button:mousereleased(x, y, button)
	if not self.selected then return end
	self.selected = false
	if not self.hover then return end
	
	self:_onclick(x, y, button)
	return true
end

-----------------------------------------

local Toggler = class("Toggler", Button)

function Toggler:init(x, y, limit, align, font)
	Button.init(self, x, y, limit, align, font)
	self.on = false
	self.group = nil
end

function Toggler:_onclick(x, y, mbutton)
	local prevstate = self.on
	local group = self.group
	if group and #group > 1 then
		if prevstate then return end
		for i, v in ipairs(group) do v.on = false end
		self.on = true
		if self.onclick then self.onclick(self, x, y, mbutton) end
		playclick(self)
	else
		self.on = not prevstate
		if self.onclick then self.onclick(self, x, y, mbutton) end
		playclick(self)
	end
end

function Toggler:draw()
	local colors = gui.theme.colors
	local color = self.bgcolor or colors.bgcolor
	if color then
		love.graphics.setColor(color)
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	
	love.graphics.setFont(self.font or gui.font)
	if self.disabled then color = colors.disabled
	elseif self.hover or self.on or self.selected then color = colors.main
	else color = self.color or colors.text end
	love.graphics.setColor(color)
	
	Label.draw(self)
end

-----------------------------------------

local Cycler = class("Cycler", Button)

function Cycler:init(x, y, limit, align, font)
	Button.init(self, x, y, limit, align, font)
	self.list = nil
	self.index = 1
end

function Cycler:_onclick(x, y, mbutton)
	self:setIndex(self.index % #self.list + 1)
	self:mousemoved(x, y)
	if self.onclick then self.onclick(self, self.index, self.text) end
	playclick(self)
end

function Cycler:setIndex(index)
	if index < 1 and index > #self.list then return self end
	self.index = index
	local v = self.list[self.index]
	local vtype = type(v)
	if vtype == "string" or vtype == "number" then
		self:setImage():setText(v)
	elseif vtype == "userdata" and v.typeOf and v.typeOf(v, "Drawable") then
		self:setText():setImage(v)
	end
	return self
end

function Cycler:setIndexFromValue(value)
	for k, v in ipairs(self.list) do
		if v == value then return self:setIndex(k), k end
	end
	return self
end

function Cycler:setList(list, index)
	self.list = list
	if not index then return self:setIndex(1) end
	
	if type(index) == "number" then return self:setIndex(index) end
	return self:setIndexFromValue(index) -- a little loose?
end

Cycler.set = Cycler.setList

-----------------------------------------

local Typer = class("Typer", Button)

--function Typer:init(x, y, limit, align, font)
--	Button.init(self, x, y, limit, align, font)
--end

function Typer:setText(text, font, color)
	self.buffer = text
	Button.setText(self, text, font, color)
	return self
end

Typer.set = Typer.setText

function Typer:draw()
	if not self.focus then
		Button.draw(self)
		return
	end
	love.graphics.setFont(self.font or gui.font)
	love.graphics.setColor(gui.theme.colors.main)
	love.graphics.print(self.buffer, self.posx, self.posy)
	love.graphics.rectangle("line", self.posx, self.posy, self.limit, self.height)
end

function Typer:onEnable(enable)
	self:_onchange(); self.focus = false
end

function Typer:_onchange()
	if self.buffer == self.text then return end
	if self.onchange then
		self.buffer = self.onchange(self, self.buffer, self.text)
		if self.buffer == self.text then return end
	end
	self:setText(self.buffer)
end

function Typer:mousereleased(x, y, button)
	local clicked = Button.mousereleased(self, x, y, button)
	if self.focus and not clicked then
		self:_onchange(); self.focus = false
	else
		self.focus = clicked
	end
	return clicked
end

function Typer:textinput(text)
	if not self.focus then return end
	if self.ontextinput then
		text = self.ontextinput(self, text)
		if not text then return end
	end
	self.buffer = self.buffer ..  text
end

function Typer:keypressed(key, scancode)
	if not self.focus then return end
	if key == "backspace" then
		local offset = utf8.offset(self.buffer, -1)
		if offset then
			self.buffer = string.sub(self.buffer, 1, offset - 1)
		end
	elseif key == "return" then
		self:_onchange(); self.focus = false
	end
end

-----------------------------------------

local Slider = class("Slider", uiBase)

local function sliderbuttononclick(slider, dir)
	slider.dec:setEnabled(); slider.inc:setEnabled()
	
	local oldvalue, step = slider.value, slider.step
	slider.value = oldvalue + dir * step
	if slider.value <= slider.min then
		slider.value = slider.min
		slider.dec:setEnabled(false)
	elseif slider.value >= slider.max then
		slider.value = slider.max
		slider.inc:setEnabled(false)
	end
	
	if slider.value == oldvalue then return end -- this should not happen
	
	if slider.onclick then slider.onclick(slider, dir) end
end

function Slider:init(x, y, limit, align, font)
	x, y = _floor(x), _floor(y)
	self.x, self.y = x, y
	self.value = 0
	self.min, self.max, self.step = 0, 10, 1
	if font then self.font = font end
	self.dec = Button(x, y, limit, "left"  , font)
	self.inc = Button(x, y, limit, "right" , font)
	
	self.dec.onclick = function()
		sliderbuttononclick(self, -1)
	end
	
	self.inc.onclick = function()
		sliderbuttononclick(self, 1)
	end
end

function Slider:onEnable(enable)
	self.dec:setEnabled(enable)
	self.inc:setEnabled(enable)
	self.totalTime = nil
	self.selectTime = nil
end

function Slider:setValueRange(value, min, max, step)
	self.value = value
	self.min, self.max, self.step = min, max, step or 1

	if     self.value == self.min then self.dec:setEnabled(false)
	elseif self.value == self.max then self.inc:setEnabled(false) end
	
	self.inc:setText(">")
	self.dec:setText("<")
	
	return self
end

Slider.set = Slider.setValueRange

function Slider:draw()
	self.inc:draw()
	self.dec:draw()
	love.graphics.setFont(self.font or gui.font)
	local color
	if self.disabled then color = gui.theme.colors.disabled
	else color = gui.theme.colors.text end
	love.graphics.setColor(color)
	love.graphics.printf(self.value, self.x, self.y, self.dec.limit, "center")
end

function Slider:mousemoved(x, y, dx, dy)
	self.inc:mousemoved(x, y, dx, dy)
	self.dec:mousemoved(x, y, dx, dy)
end

function Slider:mousepressed(x, y, button)
	self.totalTime = nil
	self.selectTime = nil
	
	if self.inc:mousepressed(x, y, button) then
		self.selectTime = love.timer.getTime()
		--return true
	end
	
	if self.dec:mousepressed(x, y, button) then
		self.selectTime = love.timer.getTime()
		--return true
	end
end

function Slider:mousereleased(x, y, button)
	self.selectTime = nil
	if self.totalTime then
		self.totalTime = nil
		self.inc.selected = false
		self.dec.selected = false
		return true
	end
	
	self.inc:mousereleased(x, y, button)
	self.dec:mousereleased(x, y, button)
end


local ssmdur = 2 -- slow mode duration
local ssmdt = 0.2 -- slow mode delta time
local stime = 5 -- total time for min to max
local sdelay = 0.5 -- start delay

function Slider:update(dt)
	if not self.selectTime then return end
	
	if self.totalTime then
		self.totalTime = self.totalTime + dt
		
		if self.slowmode and love.timer.getTime() - self.selectTime > ssmdur then
			self.slowmode = nil
		end
		local delta = self.slowmode and ssmdt or stime / (self.max - self.min)
		if self.totalTime < delta then return end
		self.totalTime = self.totalTime - delta
		
		
		if self.dec.selected then
			sliderbuttononclick(self, -1)
		end
		
		if self.inc.selected then
			sliderbuttononclick(self,  1)
		end
	elseif love.timer.getTime() - self.selectTime > sdelay then
		self.totalTime = 0
		self.slowmode = true
	end
end

gui.Button = Button
gui.Toggler = Toggler
gui.Cycler = Cycler
gui.Typer = Typer
gui.Slider = Slider

return gui

----- GUI MODULE FUNCTION END -----
end
-----------------------------------
