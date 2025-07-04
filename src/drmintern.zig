const std = @import("std");
const c = @cImport({
    @cInclude("xf86drm.h");
    @cInclude("xf86drmMode.h");
});


const IOC = struct {
    const ioc = @This();

    const NONE = 0;
    const WRITE = 1;
    const READ = 2;

    const NRBITS = 8;
    const TYPEBITS = 8;
    const SIZEBITS = 14;
    const DIRBITS = 2;

    const NRSHIFT = 0;
    const TYPESHIFT = ioc.NRSHIFT + ioc.NRBITS;
    const SIZESHIFT = ioc.TYPESHIFT + ioc.TYPEBITS;
    const DIRSHIFT = ioc.SIZESHIFT + ioc.SIZEBITS;

    inline fn IOC_BASE(dir: u32, _type: u32, nr: u32, size: u32) u32 {
        return (dir << ioc.DIRSHIFT) |
            (_type << ioc.TYPESHIFT) |
            (nr << ioc.NRSHIFT) |
            (size << ioc.SIZESHIFT);
    }

    inline fn IOWR(_type: u32, nr: u32, size: u32) u32 {
        return IOC_BASE(ioc.READ | ioc.WRITE, _type, nr, size);
    }
};

const DRM_IOCTL_BASE: u32 = c.DRM_IOCTL_BASE;
const DRM_COMMAND_BASE: u32 = c.DRM_COMMAND_BASE;
const DRM_IOCTL_GET_CAP_NR = 0x0C;

const DRM_IOCTL_MODE_GET_RESOURCES_NR = 0xA0;
const DRM_IOCTL_MODE_GET_RESOURCES = c.DRM_IOCTL_MODE_GETRESOURCES;

const ioctl = std.os.linux.ioctl;

pub const Version = extern struct {
    major: c_int,
    minor: c_int,
    patch: c_int,
    name_len: c_ulong,
    name: [*]u8,
    date_len: c_ulong,
    date: [*]u8,
    desc_len: c_ulong,
    desc: [*]u8,
};

const drm_get_cap = extern struct {
    capability: u64,
    value: u64,
};

const DRM_IOCTL_VERSION = IOC.IOWR(DRM_IOCTL_BASE, 0x00, @sizeOf(Version));
const DRM_IOCTL_GET_CAP = IOC.IOWR(DRM_IOCTL_BASE, DRM_IOCTL_GET_CAP_NR, @sizeOf(drm_get_cap));


pub const Capability = enum(u64){
    DUMB_BUFFER = 0x01,    
    VBLANK_HIGH_CRTC = 0x02,
    DUMB_PREFERRED_DEPTH = 0x03,
    DUMB_PREFER_SHADOW = 0x04,
    PRIME = 0x05,
    TIMESTAMP_MONOTONIC = 0x06,
    ASYNC_PAGE_FLIP = 0x07,
    CURSOR_WIDTH = 0x08,
    CURSOR_HEIGHT = 0x09,
    ADDFB2_MOD = 0x10,
};

const drm_CardResources = extern struct {
    fb_id_ptr: u64,
    crtc_id_ptr: u64,
    connector_id_ptr: u64,
    encoder_id_ptr: u64,
    count_fbs: u32,
    count_crtcs: u32,
    count_connectors: u32,
    count_encoders: u32,
    min_width: u32,
    max_width: u32,
    min_height: u32,
    max_height: u32,
};

pub const Resources = struct {
    fb_ids: []u32,
    crtc_ids: []u32,
    connector_ids: []u32,
    encoder_ids: []u32,
    limits: struct {
        min: struct { width: u32, height: u32 },
        max: struct { width: u32, height: u32 },
    },
    allocator: std.mem.Allocator,
};

pub fn query_cap(card: std.posix.fd_t, capability: Capability) !u64 {
    var cap = drm_get_cap {
        .capability = @intFromEnum(capability),
        .value = 0,
    };
    const ret = ioctl(card, c.DRM_IOCTL_GET_CAP, @intFromPtr(&cap));
    if(ret < 0){
        return std.posix.unexpectedErrno();
    }
    return cap.value;
}

pub fn query_card_resources(card: std.posix.fd_t, allocator: std.mem.Allocator) !Resources {
    var res = std.mem.zeroes(drm_CardResources);
    const ret0 = ioctl(card, c.DRM_IOCTL_MODE_GETRESOURCES, @intFromPtr(&res));

    const empty: [0]u32 = undefined;

    if(ret0 < 0){
        return std.posix.unexpectedErrno();
    }
    var resources = Resources {
        .allocator = allocator,
        .fb_ids = &empty,
        .connector_ids = &empty,
        .encoder_ids = &empty,
        .crtc_ids = &empty,
        .limits = undefined,
    };
    
    resources.fb_ids = try allocator.alloc(u32, res.count_fbs);
    errdefer allocator.free(resources.fb_ids);

    resources.connector_ids = try allocator.alloc(u32, res.count_connectors);
    errdefer allocator.free(resources.connector_ids);

    resources.encoder_ids = try allocator.alloc(u32, res.count_encoders);
    errdefer allocator.free(resources.encoder_ids);

    resources.crtc_ids = try allocator.alloc(u32, res.count_crtcs);
    errdefer allocator.free(resources.crtc_ids);

    resources.limits.min.width = res.min_width;
    resources.limits.min.height = res.min_height;
    resources.limits.max.width = res.max_width;
    resources.limits.max.height = res.max_height;

    res.fb_id_ptr = @intFromPtr(resources.fb_ids.ptr);
    res.connector_id_ptr = @intFromPtr(resources.connector_ids.ptr);
    res.encoder_id_ptr = @intFromPtr(resources.encoder_ids.ptr);
    res.crtc_id_ptr = @intFromPtr(resources.crtc_ids.ptr);

    const ret1 = ioctl(card, c.DRM_IOCTL_MODE_GETRESOURCES, @intFromPtr(&res));

    if(ret1 < 0){
        return std.posix.unexpectedErrno();
    }
    return resources;
}

pub fn free_card_resources(res: Resources) void {
    res.allocator.free(res.fb_ids);
    res.allocator.free(res.connector_ids);
    res.allocator.free(res.encoder_ids);
    res.allocator.free(res.crtc_ids);
}

pub const FramebufferInfo = struct {
    resolution: Resolution,
};

pub const Connection = struct {
    connector_id: u32,
    connector_mode: u32,
    encoder_id: u32,
    crtc_id: u32,
};

pub const Resolution = union(enum) {
    small: Small,
    medium: Medium,
    large: Large,

    pub const Small = struct{ size: @Vector(2, u32) = .{ 640, 480 }, half: bool = false, };
    pub const Medium = struct{ size: @Vector(2, u32) = .{ 800, 600 }, half: bool = false, };
    pub const Large = struct{ size: @Vector(2, u32) = .{ 1280, 720 }, half: bool = false, };
    
    pub fn get_native_size(self: @This()) @Vector(2, u32) {
        return switch(self){
            .small => |s| s.size / @as(@Vector(2, u32), @splat(@intFromBool(s.half) + 1)),
            .medium => |m| m.size / @as(@Vector(2, u32), @splat(@intFromBool(m.half) + 1)),
            .large => |l| l.size / @as(@Vector(2, u32), @splat(@intFromBool(l.half) + 1)),
        };
    }

    pub fn get_size(self: @This()) @Vector(2, u32) {
        return switch(self){
            .small => |s| s.size,
            .medium => |m| m.size,
            .large => |l| l.size,
        };
    }
};

fn select_open_connector(card: std.posix.fd_t, res: Resources) !u32 {
    for(res.connector_ids) |conn_id| {
        const conn = c.drmModeGetConnector(card, conn_id);
        if(conn == null){
            continue;
        }
        if(conn.*.connection != c.DRM_MODE_CONNECTED or conn.*.count_modes == 0){
            continue;
        }

        return conn_id;
    }
    else {
        return error.CONN_NOT_FOUND;
    }
}

fn select_mode(connector: *c.drmModeConnector, info: FramebufferInfo) ?struct { c.drmModeModeInfo, u32 } {
    const resolution = info.resolution.get_native_size();
    for(0..@intCast(connector.count_modes)) |idx| {
        const mode = connector.modes[idx];
        if(mode.hdisplay == resolution[0] and mode.vdisplay == resolution[1]){
            return .{
                mode,
                @intCast(idx),
            };
        }
    }
    return null;
}

pub fn select_connection_and_encoder(card: std.posix.fd_t, res: Resources, info: FramebufferInfo) !Connection {
    const connector_id = try select_open_connector(card, res);

    const connector = c.drmModeGetConnector(card, connector_id);
    if(connector == null){
        return error.NoActiveConnection;
    }

    if(select_mode(connector.?, info)) |mode| {
        for(0..@intCast(connector.*.count_encoders)) |idx| {
            const encoder_id = connector.*.encoders[idx];
            const encoder = c.drmModeGetEncoder(card, encoder_id);
            
            for(0..res.crtc_ids.len) |crtc_idx| {
                if(encoder.*.possible_crtcs & (@as(u32, 1) << @as(u5, @truncate(crtc_idx))) != 0) {
                    return Connection{
                        .connector_id = connector_id,
                        .connector_mode = mode[1],
                        .encoder_id = encoder_id,
                        .crtc_id = res.crtc_ids[crtc_idx],
                    };
                }
            }

        }
        
        return error.UnableToResolveConnectorDetailsForMode;

        //return Connection{
        //    .connector_id = connector_id,
        //    .connector_mode = mode[1],
        //    .encoder_id = 0,
        //    .crtc_id = 0,
        //};
    }
    
    return error.ModeNotAvailable;
}
