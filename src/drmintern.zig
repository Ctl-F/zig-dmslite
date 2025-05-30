const std = @import("std");
const c = @cImport({
    @cInclude("xf86drm.h");
    @cInclude("xf86drmMode.h");
    //@cInclude("asm/ioctl.h");
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

const DRM_IOCTL_BASE: u32 = 'd';
const DRM_COMMAND_BASE: u32 = 0x40;
const DRM_IOCTL_GET_CAP_NR = 0x0c;

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

};


pub fn query_cap(card: std.posix.fd_t, capability: Capability) !u64 {
    var cap = drm_get_cap {
        .capability = @intFromEnum(capability),
        .value = 0,
    };
    const ret = std.posix.system.ioctl(card, DRM_IOCTL_GET_CAP, @intFromPtr(&cap));
    if(ret != 0){
        return error.DRM_ERROR_CODE;
    }
    return cap.value;
}

