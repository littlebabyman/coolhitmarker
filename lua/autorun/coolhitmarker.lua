CoolHitmarkersInstalled = true
-- if engine.ActiveGamemode() != "sandbox" then return end
local longrangeshot = 3937 * 0.5 -- 50m

local flags = {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED}

local hmoverride = CreateConVar("profiteers_override_enabled", "0", flags, "Override Profiteers UI settings.", 0, 1)
local hmsv = CreateConVar("profiteers_override_hitmarker_enable", "1", flags, "Override Profiteers Hitmarker. 0 disabled, 1 audiovisual, 2 visual only, 3 audio only.", 0, 3)
local hmpossv = CreateConVar("profiteers_override_hitmarker_dynamic", "1", flags, "Override dynamic ''real'' position for hit markers.", 0, 1)
local hmscalesv = CreateConVar("profiteers_override_hitmarker_scale", "1", flags, "Override Longshot indicators. 1 for all hits, 2 for kills only.", 0.25, 2.5)
local indicatorssv = CreateConVar("profiteers_override_dmgindicator_enable", "1", flags, "Override Profiteers Damage indicators.", 0, 1)
local indicatorscalesv = CreateConVar("profiteers_override_dmgindicator_scale", "1", flags, "Override custom scaling for Profiteers damage indicators.", 0.25, 2.5)
local distantshotsv = CreateConVar("profiteers_override_hitmarker_longshot", "1", flags, "Override Longshot indicators. 1 for all hits, 2 for kills only.", 0, 2)
local hmarmorsv = CreateConVar("profiteers_override_hitmarker_armor", "1", flags, "Override armor hit indicators.", 0, 1)
local hmheadsv = CreateConVar("profiteers_override_hitmarker_head", "1", flags, "Override headshot indicators.", 0, 1)
local hmkillsv = CreateConVar("profiteers_override_hitmarker_kill", "1", flags, "Override kill indicators.", 0, 1)
local hmfiresv = CreateConVar("profiteers_override_hitmarker_fire", "1", flags, "Override afterburn indicators.", 0, 1)
local hmpropsv = CreateConVar("profiteers_override_hitmarker_prop", "1", flags, "Override prop (and other breakable entity) hit indicators.", 0, 1)
local skullssv = CreateConVar("profiteers_override_skulls", "1", flags, "Override Show how many enemys youve killed. very cruel.", 0, 1)

local ammotable = { -- plese nothing bigger than 2 digits :) uint bitch
    ["buckshot"] = 0.3,
    ["pistol"] = 0.5,
    ["smg1"] = 0.7,
    ["sniperpenetratedround"] = 1.5,
    ["sniperround"] = 1.5,
    ["xbowbolt"] = 1.5,

    ["default"] = 1,
    -- 357 used often for sniper rifles, not only pistols, so keeping it on 1
    -- ar2 is default basically so 1 too
}

if SERVER then
    util.AddNetworkString("profiteers_hitmark")
    util.AddNetworkString("profiteers_gothit")

    local npcheadshotted = false -- fuck you garry

    local function hitmark(ent, dmginfo, took)
        local attacker, inflictor = dmginfo:GetAttacker(), dmginfo:GetInflictor()
        if attacker:IsVehicle() and IsValid(attacker:GetDriver()) then attacker = attacker:GetDriver() end
        local attply, vicply = attacker:IsPlayer(), ent:IsPlayer()
        if (!attply and !vicply) then return end
        if inflictor == ent or attacker == ent then return end
        local vichp = ent:Health()
        local ct = CurTime()
        if ent.phm_lastHealth and ent.phm_lastHealth == vichp and (!took and (vichp <= 0 or attacker.phm_lastMarker and attacker.phm_lastMarker > ct) or dmginfo:GetDamage() == 0 or took) then return end
        local vicnpc = ent:IsNextBot() or ent:IsNPC()

        if IsValid(ent) and IsValid(attacker) and attply then
            attacker.phm_lastMarker = ct + 0.5 -- stop fucking shooting shit you cant hurt
            local distance = ent:GetPos():Distance(attacker:GetPos())
            local dmgpos = (inflictor:IsWeapon() or inflictor:IsPlayer()) and dmginfo:GetDamagePosition() or ent:WorldSpaceCenter()
            local swep = attacker:GetActiveWeapon()
            local ammo = swep:IsValid() and swep:IsScripted() and string.lower(swep.Primary.Ammo or "default") or "default"
            local armored = ent.Armor and isnumber(ent:Armor()) and ent.phm_lastArmor
            local dmg = math.Clamp(math.ceil(ent.phm_lastHealth and ent.phm_lastHealth - vichp or dmginfo:GetDamage() * 0.025), 0, 3)
            local dmgtype = dmginfo:GetDamageType()
            local sentient = vicply or vicnpc
            local hitdata = 0
            local killtype = 0
            if sentient then hitdata = hitdata + 1 end
            if (sentient and vichp <= 0) or (ent:GetNWInt("PFPropHealth", 1) <= 0) then
                hitdata = hitdata + 2
                if inflictor == attacker and dmginfo:GetDamageCustom() == 67 then killtype = 1
                elseif inflictor:IsWeapon() and bit.band(dmgtype, bit.bor(DMG_CLUB, DMG_SLASH)) != 0 then killtype = 2
                elseif bit.band(dmgtype, DMG_BLAST) != 0 then killtype = 3
                elseif inflictor:IsVehicle() and bit.band(dmgtype, bit.bor(DMG_VEHICLE, DMG_CRUSH)) != 0 then killtype = 4
                elseif bit.band(dmgtype, DMG_DISSOLVE) != 0 then killtype = 5
                elseif bit.band(dmgtype, DMG_CRUSH) != 0 then killtype = 6
                elseif bit.band(dmgtype, DMG_BURN+DMG_DIRECT) != 0 then killtype = 7
                end
            end
            if (ent.LastHitGroup and ent:LastHitGroup() == HITGROUP_HEAD or npcheadshotted) then
                hitdata = hitdata + 4
                if ent.SetLastHitGroup then ent:SetLastHitGroup(HITGROUP_GENERIC) end
            end
            if bit.band(dmgtype, DMG_BURN+DMG_DIRECT) != 0 then hitdata = hitdata + 8 end

            if !ammotable[ammo] then ammo = "default" end

            if ammotable[ammo] == 0.3 then -- its shotgun, checking for slugs
                if (swep.ARC9 and swep:GetValue("Num") or swep.GripPoseParameters and swep.Bullet.NumBullets or swep.ArcCW and (swep:GetBuff_Override("Override_Num") or swep.Num) or swep.Primary.Num or 6) < 3 then
                    ammo = "smg1" -- setting range mult to 0.7
                end
            end

            -- if you making some gamemode you can add here check for distance and give more points/moneys for long kills
            net.Start("profiteers_hitmark")
            net.WriteUInt(dmg or 0, 2) -- Damage
            net.WriteUInt(hitdata, 5) -- All the necessary data
            net.WriteUInt(killtype, 3) -- Type of kill damage
            -- net.WriteBool(sentient) -- Sentient (Player or npc) or prop
            -- net.WriteBool(ent.LastHitGroup and ent:LastHitGroup() == HITGROUP_HEAD or npcheadshotted or false) -- Headshot
            -- net.WriteBool(bit.band(dmgtype, DMG_BURN+DMG_DIRECT) == DMG_BURN+DMG_DIRECT or false) -- Burned, done on client
            -- net.WriteBool((sentient and vichp <= 0) or (ent:GetNWInt("PFPropHealth", 1) <= 0) or false) -- Was killed
            -- net.WriteBool(dmginfo:GetInflictor() == attacker and dmginfo:GetDamageCustom() == 67)
            net.WriteNormal(dmgpos != vector_origin and attacker:VisibleVec(dmgpos) and (dmgpos-attacker:EyePos()):GetNormalized() or vector_origin) -- Hit position
            net.WriteUInt(armored and (ent:Armor() > 0 and 1 or 0) + ((ent.phm_lastArmor or 0) > 0 and 2 or 0) or 0, 2) -- Armor and break
            net.WriteUInt(distance, 16) -- Distance to hit
            net.WriteUInt(ammotable[ammo]*10, 6) -- Ammo type in gun
            -- net.WriteUInt( ((dmgtype == DMG_CLUB or dmgtype == DMG_SLASH) and 1) or (dmgtype == DMG_BLAST and 2) or 0, 2) -- Melee or explosion or other dmg type (for skulls), done on client
            net.Send(attacker)
            npcheadshotted = false
        end

        if took and IsValid(ent) and IsValid(attacker) and vicply and !ent:IsBot() then -- hit indicators
            net.Start("profiteers_gothit")
            net.WriteEntity(inflictor)
            net.WriteUInt((vicply and (ent:Armor() > 0 and 1 or 0) + ((ent.phm_lastArmor or 0) > 0 and 2 or 0)) or 0, 2)
            net.Send(ent)
        end
    end

    -- fuck you garry
    hook.Add("ScaleNPCDamage", "profiteers_hitmarkers_npcheadshots", function(ent, hitgroup, dmginfo)
        npcheadshotted = IsValid(ent) and IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker():IsPlayer() and hitgroup == HITGROUP_HEAD
    end)

    hook.Add("EntityTakeDamage", "profiteers_hitmarkers", function(target, dmginfo)

        -- largely copied idea from hit numbers
        if !target:IsValid() or dmginfo:GetDamage() <= 0 then return end
        if dmginfo:GetAttacker():IsPlayer() and dmginfo:IsDamageType(DMG_BURN+DMG_SLOWBURN) then target.phm_lastAttacker = dmginfo:GetAttacker() end
        if target.phm_lastAttacker and dmginfo:IsDamageType(DMG_BURN+DMG_SLOWBURN) then
            dmginfo:SetAttacker(target.phm_lastAttacker)
        end
        if target.Armor and isnumber(target:Armor()) then
            target.phm_lastArmor = target:Armor() or 0
        end
        target.phm_lastHealth = target:Health() or 0
    end)

    hook.Add("PostEntityTakeDamage", "profiteers_hitmarkers", hitmark)
else
    local hm = CreateClientConVar("profiteers_hitmarker_enable", "1", true, true, "Enable Profiteers Hitmarker. 0 disabled, 1 audiovisual, 2 visual only, 3 audio only.", 0, 3)
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
    local skulls = CreateClientConVar("profiteers_skulls", "1", true, true, "Show how many enemys youve killed. very cruel.", 0, 1)
    local hmlength = 0.22 -- 0.5 if kill
    local hmrotata = 0
    local hmauth = 0
    local lasthm = 0
    local lasthurt = false
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
    local matgear = Material("profiteers/hitgear.png", "noclamp smooth")
    local matfire = Material("profiteers/hitfire.png", "noclamp smooth")
    local matarmor = Material("profiteers/kevlar.png", "noclamp smooth")
    local matarmorb = Material("profiteers/kevlarbroken.png", "noclamp smooth")
    local matarmor2 = Material("profiteers/kevlar2.png", "noclamp smooth")
    local matarmorb2 = Material("profiteers/kevlar2broken.png", "noclamp smooth")

    local hitindicators = {}
    local matgothit = Material("profiteers/hiteffect.png", "noclamp smooth")
    local matarmorhit = Material("profiteers/hiteffectarmor.png", "noclamp smooth")
    local matarmorbreak = Material("profiteers/hiteffectarmorbroken.png", "noclamp smooth")
    
    hook.Add("PopulateToolMenu", "profiteers_hitmark_options", function()
        spawnmenu.AddToolMenuOption("Utilities", "Cool™ Combat", "profiteers_hitmarker", "Hitmarkers", "", "", function(pan)
            pan:SetName("Cool™ Hitmarkers")
            local cl, sv = vgui.Create("DForm"), vgui.Create("DForm")
            pan:AddItem(cl)
            pan:AddItem(sv)
            cl:SetName("Client")
            sv:SetName("Server Overrides")
            cl:ControlHelp("\nHitmarkers")
            local mode = cl:ComboBox("Hitmarker mode", "profiteers_hitmarker_enable")
            mode:SetSortItems(false)
            mode:AddChoice("Disabled", 0)
            mode:AddChoice("Full hitmarkers", 1)
            mode:AddChoice("Visuals only", 2)
            mode:AddChoice("Sound only", 3)
            cl:NumSlider("Hitmarker scale", "profiteers_hitmarker_scale", 0.25, 2.5, 3)
            cl:CheckBox("Use dynamic position for hit markers", "profiteers_hitmarker_dynamic")
            local long = cl:ComboBox("Longshot indicators", "profiteers_hitmarker_longshot")
            long:SetSortItems(false)
            long:AddChoice("Disabled", 0)
            long:AddChoice("Every hit", 1)
            long:AddChoice("Kills only", 2)
            cl:CheckBox("Show armor hit indicators", "profiteers_hitmarker_armor")
            cl:CheckBox("Show headshot indicators", "profiteers_hitmarker_head")
            cl:CheckBox("Show kill indicators", "profiteers_hitmarker_kill")
            cl:CheckBox("Show afterburn indicators", "profiteers_hitmarker_fire")
            cl:CheckBox("Show breakable entity hit indicators", "profiteers_hitmarker_prop")
            cl:ControlHelp("\nDamage indicators")
            cl:CheckBox("Show directional damage indicators", "profiteers_dmgindicator_enable")
            cl:NumSlider("Damage indicator scale", "profiteers_dmgindicator_scale", 0.25, 2.5, 3)
            cl:Help("It's those arrows pointing toward where you were shot from.")

            if !CoolKillchainsInstalled then
                pan:ControlHelp("\nBest used with:")
                local btn = pan:Button("Cool™ Killchains <3")
                btn.DoClick = function()
                    gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3193486764") -- uhh please edit link to the killchains page later
                end
            end

            sv:CheckBox("Enforce server hitmarker settings for all players", "profiteers_override_enabled")
            sv:ControlHelp("\nHitmarkers")
            local mode = sv:ComboBox("Hitmarker mode", "profiteers_override_hitmarker_enable")
            mode:SetSortItems(false)
            mode:AddChoice("Disabled", 0)
            mode:AddChoice("Full hitmarkers", 1)
            mode:AddChoice("Visuals only", 2)
            mode:AddChoice("Sound only", 3)
            sv:NumSlider("Hitmarker scale", "profiteers_override_hitmarker_scale", 0.25, 2.5, 3)
            sv:CheckBox("Use dynamic position for hit markers", "profiteers_override_hitmarker_dynamic")
            local long = sv:ComboBox("Longshot indicators", "profiteers_override_hitmarker_longshot")
            long:SetSortItems(false)
            long:AddChoice("Disabled", 0)
            long:AddChoice("Every hit", 1)
            long:AddChoice("Kills only", 2)
            sv:CheckBox("Show armor hit indicators", "profiteers_override_hitmarker_armor")
            sv:CheckBox("Show headshot indicators", "profiteers_override_hitmarker_head")
            sv:CheckBox("Show kill indicators", "profiteers_override_hitmarker_kill")
            sv:CheckBox("Show afterburn indicators", "profiteers_override_hitmarker_fire")
            sv:CheckBox("Show breakable entity hit indicators", "profiteers_override_hitmarker_prop")
            sv:ControlHelp("\nDamage indicators")
            sv:CheckBox("Show directional damage indicators", "profiteers_override_dmgindicator_enable")
            sv:NumSlider("Damage indicator scale", "profiteers_override_dmgindicator_scale", 0.25, 2.5, 3)
            sv:Help("It's those arrows pointing toward where you were shot from.")
        end)
    end)

    -- hush
    local function DoSize(size, scale) -- scale is 2 bit operator, first bit dimension, second indicator or hitmarker
        scale = scale or 0
        local iscale, hscale = (hmauth and indicatorscalesv or indicatorscale), (hmauth and hmscalesv or hmscale)
        return size * (bit.band(scale, 1) == 1 and (ScrH() / 480) or (ScrW() / 640)) * (bit.band(scale, 2) == 2 and iscale:GetFloat() or hscale:GetFloat())
    end
    
    hook.Add("HUDPaint", "profiteers_hitmark_paint", function()
        local modee = (hmauth and hmsv:GetInt() or hm:GetInt())
        local novisual = modee == 0 or modee == 3

        if novisual then return end

        local lp = LocalPlayer()
        local ct = CurTime()
        local scrw, scrh = ScrW(), ScrH()
        local alpha = lasthurt and 255 or 119
        local x, y = 0 < lasthmtbl.x and lasthmtbl.x < scrw and lasthmtbl.x or scrw * 0.5, 0 < lasthmtbl.y and lasthmtbl.y < scrh and lasthmtbl.y or scrh * 0.5
        local dist, ind = (hmauth and distantshotsv or distantshot), (hmauth and indicatorssv or indicators)

        if !novisual then
            if lasthm > ct then -- any hitmarkers
                local state = (lasthm - ct) / hmlength
                -- hmrotata = math.max(0, hmrotata - FrameTime()*300)
                hmrotata = Lerp(FrameTime()*25, hmrotata, 0)
                local armor = (hmauth and hmarmorsv or hmarmor)
                local fire = (hmauth and hmfiresv or hmfire)
                local kill = (hmauth and hmkillsv or hmkill)
                local head = (hmauth and hmheadsv or hmhead)

                if lasthmprop or fire:GetBool() and lasthmfire or !lasthurt then
                    surface.SetMaterial(hmmat3)
                elseif armor:GetBool() and lasthmarmor == 2 then
                    surface.SetMaterial(hmmat4)
                else
                    surface.SetMaterial(head:GetBool() and lasthmhead and hmmat2 or hmmat)
                end
                
                if kill:GetBool() and lasthmkill then
                    surface.SetDrawColor(255, 0, 0, alpha * state)
                elseif armor:GetBool() and lasthmarmor > 0 then
                    surface.SetDrawColor(119, 119, 255, alpha * state)
                else
                    surface.SetDrawColor(255, 255, 255, alpha * state)
                end

                -- surface.DrawTexturedRect(x - DoSize(6) - DoSize(8) * state, y - DoSize(6) - DoSize(8) * state, DoSize(12) + DoSize(16) * state, DoSize(12) + DoSize(16) * state)
                surface.DrawTexturedRectRotated(x, y, DoSize(12) + DoSize(16) * state, DoSize(12) + DoSize(16) * state, hmrotata)

                if armor:GetBool() and lasthmarmor > 0 then
                    surface.SetDrawColor(119, 119, 255, alpha * state)
                    if lasthmarmor == 3 then -- armor damage
                        surface.SetMaterial(matarmor)
                    else
                        surface.SetMaterial(matarmorb)
                    end
                    surface.DrawTexturedRect(x + DoSize(16), y - DoSize(12), DoSize(8), DoSize(8))
                end
                if lasthmprop then -- prop damage
                    surface.SetDrawColor(255, 255, 255, alpha * state)
                    surface.SetMaterial(matgear)
                    surface.DrawTexturedRect(x + DoSize(16), y + DoSize(4), DoSize(8), DoSize(8))
                end
                if fire:GetBool() and lasthmfire then -- afterburn damage
                    surface.SetDrawColor(255, 255, 255, alpha * state)
                    surface.SetMaterial(matfire)
                    surface.DrawTexturedRect(x - DoSize(4), y + DoSize(16), DoSize(8), DoSize(8))
                end
            end

            if (lasthmkill and dist:GetInt() == 2 or dist:GetInt() == 1) and lastdistantshot > ct then -- long range hits
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

            if ind:GetBool() then
                for k, v in ipairs(hitindicators) do -- hit indicators
                    local decay = math.max(0, (v.time - ct)) * 30

                    if decay <= 0 then
                        table.remove(hitindicators, k) -- removing old stains
                    end

                    local hitVec = v.hitvec
                    local armorBreak = v.armor
                    local ang = math.atan2(hitVec.x, hitVec.y) + math.rad(lp:EyeAngles().y) + 3.14
                    local x, y = scrw * 0.5 + math.cos(ang) * DoSize(60, 3), scrh * 0.5 + math.sin(ang) * DoSize(60, 3)

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
        end
    end)

    
    local function hitmarker(...)
        local sv = hmoverride:GetBool()
        local mode = sv and hmsv:GetInt() or hm:GetInt()
        if mode <= 0 and !(sv and skullssv:GetBool() or skulls:GetBool()) then return end
        local dmg = net.ReadUInt(2)
        local hitdata = net.ReadUInt(5)
        local killtype = net.ReadUInt(3)
        local isliving = bit.band(hitdata, 1) != 0
        local killed = bit.band(hitdata, 2) != 0
        local head = bit.band(hitdata, 4) != 0
        local onfire = bit.band(hitdata, 8) != 0
        local pos = net.ReadNormal()
        local armored = net.ReadUInt(2)
        local distance = net.ReadUInt(16)
        local longrangemult = net.ReadUInt(6) * 0.1
        if dmg <= 0 and !isliving then return end
        local lp = LocalPlayer()
        local ct = CurTime()

        if CoolKillchainsInstalled then
            if killed and (sv and skullssv or skulls):GetBool() then -- here cuz that line below
                CoolKillchainFunction(head, killtype, sv)
            end
        end


        if lasthm > ct and lasthmkill then return end
        hmauth = sv
        lasthurt = dmg > 0
        lasthmhead = head
        lasthmfire = onfire
        lasthmkill = killed
        lasthmpos = pos

        hmrotata = math.random(-12, 12)

        lasthmtbl = {x = ScrW() * 0.5, y = ScrH() * 0.5, visible = false }

        if (sv and hmpossv or hmpos):GetBool() and lasthmpos != vector_origin then
            pos = lp:EyePos()-lp:GetAimVector()+pos*distance

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
            if !onfire and distance > longrangeshot * longrangemult and lasthurt then
                lasthmdistance = math.Round(distance * 0.0254, 1)
                lastdistantshot = ct + 3
            end
        elseif !(sv and hmpropsv or hmprop):GetBool() then return end

        lasthm = ct + hmlength

        if mode == 0 or mode == 2 then return end

        if armored == 2 then -- seperate armor break sond without delay
            surface.PlaySound("profiteers/breakarmorr.ogg")
        end

        timer.Simple(0.06, function()
            if !lp then return end -- just to be sure
            if !lasthurt then surface.PlaySound("profiteers/hitmarkfail.ogg") return end
            -- juicer when many dmg
            for i = 1, math.Clamp(dmg, 1, 2) do
                if !onfire and head then
                    surface.PlaySound("profiteers/headmarker.ogg")
                elseif armored == 3 then
                    surface.PlaySound("player/kevlar" .. math.random(5) .. ".wav")
                else
                    surface.PlaySound("profiteers/mwhitmarker.ogg")
                end

            end
            if killed then
                timer.Simple(0.03, function()
                    if !IsValid(lp) then return end -- just to be sure
                    surface.PlaySound("profiteers/newkillmarker.ogg")
                end)
            end
        end)

    end

    net.Receive("profiteers_hitmark", hitmarker)

    local function addgothit(attacker, armor)
        local lp = LocalPlayer()
        if !attacker:IsValid() then return end
        -- local scrw, scrh = ScrW(), ScrH()

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