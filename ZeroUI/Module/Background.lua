--[[

	背景组件

--]]

local _, ns = ...

-- 初始化
local config = ns.config

-- 组件函数
function config.module.Background(self)
	
	-- 创建容器
	local frmae = CreateFrame("Frame", nil, self)
	frmae:SetPoint("CENTER", self, "CENTER", 0, 0)
	frmae:SetSize(config.module.Size, config.module.Size)
	frmae:SetFrameLevel(self:GetFrameLevel() - 1)
	
	-- 创建纹理
	local texture = frmae:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints(frmae)
	texture:SetTexture(config.module.Texture .. "Background.tga")
	
	-- 旋转动画 逆时针
	config.module.Funs.Animation(texture, 1)
	
	-- 右键弹出玩家菜单
	local button = CreateFrame("Button", nil, frmae, "SecureUnitButtonTemplate")
	local Size = config.module.Size * 0.5
	button:SetSize(Size, Size)							-- 尺寸设置为容器的一半
	button:SetPoint("CENTER", frmae, "CENTER", 0, 0)
	button:SetFrameLevel(self:GetFrameLevel() + 10)		-- 提高层级
	button:SetAttribute("unit", "player")				-- 强制设定单位框体对象为 "player" (永远弹出玩家菜单)
    button:RegisterForClicks("AnyUp")					-- 注册鼠标释放事件	
    button:SetAttribute("*type2", "togglemenu")			-- 绑定右键菜单
	
	-- 注册 Texture
	frmae.Texture = texture
	
	-- 注册到 self
	self.Background = frmae
end