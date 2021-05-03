local options = {
    offset = 1.5,
    cutoff = 0,
    dscale_nearest = true,
    dscale_nearest_level = -3,
    debug_message = false,
}
(require 'mp.options').read_options(options)

local cutoff_check = true
local dscale_nearest_check = false

local offset_list = {
    0,
    0.1,
	0.25,
    0.333,
    0.5,
    0.75,
    1,
    1.25,
    1.5,
    1.75,
    2,
}

function get_video_dimensions()
    local video_params = mp.get_property_native("video-out-params")
    if not video_params then
        _video_dimensions = nil
        return nil
    end
    _video_dimensions = {
        top_left = { 0,  0 },
        bottom_right = { 0,  0 },
        size = { 0,  0 },
        ratios = { 0,  0 }, -- by how much the original video got scaled
    }
    local keep_aspect = mp.get_property_bool("keepaspect")
    local w = video_params["w"]
    local h = video_params["h"]
    local dw = video_params["dw"]
    local dh = video_params["dh"]
    if mp.get_property_number("video-rotate") % 180 == 90 then
        w, h = h,w
        dw, dh = dh, dw
    end
    local window_w, window_h = mp.get_osd_size()

    if keep_aspect then
        local unscaled = mp.get_property_native("video-unscaled")
        local panscan = mp.get_property_number("panscan")

        local fwidth = window_w
        local fheight = math.floor(window_w / dw * dh)
        if fheight > window_h or fheight < h then
            local tmpw = math.floor(window_h / dh * dw)
            if tmpw <= window_w then
                fheight = window_h
                fwidth = tmpw
            end
        end
        local vo_panscan_area = window_h - fheight
        local f_w = fwidth / fheight
        local f_h = 1
        if vo_panscan_area == 0 then
            vo_panscan_area = window_h - fwidth
            f_w = 1
            f_h = fheight / fwidth
        end
        if unscaled or unscaled == "downscale-big" then
            vo_panscan_area = 0
            if unscaled or (dw <= window_w and dh <= window_h) then
                fwidth = dw
                fheight = dh
            end
        end

        local scaled_width = fwidth + math.floor(vo_panscan_area * panscan * f_w)
        local scaled_height = fheight + math.floor(vo_panscan_area * panscan * f_h)

        local split_scaling = function (dst_size, scaled_src_size, zoom, align, pan)
            scaled_src_size = math.floor(scaled_src_size * 2 ^ zoom)
            align = (align + 1) / 2
            local dst_start = math.floor((dst_size - scaled_src_size) * align + pan * scaled_src_size)
            if dst_start < 0 then
                --account for C int cast truncating as opposed to flooring
                dst_start = dst_start + 1
            end
            local dst_end = dst_start + scaled_src_size
            if dst_start >= dst_end then
                dst_start = 0
                dst_end = 1
            end
            return dst_start, dst_end
        end
        local zoom = mp.get_property_number("video-zoom")

        local align_x = mp.get_property_number("video-align-x")
        local pan_x = mp.get_property_number("video-pan-x")
        _video_dimensions.top_left[1], _video_dimensions.bottom_right[1] = split_scaling(window_w, scaled_width, zoom, align_x, pan_x)

        local align_y = mp.get_property_number("video-align-y")
        local pan_y = mp.get_property_number("video-pan-y")
        _video_dimensions.top_left[2], _video_dimensions.bottom_right[2] = split_scaling(window_h,  scaled_height, zoom, align_y, pan_y)
    else
        _video_dimensions.top_left[1] = 0
        _video_dimensions.bottom_right[1] = window_w
        _video_dimensions.top_left[2] = 0
        _video_dimensions.bottom_right[2] = window_h
    end
    _video_dimensions.size[1] = _video_dimensions.bottom_right[1] - _video_dimensions.top_left[1]
    _video_dimensions.size[2] = _video_dimensions.bottom_right[2] - _video_dimensions.top_left[2]
    _video_dimensions.ratios[1] = _video_dimensions.size[1] / w
    _video_dimensions.ratios[2] = _video_dimensions.size[2] / h
    return _video_dimensions
end

function dynamic_scale()
	local video_dimensions = get_video_dimensions()
	if not video_dimensions then return end

	local ratio

	if video_dimensions.keep_aspect then
		ratio = video_dimensions.ratios[1]
	else
		ratio = (video_dimensions.ratios[1] + video_dimensions.ratios[2])/2
	end

    local log_ratio = math.log(ratio) / math.log(2)

    if options.dscale_nearest and options.dscale_nearest_level <= 0 and options.offset==1.5 and options.cutoff == 0 then
        if log_ratio <= options.dscale_nearest_level then
            if not options.dscale_nearest_check then
                mp.command("no-osd set dscale nearest")
                dscale_nearest_check = true
            end
        else
            if dscale_nearest_check then
                mp.command("no-osd set dscale bcspline")
                dscale_nearest_check = false
            end

            if log_ratio >= options.cutoff then
                cutoff_check = true
                set_params(log_ratio)
            end
        end

        if log_ratio < options.cutoff and cutoff_check then
            set_params(options.cutoff)
            cutoff_check = false;
        end
    else    -- default without transition to nearest
        if log_ratio >= options.cutoff then
            cutoff_check = true
            set_params(log_ratio)
        elseif cutoff_check then
            set_params(options.cutoff)
            cutoff_check = false;
        end
    end

    if debug_message then
        mp.osd_message("B: "..mp.get_property_osd("scale-param1").." C: "..mp.get_property_osd("scale-param2").." Offset: "..string.format("%.3f", options.offset).." Cutoff: "..string.format("%.3f", options.cutoff).." dscale: "..mp.get_property_osd("dscale"))
    end
end

function set_params(log_ratio)
    local x = log_ratio * options.offset
    local B = x / (1 + math.abs(x))
    local C = 0.5 * -B + 0.5    --C = (1 - B) / 2
    if log_ratio >= 0 then
        mp.command("no-osd set scale-param1 "..B.."; no-osd set scale-param2 "..C)
    else
        mp.command("no-osd set dscale-param1 "..B.."; no-osd set dscale-param2 "..C)
    end
end

function on_scale()
	dynamic_scale()
end

function on_load()
    mp.command("no-osd set scale bcspline; no-osd set dscale bcspline")
	dynamic_scale()
end

local function cycle_offset()
    local i, index = 1
    for i = 1, #offset_list do
        if (offset_list[i] == options.offset) then
            index = i + 1
            if index > #offset_list then
                index = 1
            end
            break
        end
    end
    options.offset = offset_list[index]
	mp.osd_message(offset_list[index])
	dynamic_scale()
end

mp.observe_property("osd-dimensions", "native", on_scale)
mp.observe_property("dwidth", "native", on_load)	        --video size after filters and aspect, not windows output

mp.register_script_message('cycle-offset', function() cycle_offset() end)