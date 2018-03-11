local oldCreateChildren = ISCharacterInfoWindow.createChildren
-- xpSystemText is a server file, cant modify here
-- xpSystemText.traitPurchase = "Traits" -- getText("IGUI_XP_Skills")
function ISCharacterInfoWindow:createChildren()
    oldCreateChildren(self)
    self.traitPurchaseView = ISTraitPurchaseScreen:new(0, 8, self.width, self.height-8, self.playerNum)
    self.traitPurchaseView:initialise()
    self.traitPurchaseView.infoText = "Traits" --getText("UI_SkillPanel")
    self.panel:addView('Traits', self.traitPurchaseView)
--	self.panel:addView(xpSystemText.skills, self.traitPurchaseView)

end
