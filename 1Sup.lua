
--[[
--Aobject represents things to be drawn on the screen
--
--Main attributes:
-- - position: lower left corner within the parent, or within the screen if no parent
-- - width, height, background, borderColor,borderWidth: should be self explanatory
-- - note that borders are drawn within the object. For example a really large border will 
--    completely fill the object
-- - active: if false then touches don't get triggered
--
-- The user can overwrite these methods
-- - draw: draw in coordinates relative to this object. Note that attempts to draw outside 
--    the boundaries of this object or its parent are clipped
-- - touched: called with this object is touched
--]]

Aobject = class()

function Aobject:init(pos,w,h)
    self.pos = pos  -- relative to its parent
    self.width = w
    self.height = h
    self.background = color(0,0,0,0)
    self.borderColor = color(0, 156, 255, 255)
    self.borderWidth = 3
    self.active = true
    self.touchStates = {}  -- used to generate fake BEGAN and ENDED events as the touch moves
end

function Aobject:draw() end        -- defined by user
function Aobject:touched(t) end    -- defined by user
function Aobject:close() end    -- defined by user

-- internal function that checks if active and if the touch was within this object
function Aobject:__touched(touch)
    if not self.active then return(nil) end
    
    if self:inbounds(vec2(touch.x,touch.y)) then
        local t = Aobject.touchTranslate(touch,self.pos.x,self.pos.y)

        -- generate a fake BEGAN event if this is not a began even and we didn't know 
        -- what this touch yet
        if t.state ~= BEGAN and not self.touchStates[t.id] then
            local tbegan = Aobject.touchTranslate(t,0,0) -- hacky clone
            --print("fake started",self.pos)
            self:touched(tbegan)
        end
        
        -- call the user defined function
        self:touched(t)
        
        -- update state
        if t.state == ENDED then self.touchStates[t.id] = nil
        else self.touchStates[t.id] = t end
    else
        -- this is an out of bound touch. if it were previously in bounds,
        -- generate a fake ENDED event
        local t = self.touchStates[touch.id]
        if t then
            t.state = ENDED
            self:touched(t)
            self.touchStates[touch.id] = nil
        end
    end
end

-- checks whether pos is within this object
function Aobject:inbounds(pos)
    return(pos.x>=self.pos.x and pos.y>=self.pos.y and 
        pos.x<=self.pos.x+self.width and pos.y<=self.pos.y+self.height)
end

-- internal function that draws the border and calls the user defined draw
function Aobject:__draw()
    pushMatrix()
    pushStyle()
    translate(self.pos.x,self.pos.y)
    
    --draw the background and color
    rectMode(CORNERS)
    strokeWidth(self.borderWidth)
    fill(self.background)
    stroke(self.borderColor)
    rect(0,0,self.width,self.height)
    popStyle()
    
    -- call user defined draw
    self:setClip()
    pushStyle()
    self:draw()
    popStyle()
    noClip()
    
    popMatrix()
end

-- helper for clipping stuff that the user attempts to draw outside this object
function Aobject:setClip()
    local corners = self:canvasCorners()
    clip(corners[1].x,corners[1].y,corners[2].x-corners[1].x,corners[2].y-corners[1].y)
end

-- returns the absolute position within the screen
function Aobject:absPos()
    if self.parent then return(self.parent:absPos()+self.pos)
    else return self.pos end
end

-- the drawing area of this object. Smaller as the borderWidth increases.
-- the first elem is the lower left corner and the second elem is the top right
function Aobject:canvasCorners()
    local corner1 = self:absPos()
    local corner2 = corner1+vec2(self.width,self.height)

    if self.borderWidth > 0 then
        corner1 = corner1 + vec2(self.borderWidth,self.borderWidth)
        corner2 = corner2 - vec2(self.borderWidth,self.borderWidth)
    end
    
    if self.parent then   -- parent is set on the panel class
        local pc = self.parent:canvasCorners()
        corner1.x = math.min(math.max(corner1.x,pc[1].x),pc[2].x)
        corner2.x = math.min(math.max(corner2.x,pc[1].x),pc[2].x)
        corner1.y = math.min(math.max(corner1.y,pc[1].y),pc[2].y)
        corner2.y = math.min(math.max(corner2.y,pc[1].y),pc[2].y)
    end

    return({corner1,corner2})
end

function Aobject.touchTranslate(touch,x,y)
    local ta = {
        id = touch.id,
        x = touch.x - x,
        y = touch.y - y,
        prevX = touch.prevX - x,
        prevY = touch.prevY - y,
        deltaX = touch.deltaX,
        deltaY = touch.deltaY,
        state = touch.state,
        tapCount = touch.tapCount
    }
    return ta
end

--[[
-- Panel is the main container class, everything needs to be inside a Panel
-- Panels are automatically drawn so that you don't have to worry about drawing them,
-- unless you set their visible property to false
-- Panels can be closed with Panel.close() 
-- Panels have an array of elems. The elem positions are specified relative to this
-- panel position. The elems are only touched when this Panel is touched
--
-- Panels also implement a radio button type of functionality. If you add elems with
-- Panel.addSelection() then only one of those elems can be selected at any one
-- time and to find out which one is selected use Panel.getSelection
--
-- To progratically select one of the elems use Panel.select()
--]]
Panel = class(Aobject)

__panels = {}
function Panel:init(pos,w,h)
    Aobject.init(self,pos,w,h)
    self.elems = {}
    self.visible = true
    
    if #__panels == 0 then
        local temp = touched
        touched = function(touch)
            for _,panel in ipairs(__panels) do panel:__touched(touch) end
            if temp then temp(touch) end
        end
        
        local tempD = draw
        draw = function()
            background(0, 0, 0, 255)
            noSmooth()
            for _,panel in ipairs(__panels) do panel:__draw() end
            if tempD then tempD() end
        end
    end
    
    table.insert(__panels,self)
    self.borderWidth = -1
end

function Panel:close()
    for idx,p in ipairs(__panels) do
        if p == self then 
            table.remove(__panels,idx)
            break
        end
    end
    
    -- close the children
    for _,elem in ipairs(self.elems) do
        if elem.close then elem:close() end
    end
end

function Panel:setVisible(v)
    self.visible = v
    for _,elem in ipairs(self.elems) do
        if elem.setVisible then elem:setVisible(v) end
    end
end

function Panel:add(elem)
    elem.parent = self
    table.insert(self.elems,elem)
    
    -- if elem is a panel then remove it from __panels
    for idx,e in ipairs(__panels) do
        if e == elem then
            table.remove(__panels,idx) 
            break
        end
    end
end

function Panel:__draw()
    if not self.visible then return(nil) end
    Aobject.__draw(self)
    pushMatrix()
    pushStyle()
    translate(self.pos.x,self.pos.y)
    for _,elem in ipairs(self.elems) do
        self:setClip() -- elem draw will do a noclip
        elem:__draw()
        noClip()
    end
    popMatrix()
    popStyle() 
end

function Panel:__touched(touch)
    if not self.active or not self.visible then return(nil) end
    
    --if not self:inbounds(touch) then return(nil) end
    
    local t2 = Aobject.touchTranslate(touch,0,0)
    Aobject.__touched(self,t2)
    
    local t = Aobject.touchTranslate(touch,self.pos.x,self.pos.y)
    for _,elem in ipairs(self.elems) do elem:__touched(t) end
end

--[[
-- A simple button class. Main feature is that it only gets called once per touch. 
-- It gets called at Touch.state == ENDED
-- A button can also have an icon which is specified as an image object
--]]

Button = class(Aobject)

function Button:init(pos,w,h)
    Aobject.init(self,pos,w,h)
end

function Button:setText(text,col,scl)
    col = col or color(255, 255, 255, 255)
    scl = scl or 10000
    self.draw = function()
        local font = ImageFont.singleton()
        font.color = col
        
        local len = font:len(text)+7
        local sclX = self.width/len
        
        local height = 35
        local sclY = self.height/height
        scale(math.min(scl,math.min(sclX,sclY)))
        smooth()
        font:drawstring(text,0,0)
    end
end

function Button:setIcon(img,scl)
    scl = scl or 1
    self.draw = function()
        spriteMode(CENTER)
        local corners = self:canvasCorners()
        corners[1] = corners[1] - self:absPos()
        corners[2] = corners[2] - self:absPos()
        sprite(img,(corners[1].x+corners[2].x)/2,
            (corners[1].y+corners[2].y)/2,
            (corners[2].x-corners[1].x)*scl,
            (corners[2].y-corners[1].y)*scl)
    end
end

function Button:__touched(touch)
    if touch.state ~= ENDED then return(nil) end
    Aobject.__touched(self,touch)
end

--[[
-- ButtonGroup is not an object on the screen. Instead it manages a group
-- of buttons, only one of which can be selected at any one time
--]]
ButtonGroup = class()

function ButtonGroup:init()
    self.elems = {}
end

function ButtonGroup:add(elem)
    local temp = elem.touched
    elem.touched = function(obj,t)
        for _,b in ipairs(self.elems) do
            b.unselect()
        end

        self.selection = obj
        obj.select()
        temp(obj,t)
    end
    
    table.insert(self.elems,elem)
end

function ButtonGroup:select(i)
    self.elems[i].select()
    self.selection = self.elems[i]
end

function ButtonGroup:getSelection()
    return(self.selection)
end

--[[
-- OkCancelPopup implements a pop-up dialog with ok/cancel
-- Until the user either selected ok or cancel the rest of the screen is innactive
--]]

OkCancelPopup = class(Panel)

function OkCancelPopup:init(pos,w,h,callback)
    -- innactivate everything else
    self.activeBackup = {}
    for _,panel in ipairs(__panels) do
        self.activeBackup[panel] = panel.active
        panel.active = false
    end

    Panel.init(self,pos,w,h)
    self.borderWidth = 3
    self.background = color(186, 186, 186, 255)
    
    -- cancel buttom
    local butwidth = w/7
    local cancel = cancelButton(vec2(w-2*(butwidth+10),10),butwidth,butwidth/2)
    cancel.touched = function(obj,t)
        self:close()
        for panel,act in pairs(self.activeBackup) do panel.active = act end
    end
    self:add(cancel)
    
    -- ok button
    local ok = okButton(vec2(w-butwidth-10,10),butwidth,butwidth/2)
    ok.touched = function(obj,t)
        callback()
        cancel.touched()
    end
    self:add(ok)
end

function okButton(pos,w,h)
    local b = Button(pos,w,h)
    b.draw = function() 
        stroke(30, 125, 41, 255)
        strokeWidth(3)
        line(b.width*.5, b.height*.2, b.width*.8, b.height*.8)
        line(b.width*.2, b.height*.5, b.width*.5, b.height*.2)
    end
    return(b)
end

function cancelButton(pos,w,h)
    local b = Button(pos,w,h)
    b.draw = function() 
        stroke(251, 9, 11, 255)
        strokeWidth(3)
        line(b.width*.2, b.height*.2, b.width*.8, b.height*.8)
        line(b.width*.2, b.height*.8, b.width*.8, b.height*.2)
    end
    return(b)
end

--[[
-- a simple font class that's based on images
--]]
ImageFont = class()

function ImageFont:init()
    self.charImgs = {}
    for i = 32,126 do
        local cs = string.char(i)
        local filename = "char_"..cs
        self.charImgs[cs] = self:loadChar(filename)
    end
    self.color = color(255, 255, 255, 255)
end

function ImageFont.singleton()
    if not __font then __font = ImageFont() end
    return __font
end

-- assumes scale=1
function ImageFont:len(s)
    local len = 0
    for i = 1, string.len(s) do
        local c = s:sub(i, i)
        local w = self.charImgs[c].width 
        len = len + w
        if c == " " then len = len + 12 end
    end
    return len
end

function ImageFont:drawstring(s, x, y)
    pushStyle()
    tint(self.color)
    spriteMode(CORNER)
    local startX=x
    for i = 1, string.len(s) do
        local c = s:sub(i, i)
        local w = self.charImgs[c].width 
        if ((x+w) <0) or (x > WIDTH) then
            x = x + w
        else
            x = x + (self:drawchar(c, x, y))
        end
    end
    popStyle()
    return x - startX
end

function ImageFont:drawchar(c, x, y)
    local img = self.charImgs[c]
    sprite(img,x,y,img.width,img.height)
    if c == " " then return img.width+12
    else return img.width end
end

function ImageFont:loadChar(imgName)
    local data = readProjectData(imgName)
    if not data then return(nil) end
    local img = nil 
    for x,y in data:gmatch"(%d+),(%d+)" do
        if not img then img = image(x,y)
        else img:set(x,y,255,255,255,255) end
    end
    return(img)
end

function ImageFont.buildStr(img)
    local s = img.width..","..img.height
    for x = 1, img.width do
        for y = 1, img.height do
            r,g,b,a = img:get(x,y)
            if r+g+b+a > 0 then
                s = s..","..x..","..y
            end
        end
    end
    return(s)
end
