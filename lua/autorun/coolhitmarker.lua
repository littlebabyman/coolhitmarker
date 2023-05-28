if engine.ActiveGamemode() != "sandbox" then return end
local longrangeshot = 3937/2 -- 50m
local extralongrangeshot = 3937/2 * 3 -- 150m

if SERVER then
    util.AddNetworkString("profiteers_hitmark")
    util.AddNetworkString("profiteers_gothit")

    local npcheadshotted = false -- fuck you garry

    local function hitmark(ent, dmginfo, took)
        local attacker = dmginfo:GetAttacker()

        if ent.phm_lastHealth == nil then
            if not ( ent:Health() > 0 ) then return end
        else
            if not ( ent.phm_lastHealth > 0 ) then return end
        end

        if took and IsValid(ent) and IsValid(attacker) and attacker:IsPlayer() then
            local distance = ent:GetPos():Distance(attacker:GetPos())

            -- if distance > longrangeshot blabla give more moneys                     btw and check if ent is player because everyone can kill static npcs on long range
            -- if distance > extralongrangeshot blabla give more more moneys and type something in chat about attacker's crazy sniper skills
            
            net.Start("profiteers_hitmark")
            net.WriteUInt(dmginfo:GetDamage(), 16)
            net.WriteBool(ent:IsPlayer() or ent:IsNextBot() or ent:IsNPC())
            net.WriteBool((ent:IsPlayer() and ent:LastHitGroup() == HITGROUP_HEAD) or ((ent:IsNPC() or ent:IsNextBot()) and npcheadshotted) or false)
            net.WriteBool(((ent:IsPlayer() or ent:IsNextBot() or ent:IsNPC()) and ent:Health() <= 0) or (ent:GetNWInt("PFPropHealth", 1) <= 0) or false)
            net.WriteBool((ent:IsPlayer() and ent:Armor() > 0) or false)
            net.WriteUInt(distance, 16)
            net.Send(attacker)
            npcheadshotted = false
        end

		if took and IsValid(ent) and IsValid(attacker) and ent:IsPlayer() then -- hit indicators
			net.Start("profiteers_gothit")
			net.WriteEntity(dmginfo:GetInflictor())
			net.Send(ent)
		end
    end

    -- fuck you garry
    hook.Add("ScaleNPCDamage", "profiteers_hitmarkers_npcheadshots", function(npc, hitgroup, dmginfo)
        if IsValid(npc) and IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker():IsPlayer() then
            if hitgroup == HITGROUP_HEAD then
                npcheadshotted = true
            end
        end
    end)

    hook.Add("EntityTakeDamage", "profiteers_hitmarkers", function(target, dmginfo)
	
        -- This is needed to determine if a player/entity had a health pool
        -- before being killed. Used in "hdn_onEntDamage" hook.
        
        -- This is awful, inelegant, and I hate it. But, it does work.
        -- This solution is temporary until I can find a better way around this. Thankfully, this
        -- is a fairly lightweight bandaid fix and overhead should be tiny, especially since an
        -- entity's lua table is serverside only.

        -- I stole this from Hit Numbers
        
        if not target:IsValid() then return end
        if target:GetCollisionGroup() == COLLISION_GROUP_DEBRIS then return end
        
        target.phm_lastHealth = target:Health()
    end)

    hook.Add("PostEntityTakeDamage", "profiteers_hitmarkers", hitmark)
else
    local hmlength = 0.22 -- 0.5 if kill
    local lasthm = 0
    local lastdistantshot = 0
    local lasthmhead = false
    local lasthmkill = false
    local lasthmarmor = false
    local lasthmprop = false
    local hmmat = Material("profiteers/hitmark.png", "noclamp smooth")
    local hmmat2 = Material("profiteers/headmark.png", "noclamp smooth")
    local hmmat3 = Material("profiteers/hitprop.png", "noclamp smooth")
    local matgear = Material("profiteers/gear.png", "noclamp smooth")

	local hitindicators = {}
    local matgothit = Material("profiteers/hiteffect.png", "noclamp smooth")

    hook.Add("HUDPaint", "profiteers_hitmark_paint", function()
        local lp = LocalPlayer()
        local ct = CurTime()
		local scrw, scrh = ScrW(), ScrH()

        if lasthm > ct then -- any hitmarkers
            local state = (lasthm - ct) / hmlength

            if lasthmprop then
                surface.SetMaterial(hmmat3)
            else
                surface.SetMaterial(lasthmhead and hmmat2 or hmmat)
            end

            if lasthmkill then
                surface.SetDrawColor(255, 0, 0, 255 * state)
            elseif lasthmarmor then
                surface.SetDrawColor(119, 119, 255, 255 * state)
            else
                surface.SetDrawColor(255, 255, 255, 255 * state)
            end

            surface.DrawTexturedRect(scrw / 2 - 18 - 25 * state, scrh / 2 - 18 - 25 * state, 36 + 50 * state, 36 + 50 * state)

			if lasthmprop then -- prop damage
                surface.SetMaterial(matgear)
				surface.DrawTexturedRect(scrw / 2 + 96, scrh / 2 -12, 24, 24)
			end
        end

        if lastdistantshot > ct then -- long range hits
            local state = (lastdistantshot - ct) * 2
            local message = (lasthmkill and lasthmhead) and "Long range HEADSHOT!!" or lasthmkill and "Long range kill!" or "Long range hit"
            -- surface.SetFont("CGHUD_7_Shadow")
            surface.SetFont("ARC9_8_Glow")
            surface.SetTextColor(0, 0, 0, 255 * state)
            surface.SetTextPos(scrw / 2 + 75 + 1, scrh / 2 + 1)
            surface.DrawText(message)
            surface.SetTextPos(scrw / 2 + 75 + 1, scrh / 2 + 20 + 1)
            surface.DrawText(lasthmdistance .. " m")
            -- surface.SetFont("CGHUD_7")
            surface.SetFont("ARC9_8")
            surface.SetTextColor(255, lasthmkill and 75 or 255, lasthmkill and 75 or 255, 255 * state)
            surface.SetTextPos(scrw / 2 + 75, scrh / 2)
            surface.DrawText(message)
            surface.SetTextColor(300 - 255 * (lasthmdistance / 400), 300 - 255 * (lasthmdistance / 400), 255, 255 * state)
            surface.SetTextPos(scrw / 2 + 75, scrh / 2 + 20)
            surface.DrawText(lasthmdistance .. " m")
        end


		for k, v in ipairs(hitindicators) do -- hit indicators
			local decay = math.max(0, (v.time - ct)) * 30

			if decay <= 0 then 
				table.remove(hitindicators, k) -- removing old stains
			end

			local hitVec = v.hitvec
			local ang = math.atan2(hitVec.x, hitVec.y) + math.rad(lp:EyeAngles().y) + 3.14
			local x, y = scrw/2 + math.cos(ang) * scrh/6, scrh/2 + math.sin(ang) * scrh/6
			
			surface.SetDrawColor(255, 255, 255, decay)
			surface.SetMaterial(matgothit)
			surface.DrawTexturedRectRotated(x, y, scrh/14, scrh/14, math.deg(-ang) - 90)  
		end
    end)

    local function hitmarker()
        local dmg = net.ReadUInt(16)
        local isliving = net.ReadBool()
        local head = net.ReadBool()
        local killed = net.ReadBool()
        local armored = net.ReadBool()
        local distance = net.ReadUInt(16)
        local lp = LocalPlayer()
        local ct = CurTime()
        if lasthm > ct and lasthmkill then return end
        lasthmhead = head
        lasthmkill = killed
        lasthmarmor = armored
        lasthmdistance = math.Round(distance * ARC9.HUToM, 1)
        lasthmprop = !isliving
        hmlength = killed and 0.5 or 0.22

        if isliving and distance > longrangeshot then
            lastdistantshot = ct + 3
        end

        lasthm = ct + hmlength

        timer.Simple(0.1, function()
            if not IsValid(lp) then return end -- just to be sure

            -- juicer when many dmg
            for i = 1, math.Clamp(math.ceil(dmg / 40), 1, 4) do
                if head then
                    surface.PlaySound("profiteers/headmarker.wav")
                elseif armored then
                    surface.PlaySound("player/kevlar" .. math.random(1, 5) .. ".wav")
                else
                    surface.PlaySound("profiteers/mwhitmarker.wav")
                end

                if killed then
                    timer.Simple(0.15, function()
                        if not IsValid(lp) then return end -- just to be sure

                        for i = 1, 3 do
                            surface.PlaySound("profiteers/killmarker.wav")
                        end
                    end)
                end
            end
        end)
    end

    net.Receive("profiteers_hitmark", hitmarker)

	local function addgothit(attacker)
		local lp = LocalPlayer()
		if !attacker:IsValid() then return end
		local scrw, scrh = ScrW(), ScrH()
        
		local hitVec =  attacker:GetPos() - lp:GetPos()
	
		table.insert(hitindicators, {
		    time = CurTime() + 3,
			hitvec = hitVec
		})
	end

	net.Receive("profiteers_gothit", function() addgothit(net.ReadEntity()) end)
end