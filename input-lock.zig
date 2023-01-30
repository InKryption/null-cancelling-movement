const std = @import("std");
const assert = std.debug.assert;

pub const InputLock = enum(u3) {
    inactive = @bitCast(u3, InputLockState{ .held_by = .none, .contested = false }),
    stalemate = @bitCast(u3, InputLockState{ .held_by = .none, .contested = true }),

    a_exclusive = @bitCast(u3, InputLockState{ .held_by = .a, .contested = false }),
    a_contested = @bitCast(u3, InputLockState{ .held_by = .a, .contested = true }),

    b_exclusive = @bitCast(u3, InputLockState{ .held_by = .b }),
    b_contested = @bitCast(u3, InputLockState{ .held_by = .b, .contested = true }),

    pub const Decision = enum(u2) { none, a, b };
    pub const InputState = packed struct(u2) { a: bool, b: bool };

    pub inline fn init() InputLock {
        return .inactive;
    }

    pub inline fn decision(inlock: InputLock) Decision {
        const inlock_state = @bitCast(InputLockState, @enumToInt(inlock));
        return inlock_state.held_by;
    }
    comptime {
        for (@typeInfo(InputLock).Enum.fields) |field| {
            const tag = @field(InputLock, field.name);
            switch (tag) {
                .inactive => assert(decision(tag) == .none),
                .stalemate => assert(decision(tag) == .none),

                .a_exclusive => assert(decision(tag) == .a),
                .a_contested => assert(decision(tag) == .a),

                .b_exclusive => assert(decision(tag) == .b),
                .b_contested => assert(decision(tag) == .b),
            }
        }
    }

    pub fn updateCopy(inlock: InputLock, inputs: InputState, comptime bias: Decision) InputLock {
        return switch (@intToEnum(InputStatePermutation, @bitCast(u2, inputs))) {
            .__ => .inactive,
            .a_ => .a_exclusive,
            ._b => .b_exclusive,
            .ab => switch (inlock) {
                .inactive, .stalemate => comptime switch (bias) {
                    .none => .stalemate,
                    .a => .a_contested,
                    .b => .b_contested,
                },
                .a_exclusive, .b_contested => .b_contested,
                .b_exclusive, .a_contested => .a_contested,
            },
        };
    }

    pub fn updateInPlace(inlock: *InputLock, inputs: InputState, comptime bias: Decision) void {
        inlock.* = @call(.always_inline, updateCopy, .{ inlock.*, inputs, bias });
    }

    pub fn DecisionAsVals(comptime T: type) type {
        return struct { none: T, a: T, b: T };
    }
    pub fn decisionAs(
        inlock: InputLock,
        comptime T: type,
        comptime values: DecisionAsVals(T),
    ) T {
        return switch (inlock.decision()) {
            inline else => |tag| @field(values, @tagName(tag)),
        };
    }

    const InputLockState = packed struct(u3) {
        held_by: Decision = .none,
        contested: bool = false,
    };
    const InputStatePermutation = enum(u2) {
        // zig fmt: off
        __ = @bitCast(u2, InputState{ .a = false, .b = false }),
        a_ = @bitCast(u2, InputState{ .a = true,  .b = false }),
        _b = @bitCast(u2, InputState{ .a = false, .b = true }),
        ab = @bitCast(u2, InputState{ .a = true,  .b = true }),
        // zig fmt: on
    };
};

fn expectDecisionWithBias(
    il: *InputLock,
    inputs: InputLock.InputState,
    comptime bias: InputLock.Decision,
    expected: InputLock.Decision,
) !void {
    il.updateInPlace(inputs, bias);
    const actual = il.decision();
    return std.testing.expectEqual(expected, actual);
}
fn expectDecision(
    il: *InputLock,
    inputs: InputLock.InputState,
    expected: InputLock.Decision,
) !void {
    return expectDecisionWithBias(il, inputs, .none, expected);
}

test {
    var ncs = InputLock.init();
    const _______ = comptime InputLock.InputState{ .a = false, .b = false };
    const @"<== " = comptime InputLock.InputState{ .a = true, .b = false };
    const @" ==>" = comptime InputLock.InputState{ .a = false, .b = true };
    const @"<==>" = comptime InputLock.InputState{ .a = true, .b = true };

    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, @"<==>", .none); // extremely rare case (no input followed by simultaneous inputs)
    try expectDecision(&ncs, _______, .none);
    try expectDecisionWithBias(&ncs, @"<==>", .a, .a); // simultaneous inputs can be handled with bias
    try expectDecisionWithBias(&ncs, @"<==>", .a, .a);
    try expectDecisionWithBias(&ncs, @"<==>", .b, .a); // <- bias doesn't affect the normal case
    try expectDecisionWithBias(&ncs, @"<==>", .b, .a);
    try expectDecision(&ncs, @"<==>", .a);
    try expectDecision(&ncs, _______, .none);
    try expectDecisionWithBias(&ncs, @"<==>", .b, .b); // ^
    try expectDecisionWithBias(&ncs, @"<==>", .b, .b);
    try expectDecisionWithBias(&ncs, @"<==>", .a, .b);
    try expectDecisionWithBias(&ncs, @"<==>", .a, .b);
    try expectDecision(&ncs, @"<==>", .b);
    try expectDecision(&ncs, _______, .none);

    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, @"<==>", .b);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, @"<==>", .a);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, @"<==>", .a);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, @"<==>", .b);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, @"<==>", .b);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, @"<==>", .b);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, _______, .none);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, @"<==>", .a);
    try expectDecision(&ncs, @" ==>", .b);
    try expectDecision(&ncs, @"<==>", .a);
    try expectDecision(&ncs, @"<== ", .a);
    try expectDecision(&ncs, _______, .none);
}
