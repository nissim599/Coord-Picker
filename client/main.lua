-- rl_coord_picker (stable)
-- /pickcoords -> toggle ON/OFF
-- LMB or E -> print vector4 coords (NO GetEntityModel to avoid native streaming crashes)
-- /picklast -> re-print last pick
-- /pickhist -> print last 10 picks

local enabled = false
local lastPickMs = 0

local CFG = {
    cooldownMs = 300,
    rayDistance = 250.0,
    decimals = 4,
    keyPick1 = 24, -- LMB
    keyPick2 = 38, -- E
    historyMax = 10,
    drawHint = true,
    hintSeconds = 12,
}

local history = {}
local lastMsg = nil
local lastMsgUntil = 0

local function round(n, d)
    local m = 10 ^ (d or 4)
    return math.floor(n * m + 0.5) / m
end

local function vec4str(v, h)
    return string.format(
        "vector4(%.4f, %.4f, %.4f, %.4f)",
        round(v.x, CFG.decimals),
        round(v.y, CFG.decimals),
        round(v.z, CFG.decimals),
        round(h, CFG.decimals)
    )
end

local function notify(msg)
    -- always to F8
    print('[CoordPicker] ' .. msg)

    -- prefer ox_lib notify if present
    if GetResourceState('ox_lib') == 'started' then
        pcall(function()
            exports.ox_lib:notify({
                title = 'CoordPicker',
                description = msg,
                type = 'inform'
            })
        end)
    elseif GetResourceState('chat') == 'started' then
        TriggerEvent('chat:addMessage', {
            color = { 120, 180, 255 },
            args = { '[CoordPicker]', msg }
        })
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName('[CoordPicker] ' .. msg)
        EndTextCommandThefeedPostTicker(false, false)
    end

    lastMsg = msg
    lastMsgUntil = GetGameTimer() + (CFG.hintSeconds * 1000)
end

local function pushHistory(msg)
    table.insert(history, 1, msg)
    while #history > (CFG.historyMax or 10) do
        table.remove(history)
    end
end

local function draw2dText(x, y, text, scale)
    SetTextFont(4)
    SetTextScale(scale or 0.45, scale or 0.45)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function raycastFromCamera(distance)
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)

    local pitch = math.rad(camRot.x)
    local yaw = math.rad(camRot.z)

    local dir = vector3(
        -math.sin(yaw) * math.cos(pitch),
         math.cos(yaw) * math.cos(pitch),
         math.sin(pitch)
    )

    local dest = camCoord + (dir * distance)
    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(ray)
    return hit == 1, endCoords, entityHit
end

local function canPickNow()
    local now = GetGameTimer()
    if (now - lastPickMs) < (CFG.cooldownMs or 300) then return false end
    lastPickMs = now
    return true
end

RegisterCommand('pickcoords', function()
    enabled = not enabled
    notify(enabled and 'ON: Aim and press LMB or E to pick coords.' or 'OFF')
end, false)

RegisterCommand('picklast', function()
    if lastMsg then
        notify('LAST: ' .. lastMsg)
    else
        notify('No last pick yet.')
    end
end, false)

RegisterCommand('pickhist', function()
    if #history == 0 then
        notify('History empty.')
        return
    end

    notify('History printed to F8 console (last 10).')
    print('--- [CoordPicker] HISTORY ---')
    for i, msg in ipairs(history) do
        print(('#%d %s'):format(i, msg))
    end
    print('--- [CoordPicker] /HISTORY ---')
end, false)

CreateThread(function()
    while true do
        if not enabled then
            Wait(400)
        else
            Wait(0)

            if CFG.drawHint then
                draw2dText(0.5, 0.90, '~w~CoordPicker: ~g~ON~w~ | LMB/E=Pick | /pickcoords=Exit | /picklast | /pickhist', 0.45)
                if lastMsg and GetGameTimer() < lastMsgUntil then
                    draw2dText(0.5, 0.93, '~b~Last:~w~ ' .. lastMsg, 0.40)
                end
            end

            local hit, hitPos, ent = raycastFromCamera(CFG.rayDistance)

            if (IsControlJustPressed(0, CFG.keyPick1) or IsControlJustPressed(0, CFG.keyPick2)) and canPickNow() then
                -- NOTE: We do NOT call GetEntityModel here (prevents native exception)
                if ent ~= 0 and DoesEntityExist(ent) then
                    local coords = GetEntityCoords(ent)
                    local heading = GetEntityHeading(ent)
                    local msg = vec4str(coords, heading) .. ' | type=entity'
                    pushHistory(msg)
                    notify(msg)
                else
                    local heading = GetGameplayCamRot(2).z
                    local msg = vec4str(hitPos, heading) .. ' | type=world_hit'
                    pushHistory(msg)
                    notify(msg)
                end
            end
        end
    end
end)
