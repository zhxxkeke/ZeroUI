--[[

	职业能量组件

--]]

local _, ns = ...

-- 初始化
local config = ns.config

-- 动画参数
local ANIM_DURATION = 0.4       -- 动画完成所需时间 (秒)
local ANIM_OFFSET   = 60        -- 动画位移角度 (入场时从+60度飞入，出场向+60度飞出)
local RADIUS        = 50        -- 连击点排列的圆环半径

-- 缓动函数
-- 效果：速度由快到慢，结尾非常平滑
local function EaseOut(t)
    return 1 - math.pow(1 - t, 4)
end

-- 根据角度设置 UI 坐标
-- 原理：极坐标系 (角度, 半径) -> 直角坐标系 (x, y)
local function SetPositionByAngle(point, center, angle)
    local rad = math.rad(angle)
    local x = math.cos(rad) * RADIUS
    local y = math.sin(rad) * RADIUS
    
    point:ClearAllPoints()
    point:SetPoint("CENTER", center, "CENTER", x, y)
    
    -- 记录当前视觉所在的实际角度，用于下一次动画的起始点
    point.currentVisualAngle = angle 
end

--[[
	执行角度插值动画
	@point: 		运动的物体;
	@center: 		中心锚点
	@onFinish: 		动画结束回调
--]]
local function RunAnimation(point, center, startAngle, endAngle, onFinish)

    -- 性能优化：如果视觉角度已在终点且无回调，直接跳过
    if point.currentVisualAngle == endAngle and not onFinish then 
        return 
    end

    -- 初始化动画状态
    point.animStart = startAngle
    point.animEnd   = endAngle
    point.animTime  = GetTime()
    point.isAnimating = true
    
    -- 注册帧更新脚本 (OnUpdate)
    point:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        -- 计算进度 (0.0 ~ 1.0)
        local progress = (now - self.animTime) / ANIM_DURATION
        
        if progress >= 1 then
            -- [动画结束]
            self:SetScript("OnUpdate", nil) -- 注销脚本节省性能
            self.isAnimating = false
            SetPositionByAngle(self, center, self.animEnd) -- 强制修正到终点
            
            if onFinish then onFinish() end
        else
            -- [动画进行中]
            local ease = EaseOut(progress)
            -- 线性插值计算当前角度
            local curAngle = self.animStart + (self.animEnd - self.animStart) * ease
            SetPositionByAngle(self, center, curAngle)
        end
    end)
end

-- 强制应用模型参数：WoW 的 PlayerModel 经常出现缩放丢失或相机重置的问题，需要反复校准
local function ApplyModelSettings(self)

    -- 修正模型 ID
    if self:GetModelFileID() ~= 840373 then
        self:SetModel(840373)
    end

    -- 重置相机与坐标 SetCamera(0) 极其重要，防止模型加载后尺寸异常或视角偏移
    self:SetCamera(0) 
    self:SetPosition(0, 0, 0)
end

-- [PostUpdate] 连击点更新时触发：负责计算每个连击点的目标角度，并触发动画
local function UpdateComboPointsLayout(element, cur, max, hasMaxChanged, powerType)
    if not element.prevCount then element.prevCount = 0 end
    
    -- 确定循环边界：取历史值、当前值、最大值中的最大者，确保动画能正确播放完（例如从5星变0星）
    local loopMax = math.max(element.prevCount, cur, max or 0)
    if loopMax == 0 then return end

    -- 动态布局算法：
    -- 根据当前连击点数量，将 360 度圆环均分
    -- 例如：3星时每120度一个，5星时每72度一个
    local calcBase = (cur > 0) and cur or element.prevCount
    local angleStep = 360 / (calcBase > 0 and calcBase or 1)

    for i = 1, #element do
        local point = element[i]

		-- 计算目标角度：从正上方(90度)开始，逆时针排列
        local targetAngle = 90 - (i - 1) * angleStep
        
        if i <= cur then
            -- [状态：激活/存在]
            point:Show()
            
            if i == 1 then
                -- 第一个点作为视觉锚定点，通常直接定位，防止整体旋转产生的晕眩感
                point:SetScript("OnUpdate", nil)
                SetPositionByAngle(point, element, targetAngle)
            else
                -- 计算起始角度：
                -- 如果是新产生的点 (i > prevCount)，从 "目标位置 + 偏移" 处飞入
                -- 如果是已存在的点，则从 "当前视觉位置" 平滑过渡到新位置
                local startAngle
                if i > element.prevCount then
                    startAngle = targetAngle + ANIM_OFFSET
                else
                    startAngle = point.currentVisualAngle or targetAngle
                end
                RunAnimation(point, element, startAngle, targetAngle, nil)
            end
        else
			-- [状态：非激活/消失]
            if point:IsShown() then
                if i == 1 then
					 -- 第一个点直接隐藏，不播放飞出动画
                    point:SetScript("OnUpdate", nil)
                    point:Hide()
                else
                    -- 其他点播放"飞出"动画：向偏移方向飞去，动画结束后隐藏
                    local currentAngle = point.currentVisualAngle or targetAngle
                    local exitAngle = currentAngle + ANIM_OFFSET
                    RunAnimation(point, element, currentAngle, exitAngle, function()
                        point:Hide()
                    end)
                end
            else
				-- 已经是隐藏状态，确保清理 Update 脚本
                point:Hide()
                point:SetScript("OnUpdate", nil)
            end
        end
    end
	-- 更新历史记录
    element.prevCount = cur
end

-- [oUF Tag] 注册自定义标签：盗贼充能连击点
oUF.Tags.Events['rogue:charged_count'] = 'UNIT_POWER_POINT_CHARGE PLAYER_ENTERING_WORLD'
oUF.Tags.Methods['rogue:charged_count'] = function(unit)
    if unit ~= "player" then return "" end
    local chargedIndexes = GetUnitChargedPowerPoints("player")
    local count = chargedIndexes and #chargedIndexes or 0
    return count > 0 and count or ""
end

-- 组件函数
function config.module.ClassPower(self)

	-- 创建容器
	local frame = CreateFrame("Frame", nil, self)
	frame:SetSize(config.module.Size, config.module.Size)
	frame:SetPoint("CENTER", self, "CENTER", 0, 0)
	
	frame.prevCount = 0
	
	-- 循环创建 7 个模型点 (支持最大连击点数)
	for index = 1, 7 do
		local cp = CreateFrame('Model', nil, frame)
		cp:SetSize(80, 80)
		
		-- 解决模型消失/缩放错误的问题：监听 UI_MODEL_SCENE_INFO_UPDATED 事件，在游戏引擎重绘场景时强制重置相机
        cp:RegisterEvent("UI_MODEL_SCENE_INFO_UPDATED")
        cp:SetScript("OnEvent", function(self, event)
            ApplyModelSettings(self)
        end)
		
        -- 显隐时再次校准
        cp:SetScript("OnShow", function(self)
            ApplyModelSettings(self)
        end)

        -- 初始调用
        ApplyModelSettings(cp)
		
		-- 兼容 oUF 接口调用，防止报错
        cp.SetStatusBarColor = function() end
        cp.SetVertexColor = function() end 
        cp.SetValue = function() end
		
		frame[index] = cp
	end

    -- 绑定 oUF 更新回调
    frame.PostUpdate = UpdateComboPointsLayout
	
	-- 注册 oUF 对象 
	self.ClassPower = frame
	
    -- 创建文字容器，层级 +5 确保位于模型之上
    local text = CreateFrame("Frame", nil, frame)
    text:SetAllPoints(frame)
    text:SetFrameLevel(frame:GetFrameLevel() + 5)
    
    -- 在高层级容器里创建文字
    local chargedText = text:CreateFontString(nil, "OVERLAY")
    chargedText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    chargedText:SetPoint("CENTER", self, "CENTER", 0, 86)
    
    -- 绑定 oUF 标签
    self:Tag(chargedText, '[rogue:charged_count]')
    self.ChargedCountText = chargedText
end