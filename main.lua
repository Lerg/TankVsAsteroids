--[[
A simple sample game for Corona SDK.
http://coronalabs.com

Made by @SergeyLerg.
Licence: MIT.
]]

-- Don't show pesky status bar.
display.setStatusBar(display.HiddenStatusBar)

local particleDesigner = require('particle_designer')

-- Screen size.
local _W, _H = display.contentWidth, display.contentHeight
-- Screen center coordinates.
local _CX, _CY = _W / 2, _H / 2

-- Add Box 2D support.
local physics = require('physics')
physics.start()
physics.setGravity(0, 0) -- Nothing is falling

-- List of all colors used in the game.
local colors = {
	tankHull = {0.2, 0.4, 0.2}, -- colors are in RGB format, 0 - min, 1 - max.
	tankTrack = {0.4, 0.6, 0.2},
	tankTurret = {0.2, 1, 1},
	tankBullet = {1, 0.2, 0.1},
	asteroid = {0.2, 0.2, 0.2},
	stroke = {0.9, 1, 1}
}

-- Base layer for all display objects.
local group = display.newGroup()

-- Construct a tetromino from individual parts.
local function newAsteroid(params)
	local vertices = {0,-50, 40,-60, 60,-40, 60,30, 40,40, 0,20, -30,50, -20,27, -60,-10, -15,-20}
	local asteroid = display.newPolygon(group, params.x, params.y, vertices) -- polygonal display object.
	asteroid:setFillColor(unpack(colors.asteroid)) -- fill color.
	asteroid:setStrokeColor(unpack(colors.stroke)) -- stroke color.
	asteroid.strokeWidth = 2

	physics.addBody(asteroid, {density = 0.2, friction = 1, bounce = 0, filter = {groupIndex = -1}}) -- add physics to the object.

	asteroid.angularVelocity = math.random(-100, 100)

	local speed = math.random(50, 150)
	local angle = math.atan2(_CY + math.random(-_H * 0.2, _H * 0.2) - asteroid.y, _CX + math.random(-_W * 0.2, _W * 0.2) - asteroid.x)
	asteroid:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)

	function asteroid:destroy()
		local explosion = particleDesigner.newEmitter('particle.json')
		group:insert(explosion)
		explosion.x, explosion.y = self.x, self.y
		self:removeSelf()
	end

	-- Physics collision event.
	function asteroid:collision(event)
		if event.phase == 'began' then
			if event.other.isBullet then -- asteroid is colliding with a tank bullet.
				timer.performWithDelay(1, function()
					event.other:removeSelf()
					self:destroy()
				end)
			elseif event.other.isTank then
				-- GAME OVER
				print('GAME OVER')
			end
		end
	end
	asteroid:addEventListener('collision')
end

-- Borders of the gameplay area.
local function newTank()
	local tankBodyParams = {density = 20, bounce = 0.2, friction = 0.1, filter = {groupIndex = -2}} -- all tank parts share the same physics properties.

	local hullSize = 16
	local trackWidth = hullSize / 2
	local trackHeight = hullSize * 1.5
	local turretWidth = hullSize / 2
	local turretHeight = hullSize * 1.5

	-- Main frame.
	local hull = display.newRect(group, _CX, _CY, hullSize, hullSize)
	hull:setFillColor(unpack(colors.tankHull))
	hull:setStrokeColor(unpack(colors.stroke))
	hull.strokeWidth = 2
	physics.addBody(hull, tankBodyParams)

	-- Left track.
	local leftTrack = display.newRect(group, hull.x - hullSize / 2 - trackWidth / 2, hull.y, trackWidth, trackHeight)
	leftTrack:setFillColor(unpack(colors.tankTrack))
	leftTrack:setStrokeColor(unpack(colors.stroke))
	leftTrack.strokeWidth = 2
	physics.addBody(leftTrack, tankBodyParams)

	-- Right track.
	local rightTrack = display.newRect(group, hull.x + hullSize / 2 + trackWidth / 2, hull.y, trackWidth, trackHeight)
	rightTrack:setFillColor(unpack(colors.tankTrack))
	rightTrack:setStrokeColor(unpack(colors.stroke))
	rightTrack.strokeWidth = 2
	physics.addBody(rightTrack, tankBodyParams)

	-- Turret.
	local turret = display.newRect(group, hull.x, hull.y, turretWidth, turretHeight)
	turret:setFillColor(unpack(colors.tankTurret))
	turret:setStrokeColor(unpack(colors.stroke))
	turret.anchorY = 0.8

	-- Keep parts together
	hull.leftJoint = physics.newJoint('weld', hull, leftTrack, hull.x, hull.y)
	hull.rightJoint = physics.newJoint('weld', hull, rightTrack, hull.x, hull.y)

	local tank = {}
	tank.isTank = true

	function tank:fire()
		local bullet = display.newCircle(group, hull.x, hull.y, 3)
		bullet.isBullet = true
		bullet:setFillColor(unpack(colors.tankBullet))
		bullet:setStrokeColor(unpack(colors.stroke))
		physics.addBody(bullet, tankBodyParams)
		local speed = 500
		local angle = math.rad(turret.rotation - 90)
		bullet:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
	end

	local tankRotation = 0
	local tankSpeed = 0
	local turretRotation = 0

	function tank.axis(event)
		local v = event.normalizedValue
		local t = event.axis.type
		if t == 'x' then
			tankRotation = v * 300
		elseif t == 'y' then
			tankSpeed = v * 200
		elseif t == 'z' then
			turretRotation = v * 5
		end
	end
	Runtime:addEventListener('axis', tank.axis)

	function tank.key(event)
		if (event.keyName == 'buttonA' or event.keyName == 'button1' or event.keyName == 'button5' or event.keyName == 'button6' or event.keyName == 'rightShoulderButton1' or event.keyName == 'leftShoulderButton1') and event.phase == 'down' then
			tank:fire()
		end
	end
	Runtime:addEventListener('key', tank.key)

	function tank.eachFrame()
		turret.x, turret.y = hull.x, hull.y
		turret.rotation = turret.rotation + turretRotation
		hull.angularVelocity = tankRotation
		local angle = math.rad(hull.rotation + 90)
		hull:setLinearVelocity(math.cos(angle) * tankSpeed, math.sin(angle) * tankSpeed)
	end
	tank.eachFrameId = timer.performWithDelay(1, tank.eachFrame, 0)

	return tank
end

-- Random start value depends on the current time value.
math.randomseed(os.time())
-- Create the tank.
newTank()

-- Create tetrominoes indefinitely each second.
timer.performWithDelay(1000, function()
	-- Position is random around the x center of the screen.
	local x, y = math.random(-_CX / 2, _W + _CX / 2), math.random(-_CY / 2, _H + _CY / 2)
	if math.random(1, 2) == 1 then
		if math.random(1, 2) == 1 then
			x = -_CX / 2
		else
			x = _W + _CX / 2
		end
	else
		if math.random(1, 2) == 1 then
			y = -_CY / 2
		else
			y = _H + _CY / 2
		end
	end
	newAsteroid{x = x, y = y}
end, 0)
