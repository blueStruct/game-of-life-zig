const rl = @import("raylib");
const std = @import("std");
const print = std.debug.print;

// type definitions
const Coords = struct {
    x: i32,
    y: i32,
};

const RelativeCoords = struct {
    x: i8,
    y: i8,
};

pub fn main() anyerror!void {
    // initialization
    const cell_size_pixels = 4;
    const cell_count_horizontal = 360;
    const cell_count_vertical = 240;
    const screen_width = cell_size_pixels * cell_count_horizontal;
    const screen_height = cell_size_pixels * cell_count_vertical;
    const cell_count = cell_count_vertical * cell_count_horizontal;
    var cell_buffer1: [cell_count]bool = undefined; // double buffer pattern
    var cell_buffer2: [cell_count]bool = undefined;
    var read_buffer: [*]bool = &cell_buffer1;
    var write_buffer: [*]bool = &cell_buffer2;

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.rand.DefaultPrng.init(seed);
    var rand = prng.random();

    for (read_buffer[0..cell_buffer1.len]) |*cell| {
        cell.* = rand.boolean();
    }

    rl.initWindow(screen_width, screen_height, "conway's game of life with raylib-zig");
    defer rl.closeWindow();
    rl.setTargetFPS(10);

    // main game loop
    while (!rl.windowShouldClose()) { // detect window close button or ESC key
        // update
        for (0.., write_buffer[0..cell_buffer1.len]) |i, *cell| {
            // count live neighbors
            const cell_alive = read_buffer[i];
            var count_live_neighbors: u32 = 0;
            for (getNeighborIndices(i, cell_count_horizontal, cell_count_vertical)) |neighborIndex| {
                if (read_buffer[neighborIndex]) {
                    count_live_neighbors += 1;
                }
            }

            // apply rules
            if (count_live_neighbors == 3) {
                cell.* = true;
            } else if (cell_alive and count_live_neighbors == 2) {
                cell.* = true;
            } else {
                cell.* = false;
            }
        }

        // draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        for (0.., read_buffer[0..cell_buffer1.len]) |i, *cell| {
            if (cell.* == true) {
                const coords = getXandY(i, cell_count_horizontal);
                rl.drawRectangle(coords.x * cell_size_pixels, coords.y * cell_size_pixels, cell_size_pixels, cell_size_pixels, rl.Color.white);
            }
        }

        // swap buffers
        std.mem.swap([*]bool, &read_buffer, &write_buffer);
    }
}

fn getArrayIndex(coords: Coords, width: comptime_int) usize {
    return @intCast(coords.y * width + coords.x);
}

fn getXandY(index: usize, width: comptime_int) Coords {
    const x = index % width;
    const y = @divFloor(index, width);
    return .{ .x = @intCast(x), .y = @intCast(y) };
}

fn wrap(coords: Coords, diff: RelativeCoords, width: comptime_int, height: comptime_int) Coords {
    return .{ .x = @rem(coords.x + width + diff.x, width), .y = @rem(coords.y + height + diff.y, height) };
}

fn getNeighborIndices(index: usize, width: comptime_int, height: comptime_int) [8]usize {
    var neighbors_relative_coords: [8]RelativeCoords = undefined;
    neighbors_relative_coords[0] = .{ .x = -1, .y = -1 };
    neighbors_relative_coords[1] = .{ .x = 0, .y = -1 };
    neighbors_relative_coords[2] = .{ .x = 1, .y = -1 };
    neighbors_relative_coords[3] = .{ .x = -1, .y = 0 };
    neighbors_relative_coords[4] = .{ .x = 1, .y = 0 };
    neighbors_relative_coords[5] = .{ .x = -1, .y = 1 };
    neighbors_relative_coords[6] = .{ .x = 0, .y = 1 };
    neighbors_relative_coords[7] = .{ .x = 1, .y = 1 };

    const cell_coords = getXandY(index, width);
    var neighbors_indices: [8]usize = undefined;

    for (0.., neighbors_relative_coords) |i, n_coords| {
        const wrapped_coords = wrap(cell_coords, n_coords, width, height);
        neighbors_indices[i] = getArrayIndex(wrapped_coords, width);
    }

    return neighbors_indices;
}
