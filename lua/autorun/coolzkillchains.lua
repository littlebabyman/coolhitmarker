-- this was initially a part of coolhitmarkers 
-- so in order to make it work without them i need to crop out hooks & nets from it here (with removal of some useless things)

local usefallback = false
if !CoolHitmarkersInstalled then usefallback = true end
CoolKillchainsInstalled = true


local hmoverride = usefallback and CreateConVar("profiteers_override_enabled", "0", flags, "Override Profiteers UI settings.", 0, 1) or GetConVar("profiteers_override_enabled")
local skullssv = usefallback and CreateConVar("profiteers_override_skulls", "1", flags, "Override Show how many enemys youve killed. very cruel.", 0, 1) or GetConVar("profiteers_override_skulls")
local skullscalesv = CreateConVar("profiteers_override_skull_scale", "1", flags, "Override scale of skylls", 0.25, 2.5)
local skullglobaloffsetsv = CreateConVar("profiteers_override_offset", "0.7", flags, "Override offset of skylls", 0.05, 0.95)
local skullmaxxsv = CreateConVar("profiteers_override_max", "0", flags, "Override max skulls, zero means no more than half of screen width", 0, 50)

if SERVER then
    if usefallback then
        util.AddNetworkString("profiteers_hitmark_FALLBACK")

        local npcheadshotted = false -- fuck you garry

        local function fallbackhitmarker(ent, dmginfo, took)
            local attacker, inflictor = dmginfo:GetAttacker(), dmginfo:GetInflictor()
            if attacker:IsVehicle() and IsValid(attacker:GetDriver()) then attacker = attacker:GetDriver() end
            local attply, vicply = attacker:IsPlayer(), ent:IsPlayer()
            if !attply then return end
            if inflictor == ent or attacker == ent then return end
            local vichp = ent:Health()
            -- local ct = CurTime()
            -- if ent.phm_lastHealth and ent.phm_lastHealth == vichp and (!took and (vichp <= 0 or attacker.phm_lastMarker and attacker.phm_lastMarker > ct) or dmginfo:GetDamage() == 0 or took) then return end
            local vicnpc = ent:IsNextBot() or ent:IsNPC()
    
            if IsValid(ent) and IsValid(attacker) and attply then
                local dmgtype = dmginfo:GetDamageType()
                local sentient = vicply or vicnpc
                if !sentient or !took or dmginfo:GetDamage() <= 0 then return end
                local hitdata = false
                if (sentient and vichp <= 0) then
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
                    hitdata = true
                    if ent.SetLastHitGroup then ent:SetLastHitGroup(HITGROUP_GENERIC) end
                end
    
                -- if you making some gamemode you can add here check for distance and give more points/moneys for long kills
    
                net.Start("profiteers_hitmark_FALLBACK")
                -- net.WriteUInt(0, 2) -- Damage -- DO NOT NEED IN FALLBACK
                net.WriteBool(hitdata) -- Headshot or not
                net.WriteUInt(killtype, 3) -- Type of kill damage
                -- net.WriteVector(vector_origin) -- Hit position -- DO NOT NEED IN FALLBACK
                -- net.WriteUInt(0, 2) -- Armor and break -- DO NOT NEED IN FALLBACK
                -- net.WriteUInt(0, 16) -- Distance to hit -- DO NOT NEED IN FALLBACK
                -- net.WriteUInt(0, 6) -- Ammo type in gun -- DO NOT NEED IN FALLBACK
                net.Send(attacker)
                npcheadshotted = false
            end
        end
    
        -- fuck you garry
        hook.Add("ScaleNPCDamage", "profiteers_killchain_npcheadshots", function(ent, hitgroup, dmginfo)
            if !dmginfo:GetAttacker():IsPlayer() then return end
            npcheadshotted = IsValid(ent) and IsValid(dmginfo:GetAttacker()) and hitgroup == HITGROUP_HEAD
        end)

        hook.Add("PostEntityTakeDamage", "profiteers_killchain", fallbackhitmarker)
    end
else
    local skulls = usefallback and CreateClientConVar("profiteers_skulls", "1", true, true, "Show how many enemys youve killed. very cruel.", 0, 1) or GetConVar("profiteers_skulls")
    local skullscale = CreateClientConVar("profiteers_skull_scale", "1", true, true, "scale of skylls", 0.25, 2.5)
    local skullglobaloffset = CreateClientConVar("profiteers_skull_offset", "0.7", true, true, "offset of skylls", 0.05, 0.95)
    local skullmaxx = CreateClientConVar("profiteers_skull_max", "0", true, true, "max skulls, zero means no more than half of screen width", 0, 50)

    
    hook.Add("PopulateToolMenu", "profiteers_hitmark_options_killchains", function()
        spawnmenu.AddToolMenuOption("Utilities", "Cool Hitmarkers", "profiteers_hitmarker_cl_kc", "Killchains", "", "", function(pan)
            pan:ControlHelp("\nKillstreak skulls")
            pan:CheckBox("Show killstreak skulls under crosshair", "profiteers_skulls")
            pan:NumSlider("Skulls scale", "profiteers_skull_scale", 0.25, 2.5, 3)
            pan:NumSlider("Skulls vertical offset", "profiteers_skull_offset", 0.05, 0.95, 2)
            pan:NumSlider("Max streak on screen", "profiteers_skull_max", 0, 50, 0)
            pan:Help("0 means autocalculated - won't take more than half of screen width")

            pan:ControlHelp("\n\n\nKillstreak skulls - SERVER OVERRIDE")
            pan:CheckBox("Force those server killchain settings below for every player", "profiteers_override_enabled")
            pan:CheckBox("sv - Show killstreak skulls under crosshair", "profiteers_override_skulls")
            pan:NumSlider("sv - Skulls scale", "profiteers_override_skull_scale", 0.25, 2.5, 3)
            pan:NumSlider("sv - Skulls vertical offset", "profiteers_override_offset", 0.05, 0.95, 2)
            pan:NumSlider("sv - Max streak on screen", "profiteers_override_max", 0, 50, 0)
            pan:Help("0 means autocalculated - won't take more than half of screen width")

            if usefallback then
                pan:ControlHelp("\n\n\n\n\nBest used with:")
                local btn = pan:Button("Cool™ Hitmarkers <3")
                btn.DoClick = function()
                    gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=2987119816")
                end
            end
        end)
    end)

    local hmauth = 0
    local lasthmhead = false
    local lasthmkill = false

    -- hush
    local function DoSize2(size, scale)
        return size * (ScrW() / 640) * ((hmauth and skullscalesv or skullscale):GetFloat())
    end
    

    local skulltable = {}
    local skullnextdelete = 0
    local skullsmoothcount = 0
    local skullsize = 10
    local skulldecaytimeconstant = 4
    local skulldecaytime = 4 -- +0.33s per kill in a streak

    local matskull = Material("profiteers/skull.png", "noclamp smooth")
    local matskullhs = Material("profiteers/skullhs.png", "noclamp smooth")
    local matexplosion = Material("profiteers/explosion.png", "noclamp smooth")
    local matmelee = Material("profiteers/knife.png", "noclamp smooth")
    local matkick = Material("profiteers/kick.png", "noclamp smooth")
    local matkick2 = Material("profiteers/kick2.png", "noclamp smooth")
    local matcar = Material("profiteers/car.png", "noclamp smooth")
    local matball = Material("profiteers/dissolve.png", "noclamp smooth")
    local matprop = Material("profiteers/propkill.png", "noclamp smooth")
    local matfire = Material("profiteers/fire.png", "noclamp smooth")

    hook.Add("HUDPaint", "profiteers_hitmark_paint_killchains", function()
        if !(hmauth and skullssv:GetBool() or skulls:GetBool()) then return end

        -- local lp = LocalPlayer()
        local ct = CurTime()
        local scrw, scrh = ScrW(), ScrH()
        
        if #skulltable > 0 then
            skullsmoothcount = math.max(1, math.Round(Lerp(FrameTime()*5, skullsmoothcount, #skulltable), 5))
            local wholeoffset = skullsmoothcount * DoSize2(skullsize + 2) * 0.5
            local skullsdecay = math.Clamp((skullnextdelete - ct) * skulldecaytime * 0.5, 0, 1)
            local maxoverride = (hmauth and skullmaxxsv or skullmaxx):GetInt() or 0
            local maxskulls = (maxoverride == 0) and (math.ceil((scrw * 0.5) / (DoSize2(skullsize + 2)))) or maxoverride
            -- local maxskulls = 5
            local verticaloffset = (hmauth and skullglobaloffsetsv or skullglobaloffset):GetFloat() or 0.7
            
            -- if #skulltable == maxskulls and skulltable[1].fadein then skulltable[1].fadein = false skulltable[1].time = ct + 0.33 end
            if #skulltable > maxskulls then
                skullsmoothcount = skullsmoothcount - 1 -- for noticable new skull
                table.remove(skulltable, 1)
            end
            
            for k, v in pairs(skulltable) do -- skulls
                local offsett = k * DoSize2(skullsize + 2)
                local fadein = math.ease.InQuart(math.min((1 - (v.time - ct) / skulldecaytime)*30, 1))

                surface.SetDrawColor(255, 255, 255, 200 * skullsdecay * fadein)
                surface.SetMaterial(matskull)
                if v.hs then
                    surface.SetDrawColor(255, 58, 58, 200 * skullsdecay * fadein)
                    surface.SetMaterial(matskullhs)
                elseif v.exploded then
                    surface.SetDrawColor(255, 137, 59, 200 * skullsdecay * fadein)
                    surface.SetMaterial(matexplosion)
                elseif v.burned then
                    surface.SetDrawColor(255, 137, 59, 200 * skullsdecay * fadein)
                    surface.SetMaterial(matfire)
                end

                if v.roadkill then
                    surface.SetMaterial(matcar)
                elseif v.dissolve then
                    surface.SetMaterial(matball)
                elseif v.propkill then
                    surface.SetMaterial(matprop)
                elseif v.kicked then
                    surface.SetMaterial(matkick2)
                elseif v.meleed then
                    surface.SetDrawColor(255, 58, 58, 200 * skullsdecay * fadein)
                    surface.SetMaterial(matmelee)
                end

                surface.DrawTexturedRect(scrw * 0.5 - DoSize2(skullsize * 0.5 + (skullsize + 2) * 0.5) + offsett - wholeoffset, scrh * verticaloffset, DoSize2(skullsize), DoSize2(skullsize))

                if skullnextdelete < ct then
                    skulltable = {}
                    skullsmoothcount = 0
                    skulldecaytime = skulldecaytimeconstant
                    break
                end
            end
        end
    end)

    function CoolKillchainFunction(head, killed, killtype, sv)
        lasthmhead = head -- two params from below
        lasthmkill = killed

        local ct = CurTime()
        skulldecaytime = skulldecaytimeconstant + #skulltable * 0.33
        skullnextdelete = ct + skulldecaytime

        table.insert(skulltable, {
            time = ct + skulldecaytime,
            hs = lasthmhead,
            kicked = killtype == 1,
            meleed = killtype == 2,
            exploded = killtype == 3,
            roadkill = killtype == 4,
            dissolve = killtype == 5,
            propkill = killtype == 6,
            burned = killtype == 7,
            fadein = true,
        })

        hmauth = sv
    end

    if usefallback then
        local function fallbackhitmarker()
            local sv = hmoverride:GetBool()
            if !(sv and skullssv:GetBool() or skulls:GetBool()) then return end
            local hitdata = net.ReadUInt(5)
            local killtype = net.ReadUInt(3)
            local isliving = bit.band(hitdata, 1) != 0
            local killed = bit.band(hitdata, 2) != 0
            local head = bit.band(hitdata, 4) != 0
            local onfire = bit.band(hitdata, 8) != 0
            if !isliving then return end -- if dmg <= 0 and !isliving then return end
            local lp = LocalPlayer()
            local ct = CurTime()

            if killed then -- here cuz that line below
                CoolKillchainFunction(head, killed, killtype, sv)
            end
            
        end

        net.Receive("profiteers_hitmark_FALLBACK", fallbackhitmarker)
    end
end