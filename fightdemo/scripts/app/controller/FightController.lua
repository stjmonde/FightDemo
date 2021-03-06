--[[控制器层
处理用户的输入
与modle层交换更新数据
控制视图的显示，比如卡牌的进入
接受用户状态改变的通知，并调用页面的更新方法，更新页面
]]

-- local Actor = import("..models.Actor")
-- local HeroView = import("..views.HeroView")
local FightController = class("FightController", function (  )
    local node = display.newLayer()
    require("framework.api.EventProtocol").extend(node)
    return node
end)

FightController.ACTION_FINISHED_EVENT = "ACTION_FINISHED_EVENT"            -- 动作完成后

function FightController:ctor( battleView )
    -- -- 完成初始化
    self.battleView_ = battleView
    self.views_ = self.battleView_:getAllHeroView()
    self.battleModel_ = self.battleView_:getBattleField()
    self.heros_ = self.battleModel_:getAllHeros()        -- 存放所有英雄卡片视图

    -- -- 建立对战场视图对象状态改变的监听
    local cls = self.battleView_.class
        cc.EventProxy.new(self.battleView_, self)
            :addEventListener(cls.BATTLE_ANIMATION_FINISHED, function ( event )
                self:battleActionFinished( event )
            end , self)
            :addEventListener(cls.SKILL_ATK_FROM_SM_TO_C_EVENT, function ( event )
                self:continueSkillAtk( event )
            end , self)
    -- -- 对每一个英雄视图对象的监听
    for k,v in pairs(self.views_) do
        local cls = v.class
        cc.EventProxy.new(v, self)
            :addEventListener(cls.ANIMATION_FINISHED_EVENT, function ( event )
                self:heroActionFinished( event )
            end , self)
    end
    self.battleModel_:initAction()
    self.battleActFinishedCount_ = 0

    self.atkIndexS0_ = 1
    self.atkIndexS1_ = 1

    self.crtAtkSide_ = 0
    self.deadCount = 0
end

--
function FightController:getViewBySideAndPos( side,pos )
    for i=1,#self.heros_ do
        local hero = self.heros_[i]
        if hero:getSide() == side and hero:getPos() == pos then
            return hero
        end
    end
end
-- 进入战场
function FightController:entFightScene(  )
    local i = 1
    for k,v in pairs(self.heros) do
        
        local nickname = v:getNickName()
        local player = self.views_[nickname]
        local array = CCArray:create()
        local move
        if v:getSide() ~= 1 then
            move = CCMoveTo:create(1,ccp(player:getPositionX(),display.cy + 150))
        else
            move = CCMoveTo:create(1,ccp(player:getPositionX(),display.cy - 150))
        end
        
        local delay = CCDelayTime:create(1)
        local callBack = CCCallFunc:create(function(  )
            if v:getSide() == 1 and v:getPos() == 1 then
                self:enterNextAtk()
            end
        end)
        array:addObject(move)
        array:addObject(delay)
        
        array:addObject(callBack)
        local seq = CCSequence:create(array)
        player:runAction(seq)
        i = i + 1
    end
end

-- 进入下一轮的攻击
function FightController:enterNextAtk(  )
    if self.deadCount == 2 then
        self.stateLabel_ = ui.newTTFLabel({
            text = "进入下一个回合",
            size = 22,
            color = display.COLOR_RED,
        })
        :pos(self:getContentSize().width / 2, self:getContentSize().height / 2)
        :addTo(self)
        return
    end 
    local tSide = self.crtAtkSide_ == 1 and 0 or 1

    if self.crtAtkSide_ == 0 then
        local atkPos = self.atkIndexS0_
        local defPos = self.atkIndexS0_
        local atker = self:getViewBySideAndPos(self.crtAtkSide_ ,atkPos)
        local defer = self:getViewBySideAndPos(tSide,atkPos)
        if self.atkIndexS0_ == 2 then
            self.atkIndexS0_ = 1
        else
            self.atkIndexS0_ = self.atkIndexS0_ + 1
        end
        self.crtAtkSide_ = self.crtAtkSide_ == 0 and 1 or 0
        if atker:isCanAtk() and not defer:isDead() then
            atker:skillAtk(defer)
        else
            -- self:enterNextAtk()
        end
    else
        local atkPos = self.atkIndexS1_
        local defPos = self.atkIndexS1_
        local atker = self:getViewBySideAndPos(self.crtAtkSide_ ,atkPos)
        local defer = self:getViewBySideAndPos(tSide,atkPos)
        if self.atkIndexS1_ == 2 then
            self.atkIndexS1_ = 1
        else
            self.atkIndexS1_ = self.atkIndexS1_ + 1
        end
        self.crtAtkSide_ = self.crtAtkSide_ == 0 and 1 or 0
        if atker:isCanAtk() and not defer:isDead() then
            atker:skillAtk(defer)
        else
            -- self:enterNextAtk()
        end
    end
end

-- 接受用户输入的处理函数
function FightController:skillBtnTaped( tag,sender )
    
end

-- 
function FightController:continueSkillAtk( event )
    self.battleModel_:beginEnterDamage(event.atker,event.targets,event.skill)
end

-- 战斗宏观动画做完后的回调
function FightController:battleActionFinished( event )
    if event.actType == "enterbattle" then
        self.battleActFinishedCount_ = self.battleActFinishedCount_ + 1
        if self.battleActFinishedCount_ == 4 then
            self:enterNextAtk()
            self.battleActFinishedCount_ = 0
        else
            
        end
    elseif event.actType == "playskill" then
        self.battleModel_:continueAtk()
    end
    
end

-- 接受用户动作结束的通知，并调用model的处理方法  如状态改变
function FightController:heroActionFinished( event )
    -- event是一个table，基础包含name和target字段
    -- name是事件名称
    -- target是分发事件的对象
    -- event.target:removeSelf()
    if event.actType == "atking" then
        -- 攻击动作完成
        local atker = event.atker
        atker:getHeroInfo():enterNextState()
    elseif event.actType == "kill" then
        -- 死亡动作完成
        self.deadCount = self.deadCount + 1
        local target = event.target
        local actor = target:getHeroInfo()
        actor:enterNextState()
    elseif event.actType == "underatk" then
        local delayTime = CCDelayTime:create(1)
        local callBack = CCCallFunc:create(function (  )
            self:enterNextAtk()
        end)
        local target = event.target
        local actor = target:getHeroInfo()
        actor:enterNextState()
        self:runAction(CCSequence:createWithTwoActions(delayTime,callBack))
    end
end
return FightController
