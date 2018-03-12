-- global variables, so other mods can overwrite these values.
-- multiplier cost for trait purchase
TraitCostMultiplier = 4

-- trait blackslist, these cannot be bought or sold
TraitBlackListTable = {"Emaciated", "Very Underweight", "Underweight", "Overweight", "Obese"}

-------------------------------------------------------------------------
local Colors = {
    good={r=0, g=1, b=0},
    bad={r=1, g=0,b=0},
    free={r=1, g=1, b=1},
}

-------------------------------------------------------------------------
-- local functions

--[[ isBlackListedTrait(trait)
    checks if our trait (string) is in the TraitBlackListTable
    returns true/false
    
]]
local function isBlackListedTrait(trait)
    for _, name in ipairs(TraitBlackListTable) do
        if trait == name then return true end
    end
    return false
end

--[[ sortByCost(a, b)
    Sort function, used to sort the trait listboxes by cost. 
    Note uses the original trait cost, not the new modified one.
    
]]
local function sortByCost(a, b)
    if a.item:getCost() == b.item:getCost() then
        return not string.sort(a.text, b.text)
    end
    return a.item:getCost() < b.item:getCost()
end

--[[ onRemoveBadTrait(this, button, trait, cost)
    Callback function for the popup confirmation box.
    
]]
local function onRemoveBadTrait(this, button, trait, cost)
    if button.internal ~= "YES" then return end
    local player = ISTraitPurchaseScreen.instance.char
    local points = player:getNumberOfPerksToPick()
    -- check here, player still has points, still has trait
    if not player:HasTrait(trait:getType()) or points < cost then return end

    local map = trait:getXPBoostMap()
    map = transformIntoKahluaTable(map)
    for perk, value in pairs(map) do
        value = tonumber(tostring(value)) -- for loop chokes using value as a integer (its a double..)
        if value < 0 then
            value = value * -1
            for i=1, tonumber(tostring(value)) do
                if player:getPerkLevel(perk) == 10 then break end
                player:LevelPerk(perk)
                luautils.updatePerksXp(perk, player)
            end
        end
    end
    

    player:setNumberOfPerksToPick(player:getNumberOfPerksToPick() - cost)
    player:getTraits():remove(trait:getType())
    ISTraitPurchaseScreen.instance:updateList()
end

--[[ onAddGoodTrait(this, button, trait, cost)
    Callback function for the popup confirmation box.
    
]]
local function onAddGoodTrait(this, button, trait, cost)
    if button.internal ~= "YES" then return end
    local player = ISTraitPurchaseScreen.instance.char
    local points = player:getNumberOfPerksToPick()
    -- check here, player still has points, still doesn't have trait
    if player:HasTrait(trait:getType()) or points < cost then return end
    
    local map = trait:getXPBoostMap()
    map = transformIntoKahluaTable(map)
    for perk, value in pairs(map) do
        for i=1, tonumber(tostring(value)) do -- for loop chokes using value as a integer (its a double..)
            if player:getPerkLevel(perk) == 10 then break end
            player:LevelPerk(perk)
            luautils.updatePerksXp(perk, player)
        end
    end
    
    for i=0, trait:getFreeRecipes():size()-1 do
        local r = trait:getFreeRecipes():get(i)
        if not player:getKnownRecipes():contains(r) then
            player:getKnownRecipes():add(r)
        end
    end
    
    player:setNumberOfPerksToPick(points - cost)
    player:getTraits():add(trait:getType())
    ISTraitPurchaseScreen.instance:updateList()

end

--------------------------------------------------------------------------
--[[ ISCharacterInfoWindow:createChildren()
    Overwrite function replacing the original.
    First we store the original method into a local var, replace, then 
    call our stored var. 
    This is so we can inject the new child 'traits' tab onto the character 
    info window.

]]
local oldCreateChildren = ISCharacterInfoWindow.createChildren
function ISCharacterInfoWindow:createChildren()
    oldCreateChildren(self)
    self.traitPurchaseView = ISTraitPurchaseScreen:new(0, 8, self.width, self.height-8, self.playerNum)
    self.traitPurchaseView:initialise()
    -- TODO: this needs a translation such as:
    -- UI_SkillPanel = " <CENTRE> <SIZE:medium> This is the Skill Panel. <LINE> <LINE> <SIZE:small> <LEFT> Every skill that you can learn is shown here. <LINE> <LINE> Learning speed depends on your chosen profession and traits. It can be accelerated by reading Skill Books - which provide an XP multiplier for that particular skill. <LINE> <LINE> XP is gained passively, through repeated actions throughout your survival experience, and improves the quality of your actions. <LINE> <LINE> Gaining skill XP also rewards you with a global XP. It is this that provides points to unlock the next level of each skill, once the previous level has been mastered.",
    self.traitPurchaseView.infoText = "Traits" --getText("UI_SkillPanel")
    self.panel:addView(getText("IGUI_char_Traits"), self.traitPurchaseView) 
end
--------------------------------------------------------------------------
--[[ ISTraitPurchaseScreen
    Class for the Purchase tab
    I have to say...PZ's GUI system is a pain in the ass..

]]

ISTraitPurchaseScreen = ISPanelJoypad:derive("ISTraitPurchaseScreen")

function ISTraitPurchaseScreen:new (x, y, width, height, playerNum)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.char = getSpecificPlayer(playerNum)
    o:noBackground()
    o.txtLen = 0
    o.fontHgt = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()

    o.smallFontHgt = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight() + 1
    o.mediumFontHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()
    ISTraitPurchaseScreen.instance = o
    return o
end

function ISTraitPurchaseScreen:createChildren()
    self.tablePadX = 20
    self.tableWidth = 256
    self.tableHeight = 256
    self.topOfLists = 48
    self.traitButtonHgt = 25
    self.traitButtonPad = 6

    self.smallFontHgt = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight() + 1
    self.mediumFontHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()

    
    self.listboxTraitSelected = ISScrollingListBox:new(8, self.topOfLists + self.smallFontHgt, self.tableWidth, self.tableHeight)
    self.listboxTraitSelected:initialise()
    self.listboxTraitSelected:instantiate()
    self.listboxTraitSelected:setAnchorLeft(true)
    self.listboxTraitSelected:setAnchorRight(true)
    self.listboxTraitSelected:setAnchorTop(true)
    self.listboxTraitSelected:setAnchorBottom(true)
    self.listboxTraitSelected.itemheight = 30
    self.listboxTraitSelected.selected = -1
    self.listboxTraitSelected.doDrawItem = ISTraitPurchaseScreen.drawTraitMap
    --self.listboxTraitSelected:setOnMouseDownFunction(self, ISTraitPurchaseScreen.onSelectChosenTrait)
    self.listboxTraitSelected:setOnMouseDoubleClick(self, ISTraitPurchaseScreen.onDblClickSelectedTrait)
    self.listboxTraitSelected.resetSelectionOnChangeFocus = true
    self.listboxTraitSelected.drawBorder = true
    self:addChild(self.listboxTraitSelected)

    
    -- the traits list choice
    self.listboxTrait = ISScrollingListBox:new(8+self.tablePadX+self.tableWidth, self.topOfLists + self.smallFontHgt, self.tableWidth, self.tableHeight)
    self.listboxTrait:initialise()
    self.listboxTrait:instantiate()
    self.listboxTrait:setAnchorLeft(true)
    self.listboxTrait:setAnchorRight(true)
    self.listboxTrait:setAnchorTop(true)
    self.listboxTrait:setAnchorBottom(true)
    self.listboxTrait.itemheight = 30
    self.listboxTrait.selected = -1
    self.listboxTrait.doDrawItem = ISTraitPurchaseScreen.drawTraitMap
    --self.listboxTrait:setOnMouseDownFunction(self, ISTraitPurchaseScreen.onSelectTrait)
    self.listboxTrait:setOnMouseDoubleClick(self, ISTraitPurchaseScreen.onDblClickTrait)
    self.listboxTrait.resetSelectionOnChangeFocus = true
    self.listboxTrait.drawBorder = true
    self:addChild(self.listboxTrait)

    self:updateList()
    
    --self.char:setNumberOfPerksToPick(50) -- TODO: remove, testing line
end


function ISTraitPurchaseScreen:onDblClickSelectedTrait(item)
    if isBlackListedTrait(item:getType()) then return end
    local player = self.char
    local cost = item:getCost() * TraitCostMultiplier * -1
    if cost > 0 and player:getNumberOfPerksToPick() >= cost then
        -- TODO: add translation
        -- IGUI_BuyableTraits_remove = "Remove %1 for %2 points?"
        local modal = ISModalDialog:new(48, 48, 250, 150, "Remove ".. item:getLabel() .. " for "..cost.. " points?", true, nil, onRemoveBadTrait, player:getPlayerNum(), item, cost)
        modal:initialise()
        modal:addToUIManager()        
    end
end

function ISTraitPurchaseScreen:onDblClickTrait(item)
    if isBlackListedTrait(item:getType()) then return end
    local player = self.char
    local cost = item:getCost() * TraitCostMultiplier
    if cost > 0 and player:getNumberOfPerksToPick() >= cost then
        -- TODO: add translation
        -- IGUI_BuyableTraits_add = "Add %1 for %2 points?"
        --local modal = ISModalDialog:new(48, 48, 250, 150, getText("IGUI_BuyableTraits_add", item:getLabel(), cost), true, nil, ISTraitPurchaseScreen.onAddGoodTrait, player:getPlayerNum(), item, cost)
        local modal = ISModalDialog:new(48, 48, 250, 150, "Add ".. item:getLabel() .. " for "..cost.. " points?", true, nil, onAddGoodTrait, player:getPlayerNum(), item, cost)
        modal:initialise()
        modal:addToUIManager()        
    end
end


function ISTraitPurchaseScreen:prerender()
    ISPanel.prerender(self)
    self.listboxTrait:setWidth(self.tableWidth)
    self.listboxTraitSelected:setWidth(self.tableWidth)
    self.listboxTrait:setHeight(self.tableHeight)
    self.listboxTraitSelected:setHeight(self.tableHeight)
end

--[[ ISTraitPurchaseScreen:render()
    Apparently, we need to draw text here, there is a ISLabel class, but theres not much point using it.
    We also need to reset our width and height (as well as our parents) or our listboxes go right off
]]
function ISTraitPurchaseScreen:render()
    self:drawText(getText("UI_characreation_choosentraits"), self.x + 8, 32, 1, 1, 1, 1, UIFont.Medium)
    self:drawText(getText("UI_characreation_availabletraits"), self.x + 8+self.tablePadX + self.tableWidth, 32, 1, 1, 1, 1, UIFont.Medium)
    local ptstring = getText("IGUI_PlayerStats_AvailableSkillPt") .. self.instance.char:getNumberOfPerksToPick()
    self:drawText(ptstring, self.x + 8+self.tablePadX + self.tableWidth, self.topOfLists + self.smallFontHgt + self.tableHeight + 8, 1, 1, 1, 1, UIFont.Medium)
    self:setWidthAndParentWidth(16 + self.tablePadX + (self.tableWidth*2))
    self:setHeightAndParentHeight(self.topOfLists*2 + self.smallFontHgt + self.tableHeight)
    
end

--[[ ISTraitPurchaseScreen:drawTraitMap(y, item, alt)
    This function is mostly copied from the initial character creation, but cleaned up a bit
    and modified to suit our purposes
]]
function ISTraitPurchaseScreen:drawTraitMap(y, item, alt)
    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight - 1, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    local trait = item.item
    
    -- if we selected an item, we display a grey rect over it
    local isMouseOver = self.mouseoverselected == item.index and not self:isMouseOverScrollBar()
    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    elseif isMouseOver then
        self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 4, 0.95, 0.05, 0.05, 0.05)
    end

    local cost = trait:getCost()
    local tex = trait:getTexture()
    local w = 16
    if tex then
        self:drawTexture(tex, 16-2, y + (self.itemheight - tex:getHeight()) / 2, 1, 1, 1, 1);
        w = tex:getWidth() + 20
    end

    local col = Colors.free
    if cost > 0 then col = Colors.good
    elseif cost < 0 then col = Colors.bad end

    local dy = (self.itemheight - ISTraitPurchaseScreen.instance.fontHgt) / 2
    self:drawText(trait:getLabel(), w, y + dy, col.r, col.g, col.b, 0.9, UIFont.Small);

    -- need to figure out what listbox we're drawing in so we can properly set the cost.
    if self == ISTraitPurchaseScreen.instance.listboxTrait then -- buyable good traits
        cost = cost*TraitCostMultiplier
    elseif self == ISTraitPurchaseScreen.instance.listboxTraitSelected then -- sellable bad traits
        cost = cost*TraitCostMultiplier*-1
    end
    -- blacklisted traits set to 0
    if isBlackListedTrait(item.item:getType()) then cost = 0 end
    
    if cost > 0 then -- costs something, so print the cost
        -- normally we'd use trait:getRightLabel(), but we modified the cost
        self:drawTextRight(tostring(cost), self:getWidth() - 20, y + 8, col.r, col.g, col.b, 0.9, UIFont.Small);
    end
    self.itemheightoverride[trait:getLabel()] = self.itemheight
    y = y + self.itemheightoverride[trait:getLabel()]
    return y
end

--[[ ISTraitPurchaseScreen:updateList()
    Updates the listboxes of traits.
    
]]
function ISTraitPurchaseScreen:updateList()
    local traits = TraitFactory.getTraits()
    local player = self.char
    local playerTraits = self.char:getTraits()
    self.listboxTraitSelected:clear()
    self.listboxTrait:clear()
    
    for i=0, playerTraits:size()-1 do
        print(playerTraits:get(i))
        local trait = TraitFactory.getTrait(playerTraits:get(i))
        local newItem = self.listboxTraitSelected:addItem(trait:getLabel(), trait)
        newItem.tooltip = trait:getDescription()
    end
    for i=0, traits:size() -1 do repeat
        local trait = traits:get(i)
        if trait:getCost() <= 0 then break end -- no buying negative or free traits
        if player:HasTrait(trait:getType()) then break end
        local exclude = trait:getMutuallyExclusiveTraits()
        local isOK = true
        for i2=0, exclude:size() -1 do
            if player:HasTrait(exclude:get(i2)) then 
                isOK = false  -- we cant buy this trait, we have a conflicting one
                break 
            end
        end
        if not isOK then break end
        local newItem = self.listboxTrait:addItem(trait:getLabel(), trait)
        newItem.tooltip = trait:getDescription()
    until true end 
    table.sort(self.listboxTrait.items, sortByCost)
    table.sort(self.listboxTraitSelected.items, sortByCost)
end
