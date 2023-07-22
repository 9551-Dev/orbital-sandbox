local CEIL,FLOOR = math.ceil,math.floor

return {init=function(w,h)
    local function range_pixel(canvas,y,x,color)
        x,y = math.ceil(x-0.5),math.ceil(y-0.5)
        if x>0 and x<=w and y>0 and y<=h then
            canvas[y][x] = color
        end
    end

    return function(canvas,radius,xc,yc,color)
        local rx = CEIL(FLOOR(radius-0.5)/2)
        local ry = rx
        local x,y = 0,ry
        local d1 = ((ry * ry) - (rx * rx * ry) + (0.25 * rx * rx))
        local dx = 2*ry^2*x
        local dy = 2*rx^2*y
        while dx < dy do
            range_pixel(canvas, y+yc, x+xc,color)
            range_pixel(canvas, y+yc,-x+xc,color)
            range_pixel(canvas,-y+yc, x+xc,color)
            range_pixel(canvas,-y+yc,-x+xc,color)
            for y=-y+yc+1,y+yc-1 do
                range_pixel(canvas,y, x+xc,color)
                range_pixel(canvas,y,-x+xc,color)
            end
            if d1 < 0 then
                x = x + 1
                dx = dx + 2*ry^2
                d1 = d1 + dx + ry^2
            else
                x,y = x+1,y-1
                dx = dx + 2*ry^2
                dy = dy - 2*rx^2
                d1 = d1 + dx - dy + ry^2
            end
        end
        local d2 = (((ry * ry) * ((x + 0.5) * (x + 0.5))) + ((rx * rx) * ((y - 1) * (y - 1))) - (rx * rx * ry * ry))
        while y >= 0 do
            range_pixel(canvas, y+yc, x+xc,color)
            range_pixel(canvas, y+yc,-x+xc,color)
            range_pixel(canvas,-y+yc, x+xc,color)
            range_pixel(canvas,-y+yc,-x+xc,color)
            for y=-y+yc,y+yc do
                range_pixel(canvas,y, x+xc,color)
                range_pixel(canvas,y,-x+xc,color)
            end
            if d2 > 0 then
                y = y - 1
                dy = dy - 2*rx^2
                d2 = d2 + rx^2 - dy
            else
                y = y - 1
                x = x + 1
                dy = dy - 2*rx^2
                dx = dx + 2*ry^2
                d2 = d2 + dx - dy + rx^2
            end
        end
    end
end}