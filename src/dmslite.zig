const std = @import("std");

const c = @cImport({
    @cInclude("xf86drm.h");
    @cInclude("xf86drmMode.h");
});

pub const PhysicalCard = std.posix.fd_t;

pub const Error = error {
    DMS_NOT_AVAILABLE,
    OUT_OF_MEMORY,
    DIR_NOT_FOUND,
};


pub fn enumerate_cards(allocator: std.mem.Allocator) Error!std.ArrayList([]u8) {
    const List = std.ArrayList([]u8);
    var list = List.init(allocator);
    errdefer free_card_enumeration(list);


    var dir = std.fs.cwd().openDir("/dev/dri/", .{ .iterate = true } ) catch return Error.DIR_NOT_FOUND;
    defer dir.close();

    var it = dir.iterate();
    while(it.next() catch return Error.DIR_NOT_FOUND) |entry| {
        if(entry.kind != .file){
            continue;
        }

        if(std.mem.startsWith(u8, entry.name, "card")){
            const path = std.fs.path.join(allocator, &[_][]const u8{ "/dev/dri", entry.name }) catch return Error.OUT_OF_MEMORY;
            list.append(path) catch return Error.OUT_OF_MEMORY;
        }
    }

    return list;
}

pub fn free_card_enumeration(list: std.ArrayList([]u8)) void {
    for(list.items) |s| {
        list.allocator.free(s);
    }
    list.deinit();
}


pub fn open_card(path: []const u8) Error!PhysicalCard {
    const fd = std.posix.open(path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0) catch {
        return Error.DMS_NOT_AVAILABLE;
    }

    return fd;
}

pub fn release_card(card: PhysicalCard) void {
    std.posix.close(card);
}

pub const Capabilities = struct {
    can_use_dumb_buffer: bool,
    prime_dma_buf_sharing: bool,
    timestamp_monotonic: bool,
    async_page_flip: bool,
    cursor: struct { width: u64, height: u64 },
    allow_format_modifiers: bool,
};




pub fn query_card_capabilities(card: PhysicalCard) Error!Capabilities {

}


