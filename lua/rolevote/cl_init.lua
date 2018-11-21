surface.CreateFont("TTT2VoteFont", { font = "Trebuchet MS", size = 19, weight = 700, antialias = true, shadow = true})
surface.CreateFont("TTT2VoteFontCountdown", {font = "Tahoma", size = 32, weight = 700, antialias = true, shadow = true})
surface.CreateFont("TTT2VoteSysButton", {font = "Marlett", size = 13, weight = 0, symbol = true})

RoleVote.EndTime = 0
RoleVote.Panel = false

net.Receive("TTT2RoleVoteStart", function()
	RoleVote.CurrentRoles = {}
	RoleVote.Allow = true
	RoleVote.Votes = {}

	local amt = net.ReadUInt(32)

	for i = 1, amt do
		local role = net.ReadUInt(ROLE_BITS)

		RoleVote.CurrentRoles[#RoleVote.CurrentRoles + 1] = role
	end

	RoleVote.EndTime = CurTime() + net.ReadUInt(32)

	if IsValid(RoleVote.Panel) then
		RoleVote.Panel:Remove()
	end

	RoleVote.Panel = vgui.Create("RoleVoteScreen")
	RoleVote.Panel:SetRoles(RoleVote.CurrentRoles)
end)

net.Receive("TTT2RoleVoteUpdate", function()
	local update_type = net.ReadUInt(3)

	if update_type == RoleVote.UPDATE_VOTE then
		local ply = net.ReadEntity()

		if IsValid(ply) then
			local role = net.ReadUInt(ROLE_BITS)

			RoleVote.Votes[ply:SteamID64()] = role

			if IsValid(RoleVote.Panel) then
				RoleVote.Panel:AddVoter(ply)
			end
		end
	elseif update_type == RoleVote.UPDATE_WIN then
		if IsValid(RoleVote.Panel) then
			RoleVote.Panel:Flash(net.ReadUInt(ROLE_BITS))
		end
	end
end)

net.Receive("TTT2RoleVoteCancel", function()
	if IsValid(RoleVote.Panel) then
		RoleVote.Panel:Remove()
	end
end)

net.Receive("TTT2RTV_Delay", function()
	chat.AddText(Color(102, 255, 51), "[TTT2RTV]", Color(255, 255, 255), " The vote has been rocked, role vote will begin on round end")
end)

local PANEL = {}

function PANEL:Init()
	self:ParentToHUD()

	self.Canvas = vgui.Create("Panel", self)
	self.Canvas:MakePopup()
	self.Canvas:SetKeyboardInputEnabled(false)

	self.countDown = vgui.Create("DLabel", self.Canvas)
	self.countDown:SetTextColor(color_white)
	self.countDown:SetFont("TTT2VoteFontCountdown")
	self.countDown:SetText("")
	self.countDown:SetPos(0, 14)

	self.roleList = vgui.Create("DPanelList", self.Canvas)
	self.roleList:SetPaintBackground(false)
	self.roleList:SetSpacing(4)
	self.roleList:SetPadding(4)
	self.roleList:EnableHorizontal(true)
	self.roleList:EnableVerticalScrollbar()

	self.closeButton = vgui.Create("DButton", self.Canvas)
	self.closeButton:SetText("")

	self.closeButton.Paint = function(panel, w, h)
		derma.SkinHook("Paint", "WindowCloseButton", panel, w, h)
	end

	self.closeButton.DoClick = function()
		self:SetVisible(false)
	end

	self.maximButton = vgui.Create("DButton", self.Canvas)
	self.maximButton:SetText("")
	self.maximButton:SetDisabled(true)

	self.maximButton.Paint = function(panel, w, h)
		derma.SkinHook("Paint", "WindowMaximizeButton", panel, w, h)
	end

	self.minimButton = vgui.Create("DButton", self.Canvas)
	self.minimButton:SetText("")
	self.minimButton:SetDisabled(true)

	self.minimButton.Paint = function(panel, w, h)
		derma.SkinHook("Paint", "WindowMinimizeButton", panel, w, h)
	end

	self.Voters = {}
end

function PANEL:PerformLayout()
	local _, cy = chat.GetChatBoxPos()

	self:SetPos(0, 0)
	self:SetSize(ScrW(), ScrH())

	local extra = math.Clamp(300, 0, ScrW() - 640)
	self.Canvas:StretchToParent(0, 0, 0, 0)
	self.Canvas:SetWide(640 + extra)
	self.Canvas:SetTall(cy - 60)
	self.Canvas:SetPos(0, 0)
	self.Canvas:CenterHorizontal()
	self.Canvas:SetZPos(0)

	self.roleList:StretchToParent(0, 90, 0, 0)

	local buttonPos = 640 + extra - 31 * 3

	self.closeButton:SetPos(buttonPos - 31 * 0, 4)
	self.closeButton:SetSize(31, 31)
	self.closeButton:SetVisible(true)

	self.maximButton:SetPos(buttonPos - 31 * 1, 4)
	self.maximButton:SetSize(31, 31)
	self.maximButton:SetVisible(true)

	self.minimButton:SetPos(buttonPos - 31 * 2, 4)
	self.minimButton:SetSize(31, 31)
	self.minimButton:SetVisible(true)

end

local star_mat = Material("icon16/star.png")

function PANEL:AddVoter(voter)
	for _, v in pairs(self.Voters) do
		if v.Player and v.Player == voter then
			return false
		end
	end

	local icon_container = vgui.Create("Panel", self.roleList:GetCanvas())

	local icon = vgui.Create("AvatarImage", icon_container)
	icon:SetSize(16, 16)
	icon:SetZPos(1000)
	icon:SetTooltip(voter:Name())

	icon_container.Player = voter

	icon_container:SetTooltip(voter:Name())

	icon:SetPlayer(voter, 16)

	if RoleVote.HasExtraVotePower(voter) then
		icon_container:SetSize(40, 20)

		icon:SetPos(21, 2)

		icon_container.img = star_mat
	else
		icon_container:SetSize(20, 20)

		icon:SetPos(2, 2)
	end

	icon_container.Paint = function(s, w, h)
		draw.RoundedBox(4, 0, 0, w, h, Color(255, 0, 0, 80))

		if icon_container.img then
			surface.SetMaterial(icon_container.img)
			surface.SetDrawColor(Color(255, 255, 255))
			surface.DrawTexturedRect(2, 2, 16, 16)
		end
	end

	table.insert(self.Voters, icon_container)
end

function PANEL:Think()
	for _, v in pairs(self.roleList:GetItems()) do
		v.NumVotes = 0
	end

	for _, v in pairs(self.Voters) do
		if not IsValid(v.Player) then
			v:Remove()
		else
			if not RoleVote.Votes[v.Player:SteamID64()] then
				v:Remove()
			else
				local bar = self:GetMapButton(RoleVote.Votes[v.Player:SteamID64()])

				if RoleVote.HasExtraVotePower(v.Player) then
					bar.NumVotes = bar.NumVotes + 2
				else
					bar.NumVotes = bar.NumVotes + 1
				end

				if IsValid(bar) then
					local NewPos = Vector((bar.x + bar:GetWide()) - 21 * bar.NumVotes - 2, bar.y + (bar:GetTall() * 0.5 - 10), 0)

					if not v.CurPos or v.CurPos ~= NewPos then
						v:MoveTo(NewPos.x, NewPos.y, 0.3)

						v.CurPos = NewPos
					end
				end
			end
		end
	end

	local timeLeft = math.Round(math.Clamp(RoleVote.EndTime - CurTime(), 0, math.huge))

	self.countDown:SetText(tostring(timeLeft or 0) .. " seconds")
	self.countDown:SizeToContents()
	self.countDown:CenterHorizontal()
end

function PANEL:SetRoles(roles)
	self.roleList:Clear()

	for _, role in RandomPairs(roles) do
		local button = vgui.Create("DButton", self.roleList)
		button.ID = role

		button:SetText(LANG.GetTranslation(GetRoleByIndex(role).name))

		button.DoClick = function()
			net.Start("TTT2RoleVoteUpdate")
			net.WriteUInt(RoleVote.UPDATE_VOTE, 3)
			net.WriteUInt(button.ID, ROLE_BITS)
			net.SendToServer()
		end

		local rd = GetRoleByIndex(role)

		button.bgColor = table.Copy(rd.color)
		button.color = table.Copy(rd.color)
		button.dkColor = table.Copy(rd.dkcolor)
		button.bgbgColor = table.Copy(rd.bgcolor)
		button.icon = "vgui/ttt/sprite_" .. rd.abbr

		do
			local Paint = button.Paint
			button.Paint = function(s, w, h)
				local col = Color(255, 255, 255, 10)

				if button.bgColor then
					col = button.bgColor
				end

				draw.RoundedBox(4, 0, 0, w, h, col)

				if button.icon then
					local mat = Material(button.icon)

					if mat then
						surface.SetDrawColor(255, 255, 255, 255)
						surface.SetMaterial(mat)
						surface.DrawTexturedRect(5, 5, h - 10, h - 10)
					end
				end

				Paint(s, w, h)
			end
		end

		button:SetTextColor(color_white)
		button:SetContentAlignment(4)
		button:SetTextInset(48, 0)
		button:SetFont("TTT2VoteFont")

		local extra = math.Clamp(300, 0, ScrW() - 640)

		button:SetPaintBackground(false)
		button:SetTall(34)
		button:SetWide(285 + extra * 0.5)
		button:SetTooltip(LANG.GetTranslation("ttt2_desc_" .. GetRoleByIndex(role).name))

		button.NumVotes = 0

		self.roleList:AddItem(button)
	end

	-- random option
	local button = vgui.Create("DButton", self.roleList)
	button.ID = 3

	button:SetText("Random")

	button.DoClick = function()
		net.Start("TTT2RoleVoteUpdate")
		net.WriteUInt(RoleVote.UPDATE_VOTE, 3)
		net.WriteUInt(button.ID, ROLE_BITS)
		net.SendToServer()
	end

	do
		local Paint = button.Paint
		button.Paint = function(s, w, h)
			local col = Color(255, 255, 255, 10)

			if button.bgColor then
				col = button.bgColor
			end

			draw.RoundedBox(4, 0, 0, w, h, col)
			Paint(s, w, h)
		end
	end

	button:SetTextColor(color_white)
	button:SetContentAlignment(4)
	button:SetTextInset(48, 0)
	button:SetFont("TTT2VoteFont")

	local extra = math.Clamp(300, 0, ScrW() - 640)

	button:SetPaintBackground(false)
	button:SetTall(34)
	button:SetWide(285 + extra * 0.5)
	button:SetTooltip("Select a random role")

	button.NumVotes = 0

	self.roleList:AddItem(button)

	-- none option
	local buttonN = vgui.Create("DButton", self.roleList)
	buttonN.ID = 4

	buttonN:SetText("None")

	buttonN.DoClick = function()
		net.Start("TTT2RoleVoteUpdate")
		net.WriteUInt(RoleVote.UPDATE_VOTE, 3)
		net.WriteUInt(buttonN.ID, ROLE_BITS)
		net.SendToServer()
	end

	do
		local Paint = buttonN.Paint
		buttonN.Paint = function(s, w, h)
			local col = Color(255, 255, 255, 10)

			if buttonN.bgColor then
				col = buttonN.bgColor
			end

			draw.RoundedBox(4, 0, 0, w, h, col)
			Paint(s, w, h)
		end
	end

	buttonN:SetTextColor(color_white)
	buttonN:SetContentAlignment(4)
	buttonN:SetTextInset(48, 0)
	buttonN:SetFont("TTT2VoteFont")

	buttonN:SetPaintBackground(false)
	buttonN:SetTall(34)
	buttonN:SetWide(285 + extra * 0.5)
	buttonN:SetTooltip("Select no custom role")

	buttonN.NumVotes = 0

	self.roleList:AddItem(buttonN)
end

function PANEL:GetMapButton(role)
	for _, v in pairs(self.roleList:GetItems()) do
		if v.ID == role then
			return v
		end
	end

	return false
end

function PANEL:Paint()
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end

function PANEL:Flash(role)
	self:SetVisible(true)

	local bar = self:GetMapButton(role)
	local panel = self

	if IsValid(bar) then
		timer.Simple(0.0, function()
			bar.bgColor = bar.bgbgColor or Color(0, 255, 255)

			surface.PlaySound("hl1/fvox/blip.wav")
		end)

		timer.Simple(0.2, function()
			bar.bgColor = bar.color
		end)

		timer.Simple(0.4, function()
			bar.bgColor = bar.bgbgColor or Color(0, 255, 255)

			surface.PlaySound("hl1/fvox/blip.wav")
		end)

		timer.Simple(0.6, function()
			bar.bgColor = bar.color
		end)

		timer.Simple(0.8, function()
			bar.bgColor = bar.bgbgColor or Color(0, 255, 255)

			surface.PlaySound("hl1/fvox/blip.wav")
		end)

		timer.Simple(1.0, function()
			bar.bgColor = bar.dkColor
		end)

		timer.Simple(2.0, function()
			if IsValid(panel) then
				panel:SetVisible(false)
			end
		end)
	end
end

derma.DefineControl("RoleVoteScreen", "", PANEL, "DPanel")

hook.Add("TTTUlxModifySettings", "TTT2RoleVoteModifySettings", function(name)
	local tttrspnl = xlib.makelistlayout{w = 415, h = 318, parent = xgui.null}

	local tttrsclp = vgui.Create("DCollapsibleCategory", tttrspnl)
	tttrsclp:SetSize(390, 70)
	tttrsclp:SetExpanded(1)
	tttrsclp:SetLabel("RoleVote")

	local tttrslst = vgui.Create("DPanelList", tttrsclp)
	tttrslst:SetPos(5, 25)
	tttrslst:SetSize(390, 70)
	tttrslst:SetSpacing(5)

	local tttrsdh = xlib.makecheckbox{label = "Enable the RoleVoting (Def. 1)", repconvar = "rep_ttt2_rolevote_enabled", parent = tttrslst}
	tttrslst:AddItem(tttrsdh)

	xgui.hookEvent("onProcessModules", nil, tttrspnl.processModules)
	xgui.addSubModule("RoleVote", tttrspnl, nil, name)
end)
