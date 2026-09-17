const std = @import("std");
const rl = @import("raylib");

const MAX_ENTITES = 3;
const WIN_SCORE = 5;

const EntityId = enum(u2) { 
    left_paddle = 0, 
    right_paddle, 
    ball 
};

const World = struct {
    positions_x: [MAX_ENTITES]f32,
    positions_y: [MAX_ENTITES]f32,
    velocities_x: [MAX_ENTITES]f32,
    velocities_y: [MAX_ENTITES]f32,
    widths: [MAX_ENTITES]f32,
    heights: [MAX_ENTITES]f32,
    colors: [MAX_ENTITES][4]u8,
    scores: [2]u32,
    screenSize: struct { f32, f32 }
};

const GameState = enum { start, playing, end };

fn initWorld() World {
    const lPaddleId = @intFromEnum(EntityId.left_paddle);
    const rPaddleId = @intFromEnum(EntityId.right_paddle);
    const ballId = @intFromEnum(EntityId.ball);

    var positions_x: [MAX_ENTITES]f32 = undefined;

    positions_x[lPaddleId] = 20.0;
    positions_x[rPaddleId] = 770.0;

    var positions_y: [MAX_ENTITES]f32 = undefined;

    positions_y[lPaddleId] = 200.0;
    positions_y[rPaddleId] = 200.0;

    var velocities_x: [MAX_ENTITES]f32 = @splat(0.0);
    var velocities_y: [MAX_ENTITES]f32 = @splat(0.0);

    var widths: [MAX_ENTITES]f32 = undefined;

    widths[lPaddleId] = 10.0;
    widths[rPaddleId] = 10.0;
    widths[ballId] = 8.0;

    var heights: [MAX_ENTITES]f32 = undefined;

    heights[lPaddleId] = 60.0;
    heights[rPaddleId] = 60.0;
    heights[ballId] = 8.0;

    var colors: [MAX_ENTITES][4]u8 = undefined;

    colors[lPaddleId] = [4]u8{ 255, 0, 0, 200 };
    colors[rPaddleId] = [4]u8{ 0, 0, 255, 200 };
    colors[ballId] = [4]u8{ 255, 255, 255, 255 };

    const scores: [2]u32 = @splat(0);

    const screenWidth = 800.0;
    const screenHeihgt = 600.0;
    
    respawn_ball(
        .{
            &positions_x[ballId],
            &positions_y[ballId]
        },
        .{
            &velocities_x[ballId],
            &velocities_y[ballId]
        },
        .{
            screenWidth,
            screenHeihgt
        }
    );


    return World { 
        .positions_x = positions_x, 
        .positions_y = positions_y, 
        .velocities_x = velocities_x, 
        .velocities_y = velocities_y, 
        .widths = widths, 
        .heights = heights, 
        .colors = colors, 
        .scores = scores,
        .screenSize = .{ screenWidth, screenHeihgt }
    };
}

const Rectangle = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    fn intersects_rect(self: *const Rectangle, other: *const Rectangle) bool {
        if (self.x > other.x + other.width or self.x + self.width < other.x)
            return false;
        
        if (self.y > other.y + other.height or self.y + self.height < other.y)
            return false;

        return true;
    }
};

fn inputSystem(world: *World) void {
    const playerId = @intFromEnum(EntityId.left_paddle);
    const speed = 400.0;

    world.velocities_y[playerId] = 0.0;

    if (rl.isKeyDown(rl.KeyboardKey.w))
        world.velocities_y[playerId] = -speed;
        
    if (rl.isKeyDown(rl.KeyboardKey.s))
       world.velocities_y[playerId] = speed;
}

fn paddleClamp(
    paddlePosY: *f32, 
    paddleHeight: f32,
    topHeightScreen: f32, 
    bottomHeightScreen: f32
) void {
    if (paddlePosY.* < topHeightScreen) {
        paddlePosY.* = topHeightScreen;
    }
    else if (paddlePosY.* + paddleHeight > bottomHeightScreen) {
        paddlePosY.* = bottomHeightScreen - paddleHeight;
    }
}

fn movementSystem(
    world: *World, 
    dt: f32, 
    topHeightScreen: f32, 
    bottomHeightScreen: f32
) void {
    const ballId = @intFromEnum(EntityId.ball); 
    const playerId = @intFromEnum(EntityId.left_paddle);
    const aiId = @intFromEnum(EntityId.right_paddle);

    world.positions_x[ballId] += world.velocities_x[ballId] * dt;
    world.positions_y[ballId] += world.velocities_y[ballId] * dt;
    
    const ballCollider = Rectangle {
        .x = world.positions_x[ballId],
        .y = world.positions_y[ballId],
        .width = world.widths[ballId],
        .height = world.heights[ballId],
    };

    const newAiPosY = world.positions_y[aiId] + world.velocities_y[aiId] * dt;

    var aiCollider = Rectangle {
        .x = world.positions_x[aiId],
        .y = newAiPosY,
        .width = world.widths[aiId],
        .height = world.heights[aiId]
    };

    const newPlayerPosY = world.positions_y[playerId] + world.velocities_y[playerId] * dt;
    
    var playerCollider = Rectangle {
        .x = world.positions_x[playerId],
        .y = newPlayerPosY,
        .width = world.widths[playerId],
        .height = world.heights[playerId]
    };

    if (playerCollider.intersects_rect(&ballCollider)) {
        if (world.velocities_y[playerId] > 0.0) {
            playerCollider.y = @max(playerCollider.y, ballCollider.y - playerCollider.height);
        }
        else
            playerCollider.y = @min(playerCollider.y, ballCollider.y + ballCollider.height);
    }

    else if (aiCollider.intersects_rect(&ballCollider)) {
        if (world.velocities_y[aiId] > 0.0) {
            aiCollider.y = @max(aiCollider.y, ballCollider.y - aiCollider.height);
        }
        else
            aiCollider.y = @min(aiCollider.y, ballCollider.y + ballCollider.height);
    }

    world.positions_y[playerId] = playerCollider.y;

    const ballAccelaration = 1.1;

    if (ballCollider.intersects_rect(&playerCollider)) {
        world.velocities_x[ballId] = -world.velocities_x[ballId];
        world.positions_x[ballId] = world.positions_x[playerId] + world.widths[playerId];
        world.velocities_x[ballId] *= ballAccelaration;
        world.velocities_y[ballId] *= ballAccelaration;
    }
    else if (ballCollider.intersects_rect(&aiCollider)) {
        world.velocities_x[ballId] = -world.velocities_x[ballId];
        world.positions_x[ballId] = world.positions_x[aiId] - world.widths[aiId];
        world.velocities_x[ballId] *= ballAccelaration;
        world.velocities_y[ballId] *= ballAccelaration;
    }
    
    world.positions_y[aiId] = aiCollider.y;

    paddleClamp(&world.positions_y[aiId], world.heights[aiId], topHeightScreen, bottomHeightScreen);
    paddleClamp(&world.positions_y[playerId], world.heights[playerId], topHeightScreen, bottomHeightScreen);
}

fn aiSystem(world: *World) void {
    const aiId = @intFromEnum(EntityId.right_paddle);
    
    const aiCenterY = world.positions_y[aiId] + world.heights[aiId] / 2.0;
    const ballId = @intFromEnum(EntityId.ball);
    const ballCenterY = world.positions_y[ballId] + world.heights[ballId] / 2.0;

    const deadZone = 10.0;
    const diff = aiCenterY - ballCenterY;

    const speed = 300 + @abs(world.velocities_y[ballId] / 2.0);

    if (@abs(diff) <= deadZone)
    {
        world.velocities_y[aiId] = 1.0;
    }
    else if (diff < 0.0) {
        world.velocities_y[aiId] = speed;
    }
    else
        world.velocities_y[aiId] = -speed;
}

fn respawn_ball(
    ballPos: struct { *f32, *f32 }, 
    ballVelocity: struct { *f32, *f32 }, 
    screenSize: struct { f32, f32 }
) void {
    const offset = 10.0;
    const halfScreenWidth = screenSize[0] / 2.0;
    const ballPosX = [2]f32{ halfScreenWidth - offset, halfScreenWidth + offset };
    const ballPosY = [2]f32{ 0.0, screenSize[1] };
    const velocities = [2]f32{250, -250};

    var prng = std.Random.DefaultPrng.init(@as(u64, @intFromFloat(rl.getFrameTime() * 100.0)));
    const rand = prng.random();
    
    ballPos[0].* = ballPosX[rand.int(u1)];
    ballPos[1].* = ballPosY[rand.int(u1)];
    ballVelocity[0].* = velocities[rand.int(u1)];
    ballVelocity[1].* = velocities[rand.int(u1)];
}

fn scoreSystem(world: *World, state: *GameState, leftScreen: f32, rightScreen: f32) void {
    const ballId = @intFromEnum(EntityId.ball);
    const aiId = @intFromEnum(EntityId.right_paddle);
    const playerId = @intFromEnum(EntityId.left_paddle);
    var hasLeftScreen: bool = false;

    if (world.positions_x[ballId] < leftScreen) {
        world.scores[aiId] += 1;
        hasLeftScreen = true;
    }
    else if (world.positions_x[ballId] > rightScreen) {
        world.scores[playerId] += 1;
        hasLeftScreen = true;
    }

    if (world.scores[aiId] == WIN_SCORE or world.scores[playerId] == WIN_SCORE){
        state.* = .end;
    }
    else if (hasLeftScreen) {
        respawn_ball(
            .{
                &world.positions_x[ballId], 
                &world.positions_y[ballId]
            },
            .{
                &world.velocities_x[ballId],
                &world.velocities_y[ballId]
            },
            world.screenSize
        );
    }
}

fn bounceSystem(world: *World, topHeightScreen: f32, bottomHeightScreen: f32) void {
    const ballId = @intFromEnum(EntityId.ball);
    const ballTopLeft = world.positions_y[ballId];
    const ballBottomRight = world.positions_y[ballId] + world.heights[ballId];
    
    if (ballTopLeft < topHeightScreen) {
        world.positions_y[ballId] = 0.0;
        world.velocities_y[ballId] = -world.velocities_y[ballId];
    }
    else if (ballBottomRight > bottomHeightScreen) {
        world.positions_y[ballId] = bottomHeightScreen - world.heights[ballId];
        world.velocities_y[ballId] = -world.velocities_y[ballId];
    }
}

fn drawScore(world: *const World) std.fmt.BufPrintError!void {
    const playerId = @intFromEnum(EntityId.left_paddle);
    const aiId = @intFromEnum(EntityId.right_paddle);
    var buf: [256]u8 = undefined;

    const aiScore = try std.fmt.bufPrintSentinel(&buf, "{}", .{world.scores[aiId]}, 0);
    rl.drawText(aiScore, 550, 20, 40, rl.Color.white);

    const playerScore = try std.fmt.bufPrintSentinel(&buf, "{}", .{world.scores[playerId]}, 0);
    rl.drawText(playerScore, 200, 20, 40, rl.Color.white);   
}

fn drawEntities(world: *const World) !void {
    var i: usize = 0;

    while (i < MAX_ENTITES) : (i += 1) {
        const color_rgba = world.colors[i];
        const color = rl.Color {
            .r = color_rgba[0],
            .g = color_rgba[1],
            .b = color_rgba[2],
            .a = color_rgba[3],
        };

        const position = rl.Vector2 {
            .x = world.positions_x[i],
            .y = world.positions_y[i],
        };

        const size = rl.Vector2 {
            .x = world.widths[i],
            .y = world.heights[i],
        };

        rl.drawRectangleV(
            position,
            size,
            color
        );
    }
    
}

pub fn main() anyerror!void {
    const screenWidth = 800.0;
    const screenHeihgt = 600.0;
    const title = "zig-pong-dod";
    const aiId = @intFromEnum(EntityId.right_paddle);

    rl.initWindow(screenWidth, screenHeihgt, title);
    defer rl.closeWindow();

    const fps = 60.0;

    rl.setTargetFPS(fps);

    var world: World = initWorld();
    var state: GameState = GameState.start;
    var time: f32 = 0.0;
    var buf: [2]u8 = undefined;

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();


        rl.beginDrawing();
        defer rl.endDrawing();
        
        if (time > 0.2) {
            time -= dt;
            rl.clearBackground(rl.Color.black);
            try drawEntities(&world);
            try drawScore(&world);
            rl.drawText(
                try std.fmt.bufPrintSentinel(
                    &buf,
                    "{}",
                    .{@abs(@round(time))},
                    0
                ),
                screenWidth / 2,
                20,
                50,
                rl.Color.white
            );
            buf[0] = 0;
            continue;
        }

        rl.clearBackground(rl.Color.black);
        
        switch (state) {
            .start => {
                rl.drawText(
                    "Press Enter To Start", 
                    screenWidth / 2 - 300, 
                    screenHeihgt / 2 - 100, 
                    50,
                    rl.Color.white
                );
                
                if (rl.isKeyDown(rl.KeyboardKey.enter)) {
                    state = .playing;
                    time = 2.0;
                }
            },
            .playing => {
                inputSystem(&world);    
                aiSystem(&world);
                movementSystem(&world, dt, 0.0, screenHeihgt);
                bounceSystem(&world, 0.0, screenHeihgt);
                scoreSystem(&world, &state, 0.0, screenWidth);
                try drawEntities(&world);
                try drawScore(&world);
            },
            .end => {
                const winner = if (world.scores[aiId] == WIN_SCORE) "Defeat" else "Win";

                rl.drawText(
                    winner,
                    screenWidth / 2 - 100,
                    100,
                    50,
                    rl.Color.white
                );

                rl.drawText(
                    "Press Enter To ReStart", 
                    screenWidth / 2 - 300, 
                    screenHeihgt / 2 - 100, 
                    50,
                    rl.Color.white
                );
                
                rl.drawText(
                    "Press Escape To Quit", 
                    screenWidth / 2 - 300, 
                    screenHeihgt / 2, 
                    50,
                    rl.Color.white
                );

                if (rl.isKeyDown(rl.KeyboardKey.enter)) {
                    state = .playing;
                    world = initWorld();
                    time = 2.0;
                }
            },
        }
    }
}
