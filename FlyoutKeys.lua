if not SpellFlyout then
    return
end

local MAX_KEYS = 10
local PROXY_NAME = "FlyoutKeysProxy"

local function KeyFor(i)
    return i < 10 and tostring(i) or "0"
end

local function ScaledCenter(frame)
    local l, b, w, h = frame:GetRect()
    if not l then
        return
    end
    local s = frame:GetEffectiveScale()
    return (l + w / 2) * s, (b + h / 2) * s
end

local binder = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
binder:SetFrameRef("flyout", SpellFlyout)
binder:SetAttribute("numButtons", 0)

local proxies, numProxies = {}, 0
local useKeyDown = GetCVarBool("ActionButtonUseKeyDown")

local function RegisterFlyoutButtons()
    if InCombatLockdown() then
        return false
    end

    local added = false
    for _, button in ipairs({SpellFlyout:GetChildren()}) do
        if button:IsObjectType("Button") and not proxies[button] then
            numProxies = numProxies + 1

            local proxy = CreateFrame("Button", PROXY_NAME .. numProxies, UIParent, "SecureActionButtonTemplate")
            proxy:SetAttribute("type", "click")
            proxy:SetAttribute("clickbutton", button)
            proxy:RegisterForClicks(useKeyDown and "AnyDown" or "AnyUp")

            proxies[button] = proxy
            binder:SetFrameRef("fbtn" .. numProxies, button)
            binder:SetAttribute("numButtons", numProxies)
            added = true
        end
    end
    return added
end

binder:SetAttribute("_bind", [[
    self:ClearBindings()

    local flyout = self:GetFrameRef("flyout")
    local anchor = flyout:GetParent() or flyout
    local l, b, w, h = anchor:GetRect()
    if not l then return end
    local s = anchor:GetEffectiveScale()
    local ax, ay = (l + w / 2) * s, (b + h / 2) * s

    local kids, buttons, dists = newtable(flyout:GetChildren()), newtable(), newtable()
    for n = 1, #kids do
        local c = kids[n]
        if c:IsShown() and c:IsObjectType("Button") then
            local cl, cb, cw, ch = c:GetRect()
            if cl then
                local cs = c:GetEffectiveScale()
                local x, y = (cl + cw / 2) * cs, (cb + ch / 2) * cs
                local d = (x - ax)^2 + (y - ay)^2
                local pos = #buttons + 1
                while pos > 1 and dists[pos - 1] > d do
                    buttons[pos], dists[pos] = buttons[pos - 1], dists[pos - 1]
                    pos = pos - 1
                end
                buttons[pos], dists[pos] = c, d
            end
        end
    end

    local num = self:GetAttribute("numButtons") or 0
    for i = 1, #buttons do
        if i > 10 then break end
        for j = 1, num do
            if self:GetFrameRef("fbtn" .. j) == buttons[i] then
                self:SetBindingClick(true, i < 10 and tostring(i) or "0", "FlyoutKeysProxy" .. j)
                break
            end
        end
    end
]])

SecureHandlerWrapScript(SpellFlyout, "OnShow", binder, [[ owner:RunAttribute("_bind") ]])
SecureHandlerWrapScript(SpellFlyout, "OnHide", binder, [[ owner:ClearBindings() ]])

local function GetSortedButtons()
    local ax, ay = ScaledCenter(SpellFlyout:GetParent() or SpellFlyout)
    if not ax then
        return {}
    end

    local list, dist = {}, {}
    for _, button in ipairs({SpellFlyout:GetChildren()}) do
        if button:IsShown() and button:IsObjectType("Button") then
            local x, y = ScaledCenter(button)
            if x then
                dist[button] = (x - ax) ^ 2 + (y - ay) ^ 2
                list[#list + 1] = button
            end
        end
    end
    table.sort(list, function(a, b)
        return dist[a] < dist[b]
    end)
    return list
end

SpellFlyout:HookScript("OnShow", function()
    if RegisterFlyoutButtons() then
        SecureHandlerExecute(binder, binder:GetAttribute("_bind"))
    end

    for i, button in ipairs(GetSortedButtons()) do
        if i > MAX_KEYS then
            break
        end
        if button.HotKey then
            button.HotKey:SetText(KeyFor(i))
            button.HotKey:Show()
        end
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", RegisterFlyoutButtons)