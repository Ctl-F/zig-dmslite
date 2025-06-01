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
    
    for(cards.items) |card| {
        std.debug.print("Found> {s}\n", .{card});
    }

    const card = try dmslite.open_card(cards.items[0]);
    defer dmslite.release_card(card);
    
    const cap = try dmslite.query_card_capabilities(card);
    const res = try dmslite.query_card_resources(card, allocator);
    defer dmslite.free_card_resources(res);

    std.debug.print("CARD: {s}\n  DUMB_BUFFER: {}\n  PREFERRED_DEPTH: {}\n  PREFER_SHADOW: {}\n",
        .{ 
            cards.items[0],
            cap.can_use_dumb_buffer, 
            cap.dumb_buffer_preferred_depth, 
            cap.dumb_buffer_prefer_shadow,
        }
    );
    std.debug.print("  FB_COUNT: {}\n  CONN_COUNT: {}\n  ENC_COUNT: {}\n  CRTC_COUNT: {}\n  LIMITS.MIN {}x{}\n  LIMITS.MAX: {}x{}\n",
        .{
            res.fb_ids.len,
            res.connector_ids.len,
            res.encoder_ids.len,
            res.crtc_ids.len,
            res.limits.min.width, res.limits.min.height,
            res.limits.max.width, res.limits.max.height,
        }
    );

}


