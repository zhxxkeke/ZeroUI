--[[

	生命条组件

--]]

local _, ns = ...

-- 初始化
local config = ns.config

-- 组件函数
function config.module.Power(self)
	
    -- 创建 oUF 核心数据源 (不可见)
    -- 这是一个隐藏的 StatusBar，仅用于接收 oUF 的血量数据事件
    -- 我们通过 Hook 它的 PostUpdate 来驱动自己的动画系统
    local Power = CreateFrame("StatusBar", nil, self)
    Power:SetPoint("CENTER", self, "CENTER", 0, 0)
    Power:SetSize(config.module.Size, config.module.Size)
    Power:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
    Power:SetAlpha(0)    
    Power.frequentUpdates = true 	-- 开启高频更新以保证平滑
    -- Power.colorPower = true      -- 让 oUF 自动处理能量类型颜色(蓝/黄/红等)
    self.Power = Power
	
	-- 创建纹理
    local texture = self:CreateTexture(nil, "ARTWORK")
    texture:SetSize(config.module.Size, config.module.Size)
    texture:SetPoint("CENTER", self, "CENTER", 0, 0)
    texture:SetTexture(config.module.Texture .. "Power.tga")
	
	-- 纹理层级
	texture:SetDrawLayer("ARTWORK", 1)	
	
	-- 注册 Texture
	self.Power.Texture = texture
	
	-- 旋转动画 逆时针
	config.module.Funs.Animation(texture, 1)
	
	-- 遮罩层：物理大图 (Mask)
	local Mask = self:CreateMaskTexture()
	
    -- 设置为超大尺寸 (为了让图集中的"单格"刚好对齐显示区域，整张图必须放大到 (容器尺寸 * 列数))
	local Size = config.module.Size * 16 	
    Mask:SetSize(Size, Size)
    Mask:SetTexture(config.module.Texture .. "Mask.png")
	
    -- 关闭平铺，防止边缘出现重复纹理的线条
    Mask:SetHorizTile(false)
    Mask:SetVertTile(false)
	
    -- 初始化位置 (默认状态)
    config.module.Funs.UpdateMaskPosition(Mask, 1.0)
	
    -- 将遮罩应用给圆环
    texture:AddMaskTexture(Mask)
	
	-- 平滑动画系统
    self.currPower = 1 						-- 当前显示的数值
    self.destPower = 1  					-- 目标数值 (来自 oUF)
    self.isPowerInit = false
	
    local Smoother = CreateFrame("Frame", nil, self)
    Smoother:SetScript("OnUpdate", function(updater, elapsed)
        local curr = self.currPower
        local dest = self.destPower

        -- 性能优化：当数值非常接近时，直接对齐并停止计算，减少 CPU 消耗
        if math.abs(curr - dest) < 0.001 then
            if curr ~= dest then
                self.currPower = dest
                config.module.Funs.UpdateMaskPosition(Mask, dest)
            end
            return
        end

        -- 核心算法：线性插值 (Linear Interpolation / Lerp)
        -- 公式：新值 = 当前值 + (差距 * 速度 * 时间增量)
        -- 效果：先快后慢的平滑跟随效果
        local diff = dest - curr
        self.currPower = curr + (diff * config.module.SmoothSpeed * elapsed)
        config.module.Funs.UpdateMaskPosition(Mask, self.currPower)
    end)
	
	-- 数据更新回调
    Power.PostUpdate = function(element, unit, cur, min, max)
        if not max or max == 0 then max = 1 end
        
        -- 计算目标百分比 (0.0 ~ 1.0)
        local target = cur / max
        self.destPower = target
        
        -- 特殊处理：插件首次加载时，瞬间跳至目标值，不播放动画
        if not self.isPowerInit then
            self.currPower = target
            config.module.Funs.UpdateMaskPosition(Mask, target)
            self.isPowerInit = true
        end
    end
end


