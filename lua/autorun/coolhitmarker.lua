-- if engine.ActiveGamemode() != "sandbox" then return end
local longrangeshot = 3937 * 0.5 -- 50m
local extralongrangeshot = 3937 * 1.5 -- 150m

if SERVER then
    util.AddNetworkString("profiteers_hitmark")
    util.AddNetworkString("profiteers_gothit")

    local npcheadshotted = false -- fuck you garry

    local function hitmark(ent, dmginfo, took)
        local attacker = dmginfo:GetAttacker()

        if dmginfo:GetInflictor() == ent or attacker == ent then return end
        if !ent.phm_lastHealth then if ent:Health() <= 0 then return end elseif ent.phm_lastHealth <= 0 then return end

        if IsValid(ent) and IsValid(attacker) and attacker:IsPlayer() then
            local distance = ent:GetPos():Distance(attacker:GetPos())

            -- if distance > longrangeshot blabla give more moneys                     btw and check if ent is player because everyone can kill static npcs on long range
            -- if distance > extralongrangeshot blabla give more more moneys and type something in chat about attacker's crazy sniper skills

            net.Start("profiteers_hitmark")
            net.WriteUInt(dmginfo:GetDamage(), 16)
            net.WriteBool(ent:IsPlayer() or ent:IsNextBot() or ent:IsNPC())
            net.WriteBool((ent:IsPlayer() and ent:LastHitGroup() == HITGROUP_HEAD) or ((ent:IsNPC() or ent:IsNextBot()) and npcheadshotted) or false)
            net.WriteBool(bit.band(dmginfo:GetDamageType(), DMG_BURN+DMG_DIRECT) == DMG_BURN+DMG_DIRECT or false)
            net.WriteBool(((ent:IsPlayer() or ent:IsNextBot() or ent:IsNPC()) and ent:Health() <= 0) or (ent:GetNWInt("PFPropHealth", 1) <= 0) or false)
            net.WriteVector(dmginfo:GetDamagePosition() != Vector() and attacker:VisibleVec(dmginfo:GetDamagePosition()) and dmginfo:GetDamagePosition() or Vector())
            net.WriteUInt((ent:IsPlayer() and (ent:Armor() > 0 and 1 or 0) + (ent.phm_lastArmor > 0 and 2 or 0)) or 0, 2)
            net.WriteUInt(distance, 16)
            net.Send(attacker)
            npcheadshotted = false
        end

        if IsValid(ent) and IsValid(attacker) and ent:IsPlayer() then -- hit indicators
            net.Start("profiteers_gothit")
            net.WriteEntity(dmginfo:GetInflictor())
            net.WriteUInt((ent:IsPlayer() and (ent:Armor() > 0 and 1 or 0) + (ent.phm_lastArmor > 0 and 2 or 0)) or 0, 2)
            net.Send(ent)
        end
    end

    -- fuck you garry
    hook.Add("ScaleNPCDamage", "profiteers_hitmarkers_npcheadshots", function(ent, hitgroup, dmginfo)
        npcheadshotted = IsValid(ent) and IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker():IsPlayer() and hitgroup == HITGROUP_HEAD
    end)

    hook.Add("EntityTakeDamage", "profiteers_hitmarkers", function(target, dmginfo)

        -- largely copied idea from hit numbers
        if !target:IsValid() then return end
        if target:GetCollisionGroup() == COLLISION_GROUP_DEBRIS then return end
        if target:IsPlayer() then
            target.phm_lastArmor = target:Armor() or 0
        end
        target.phm_lastHealth = target:Health() or 0
        if dmginfo:GetAttacker():IsPlayer() and dmginfo:IsDamageType(DMG_BURN+DMG_SLOWBURN) then target.phm_lastAttacker = dmginfo:GetAttacker() end
        if target.phm_lastAttacker and dmginfo:IsDamageType(DMG_BURN+DMG_SLOWBURN) then
            dmginfo:SetAttacker(target.phm_lastAttacker)
        end
    end)

    hook.Add("PostEntityTakeDamage", "profiteers_hitmarkers", hitmark)
else
    local hm = CreateClientConVar("profiteers_hitmarker_enable", "1", true, true, "Enable Profiteers Hitmarker.", 0, 3)
    local hmpos = CreateClientConVar("profiteers_hitmarker_dynamic", "1", true, true, "Use dynamic ''real'' position for hit markers.", 0, 1)
    local hmscale = CreateClientConVar("profiteers_hitmarker_scale", "1", true, true, "Show Longshot indicators. 1 for all hits, 2 for kills only.", 0.25, 2.5)
    local indicators = CreateClientConVar("profiteers_dmgindicator_enable", "1", true, true, "Enable Profiteers Damage indicators.", 0, 1)
    local indicatorscale = CreateClientConVar("profiteers_dmgindicator_scale", "1", true, true, "Custom scaling for Profiteers damage indicators.", 0.25, 2.5)
    local distantshot = CreateClientConVar("profiteers_hitmarker_longshot", "1", true, true, "Show Longshot indicators. 1 for all hits, 2 for kills only.", 0, 2)
    local hmarmor = CreateClientConVar("profiteers_hitmarker_armor", "1", true, true, "Show armor hit indicators.", 0, 1)
    local hmhead = CreateClientConVar("profiteers_hitmarker_head", "1", true, true, "Show headshot indicators.", 0, 1)
    local hmkill = CreateClientConVar("profiteers_hitmarker_kill", "1", true, true, "Show kill indicators.", 0, 1)
    local hmfire = CreateClientConVar("profiteers_hitmarker_fire", "1", true, true, "Show afterburn indicators.", 0, 1)
    local hmprop = CreateClientConVar("profiteers_hitmarker_prop", "1", true, true, "Show prop (and other breakable entity) hit indicators.", 0, 1)
    local hmlength = 0.22 -- 0.5 if kill
    local hmrotata = 0
    local lasthm = 0
    local lastdistantshot = 0
    local lasthmpos = Vector()
    local lasthmtbl = {x = ScrW() * 0.5, y = ScrH() * 0.5, visible = false}
    local lasthmarmor = 0
    local lasthmhead = false
    local lasthmkill = false
    local lasthmprop = false
    local lasthmfire = false
    local hmmat = Material("profiteers/hitmark.png", "noclamp smooth")
    local hmmat2 = Material("profiteers/headmark.png", "noclamp smooth")
    local hmmat3 = Material("profiteers/hitprop.png", "noclamp smooth")
    local hmmat4 = Material("profiteers/hitmarkdestroyarmor.png", "noclamp smooth")
    local matgear = Material("profiteers/gear.png", "noclamp smooth")
    local matfire = Material("profiteers/fire.png", "noclamp smooth")
    local matarmor = Material("profiteers/kevlar.png", "noclamp smooth")
    local matarmorb = Material("profiteers/kevlarbroken.png", "noclamp smooth")
    local matarmor2 = Material("profiteers/kevlar2.png", "noclamp smooth")
    local matarmorb2 = Material("profiteers/kevlar2broken.png", "noclamp smooth")

    local hitindicators = {}
    local matgothit = Material("profiteers/hiteffect.png", "noclamp smooth")
    local matarmorhit = Material("profiteers/hiteffectarmor.png", "noclamp smooth")
    local matarmorbreak = Material("profiteers/hiteffectarmorbroken.png", "noclamp smooth")
    
    hook.Add("PopulateToolMenu", "profiteers_hitmark_options", function()
        spawnmenu.AddToolMenuOption("Utilities", "User", "profiteers_hitmarker", "Cool Hitmarkers", "", "", function(pan)
            local mode = pan:ComboBox("Hitmarker mode", "profiteers_hitmarker_enable")
            mode:SetSortItems(false)
            mode:AddChoice("Disabled", 0)
            mode:AddChoice("Audiovisual", 1)
            mode:AddChoice("Visual only", 2)
            mode:AddChoice("Audio only", 3)
            pan:NumSlider("Hitmarker scale", "profiteers_hitmarker_scale", 0.25, 2.5, 3)
            pan:CheckBox("Use dynamic position for hit markers", "profiteers_hitmarker_dynamic")
            local long = pan:ComboBox("Longshot indicators", "profiteers_hitmarker_longshot")
            long:SetSortItems(false)
            long:AddChoice("Disabled", 0)
            long:AddChoice("Every hit", 1)
            long:AddChoice("Kills only", 2)
            pan:CheckBox("Show armor hit indicators", "profiteers_hitmarker_armor")
            pan:CheckBox("Show headshot indicators", "profiteers_hitmarker_head")
            pan:CheckBox("Show kill indicators", "profiteers_hitmarker_kill")
            pan:CheckBox("Show afterburn indicators", "profiteers_hitmarker_fire")
            pan:CheckBox("Show prop (and other breakable entity) hit indicators", "profiteers_hitmarker_prop")
            pan:ControlHelp("")
            pan:CheckBox("Enable directional damage indicators", "profiteers_dmgindicator_enable")
            pan:NumSlider("Damage indicator scale", "profiteers_dmgindicator_scale", 0.25, 2.5, 3)
            pan:Help("It's those arrows pointing toward where you were shot from.")
        end)
    end)

    -- hush
    local function DoSize(size, scale) -- scale is 2 bit operator, first bit dimension, second indicator or hitmarker
        scale = scale or 0
        return size * (bit.band(scale, 1) == 1 and (ScrH() / 480) or ScreenScale(1)) * (bit.band(scale, 2) == 2 and indicatorscale:GetFloat() or hmscale:GetFloat())
    end

    hook.Add("HUDPaint", "profiteers_hitmark_paint", function()
        if hm:GetInt() == 3 then return end
        local lp = LocalPlayer()
        local ct = CurTime()
        local scrw, scrh = ScrW(), ScrH()
        local x, y = 0 < lasthmtbl.x and lasthmtbl.x < scrw and lasthmtbl.x or scrw * 0.5, 0 < lasthmtbl.y and lasthmtbl.y < scrh and lasthmtbl.y or scrh * 0.5

        if lasthm > ct then -- any hitmarkers
            local state = (lasthm - ct) / hmlength
            -- hmrotata = math.max(0, hmrotata - FrameTime()*300)
            hmrotata = Lerp(FrameTime()*25, hmrotata, 0)

            if hmarmor:GetBool() and lasthmarmor == 2 then
                surface.SetMaterial(hmmat4)
            elseif lasthmprop or hmfire:GetBool() and lasthmfire then
                surface.SetMaterial(hmmat3)
            else
                surface.SetMaterial(hmhead:GetBool() and lasthmhead and hmmat2 or hmmat)
            end
            if hmkill:GetBool() and lasthmkill then
                surface.SetDrawColor(255, 0, 0, 255 * state)
            elseif hmarmor:GetBool() and lasthmarmor > 0 then
                surface.SetDrawColor(119, 119, 255, 255 * state)
            else
                surface.SetDrawColor(255, 255, 255, 255 * state)
            end

            -- surface.DrawTexturedRect(x - DoSize(6) - DoSize(8) * state, y - DoSize(6) - DoSize(8) * state, DoSize(12) + DoSize(16) * state, DoSize(12) + DoSize(16) * state)
            surface.DrawTexturedRectRotated(x, y, DoSize(12) + DoSize(16) * state, DoSize(12) + DoSize(16) * state, hmrotata)

            if hmarmor:GetBool() and lasthmarmor > 0 then
                surface.SetDrawColor(119, 119, 255, 255 * state)
                if lasthmarmor == 3 then -- armor damage
                    surface.SetMaterial(matarmor)
                else
                    surface.SetMaterial(matarmorb)
                end
                surface.DrawTexturedRect(x + DoSize(16), y - DoSize(12), DoSize(8), DoSize(8))
            end
            if lasthmprop then -- prop damage
                surface.SetDrawColor(255, 255, 255, 255 * state)
                surface.SetMaterial(matgear)
                surface.DrawTexturedRect(x + DoSize(16), y + DoSize(4), DoSize(8), DoSize(8))
            end
            if hmfire:GetBool() and lasthmfire then -- afterburn damage
                surface.SetDrawColor(255, 255, 255, 255 * state)
                surface.SetMaterial(matfire)
                surface.DrawTexturedRect(x - DoSize(4), y + DoSize(16), DoSize(8), DoSize(8))
            end
        end

        if (distantshot:GetInt() == 2 and lasthmkill or distantshot:GetInt() == 1) and lastdistantshot > ct then -- long range hits
            local state = (lastdistantshot - ct) * 2
            local message = (lasthmkill and lasthmhead) and "Long range HEADSHOT!!" or lasthmkill and "Long range kill!" or "Long range hit"
            -- surface.SetFont("CGHUD_7_Shadow")
            surface.SetFont(ARC9 and "ARC9_8_Glow" or "GModNotify")
            surface.SetTextColor(0, 0, 0, 255 * state)
            surface.SetTextPos(scrw * 0.5 + DoSize(25) + 1, scrh * 0.5 + 1)
            surface.DrawText(message)
            surface.SetTextPos(scrw * 0.5 + DoSize(25) + 1, scrh * 0.5 + 20 + 1)
            surface.DrawText(lasthmdistance .. " m")
            -- surface.SetFont("CGHUD_7")
            surface.SetFont(ARC9 and "ARC9_8" or "GModNotify")
            surface.SetTextColor(255, lasthmkill and 75 or 255, lasthmkill and 75 or 255, 255 * state)
            surface.SetTextPos(scrw * 0.5 + DoSize(25), scrh * 0.5)
            surface.DrawText(message)
            surface.SetTextColor(300 - 255 * (lasthmdistance / 400), 300 - 255 * (lasthmdistance / 400), 255, 255 * state)
            surface.SetTextPos(scrw * 0.5 + DoSize(25), scrh * 0.5 + 20)
            surface.DrawText(lasthmdistance .. " m")
        end

        if indicators:GetBool() then
            for k, v in ipairs(hitindicators) do -- hit indicators
                local decay = math.max(0, (v.time - ct)) * 30

                if decay <= 0 then
                    table.remove(hitindicators, k) -- removing old stains
                end

                local hitVec = v.hitvec
                local armorBreak = v.armor
                local ang = math.atan2(hitVec.x, hitVec.y) + math.rad(lp:EyeAngles().y) + 3.14
                local x, y = scrw/2 + math.cos(ang) * DoSize(60, 3), scrh/2 + math.sin(ang) * DoSize(60, 3)

                if armorBreak > 0 then
                    surface.SetDrawColor(119, 119, 255, decay)
                    if armorBreak == 2 then
                        surface.SetMaterial(matarmorbreak)
                    else
                        surface.SetMaterial(matarmorhit)
                    end
                else
                    surface.SetDrawColor(255, 255, 255, decay)
                    surface.SetMaterial(matgothit)
                end
                surface.DrawTexturedRectRotated(x, y, DoSize(34, 3), DoSize(34, 3), math.deg(-ang) - 90)
            end
        end
    end)

    local function hitmarker()
        if !hm:GetBool() then return end
        local dmg = net.ReadUInt(16)
        local isliving = net.ReadBool()
        local head = net.ReadBool()
        local onfire = net.ReadBool()
        local killed = net.ReadBool()
        local pos = net.ReadVector()
        local armored = net.ReadUInt(2)
        local distance = net.ReadUInt(16)
        local lp = LocalPlayer()
        local ct = CurTime()
        if lasthm > ct and lasthmkill then return end
        lasthmhead = head
        lasthmfire = onfire
        lasthmkill = killed
        lasthmpos = pos

        hmrotata = math.random(-12, 12)

        lasthmtbl = {x = ScrW() * 0.5, y = ScrH() * 0.5, visible = false }

        if hmpos:GetBool() and lasthmpos != Vector() then
            cam.Start3D()

            local toscr = pos:ToScreen()
            if toscr.visible then
                lasthmtbl = pos:ToScreen()
            end

            cam.End3D()
        end

        lasthmarmor = armored
        lasthmprop = !isliving
        hmlength = (armored == 2 or killed) and 0.5 or 0.22

        if isliving then
            if distance > longrangeshot then
            lasthmdistance = math.Round(distance * 0.0254, 1)
            lastdistantshot = ct + 3
            end
        elseif !hmprop:GetBool() then return end

        lasthm = ct + hmlength

        if hm:GetInt() == 2 then return end

        if armored == 2 then -- seperate armor break sond without delay
            surface.PlaySound("profiteers/breakarmorr.ogg")
        end

        timer.Simple(0.06, function()
            if !lp then return end -- just to be sure

            -- juicer when many dmg
            for i = 1, math.Clamp(math.ceil(dmg / 40), 1, 4) do
                if !onfire and head then
                    surface.PlaySound("profiteers/headmarker.ogg")
                elseif armored == 3 then
                    surface.PlaySound("player/kevlar" .. math.random(5) .. ".wav")
                else
                    surface.PlaySound("profiteers/mwhitmarker.ogg")
                end

                if killed then
                    timer.Simple(0.15, function()
                        if !IsValid(lp) then return end -- just to be sure

                        for i = 1, 3 do
                            surface.PlaySound("profiteers/killmarker.ogg")
                        end
                    end)
                end
            end
        end)
    end

    net.Receive("profiteers_hitmark", hitmarker)

    local function addgothit(attacker, armor)
        local lp = LocalPlayer()
        if !attacker:IsValid() then return end
        local scrw, scrh = ScrW(), ScrH()

        local hitVec =  attacker:GetPos() - lp:GetPos()

        if armor == 2 then
            surface.PlaySound("profiteers/breakarmorself.ogg")
        end

        table.insert(hitindicators, {
            time = CurTime() + 3,
            hitvec = hitVec,
            armor = armor
        })
    end

    net.Receive("profiteers_gothit", function() addgothit(net.ReadEntity(), net.ReadUInt(2)) end)
end