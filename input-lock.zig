const std = @import("std");
const assert = std.debug.assert;

pub const Input = packed struct(u2) {
    a: bool,
    b: bool,

    inline fn permutation(input: Input) Permutation {
        return @enumFromInt(@as(u2, @bitCast(input)));
    }
    const Permutation = enum(u2) {
        ab = @bitCast(Input{ .a = true, .b = true }),
        a_ = @bitCast(Input{ .a = true, .b = false }),
        _b = @bitCast(Input{ .a = false, .b = true }),
        __ = @bitCast(Input{ .a = false, .b = false }),
    };
};

pub const InputLock = enum(u3) {
    inactive = @bitCast(State{ .held_by = .none, .contested = false }),
    stalemate = @bitCast(State{ .held_by = .none, .contested = true }),

    a_exclusive = @bitCast(State{ .held_by = .a, .contested = false }),
    a_contested = @bitCast(State{ .held_by = .a, .contested = true }),

    b_exclusive = @bitCast(State{ .held_by = .b }),
    b_contested = @bitCast(State{ .held_by = .b, .contested = true }),

    pub const Decision = enum(u2) { none, a, b };

    pub inline fn init() InputLock {
        return .inactive;
    }

    pub inline fn decision(inlock: InputLock) Decision {
        const inlock_state: State = @bitCast(@intFromEnum(inlock));
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

    pub fn updateCopy(inlock: InputLock, inputs: Input, comptime bias: Decision) InputLock {
        return switch (inputs.permutation()) {
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

    pub fn updateInPlace(inlock: *InputLock, inputs: Input, comptime bias: Decision) void {
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

    const State = packed struct(u3) {
        held_by: Decision = .none,
        contested: bool = false,
    };
};

fn expectDecisionWithBias(
    il: *InputLock,
    inputs: Input,
    comptime bias: InputLock.Decision,
    expected: InputLock.Decision,
) !void {
    il.updateInPlace(inputs, bias);
    const actual = il.decision();
    return std.testing.expectEqual(expected, actual);
}
fn expectDecision(
    il: *InputLock,
    inputs: Input,
    expected: InputLock.Decision,
) !void {
    return expectDecisionWithBias(il, inputs, .none, expected);
}

test {
    var ncs = InputLock.init();
    const _______ = comptime Input{ .a = false, .b = false };
    const @"<== " = comptime Input{ .a = true, .b = false };
    const @" ==>" = comptime Input{ .a = false, .b = true };
    const @"<==>" = comptime Input{ .a = true, .b = true };

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
