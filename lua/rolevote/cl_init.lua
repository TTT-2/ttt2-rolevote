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

	local amt = net.ReadUInt(ROLE_BITS)

	for i = 1, amt do
		local role = net.ReadUInt(ROLE_BITS)

		RoleVote.CurrentRoles[#RoleVote.CurrentRoles + 1] = role
	end

	RoleVote.EndTime = CurTime() + net.ReadUInt(32)
	RoleVote.MaxVotes = net.ReadUInt(ROLE_BITS)

	if IsValid(RoleVote.Panel) then
		RoleVote.Panel:Remove()
	end

	RoleVote.Voter = {}

	for _, v in ipairs(player.GetAll()) do
		-- everyone on the spec team is in specmode
		if IsValid(v) and not v:GetForceSpec() then
			RoleVote.Voter[#RoleVote.Voter + 1] = v
		end
	end

	RoleVote.Panel = vgui.Create("RoleVoteScreen")
end)

net.Receive("TTT2RoleVoteUpdate", function()
	local update_type = net.ReadUInt(3)

	if update_type == RoleVote.UPDATE_VOTE then
		local ply = net.ReadEntity()

		if IsValid(ply) then
			local role = net.ReadUInt(ROLE_BITS)
			local panel = RoleVote.Panel

			if not IsValid(panel) then return end

			if role == 5 then
				panel:UnvoteAll(ply)
			else
				RoleVote.Votes[ply] = RoleVote.Votes[ply] or {}

				local key

				for k, v in ipairs(RoleVote.Votes[ply]) do
					if v == role then
						key = k

						break
					end
				end

				local icon_container = panel:GetPlayerIcon(ply, role)
				if icon_container then
					if not key then -- new selection
						if icon_container.Role ~= 5 then -- used icon that was already selected
							for k, v in ipairs(RoleVote.Votes[ply]) do
								if v == icon_container.Role then
									table.remove(RoleVote.Votes[ply], k)

									break
								end
							end
						end

						RoleVote.Votes[ply][#RoleVote.Votes[ply] + 1] = role

						icon_container.Role = role
					else -- select same
						table.remove(RoleVote.Votes[ply], key)

						icon_container.Role = 5
					end
				end
			end

			if RoleVote.MaxVotes > 1 then
				if role ~= 4 then
					if #RoleVote.Votes[ply] > 0 then
						local noneButton = panel:GetRoleButton(4)

						if IsValid(noneButton) then
							noneButton.disabled = true
						end
					else
						for _, v in pairs(panel.roleList:GetItems()) do
							if v.ID ~= 5 and (v.ID == 3 or v.ID == 4 or not v.minPlayers or #RoleVote.Voter >= v.minPlayers) then
								v.disabled = false
							end
						end
					end
				else
					if #RoleVote.Votes[ply] == 1 then -- just 4 cached
						for _, v in pairs(panel.roleList:GetItems()) do
							if v.ID ~= 4 and v.ID ~= 5 then
								v.disabled = true
							end
						end
					else
						for _, v in pairs(panel.roleList:GetItems()) do
							if v.ID ~= 4 and v.ID ~= 5 and (v.ID == 3 or not v.minPlayers or #RoleVote.Voter >= v.minPlayers) then
								v.disabled = false
							end
						end
					end
				end
			end
		end
	elseif update_type == RoleVote.UPDATE_WIN then
		if IsValid(RoleVote.Panel) then
			local role_amount = net.ReadUInt(ROLE_BITS)
			local rls = {}

			for i = 1, role_amount do
				rls[#rls + 1] = net.ReadUInt(ROLE_BITS)
			end

			RoleVote.Panel:Flash(rls)
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
	self:InitVoter(RoleVote.Voter, RoleVote.MaxVotes)
	self:SetRoles(RoleVote.CurrentRoles, #RoleVote.Voter)
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

function PANEL:InitVoter(voters, amount)
	for _, voter in ipairs(voters) do
		self.Voters[voter] = self.Voters[voter] or {}

		for i = 1, amount do
			local icon_container = vgui.Create("Panel", self.roleList:GetCanvas())
			icon_container.Role = 5

			local icon = vgui.Create("AvatarImage", icon_container)
			icon:SetSize(16, 16)
			icon:SetZPos(1000)
			icon:SetTooltip(voter:Name())

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

			icon_container:SetZPos(1000)

			self.Voters[voter][#self.Voters[voter] + 1] = icon_container
		end
	end
end

function PANEL:Think()
	for _, bar in pairs(self.roleList:GetItems()) do
		bar.NumVotes = 0
	end

	for voter, tbl in pairs(self.Voters) do
		for _, icon_container in ipairs(tbl) do
			if not IsValid(voter) then
				icon_container:Remove()
			else
				if not icon_container.Role then
					icon_container:Remove()
				else
					local bar = self:GetRoleButton(icon_container.Role)

					if IsValid(bar) then
						if RoleVote.HasExtraVotePower(voter) then
							bar.NumVotes = bar.NumVotes + 2
						else
							bar.NumVotes = bar.NumVotes + 1
						end

						local mul = math.floor((bar.NumVotes + 1) / 2)
						local NewPos = Vector(bar.x + bar:GetWide() - 21 * mul - 2, bar.y + ((bar.NumVotes + 1) % 2 == 1 and (bar:GetTall() * 0.5) or 0), 0)

						if not icon_container.CurPos or icon_container.CurPos ~= NewPos then
							icon_container:MoveTo(NewPos.x, NewPos.y, 0.3)

							icon_container.CurPos = NewPos
						end
					end
				end
			end
		end

		if not IsValid(voter) then
			self.Voters[voter] = nil
		end
	end

	local timeLeft = math.Round(math.Clamp(RoleVote.EndTime - CurTime(), 0, math.huge))

	self.countDown:SetText(tostring(timeLeft or 0) .. " seconds")
	self.countDown:SizeToContents()
	self.countDown:CenterHorizontal()
end

function PANEL:SetRoles(rls, ply_count)
	self.roleList:Clear()

	local tmpTbl = {}

	for _, role in RandomPairs(rls) do
		tmpTbl[#tmpTbl + 1] = role
	end

	tmpTbl[#tmpTbl + 1] = 3 -- random
	tmpTbl[#tmpTbl + 1] = 4 -- none
	tmpTbl[#tmpTbl + 1] = 5 -- unvoted

	for _, role in ipairs(tmpTbl) do
		local button = vgui.Create("DButton", self.roleList)
		button.ID = role

		if role == 3 or role == 4 or role == 5 then
			local tmpCol = Color(150, 150, 150, 255)

			button.color = tmpCol
			button.bgColor = tmpCol
			button.mainColor = Color(255, 255, 255, 255)
			button.selCol = Color(0, 150, 150, 255)

			if role == 3 then
				button.title = "Random"
				button.ttip = "Select a random role"
			elseif role == 4 then
				button.title = "None"
				button.ttip = "Don't select any role"
			else
				button.title = "Unvoted"
				button.mainColor = button.color
				button.ttip = "Don't vote"
			end
		else
			local rd = roles.GetById(role)

			button.bgColor = table.Copy(rd.color)
			button.color = table.Copy(rd.color)
			button.dkColor = table.Copy(rd.dkcolor)
			button.selCol = table.Copy(rd.bgcolor)
			button.mainColor = Color(255, 255, 255, 255)
			button.icon = "vgui/ttt/dynamic/roles/icon_" .. rd.abbr
			button.minPlayers = GetConVar("rep_ttt_" .. rd.name .. "_min_players"):GetInt()
			button.title = LANG.GetTranslation(rd.name)
			button.ttip = LANG.GetTranslation("ttt2_desc_" .. rd.name)
		end

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
				local col = s.color
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

				-- selected
				if s.ID ~= 5 then
					local panel = RoleVote.Panel

					if IsValid(panel) then
						local btn = panel:GetPlayerIcon(LocalPlayer(), s.ID, true)

						if IsValid(btn) then -- button is selected
							draw.RoundedBox(4, 0, 0, 5, h, s.selCol)
						end
					end
				end

				if s.icon then
					local mat = Material(s.icon)

					if mat then
						if not s.disabled then
							color = Color(255, 255, 255, 255)
						else
							color = Color(100, 100, 100, 255)
						end

						DrawHudIcon(5, 5, h - 10, h - 10, mat, color)
					end
				end

				if s.minPlayers and ply_count < s.minPlayers then
					-- draw player amount
					draw.DrawText(ply_count .. " / " .. s.minPlayers .. " Players", "TTT2VoteFontNeed", s:GetWide() - 21, 13, Color(255, 255, 255, 255), TEXT_ALIGN_RIGHT)
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
		button:SetTooltip(button.ttip)

		button.NumVotes = 0

		self.roleList:AddItem(button)
	end
end

function PANEL:UnvoteAll(ply)
	for voter, tbl in pairs(self.Voters) do
		if not ply or ply == voter then
			for _, icon_container in ipairs(tbl) do
				if IsValid(voter) then
					RoleVote.Votes[voter] = {}

					if IsValid(RoleVote.Panel) then
						icon_container.Role = 5
					end
				else
					icon_container:Remove()
				end
			end
		end

		if not IsValid(voter) then
			self.Voters[voter] = nil
		end
	end
end

function PANEL:GetPlayerIcon(ply, role, state)
	-- use current icon on role button
	for voter, tbl in pairs(self.Voters) do
		if voter == ply then
			for _, icon_container in ipairs(tbl) do
				if icon_container.Role == role then
					return icon_container
				end
			end
		end
	end

	if not state then
		-- use available icon on unvoted button
		for voter, tbl in pairs(self.Voters) do
			if voter == ply then
				for _, icon_container in ipairs(tbl) do
					if icon_container.Role == 5 then
						return icon_container
					end
				end
			end
		end

		-- use only one icon if there is just one vote per player
		for voter, tbl in pairs(self.Voters) do
			if #tbl == 1 and voter == ply then
				return tbl[1]
			end
		end
	end

	return false
end

function PANEL:GetRoleButton(role)
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

function PANEL:Flash(rls)
	self:SetVisible(true)

	local bars = {}
	local panel = self

	for _, role in ipairs(rls) do
		local bar = self:GetRoleButton(role)

		if IsValid(bar) then
			bars[#bars + 1] = bar
		end
	end

	timer.Simple(0.0, function()
		for _, bar in ipairs(bars) do
			if IsValid(bar) then
				bar.bgColor = bar.color
				bar.mainColor = bar.color
			end
		end

		surface.PlaySound("hl1/fvox/blip.wav")
	end)

	timer.Simple(0.2, function()
		for _, bar in ipairs(bars) do
			if IsValid(bar) then
				bar.bgColor = Color(255, 255, 255, 255)
				bar.mainColor = Color(255, 255, 255, 255)
			end
		end
	end)

	timer.Simple(0.4, function()
		for _, bar in ipairs(bars) do
			if IsValid(bar) then
				bar.bgColor = bar.color
				bar.mainColor = bar.color
			end
		end

		surface.PlaySound("hl1/fvox/blip.wav")
	end)

	timer.Simple(0.6, function()
		for _, bar in ipairs(bars) do
			if IsValid(bar) then
				bar.bgColor = Color(255, 255, 255, 255)
				bar.mainColor = Color(255, 255, 255, 255)
			end
		end
	end)

	timer.Simple(0.8, function()
		for _, bar in ipairs(bars) do
			if IsValid(bar) then
				bar.bgColor = bar.color
				bar.mainColor = bar.color
			end
		end

		surface.PlaySound("hl1/fvox/blip.wav")
	end)

	timer.Simple(3.0, function()
		if IsValid(panel) then
			panel:SetVisible(false)
		end
	end)
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

	local tttrsdh2 = xlib.makeslider{label = "Amount of Votes (Def. 1)", min = 1, max = 32, repconvar = "rep_ttt2_rolevote_votes", parent = tttrslst}
	tttrslst:AddItem(tttrsdh2)

	xgui.hookEvent("onProcessModules", nil, tttrspnl.processModules)
	xgui.addSubModule("RoleVote", tttrspnl, nil, name)
end)
