AI = class()

function AI:init(player,turnT)
    self.player = player
    self.turnT = turnT
    self.node = Node(Board(),1)
    self.cor = coroutine.create(function() self:thinkLoop() end)
end

function AI:think()
    self.startT = os.clock()
    coroutine.resume(self.cor)
    --print(coroutine.status(self.cor))
    return self.chosenMove
end

function AI:moveNotify(board,turn)
    self.node = Node(board:clone(),turn)
    self.cor = coroutine.create(function() self:thinkLoop() end)
    self.chosenMove = nil
end

function AI:yield()
    local currentT = os.clock()
    if currentT - self.startT > self.turnT then 
        coroutine.yield()
        --print("yield")
    end
end

function AI:thinkLoop()
    --print("think")
    self.na = 0
    local bestV = -10000
    local bestM = nil
    local children = self.node:getChildren()
    for move,child in pairs(children) do
        --print("move",move)
        local v = self:analyzeNode(child,2)
        --for i = 1,10000 do
        --    self:yield()
        --end
        --print(move,v)
        v = v * (3-2*self.player)
        if v > bestV then
            bestV = v
            bestM = move
        end
        self:yield()
    end
    self.chosenMove = bestM
    --print("done",self.na)
end

function AI:analyzeNode(node,numLevels)
    if numLevels == 0 then return(self:evaluate(node)) end
    --print("st",numLevels)
    local mult = (3-2*node.turn)  -- 1 for 1, and -1 for 2
    local bestV = -10000
    local children = node:getChildren()
    for move,child in pairs(children) do
        self:yield()
        local v = self:analyzeNode(child,numLevels-1)
        --print("m",move,v)
        v = v * mult
        bestV = math.max(v,bestV)
    end
    --print("ret",(bestV*mult))
    return bestV * mult
end

-- return a positive number if good for 1
function AI:evaluate(node)
    self.na = self.na + 1
    local score = 0
    for i = 1,8 do for j = 1,8 do
        local c = node.board:get(i,j)
        if c ~= 0 then
            for dirI=-1,1 do for dirJ=-1,1 do
                local neiI, neiJ = i+dirI, j+dirJ
                if node.board:inbounds(neiI,neiJ) and node.board:get(neiI,neiJ) == 0 then
                    score = score + 2*c-3
                end
            end end
        end
    end end
    return score
end

Node = class()

function Node:init(board,turn,parent)
    self.board = board:clone()
    self.turn = turn
    self.parent = parent
end

function Node:getChildren()
    if not self.children then
        self.children = {}
        for i = 1,8 do for j = 1,8 do
            if self.board:get(i,j) == 0 then
                local captured = self.board:captured(i,j,self.turn)
                if #captured > 0 then
                    local newBoard = self.board:clone()
                    newBoard:move(i,j,self.turn)
                
                    local newTurn = 3 - self.turn
                    if not newBoard:canMove(newTurn) then newTurn = self.turn end
                
                    local newNode = Node(newBoard,newTurn,self)
                    self.children[vec2(i,j)] = newNode
                    --print("c",i,j)
                end
            end
        end end
    end
    return self.children
end
