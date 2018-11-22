surface.CreateFont("TTT2VoteFont", { font = "Trebuchet MS", size = 19, weight = 700, antialias = true})
surface.CreateFont("TTT2VoteFontNeed", { font = "Trebuchet MS", size = 20, weight = 700, antialias = true})
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

	local ply_count = 0

	for _, v in ipairs(player.GetAll()) do

		-- everyone on the spec team is in specmode
		if IsValid(v) and not v:GetForceSpec() then
			ply_count = ply_count + 1
		end
	end

	local tmpTbl = {}

	for _, role in RandomPairs(roles) do
		tmpTbl[#tmpTbl + 1] = role
	end

	tmpTbl[#tmpTbl + 1] = 3 -- random
	tmpTbl[#tmpTbl + 1] = 4 -- none

	for _, role in ipairs(tmpTbl) do
		local button = vgui.Create("DButton", self.roleList)
		button.ID = role

		if role == 3 or role == 4 then
			if role == 3 then
				button.title = "Random"
			else
				button.title = "None"
			end

			local tmpCol = Color(150, 150, 150, 255)

			button.color = tmpCol
			button.bgColor = tmpCol
		else
			local rd = GetRoleByIndex(role)

			button.bgColor = table.Copy(rd.color)
			button.color = table.Copy(rd.color)
			button.dkColor = table.Copy(rd.dkcolor)
			button.icon = "vgui/ttt/sprite_" .. rd.abbr
			button.minPlayers = GetConVar("rep_ttt_" .. rd.name .. "_min_players"):GetInt()
			button.title = LANG.GetTranslation(rd.name)
		end

		button.mainColor = Color(255, 255, 255, 255)

		if button.minPlayers and ply_count < button.minPlayers then
			button.disabled = true
		end

		button.DoClick = function(btn)
			if not btn.disabled then
				net.Start("TTT2RoleVoteUpdate")
				net.WriteUInt(RoleVote.UPDATE_VOTE, 3)
				net.WriteUInt(button.ID, ROLE_BITS)
				net.SendToServer()
			end
		end

		do
			local Paint = button.Paint
			button.Paint = function(s, w, h)
				local col = button.color
				local col2

				if s.disabled then
					col = Color(100, 100, 100, 255)
				elseif s.bgColor then
					col = s.mainColor
					col2 = s.bgColor
				else
					col2 = s.bgColor
				end

				draw.RoundedBox(4, 0, 0, w, h, col)

				-- progress
				if not s.disabled then
					local progress = s.NumVotes / ply_count
					local w2 = w * progress

					draw.RoundedBox(4, w - w2, 0, w2, h, col2)
				end

				if s.icon then
					local mat = Material(s.icon)

					if mat then
						if not s.disabled then
							surface.SetDrawColor(255, 255, 255, 255)
						else
							surface.SetDrawColor(100, 100, 100, 255)
						end

						surface.SetMaterial(mat)
						surface.DrawTexturedRect(5, 5, h - 10, h - 10)
					end
				end

				if s.disabled then
					-- draw player amount
					draw.DrawText(ply_count .. " / " .. s.minPlayers .. " Players", "TTT2VoteFontNeed", s:GetWide() - 21, 10, Color(255, 255, 255, 255), TEXT_ALIGN_RIGHT)
				end

				Paint(s, w, h)
			end
		end

		button:SetTextColor(color_black)
		button:SetText(button.title)
		button:SetContentAlignment(4)
		button:SetTextInset(48, 0)
		button:SetFont("TTT2VoteFont")

		local extra = math.Clamp(300, 0, ScrW() - 640)

		button:SetPaintBackground(false)
		button:SetTall(45)
		button:SetWide(285 + extra * 0.5)
		button:SetTooltip(LANG.GetTranslation("ttt2_desc_" .. GetRoleByIndex(role).name))

		button.NumVotes = 0

		self.roleList:AddItem(button)
	end
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
			bar.bgColor = bar.color
			bar.mainColor = bar.color

			surface.PlaySound("hl1/fvox/blip.wav")
		end)

		timer.Simple(0.2, function()
			bar.bgColor = Color(255, 255, 255, 255)
			bar.mainColor = Color(255, 255, 255, 255)
		end)

		timer.Simple(0.4, function()
			bar.bgColor = bar.color
			bar.mainColor = bar.color

			surface.PlaySound("hl1/fvox/blip.wav")
		end)

		timer.Simple(0.6, function()
			bar.bgColor = Color(255, 255, 255, 255)
			bar.mainColor = Color(255, 255, 255, 255)
		end)

		timer.Simple(0.8, function()
			bar.bgColor = bar.color
			bar.mainColor = bar.color

			surface.PlaySound("hl1/fvox/blip.wav")
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
