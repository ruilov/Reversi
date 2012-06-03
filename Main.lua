function setup()
    setInstructionLimit(10000000000)
    white = 2
    black = 2
    watch("white")
    watch("black")
    watch("dt")
    watch("numBoards")
    local side = 75
    grid = Grid(vec2(30,90),side)

    -- display whose turn it is
    local turnDisp = Panel(vec2(60+8*side,HEIGHT/2),side,side)
    turnDisp.draw = function() Grid.drawCell(grid.turn,side) end
    turnDisp.borderWidth = 2
    turnDisp.borderColor = color(255, 255, 255, 255)
    turnDisp.background = color(31, 82, 34, 255)
    
    userPlayer = 1
    ai = AI(3 - userPlayer,0.1)
end

function draw()
    dt = 100*DeltaTime
    if grid.turn == ai.player then numBoards = ai.na end
    
    ai:think()
    --if not ai.chosenMove then ai:thinkLoop() end
    
    if grid.turn == ai.player and ai.chosenMove then
        --print("ai",ai.chosenMove)
        
        grid.board:move(ai.chosenMove.x,ai.chosenMove.y,grid.turn)
        if grid.board:canMove(userPlayer) then grid.turn = userPlayer end
        ai:moveNotify(grid.board,grid.turn)
    end
end

Grid = class(Panel)

function Grid:init(pos,side)
    Panel.init(self,pos,side*8,side*8)
    self.side = side
    self.board = Board()
    self.turn = 1
    for i = 1,8 do
        for j = 1,8 do
            local cell = Button(vec2((i-1)*side,(j-1)*side),side,side)
            cell.borderWidth = 1
            cell.borderColor = color(255, 255, 255, 255)
            cell.background = color(35, 72, 37, 255)
            cell.touched = function(t) self:userMove(i,j) end
            cell.draw = function() Grid.drawCell(self.board:get(i,j),side) end
            self:add(cell)
        end
    end
end

function Grid.drawCell(state,side)
    if state == 0 then return(nil)
    elseif state == 1 then fill(255, 255, 255, 255)
    elseif state == 2 then fill(0, 0, 0, 255) end
    strokeWidth(-1)
    ellipseMode(CENTER)
    ellipse(side/2,side/2,side*.8)
end

function Grid:userMove(i,j)
    if self.turn ~= userPlayer then return(nil) end   -- it's not the users turn
    if self.board:get(i,j) ~= 0 then return(nil) end  -- cell is already occupied
    
    local captured = self.board:captured(i,j,self.turn)
    if #captured == 0 then return(nil) end            -- illegal move
    
    -- make the move
    self.board:move(i,j,self.turn)

    -- figure out whose turn it is
    if self.board:canMove(ai.player) then self.turn = ai.player end
    
    ai:moveNotify(self.board,self.turn)
    
    -- update scores
    white = self.board:score(1)
    black = self.board:score(2)
end
