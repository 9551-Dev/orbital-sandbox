local win = window.create(term.current(),1,1,term.getSize())
term.redirect(win)

local pixelbox = require("pixelbox_lite").new(win)

local w,h = term.getSize()
w,h = w*2,h*3

local render_circle = require("render_circle").init(w,h)
local planet        = require("planet")(6.6743)


local system = {
    bodies = {
        planet.new("yourmother", 0, 0, vector.new(0, 0, 0),  100, colors.yellow),
        planet.new("red-stone" ,-372,0,vector.new(0,267,0),  30,  colors.red),
        planet.new("therock"   ,-401,0,vector.new(0,190,0),  5,   colors.gray),
        planet.new("shreklor"  ,-181,0,vector.new(0,260,0),  10,  colors.lime),
    },
    G = 6.6743
}

local function deepcopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = setmetatable(deepcopy(v),getmetatable(v))
        else
            copy[k] = v
        end
    end
    return copy
end

local base_bodies = deepcopy(system.bodies)

local function apply_system(sys)
    for i=1,#system.bodies do
        local bodies = sys[i]

        for k,v in pairs(bodies) do
            system.bodies[i][k] = v
        end
    end
end

local function reset_system()
    apply_system(base_bodies)
end

local function range_pixel(canvas,y,x,color)
    x,y = math.ceil(x-0.5),math.ceil(y-0.5)
    if x>0 and x<=w and y>0 and y<=h then
        canvas[y][x] = color
    end
end

local function vector_distance(a,b)
    return math.sqrt((b.x-a.x)^2 + (b.y-a.y)^2)
end

local function calculate_direction(a,b)
    return (b - a):normalize()
end

local function calculate_force(system,mass_a,mass_b,distance)
    local mass_factor = mass_a * mass_b

    local gravity_effect = mass_factor/distance

    return system.G * gravity_effect
end

local function fast_sleep(t)
    local st = os.epoch("utc")
    while os.epoch("utc") < st+t do
        os.queueEvent("sleep")
        os.pullEvent ("sleep")
    end
end

local update_time_ms = 1
local dt

local screen_update = 20

local function update_system(system)
    local system_bodies = #system.bodies

    for updated_body = 1, system_bodies do
        local current_body = system.bodies[updated_body]

        for effecting_body = 1, system_bodies do
            local effecting_body = system.bodies[effecting_body]

            if effecting_body.id ~= current_body.id then

                local distance = vector_distance(
                    current_body.position,
                    effecting_body.position
                )

                local direction = calculate_direction(
                    current_body.position,
                    effecting_body.position
                )

                local force = direction*calculate_force(system,
                    current_body.mass,
                    effecting_body.mass,
                    distance
                )

                local acceleration = force/current_body.mass

                current_body.velocity = current_body.velocity + acceleration * dt
            end
        end
    end

    for body = 1, system_bodies do
        local current_body = system.bodies[body]
        current_body.position = current_body.position + current_body.velocity * dt
    end
end


local scale,tracked_object
local function get_screen_position(x,y)
    return  ((x - tracked_object.position.x)/scale^2) + w/2,
            ((y - tracked_object.position.y)/scale^2) + h/2
end

local body_tracker = {__index={
    add_data=function(self)
        if #self.data > self.lim then table.remove(self.data,1) end
        local x,y = get_screen_position(self.body.position.x,self.body.position.y)
        --local x,y = self.body.position.x,self.body.position.y
        self.data[#self.data+1] = {math.ceil(x-0.5),math.ceil(y-0.5)}
    end,
    render=function(self,canvas)
        self:add_data()

        for i=1,#self.data do
            local position = self.data[i]

            local from_head = #self.data-i + 1

            local color = colors.white
            if from_head > 500 then
                color = colors.gray
            elseif from_head > 200 then
                color = colors.lightGray
            end

            --local pixel_x,pixel_y = get_screen_position(position[1],position[2])
            local pixel_x,pixel_y = position[1],position[2]

            range_pixel(canvas,pixel_y,pixel_x,color)
        end
    end,
    add=function(self,list)
        list[#list+1] = self
        return self
    end,
    clear=function(self)
        self.data = {}
    end
}}

local function perform_list(list,name,...)
    for i=1,#list do
        list[i][name](list[i],...)
    end
end

local trackers = {}
local function make_body_tracker(body,limit)
    local object = {data={},body=body,lim=limit}

    return setmetatable(object,body_tracker):add(trackers)
end

local last_update = os.epoch("utc")
local function render_system(system,render)
    --local focus_object = planet.new(w/2,h/2,vector.new(0,0,0),0,colors.black)
    if render then

        pixelbox:clear(colors.black)

        local system_bodies = #system.bodies

        for i=1,#trackers do
            trackers[i]:render(pixelbox.CANVAS)
        end

        for body=1,system_bodies do
            local current_body = system.bodies[body]

            local screen_x,screen_y = get_screen_position(
                current_body.position.x,
                current_body.position.y
            )

            render_circle(
                pixelbox.CANVAS,
                current_body.radius/scale^2,
                screen_x,
                screen_y,
                current_body.color
            )
        end

        pixelbox:render()

        last_update = os.epoch("utc")
    else
        --[[for i=1,#trackers do
            trackers[i]:add_data()
        end]]
    end
end


local tracker      = make_body_tracker(system.bodies[3],600)
local preview_mode = false
scale = 2

local tracked_body = 2

tracked_object = system.bodies[tracked_body]
local controlled_body = base_bodies[tracked_body]

dt = 0.001 * (preview_mode and 100 or 1)

local is_base_body      = true
local info_visible      = true
local override_defaults = false

local last_data

local preview_simulation_batch = 1

local anchored = false
local tracker_anchored = false

local dt_regular = dt
local dt_preview = 0.1

parallel.waitForAll(function()
    while true do
        win.setVisible(false)

        if preview_mode then
            perform_list(trackers,"clear")
        end
        for i=1,preview_mode and preview_simulation_batch or 1 do
            update_system(system)
            perform_list(trackers,"add_data")
        end

        local do_render = last_update+screen_update < os.epoch("utc")

        render_system(system,do_render)

        if override_defaults then
            last_data = deepcopy(system.bodies)
        end

        if preview_mode then
            reset_system()
        end

        if info_visible and do_render then
            win.setCursorPos(1,1)
            print(textutils.serialize(controlled_body))
            if override_defaults then
                print("Preview state save enabled")
            end
            if preview_mode then
                print(("Preview after %d steps"):format(preview_simulation_batch))
            end
            if anchored then
                print("ANCHORED")
            end
            if tracker_anchored then
                print("TRACKER ANCHORED")
            end
            if is_base_body then
                print("viewing BASE body")
            else
                print("viewing REAL body")
            end
            print("delta time: "..dt)
            print("<tab to close>")
        end

        win.setVisible(true)
        fast_sleep(update_time_ms)
    end
end,function()
    while true do
        local ev = table.pack(os.pullEvent())
        if ev[1] == "key" then
            if preview_mode then
                if ev[2] == keys.up then
                    controlled_body.velocity.y = controlled_body.velocity.y + 1
                elseif ev[2] == keys.down then
                    controlled_body.velocity.y = controlled_body.velocity.y - 1
                elseif ev[2] == keys.left then
                    controlled_body.position.x = controlled_body.position.x - 1
                elseif ev[2] == keys.right then
                    controlled_body.position.x = controlled_body.position.x + 1
                elseif ev[2] == keys.numPadAdd then
                    controlled_body.mass = controlled_body.mass + 1
                    controlled_body.radius = math.sqrt(controlled_body.mass)
                elseif ev[2] == keys.numPadSubtract then
                    controlled_body.mass = controlled_body.mass - 1
                    controlled_body.radius = math.sqrt(controlled_body.mass)
                end
            end
            if ev[2] == keys.space then
                tracked_body = tracked_body + 1

                if tracked_body > #system.bodies then tracked_body = 1              end
                if tracked_body < 1              then tracked_body = #system.bodies end

                local old_tracked = tracked_object
                if not anchored then
                    tracked_object = system.bodies[tracked_body]
                end
                if not tracker_anchored then
                    tracker:clear()
                    tracker.body = old_tracked
                end
                controlled_body = is_base_body and base_bodies[tracked_body] or system.bodies[tracked_body]
            elseif ev[2] == keys.enter then
                is_base_body = not is_base_body

                if is_base_body then
                    controlled_body = base_bodies[tracked_body]
                else
                    controlled_body = system.bodies[tracked_body]
                end
            elseif ev[2] == keys.tab then
                info_visible = not info_visible
            elseif ev[2] == keys.semiColon then
                if not preview_mode then
                    if override_defaults then base_bodies = deepcopy(system.bodies) end
                    preview_simulation_batch = 1
                    dt_regular = dt
                    dt = dt_preview
                elseif preview_mode then
                    if override_defaults then
                        base_bodies = last_data
                        apply_system(last_data)
                    end

                    dt_preview = dt
                    dt = dt_regular
                end
                preview_mode = not preview_mode
            elseif ev[2] == keys.multiply then
                override_defaults = not override_defaults
            elseif ev[2] == keys.w then
                preview_simulation_batch = preview_simulation_batch + 1
            elseif ev[2] == keys.s then
                preview_simulation_batch = preview_simulation_batch - 1
            elseif ev[2] == keys.numPad0 then
                anchored = not anchored
                if not anchored then
                    tracked_object = system.bodies[tracked_body]
                end
            elseif ev[2] == keys.numPadDivide then
                tracker_anchored = not tracker_anchored
                tracker:clear()
                tracker.body = tracked_object
            elseif ev[2] == keys.pageUp then
                dt = dt + (preview_mode and 0.01 or 0.001)
            elseif ev[2] == keys.pageDown then
                dt = dt - (preview_mode and 0.01 or 0.001)
            end
        elseif ev[1] == "mouse_scroll" then
            local new_scale = scale + ev[2]/10
            if new_scale > 0 then
                scale = new_scale
            end
        end
    end
end)