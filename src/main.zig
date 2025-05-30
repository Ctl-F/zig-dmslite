const std = @import("std");
const dmslite = @import("dmslite");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    const cards = try dmslite.enumerate_cards(allocator);
    defer dmslite.free_card_enumeration(cards);

    if(cards.items.len == 0){
        std.debug.print("No DRM/KMS devices detected\n", .{});
        return;
    }

    const card = try dmslite.open_card(cards.items[0]);
    defer dmslite.release_card(card);
    
    const cap = try dmslite.query_card_capabilities(card);

    std.debug.print("CARD: {s}\n  DUMB_BUFFER: {}\n  PREFERRED_DEPTH: {}\n  PREFER_SHADOW: {}\n",
        .{ cards.items[0], cap.can_use_dumb_buffer, cap.dumb_buffer_preferred_depth, cap.dumb_buffer_prefer_shadow });

}


