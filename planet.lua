local function uuid4()
    local random = math.random
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        return string.format('%x', c == 'x' and random(0, 0xf) or random(8, 0xb))
    end)
end

return function(G)
    return {new=function(name,x,y,velocity,radius,color)
        return {
            name     = name,
            type     = "planet",
            position = vector.new(x,y),
            velocity = velocity,
            radius   = radius,
            mass     = radius^2,
            color    = color,
            id       = uuid4(),
        }
    end}
end