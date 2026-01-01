--[[

	oUF 布局组件

--]]

local _, ns = ...

-- 初始化
local oUF = ns.oUF or oUF
local config = ns.config

-- 更新状态
local UpdateStatus = config.module.Funs.UpdateStatus

-- oUF 布局函数
local function Layout(self, unit)

	-- 层级
	self:SetFrameStrata("BACKGROUND")
	self:SetFrameLevel(5)
	
	-- 尺寸
	self:SetSize(config.module.Size, config.module.Size)
	
	-- 背景组件
	config.module.Background(self)
	
	-- 职业能量组件
	config.module.ClassPower(self)

	-- 生命条组件
	config.module.Health(self, unit)
	
	-- 能量条组件
	config.module.Power(self)	
	
	--[[
		更新状态
		注册所有相关事件并执行回调
		PLAYER_UPDATE_RESTING = 休息状态
		PLAYER_ENTERING_WORLD = 载入蓝条
		PLAYER_REGEN_DISABLED = 进战斗
		PLAYER_REGEN_ENABLED  = 脱战
	--]]	
    self:RegisterEvent("PLAYER_UPDATE_RESTING", UpdateStatus, true)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateStatus, true)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", UpdateStatus, true)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", UpdateStatus, true)
	
	-- 初始化运行一次
	UpdateStatus(self)
	
	-- 隐藏目标框体
    if unit == "target" then
        if self.Portrait then
            -- 1. 物理隐藏框体
            self.Portrait:Hide()
            
            -- 2. 覆盖 Show 方法，防止 oUF 在更新时自动把它显示出来
            self.Portrait.Show = function() end 
            
            -- 3. 告诉 oUF 不要管理这个元素了
            self:DisableElement('Portrait')
            
            -- 4. 断开引用
            self.Portrait = nil 
        end
    end
end

-- 注册到 oUF 并激活
oUF:RegisterStyle('ZeroUI', Layout)
oUF:SetActiveStyle('ZeroUI')

-- 玩家
local Player = oUF:Spawn('player', 'ZeroUI')
Player:SetPoint('CENTER', StanceButton1, 'CENTER', 0, 0)	-- StanceButton1 姿态条

-- 隐藏目标框体
if oUF.DisableBlizzard then
    oUF:DisableBlizzard('target')
end