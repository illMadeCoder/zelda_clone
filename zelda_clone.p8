pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

function noop()
end

function dcopy(_o)
   local r = {}
   for key, value in pairs(_o) do
      r[key] = value
   end
   return r
end

function any(_list, _predicate)
   for item in all(_list) do
      if _predicate(item) then
	 return true
      end
   end
   return false
end

function filter(_list, _predicate)
   local r = {}
   for item in all(_list) do
      if _predicate(item) then
	 add(r, item)
      end
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

dir_map = {
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

-- timer
function t_new(_base)
   return { base = _base, f = 0 }
end

function t_reset(_t)
   _t.f = 0
end

function t_tick(_t)
   _t.f += 1
   if _t.f >= _t.base then
      t_reset(_t)
      return false
   end
   return true
end

function t_isactive(_t)
   return _t.f > 0 
end

function t_final(_t)
   return _t.f == _t.base-1
end

-- anim
function a_new(_ttl, _update, _draw)
   local t = t_new(_ttl)
   return {t=t,
	   update=_update or noop,
	   draw=_draw or noop,
	   active=false}
end

function a_activate(_a)
   _a.active = true
end

function a_isactive(_a)
   return _a.active
end

function a_update(_a, _args)
   if _a.active then
      _a.update(_a.t, _args)
      local tick = t_tick(_a.t)
      _a.active = tick
      return tick
   end
   return false
end

function a_draw(_a, _args)
   if _a.active then
      _a.draw(_a.t, _args)
   end
end

-- button
function b_new(_btn)
   return {
      btn = _btn,
      f_last = 0,
      f_held = 0,
   }
end

function b_update(_b)
   if btn(_b.btn) then
      _b.f_held += 1
      _b.f_last = 0
   else
      _b.f_held = 0
      _b.f_last += 1
   end
end

function b_down(_b)
   return _b.f_held > 0  
end

-- vector
function v_new(_x, _y)
   return { x = _x, y = _y }
end

function v_apply(_a, _b)
   _a.x = _b.x
   _a.y = _b.y
end

function v_zero(_a)
   _a.x = 0
   _a.y = 0
   return _a
end

function v_add(_a, _b)
   return v_new(_a.x+_b.x, _a.y+_b.y)
end

function v_sub(_a, _b)
   return v_new(_a.x-_b.x, _a.y-_b.y)
end

function v_addto(_a, _b)
   _a.x += _b.x
   _a.y += _b.y
   return _a
end

function v_subto(_a, _b)
   _a.x -= _b.x
   _a.y -= _b.y
   return _a
end

function v_scaleto(_a, _s)
   _a.x *= _s
   _a.y *= _s
   return _a
end

function v_threshto(_a, _t)
   _a.x = thresh(_a.x, _t)
   _a.y = thresh(_a.y, _t)
   return _a
end

function v_mag(_a)
   return sqrt(_a.x*_a.x + _a.y*_a.y)
end

function v_unit(_a)
   local m = v_mag(_a)
   return v_new(_a.x/m, _a.y/m)
end

function e_rectpos(_e)
   return round(_e.pos.x),
      round(_e.pos.y),
      round(_e.pos.x+_e.lx-(1*sign(_e.lx))),
      round(_e.pos.y+_e.ly-(1*sign(_e.ly)))
end

function e_rectfill(_e)
   color(_e.c)
   rectfill(e_rectpos(_e))
end

e_data = {
   player = {
      function (_self)

	 -- input
	 for b in all(_self.b_dirs) do
	    b_update(b)
	 end
	 
	 b_update(_self.b_z)
	 b_update(_self.b_x)

	 local b_dirs_down = filter(_self.b_dirs,
				    function (_b_dir)
				       return b_down(_b_dir)
	 end)
	 local is_b_dir_down = #b_dirs_down > 0 
	 
	 local is_b_z_down = b_down(_self.b_z)
	 local is_b_x_down = b_down(_self.b_x)

	 local update_vel_move = function ()
	    for b in all(b_dirs_down) do
	       local dir_vec = dir_map[b.btn+1]
	       _self.dir = b.btn
	       v_addto(_self.vel_move, dir_vec)
	    end
	 end
	 
	 -- todo tidy up/encapsualte resets? maybe not
	 v_zero(_self.vel)
	 v_zero(_self.vel_move)

	 -- todo encapsulate state
	 if _self.state == "idle" then
	    if is_b_z_down then
	       _self.state = "init_attack"
	    elseif is_b_dir_down then
	       _self.state = "moving"
	    end
	 end

	 -- todo encapsulate state
	 if _self.state == "moving" then
	    if is_b_z_down then
	       _self.state = "init_attack"
	    elseif not is_b_dir_down then
	       _self.state = "idle"
	    else
	       update_vel_move()
	    end
	 end

	 -- todo encapsulate state
	 -- restart attack
	 if _self.state == "attack" then
	    if z and not _self.prev_z then
	       if btnp(4) then
		  e_drop(_self.attack)
		  _self.state = "init_attack"
	       end
	    end
	 end

	 -- todo encapsulate state
	 if _self.state == "init_attack" then
	    local attack = e_init(e_data.attack, _self)
	    _self.attack = attack
	    _self.state = "attack"
	 end

	 -- complete attack
	 if _self.state == "attack" then
	    if _self.attack.f ==
	       _self.attack.swing_duration then
	       if not is_b_z_down then
		  e_drop(_self.attack)
		  _self.attack = nil
		  _self.state = "idle"
	       else
		  _self.state = "hold_attack"
	       end	 
	    end
	 end

	 -- todo encapsulate state
	 if _self.state == "hold_attack" then
	    update_vel_move()
	    -- todo better input system for z/x keys
	    if not is_b_z_down then
	       e_drop(_self.attack)
	       _self.attack = nil
	       if is_b_dir_down then
		  _self.state = "idle"
	       else
		  _self.state = "moving"		  
	       end
	    end
	 end

	 -- timer system for iframes
	 a_update(_self.ianim, _self)

	 -- todo apply function and comments for v types
	 v_addto(_self.vel, _self.vel_move)
	 v_addto(_self.vel, _self.vel_hit)
	 
	 -- todo alot
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

	 local new_pos = v_add(_self.pos, _self.vel)
	 
	 local x_coll = collcheck(_self.pos.x+_self.vel.x,
				  _self.pos.y,
				  _self.lx,
				  _self.ly)
	 
	 local y_coll = collcheck(_self.pos.x,
				  _self.pos.y+_self.vel.y,
				  _self.lx,
				  _self.ly)

	 -- for diagonal coll
	 local xy_coll = collcheck(_self.pos.x+_self.vel.x,
				   _self.pos.y+_self.vel.y,
				   _self.lx,
				   _self.ly)

	 
	 if not x_coll and not y_coll and xy_coll then
	 else
	    if not x_coll then
	       _self.pos.x += _self.vel.x
	    end
	    if not y_coll then
	       _self.pos.y += _self.vel.y
	    end
	 end

	 -- if there was a x_coll or y_coll
	 -- there was an intention to move that direction
	 -- try nudge
	 -- y_coll check up down left and right side
	 if y_coll then
	    for i=-1, 1, 2 do
	       local nudge_xy_coll =
		  collcheck(_self.pos.x+_self.vel.x+i,
			    _self.pos.y+_self.vel.y,
			    _self.lx,
			    _self.ly)

	       if not nudge_xy_coll then
		  _self.pos.x += _self.vel.x+i
		  _self.pos.y += _self.vel.y	       
	       end
	    end
	 end

	 -- x_coll check up down left and right side
	 if x_coll then
	    for i=-1, 1, 2 do
	       local nudge_xy_coll =
		  collcheck(_self.pos.x+_self.vel.x,
			    _self.pos.y+_self.vel.y+i,
			    _self.lx,
			    _self.ly)

	       if not nudge_xy_coll then
		  _self.pos.x += _self.vel.x
		  _self.pos.y += _self.vel.y+i	       
	       end
	    end
	 end

	 -- todo friction
	 v_scaleto(_self.vel_hit, .75)
	 -- todo vector thresh3)
	 v_threshto(_self.vel_hit, .3)
	 -- todo z x
	 _self.prev_z = z

	 -- todo this should be a state
	 -- pickup
	 if _self.pickup then
	    v_apply(_self.pickup, _self.pos)
	    -- throw
	    if btnp(5) then
	       _self.state = "throwing"
	       local dir_vec = dir_map[_self.dir+1]
	       _self.pickup.vx = dir_vec.x*6
	       _self.pickup.vy = dir_vec.y*6
	       _self.pickup.state = "thrown"
	       _self.pickup = nil
	       _self.throwf = _self.throwttl
	    end
	 end

	 -- todo encapsulate state
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

      b_dirs = {
	 b_new(0),
	 b_new(1),
	 b_new(2),
	 b_new(3)
      },      
      b_z=b_new(4),
      b_x=b_new(5),
      
      pos = v_new(57,56),     
      vel_move = v_new(0,0),
      vel_hit = v_new(0,0),
      vel = v_new(0,0),
      
      lx = 8,
      ly = 8,
      c = 3,
      -- todo let's make a dirs enum
      dir = 2,
      state = "idle",
      ianim = a_new(30,
		    function (_t, _args)
		       if flr(_t.f/4) % 2 == 0 then
			  _args.c = 8
		       else
			  _args.c = 3
		       end
		       if t_final(_t) then
			  _args.c = 3
		       end		   
		    end,
		    noop),
      
      -- todo this is awkward encaps
      prev_z = false,
      type = "player",
      -- todo encapsulate as timers
      animf = 0,
      throwttl = 10,
      
      on_coll = function(_self, _other)
	 if _other.type == "enemy"
	    and not a_isactive(_self.ianim) then
	    local u = v_unit(v_sub(_self.center, _other.center))
	    v_apply(_self.vel_hit, v_scaleto(u, 4))
	    a_activate(_self.ianim)
	 elseif _other.type == "geometry" then	    
	    v_subto(_self.pos, _self.vel)
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
	    _self.pos.x = round(_self.wielder.center.x+_self.xo)+cos(a)*5
	    _self.pos.y = round(_self.wielder.center.y+_self.yo)+sin(a)*5
	 elseif _self.f > _self.swing_duration then
	    local a = lerp(1, 0, .35) + _self.aoffset
	    _self.pos.x = round(_self.wielder.center.x+_self.xo)+cos(a)*5
	    _self.pos.y = round(_self.wielder.center.y+_self.yo)+sin(a)*5
	 end

	 if _self.f >
	    _self.swing_duration + _self.charge_duration then
	    _self.c = _self.f % 2 == 0 and 9 or 7   
	 end
      end,
      
      function (_self)
	 e_rectfill(_self)
      end,      
      swing_duration = 6,
      charge_duration = 10,
      pos = v_new(0,0),
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
	 _self.vel.x = 0
	 _self.vel.y = 0
	 
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
	       particle.x = _self.pos.x
	       particle.y = _self.pos.y
	    end
	 end

	 if _self.iframe == 0 then
	    -- chase player
	    -- local uv = v_unit(player.center.x - _self.pos.x,
	    -- 		    player.center.y - _self.pos.y)
	    -- _self.vel_move.x = uv.x*.5
	    -- _self.vel_move.y = uv.y*.5
	    -- _self.vel.x += _self.vel_move.x
	    -- _self.vel.y += _self.vel_move.y

	    -- wonder behavior
	    -- set wonder point
	    if _self.wonder_x == 0 or
	       thresh(_self.wonder_x - _self.pos.x, .5) == 0 and
	       thresh(_self.wonder_y - _self.pos.y, .5) == 0 then
	       local a = rnd(1)
	       _self.wonder_x = clamp(round(_self.pos.x+cos(a)*20), 0, 127)
	       _self.wonder_y = clamp(round(_self.pos.y+sin(a)*20), 0, 127)
	    end	    
	    -- local uv = v_unit(_self.wonder_x - _self.pos.x,
	    -- 		    _self.wonder_y - _self.pos.y)
	    -- _self.vel_hit.x = uv.x*.5
	    -- _self.vel_hit.y = uv.y*.5
	    -- _self.vel.x += _self.vel_hit.x
	    -- _self.vel.y += _self.vel_hit.y
	 end
	 
	 _self.vel.x += _self.vel_hit.x
	 _self.vel.y += _self.vel_hit.y
	 _self.vel_hit.x *= .75
	 _self.vel_hit.y *= .75
	 _self.vel_hit.x = thresh(_self.vel_hit.x, .1)
	 _self.vel_hit.y = thresh(_self.vel_hit.y, .1)	 
	 
	 if _self.iframe == 0 then
	    _self.vel_hit.x = 0
	    _self.vel_hit.y = 0
	 end
	 
	 _self.pos.x += _self.vel.x
	 _self.pos.y += _self.vel.y
      end,

      function(_self)
	 e_rectfill(_self)
      end,

      pos = v_new(30, 35),
      lx = 8,
      ly = 8,
      vel = v_new(0,0),
      vel_hit = v_new(0,0),
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
	    local u = v_unit(v_sub(_self.center,
				   _other.center))
	    _self.vel_hit.x = u.x*5
	    _self.vel_hit.y = u.y*5
	    _self.iframe = _self.iframe_ttl
	    _self.hp -= 1
	 elseif _other.type == "geometry" then
	    _self.pos.x -= _self.vel.x
	    _self.pos.y -= _self.vel.y
	    _self.vel_hit.x *= -1
	    _self.vel_hit.y *= -1
	    _self.vel_hit.x *= .5
	    _self.vel_hit.y *= .5
	 elseif _other.type == "pickup"
	    and _other.state == "thrown"
	    and _self.iframe == 0 then	    
	    local u = v_unit(_self.center.x - _other.center.x,
			   _self.center.y - _other.center.y)
	    _self.vel_hit.x = u.x*5
	    _self.vel_hit.y = u.y*5
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
		      x = _self.pos.x+(rnd(1)-.5),
		      y = _self.pos.y+(rnd(1)-.5),
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
	    _self.pos.x = _self.args[1]
	    _self.pos.y = _self.args[2]
	 end
	 if _self.state == "thrown" then
	    _self.pos.x += _self.vel.x
	    _self.pos.y += _self.vel.y
	    _self.vel.x *= .75
	    _self.vel.y *= .75
	    if thresh(_self.vel.x, .9) == 0
	       and thresh(_self.vel.y, .9) == 0 then
	       e_drop(_self)
	       local particle = e_init(e_data.particle)
	       particle.x = _self.pos.x
	       particle.y = _self.pos.y
	    end
	 end
      end,      
      function (_self)
	 spr(64,round(_self.pos.x),round(_self.pos.y))
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

geometry_map = {
   {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
   {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
   {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
   {0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0},
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

-- geometry_map = {
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
--    {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
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

function _init()
   player = e_init(e_data.player)
   -- e_init(e_data.pickup, 80, 63)
   -- e_init(e_data.pickup, 80, 71)
   -- e_init(e_data.pickup, 80, 55)   
   dummy = e_init(e_data.dummy)
end

function rectcoll(_coll_a, _coll_b)
   if _coll_a != _coll_b then
      local ax1 = round(min(_coll_a.pos.x, _coll_a.pos.x + _coll_a.lx))
      local ax2 = round(max(_coll_a.pos.x, _coll_a.pos.x + _coll_a.lx))

      local bx1 = round(min(_coll_b.pos.x, _coll_b.pos.x + _coll_b.lx))
      local bx2 = round(max(_coll_b.pos.x, _coll_b.pos.x + _coll_b.lx))

      local ay1 = round(min(_coll_a.pos.y, _coll_a.pos.y + _coll_a.ly))
      local ay2 = round(max(_coll_a.pos.y, _coll_a.pos.y + _coll_a.ly))

      local by1 = round(min(_coll_b.pos.y, _coll_b.pos.y + _coll_b.ly))
      local by2 = round(max(_coll_b.pos.y, _coll_b.pos.y + _coll_b.ly))

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
	 entity.center = v_add(entity.pos,
			       v_new((entity.lx/2),
				  (entity.ly/2)))
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
