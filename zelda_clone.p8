pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

function dcopy(_o)
   local r = {}
   for key, value in pairs(_o) do
      r[key] = value
   end
   return r
end

function lerp(_p, _from, _to)
   return _from*(1-_p)+_p*_to
end

function round(_x)
   return flr(_x+.5)
end

function thresh(_x, _t)
   return abs(_x) <= _t and 0 or _x
end

function clamp(_x, _min, _max)
   return _x <= _min and _min or _x >= _max and _max or _x
end

dir_btn_map = {
   { x = -1, y = 0 },
   { x = 1, y = 0 },
   { x = 0, y = -1 },
   { x = 0, y = 1 }
}

function sign(_x)
   return _x < 0 and -1
      or _x > 0 and 1
      or 0 
end

function e_rectpos(_e)
   return round(_e.x),
      round(_e.y),
      round(_e.x+_e.lx-(1*sign(_e.lx))),
      round(_e.y+_e.ly-(1*sign(_e.ly)))
end

function e_rectfill(_e)
   color(_e.c)
   rectfill(e_rectpos(_e))
end

function input()
   local r = {}
   for i=0, 3 do
      if btn(i) then
	 add(r, i)
      end
   end
   return r
end

e_data = {
   player = {
      function (_self)
	 _self.vx = 0
	 _self.vy = 0
	 _self.mvx = 0
	 _self.mvy = 0
	 
	 local inp = input()
	 local z = btn(4)
	 
	 if _self.state == "idle" then
	    if z then
	       _self.state = "init_attack"
	    elseif #inp > 0 then
	       _self.state = "moving"
	    end
	 end

	 if _self.state == "moving" then
	    if z then
	       _self.state = "init_attack"
	    elseif #inp == 0 then
	       _self.state = "idle"
	    else
	       for i in all(inp) do
		  local dir_vec = dir_btn_map[i+1]
		  _self.dir = i
		  _self.mvx += dir_vec.x
		  _self.mvy += dir_vec.y
	       end
	    end
	 end

	 -- restart attack
	 if _self.state == "attack" then
	    if z and not _self.prev_z then
	       if btnp(4) then
		  e_drop(_self.attack)
		  _self.state = "init_attack"
	       end
	    end
	 end

	 if _self.state == "init_attack" then
	    local attack = e_init(e_data.attack, _self)
	    _self.attack = attack
	    _self.state = "attack"
	 end

	 -- complete attack
	 if _self.state == "attack" then
	    printh(_self.attack.swing_duration)
	    if _self.attack.f == _self.attack.swing_duration then
	       if not z then
		  e_drop(_self.attack)
		  _self.attack = nil
		  _self.state = "idle"
	       elseif z then
		  _self.state = "hold_attack"
	       end
	    end
	 end

	 if _self.state == "hold_attack" then
	    for i in all(inp) do
	       local dir_vec = dir_btn_map[i+1]
	       _self.mvx += dir_vec.x
	       _self.mvy += dir_vec.y
	    end
	    if not z then
	       e_drop(_self.attack)
	       _self.attack = nil
	       if #inp == 0 then
		  _self.state = "idle"		  
	       else
		  _self.state = "moving"
	       end
	    end
	 end

	 if _self.iframe > 0 then
	    if flr(_self.iframe/4) % 2 == 0 then
	       _self.c = 3
	    else
	       _self.c = 8
	    end
	    _self.iframe -= 1
	 else
	    _self.c = 3
	 end

	 _self.vx += _self.mvx
	 _self.vy += _self.mvy
	 _self.vx += _self.hvx
	 _self.vy += _self.hvy

	 -- geometry coll behavior
	 -- project x movement and on coll limit
	 -- project y movement and on coll limit
	 -- if there is a coll try nudge on free axis

	 -- -- project x
	 -- local fx = _self.x + _self.vx
	 -- local fy = _self.y
	 
	 -- local tl = { x=fx, y=fy }
	 -- local tr = { x=fx+_self.lx-1, y=fy }
	 -- local bl = { x=fx, y=fy+_self.ly-1 }
	 -- local br = { x=fx+_self.lx-1, y=fy+_self.ly-1}
	 -- local vertices = {tl, tr, bl, br}

	 -- local nox = false
	 -- for vertex in all(vertices) do	    
	 --    if geometry_map
	 --    [flr(vertex.y/8)+1]
	 --    [flr(vertex.x/8)+1] == 1 then
	 --       -- _self.vx = 0
	 --       -- _self.vy = 0
	 --       nox = true
	 --    end
	 -- end

	 -- project y
	 
	 function collcheck(_x, _y, _lx, _ly)
	    local tl = { x=_x, y=_y }
	    local tr = { x=_x+_lx-1, y=_y }
	    local bl = { x=_x, y=_y+_ly-1 }
	    local br = { x=_x+_lx-1, y=_y+_ly-1}
	    local vertices = {tl, tr, bl, br}

	    for vertex in all(vertices) do	    
	       if geometry_map
	       [flr(vertex.y/8)+1]
	       [flr(vertex.x/8)+1] == 1 then
		  return true
	       end
	    end
	    return false
	 end

	 local x_coll = collcheck(_self.x+_self.vx,
				  _self.y,
				  _self.lx,
				  _self.ly)
	 local y_coll = collcheck(_self.x,
				  _self.y+_self.vy,
				  _self.lx,
				  _self.ly)
	 -- for diagonal coll
	 local xy_coll = collcheck(_self.x+_self.vx,
				   _self.y+_self.vy,
				   _self.lx,
				   _self.ly)

	 -- try nudge
	 local nudge_xy_coll =
	    collcheck(_self.x+_self.vx+1,
		      _self.y+_self.vy,
		      _self.lx,
		      _self.ly)
	 
	 if y_coll and not nudge_xy_coll then
	    _self.x += _self.vx+1
	 end
	 
	 if not x_coll and not y_coll and xy_coll then
	 else
	    if not x_coll then
	       _self.x += _self.vx
	    end
	    if not y_coll then
	       _self.y += _self.vy
	    end
	 end
	 
	 -- if noy then
	 --    -- try nudge
	 --    local fx = _self.x + _self.vx + 1
	 --    local fy = _self.y + _self.vy
	    
	 --    local tl = { x=fx, y=fy }
	 --    local tr = { x=fx+_self.lx-1, y=fy }
	 --    local bl = { x=fx, y=fy+_self.ly-1 }
	 --    local br = { x=fx+_self.lx-1, y=fy+_self.ly-1}
	 --    local vertices = {tl, tr, bl, br}

	 --    local nonudge = false
	 --    for vertex in all(vertices) do	    
	 --       if geometry_map
	 --       [flr(vertex.y/8)+1]
	 --       [flr(vertex.x/8)+1] == 1 then
	 -- 	  nonudge = true
	 -- 	  -- _self.vx = 0
	 -- 	  -- _self.vy = 0
	 --       end
	 --    end
	 --    if not nonudge then
	 --       _self.x = fx
	 --       _self.y = fy
	 --    end
	 -- end

	 -- if not nox then
	 --    _self.x += _self.vx
	 -- end
	 -- if not noy then
	 --    _self.y += _self.vy
	 -- end

	 _self.hvx *= .75
	 _self.hvy *= .75
	 _self.hvx = thresh(_self.hvx, .3)
	 _self.hvy = thresh(_self.hvy, .3)

	 _self.prev_z = z

	 -- pickup
	 if _self.pickup then
	    _self.pickup.x = _self.x
	    _self.pickup.y = _self.y
	    -- throw
	    if btnp(5) then
	       _self.state = "throwing"
	       local dir_vec = dir_btn_map[_self.dir+1]
	       _self.pickup.vx = dir_vec.x*6
	       _self.pickup.vy = dir_vec.y*6
	       _self.pickup.state = "thrown"
	       _self.pickup = nil
	       _self.throwf = _self.throwttl
	    end
	 end

	 if _self.state == "throwing" then
	    if _self.throwf == 0 then
	       _self.state = "idle"
	    else
	       _self.throwf -= 1
	    end
	 end
      end,
      
      function (_self)
	 e_rectfill(_self)
      end,
      
      x = 71,
      y = 56,
      
      mvx = 0,
      mvy = 0,
      hvx = 0,
      hvy = 0,      
      vx = 0,      
      vy = 0,
      
      lx = 8,
      ly = 8,
      c = 3,
      dir = 2,
      state = "idle",
      iframe = 0,
      iframe_ttl = 30,
      prev_z = false,
      type = "player",

      animf = 0,
      throwttl = 10,
      
      on_coll = function(_self, _other)
	 if _other.type == "enemy"
	    and _self.iframe == 0 then	    
	    local u = uvec(_self.cx - _other.cx,
			   _self.cy - _other.cy)
	    _self.hvx = u.x*4
	    _self.hvy = u.y*4
	    _self.iframe = _self.iframe_ttl
	 elseif _other.type == "geometry" then	    
            _self.x -= _self.vx
            _self.y -= _self.vy
	 elseif _other.type == "pickup" then
	    if btnp(5) and _self.state != "throwing" then
	       _self.pickup = _other
	    end
         end
	 
      end
     
   },

   -- dir
   attack = {
      function (_self)

	 if _self.f == 0 then
	    _self.wielder = _self.args[1]
	    if _self.wielder.dir == 0 then
	       _self.lx = -5
	       _self.ly = 1
	       _self.aoffset = .25
	       _self.xo = -1
	    end
	    if _self.wielder.dir == 1 then
	       _self.lx = 5
	       _self.ly = 1
	       _self.aoffset = -.25
	       _self.yo = -1
	    end
	    if _self.wielder.dir == 2 then
	       _self.lx = 1
	       _self.ly = -5
	       _self.aoffset = 0
	       _self.xo = -1
	       _self.yo = -1
	    end
	    if _self.wielder.dir == 3 then
	       _self.lx = 1
	       _self.ly = 5
	       _self.aoffset = .5
	    end
	 end

	 if _self.f <= _self.swing_duration then
	    local a = lerp(_self.f/_self.swing_duration
			   , 0, .35) + _self.aoffset
	    _self.x = round(_self.wielder.cx+_self.xo)+cos(a)*5
	    _self.y = round(_self.wielder.cy+_self.yo)+sin(a)*5
	 elseif _self.f > _self.swing_duration then
	    local a = lerp(1, 0, .35) + _self.aoffset
	    _self.x = round(_self.wielder.cx+_self.xo)+cos(a)*5
	    _self.y = round(_self.wielder.cy+_self.yo)+sin(a)*5
	 end

	 if _self.f > _self.swing_duration
	    + _self.charge_duration then
	    _self.c = _self.f % 2 == 0 and 9 or 7   
	 end
      end,
      function (_self)
	 e_rectfill(_self)
      end,
      swing_duration = 6,
      charge_duration = 10,
      x = 0,
      y = 0,
      xo = 0,
      yo = 0,
      lx = 1,
      ly = -4,
      c = 7,
      type = "player_attack",      
      on_coll = function(_self, _other)
      end
      
   },
   
   dummy = {
      function(_self)
	 _self.vx = 0
	 _self.vy = 0
	 
	 if _self.iframe == 0 then
	    _self.c = 4
	 else
	    if flr(_self.iframe/4) % 2 == 0 then
	       _self.c = 8
	    else
	       _self.c = 4
	    end
	    _self.iframe -= 1

	    if _self.iframe == 0
	       and _self.hp == 0 then
	       e_drop(_self)
	       local particle = e_init(e_data.particle)
	       particle.x = _self.x
	       particle.y = _self.y
	    end
	 end

	 if _self.iframe == 0 then
	    -- chase player
	    -- local uv = uvec(player.cx - _self.x,
	    -- 		    player.cy - _self.y)
	    -- _self.mvx = uv.x*.5
	    -- _self.mvy = uv.y*.5
	    -- _self.vx += _self.mvx
	    -- _self.vy += _self.mvy

	    -- wonder behavior
	    -- set wonder point
	    if _self.wonder_x == 0 or
	       thresh(_self.wonder_x - _self.x, .5) == 0 and
	       thresh(_self.wonder_y - _self.y, .5) == 0 then
	       local a = rnd(1)
	       _self.wonder_x = clamp(round(_self.x+cos(a)*20), 0, 127)
	       _self.wonder_y = clamp(round(_self.y+sin(a)*20), 0, 127)
	    end	    
	    local uv = uvec(_self.wonder_x - _self.x,
			    _self.wonder_y - _self.y)
	    _self.mvx = uv.x*.5
	    _self.mvy = uv.y*.5
	    _self.vx += _self.mvx
	    _self.vy += _self.mvy	    
	    
	 end
	 
	 _self.vx += _self.hvx
	 _self.vy += _self.hvy
	 _self.hvx *= .75
	 _self.hvy *= .75
	 _self.hvx = thresh(_self.hvx, .1)
	 _self.hvy = thresh(_self.hvy, .1)	 
	 
	 if _self.iframe == 0 then
	    _self.hvx = 0
	    _self.hvy = 0
	 end
	 
	 _self.x += _self.vx
	 _self.y += _self.vy
      end,

      function(_self)
	 e_rectfill(_self)
      end,

      x = 30,
      y = 35,
      lx = 8,
      ly = 8,
      vx = 0,
      vy = 0,
      hvx = 0,
      hvy = 0,
      wonder_x = 0,
      wonder_y = 0,
      
      c = 4,
      iframe = 0,
      iframe_ttl = 30,
      type = "enemy",
      hp = 4,

      on_coll = function(_self, _other)
	 if _other.type == "player_attack"
	    and _self.iframe == 0 then
	    local u = uvec(_self.cx - _other.wielder.cx,
			   _self.cy - _other.wielder.cy)
	    _self.hvx = u.x*5
	    _self.hvy = u.y*5
	    _self.iframe = _self.iframe_ttl
	    _self.hp -= 1
	 elseif _other.type == "geometry" then
	    _self.x -= _self.vx
	    _self.y -= _self.vy
	    _self.hvx *= -1
	    _self.hvy *= -1
	    _self.hvx *= .5
	    _self.hvy *= .5
	 elseif _other.type == "pickup"
	    and _other.state == "thrown"
	    and _self.iframe == 0 then	    
	    local u = uvec(_self.cx - _other.cx,
			   _self.cy - _other.cy)
	    _self.hvx = u.x*5
	    _self.hvy = u.y*5
	    _self.iframe = _self.iframe_ttl
	    _self.hp -= 1
	 end
      end
   },
   
   particle = {
      function (_self)
	 if _self.f == 0 then
	    -- need otherwise all particle
	    _self.particles = {}
	    for i = 1, 3 do
	       add(_self.particles, {
		      x = _self.x+(rnd(1)-.5),
		      y = _self.y+(rnd(1)-.5),
		      vx = cos(lerp(i/3,0,1))*1.4+(rnd(1)-.5),
		      vy = sin(lerp(i/3,0,1))*1.4+(rnd(1)-.5)
	       })
	    end
	 end
	 for particle in all(_self.particles) do
	    particle.x += particle.vx
	    particle.y += particle.vy
	    particle.vx *= .75
	    particle.vy *= .75
	 end
	 if _self.f == _self.ttl then
	    e_drop(_self)
	 end
      end,
      function (_self)
	 for particle in all(_self.particles) do
	    circfill(particle.x, particle.y, lerp(_self.f/_self.ttl,3,0), flr(rnd(16)))
	    circfill(particle.x, particle.y, lerp(_self.f/_self.ttl,2,0), flr(rnd(16)))
	 end
      end,
      x = 0,
      y = 0,
      ttl = 20
   },

   pickup = {
      function (_self)
	 if _self.f == 0 then
	    _self.x = _self.args[1]
	    _self.y = _self.args[2]
	 end
	 if _self.state == "thrown" then
	    _self.x += _self.vx
	    _self.y += _self.vy
	    _self.vx *= .75
	    _self.vy *= .75
	    if thresh(_self.vx, .9) == 0
	       and thresh(_self.vy, .9) == 0 then
	       e_drop(_self)
	       local particle = e_init(e_data.particle)
	       particle.x = _self.x
	       particle.y = _self.y
	    end
	 end
      end,      
      function (_self)
	 spr(64,round(_self.x),round(_self.y))
      end,
      x = 70,
      y = 40,
      vx = 0,
      vy = 0,
      lx = 8,
      ly = 8,
      type = "pickup",
      state = "idle",
      on_coll = function () end
   }
}

function mag(_x, _y)
   return sqrt(_x*_x + _y*_y)
end

function uvec(_x, _y)
   local m = mag(_x, _y)
   return { x = _x/m, y = _y/m }
end

entities = {}

function e_init(_e_data, ...)
   local e = dcopy(_e_data)
   e.f = 0
   e.alive = true
   e.args = {...}
   add(entities, e)   
   return e
end

function e_drop(_e)
   _e.alive = false
   return del(entities, _e)
end

player = nil
dummy = nil
pickup = nil

-- geometry_map = {
--    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
--    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
--    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
-- }

geometry_map = {
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}

function _init()
   player = e_init(e_data.player)
   e_init(e_data.pickup, 80, 63)
   e_init(e_data.pickup, 80, 70)
   e_init(e_data.pickup, 80, 55)   
   dummy = e_init(e_data.dummy)
end

function rectcoll(_coll_a, _coll_b)
   if _coll_a != _coll_b then
      local ax1 = round(min(_coll_a.x, _coll_a.x + _coll_a.lx))
      local ax2 = round(max(_coll_a.x, _coll_a.x + _coll_a.lx))

      local bx1 = round(min(_coll_b.x, _coll_b.x + _coll_b.lx))
      local bx2 = round(max(_coll_b.x, _coll_b.x + _coll_b.lx))

      local ay1 = round(min(_coll_a.y, _coll_a.y + _coll_a.ly))
      local ay2 = round(max(_coll_a.y, _coll_a.y + _coll_a.ly))

      local by1 = round(min(_coll_b.y, _coll_b.y + _coll_b.ly))
      local by2 = round(max(_coll_b.y, _coll_b.y + _coll_b.ly))

      if ax1 < bx2 and ax2 > bx1
	 and ay1 < by2 and ay2 > by1 then
	 _coll_a.on_coll(_coll_a, _coll_b)
	 _coll_b.on_coll(_coll_b, _coll_a)
      end
   end
end

frame_rate = 1
f = 0
function _update60()
   if f % frame_rate == 0 then
   for entity in all(entities) do
      entity[1](entity)
      entity.f += 1
      -- determine center
      if entity.lx and entity.ly then
	 entity.cx = entity.x + (entity.lx/2)
	 entity.cy = entity.y + (entity.ly/2)
      end
   end

   for entity in all(entities) do
      if entity.on_coll then
	 for entity_b in all(entities) do
	    if entity_b.on_coll then
	       rectcoll(entity, entity_b)
	    end
	 end
      end
   end
   end
   f+=1
end

function _draw()
   if f % frame_rate == 0 then
      cls()
      
      for i = 0, 63 do
	 for j = 0, 63 do
	    pset(j*2, i*2, 1)
	 end
      end

      -- geometry map
      for y,row in pairs(geometry_map) do
	 for x,id in pairs(row) do
	    if id == 1 then
	       rectfill((x-1)*8,
		  (y-1)*8,
		  (x-1)*8+7,
		  (y-1)*8+7,y)
	       rectfill((x-1)*8+1,
		  (y-1)*8+1,
		  (x-1)*8+6,
		  (y-1)*8+6,x)
	    end
	 end
      end
      
      for entity in all(entities) do
	 entity[2](entity)
      end
   end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00606666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00666000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04499440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44944944000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
49499494000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44944944000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04499440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
