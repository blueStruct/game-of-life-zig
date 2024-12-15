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
    const cellSizePixels = 4;
    const cellCountHorizontal = 360;
    const cellCountVertical = 240;
    const screenWidth = cellSizePixels * cellCountHorizontal;
    const screenHeight = cellSizePixels * cellCountVertical;
    const cellCount = cellCountVertical * cellCountHorizontal;
    var cellBuffer1: [cellCount]bool = undefined; // double buffer pattern
    var cellBuffer2: [cellCount]bool = undefined;
    var readBuffer: [*]bool = &cellBuffer1;
    var writeBuffer: [*]bool = &cellBuffer2;

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.rand.DefaultPrng.init(seed);
    var rand = prng.random();

    for (readBuffer[0..cellBuffer1.len]) |*cell| {
        cell.* = rand.boolean();
    }

    rl.initWindow(screenWidth, screenHeight, "conway's game of life with raylib-zig");
    defer rl.closeWindow();
    rl.setTargetFPS(10);

    // main game loop
    while (!rl.windowShouldClose()) { // detect window close button or ESC key
        // update
        for (0.., writeBuffer[0..cellBuffer1.len]) |i, *cell| {
            // count live neighbors
            const cellAlive = readBuffer[i];
            var countLiveNeighbors: u32 = 0;
            for (getNeighborIndices(i, cellCountHorizontal, cellCountVertical)) |neighborIndex| {
                if (readBuffer[neighborIndex]) {
                    countLiveNeighbors += 1;
                }
            }

            // apply rules
            if (cellAlive and (countLiveNeighbors < 2 or countLiveNeighbors > 3)) { // rule 1,3
                cell.* = false;
            } else if (cellAlive) { // rule 2
                cell.* = true;
            } else if (!cellAlive and countLiveNeighbors == 3) { // rule 4
                cell.* = true;
            } else { // special rule because of double buffer pattern
                cell.* = false;
            }
        }

        // draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        for (0.., readBuffer[0..cellBuffer1.len]) |i, *cell| {
            if (cell.* == true) {
                const coords = getXandY(i, cellCountHorizontal);
                rl.drawRectangle(coords.x * cellSizePixels, coords.y * cellSizePixels, cellSizePixels, cellSizePixels, rl.Color.white);
            }
        }

        // swap buffers
        std.mem.swap([*]bool, &readBuffer, &writeBuffer);
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
    var neighborsRelativeCoords: [8]RelativeCoords = undefined;
    neighborsRelativeCoords[0] = .{ .x = -1, .y = -1 };
    neighborsRelativeCoords[1] = .{ .x = 0, .y = -1 };
    neighborsRelativeCoords[2] = .{ .x = 1, .y = -1 };
    neighborsRelativeCoords[3] = .{ .x = -1, .y = 0 };
    neighborsRelativeCoords[4] = .{ .x = 1, .y = 0 };
    neighborsRelativeCoords[5] = .{ .x = -1, .y = 1 };
    neighborsRelativeCoords[6] = .{ .x = 0, .y = 1 };
    neighborsRelativeCoords[7] = .{ .x = 1, .y = 1 };

    const cellCoords = getXandY(index, width);
    var neighborsIndices: [8]usize = undefined;

    for (0.., neighborsRelativeCoords) |i, nCoords| {
        const wrappedCoords = wrap(cellCoords, nCoords, width, height);
        neighborsIndices[i] = getArrayIndex(wrappedCoords, width);
    }

    return neighborsIndices;
}
