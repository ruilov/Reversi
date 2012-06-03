Board = class()

function Board:init()
    self.cells = {}
    for i=1,8 do
        self.cells[i] = {}
        for j =1,8 do self.cells[i][j] = 0 end
    end
    
    self.cells[4][4]= 2
    self.cells[5][5]= 2
    self.cells[4][5]= 1
    self.cells[5][4]= 1
end

function Board:clone()
    local b = Board()
    for i=1,8 do for j =1,8 do b.cells[i][j] = self.cells[i][j] end end
    return(b)
end

function Board:canMove(player)
    for i=1,8 do for j =1,8 do 
        if self:get(i,j) == 0 and #self:captured(i,j,player)>0 then return(true) end
    end end
    return(false)
end

function Board:move(i,j,player)
    local captured = self:captured(i,j,player)
    for _,p in ipairs(captured) do self:set(p.x,p.y,player) end
    self:set(i,j,player)
end

function Board:set(i,j,player)
    self.cells[i][j] = player
end

function Board:get(i,j)
    return self.cells[i][j]
end

function Board:inbounds(i,j)
    return i>=1 and j>=1 and i<=8 and j<=8
end

function Board:score(player)
    local count = 0
    for i = 1,8 do for j = 1,8 do
        if self.cells[i][j]== player then count = count + 1 end
    end end
    return count
end

function Board:__tostring()
    local s = ""
    for j = 8,1,-1 do
        local line = ""
        for i = 1,8 do line = line..self.cells[i][j] end
        s = s..line.."\n" 
    end
    return(s) 
end

-- the cells stolen by this move by this player
function Board:captured(i,j,player)
    local captured = {}
    for dirX = -1,1 do
        for dirY = -1,1 do
            if dirX ~= 0 or dirY ~= 0 then
                -- see what cells we capture in the dirx,diry direction
                local pos = vec2(i+dirX,j+dirY)
                local hasEnclosing = false
                local candidates = {}
                while(true) do
                    if not self:inbounds(pos.x,pos.y) then break end
                    local s = self:get(pos.x,pos.y)
                    if s == 0 then break end -- we reached an empty cell
                    if s ~= player then 
                        table.insert(candidates,pos)
                    else 
                        hasEnclosing = true -- we reached an enclosing cell
                        break 
                    end
                    pos = pos + vec2(dirX,dirY)
                end
                
                -- if we have an enclosing stone, then we capture the ones in betweeen
                if hasEnclosing then
                    for _,p in ipairs(candidates) do table.insert(captured,p) end
                end
            end
        end
    end
    
    return(captured)
end
