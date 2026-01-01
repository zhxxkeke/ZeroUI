--[[

	初始化

--]]

-- AddonName, NameSpaces
local an, ns = ...

-- 配置文件
local config = {}

-- 材质纹理路径
local Texture = "Interface\\AddOns\\" .. an .. "\\Texture\\"

-- 模块配置
config.module = {
	Size			= 200,		-- 容器尺寸
	SmoothSpeed		= 10,		-- 平滑插值速度 (越大越快)
	Background		= {},		-- 背景组件
	ClassPower		= {},		-- 职业能量组件
	Health			= {},		-- 生命条组件
	Power			= {},		-- 能量条组件
	Funs			= {},		-- 函数功能组件
	Texture			= Texture	-- 材质纹理路径
}

--[[
	旋转动画
	@object：		旋转的对象 	Texture
	@direction：	旋转的方向	1 = 逆时针, -1 = 顺时针
--]]
function config.module.Funs.Animation(object, direction)
	
	-- 类型判断
	if object:GetObjectType() ~= "Texture" then return end
	
    -- 这两个 API 来允许"亚像素"渲染，从而消除旋转时的跳动
    object:SetSnapToPixelGrid(false)
    object:SetTexelSnappingBias(0)
	
    local ag = object:CreateAnimationGroup()		-- 创建动画组
    ag:SetLooping("REPEAT")							-- 无限循环
	
    local rot = ag:CreateAnimation("Rotation")		-- 创建 "旋转" 轨道
    rot:SetDuration(60)								-- 旋转频率：每60秒转一圈
    rot:SetDegrees(360 * (direction or -1)) 		-- 旋转方向：正数=逆时针, 负数=顺时针
    rot:SetOrder(1)									-- 轨道编号
    ag:Play()										-- 启动动画
end

-- 原理：由于 SetTexCoord 在遮罩对象上可能失效，我们采用"老式电影放映机"原理。
-- 创建一张巨大的遮罩图，通过物理移动它(SetPoint)，让正确的那一"帧"刚好对准圆环窗口。
function config.module.Funs.UpdateMaskPosition(mask, progress)
    if not mask then return end
    
    -- 钳制进度在 0.0 到 1.0 之间
    progress = math.max(0, math.min(1, progress or 1))
    
    -- 将百分比映射为帧索引 (0 ~ 255)
    local index = math.floor(progress * 255)
    
    -- 计算该帧在图集中的二维坐标 (行, 列)
    local col = index % 16
    local row = math.floor(index / 16)
    
    -- 计算物理偏移量 (Offset)
    -- 想要显示右边的格子，大图需要向左移 (负数 x)
    -- 想要显示下边的格子，大图需要向上移 (正数 y，WoW坐标系Y轴向上为正)
    local offsetX = -1 * col * config.module.Size
    local offsetY = row * config.module.Size
    
    -- 应用位置
    -- 锚点相对于 mask 的父对象 (即 RingTex 的容器 Frame)
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", mask:GetParent(), "TOPLEFT", offsetX, offsetY)
end

--[[ 
	更新状态
	@self： 	本体
	@event：	事件
--]]
function config.module.Funs.UpdateStatus(self, event)

	-- 战斗状态检测
	if event == "PLAYER_REGEN_DISABLED" then
		self.Background.Texture:SetDesaturated(true)
		self.Power.Texture:SetVertexColor(0, 0, 1, 0.7)
		self.Health.Texture:SetVertexColor(1, 0, 0, 1)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self.Background.Texture:SetDesaturated(false)
		self.Power.Texture:SetVertexColor(1, 1, 1, 1)
		self.Health.Texture:SetVertexColor(0, 0, 0, 1)
	end
	
	-- 休息状态检测
	if IsResting() then
		self.Background.Texture:SetAlpha(0.5)
	else
		self.Background.Texture:SetAlpha(1)
	end
end

-- 注册到全局
ns.config = config