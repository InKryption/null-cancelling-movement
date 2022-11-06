const std = @import("std");

/// Monad-like enum used to implement null-cancelling input.
pub const NCState = enum(u4) {
    // zig fmt: off
    off          = 0x0,
    a_exclusive  = 0x1,
    b_exclusive  = 0x2,
    a_transition = 0x4,
    b_transition = 0x8,
    // zig fmt: on

    pub inline fn init() NCState {
        return .off;
    }

    pub const Decision = enum(u2) { none, a, b };
    pub const Input = enum(u2) {
        none = @enumToInt(NCState.off),
        only_a = @enumToInt(NCState.a_exclusive),
        only_b = @enumToInt(NCState.b_exclusive),
        both_ab = 3,
    };
    pub fn input(a: bool, b: bool) Input {
        const Bits = packed struct(u2) { a: bool, b: bool };
        return @intToEnum(Input, @bitCast(u2, Bits{ .a = a, .b = b }));
    }

    pub fn decision(ncs: NCState) Decision {
        return switch (ncs) {
            .off => .none,
            .a_exclusive, .a_transition => .a,
            .b_exclusive, .b_transition => .b,
        };
    }

    pub fn decide(ncs: NCState, in: Input) NCState {
        const is_transition_value = in == .both_ab;

        const maybe_non_transition_value = @boolToInt(!is_transition_value) * @enumToInt(in);
        const maybe_transition_value = @boolToInt(is_transition_value) * blk: {
            const maybe_transition_a_value = @enumToInt(NCState.b_transition) * @boolToInt(ncs.isEither(.a_exclusive, .b_transition));
            const maybe_transition_b_value = @enumToInt(NCState.a_transition) * @boolToInt(ncs.isEither(.b_exclusive, .a_transition));
            break :blk maybe_transition_a_value | maybe_transition_b_value;
        };

        return @intToEnum(NCState, maybe_non_transition_value | maybe_transition_value);
    }

    pub fn decideSwitch(ncs: NCState, in: Input) NCState {
        return switch (in) {
            .none => .off,
            .only_a => .a_exclusive,
            .only_b => .b_exclusive,
            .both_ab => switch (ncs) {
                .off => .off,
                .a_transition, .b_exclusive => .a_transition,
                .a_exclusive, .b_transition => .b_transition,
            },
        };
    }

    inline fn isEither(ncs: NCState, x: NCState, y: NCState) bool {
        return 0 != @enumToInt(ncs) & (@enumToInt(x) | @enumToInt(y));
    }
};

fn expectDecisionInPlace(ncs: *NCState, input: NCState.Input, expected: NCState.Decision) !void {
    ncs.* = ncs.decideSwitch(input);
    const decision = ncs.decision();
    return std.testing.expectEqual(expected, decision);
}

test "Example Usage" {
    var ncs = NCState.init();
    try std.testing.expectEqual(NCState.Decision.none, ncs.decision());

    ncs = ncs.decide(NCState.input(true, false));
    try std.testing.expectEqual(NCState.Decision.a, ncs.decision());

    ncs = ncs.decide(NCState.input(true, true));
    try std.testing.expectEqual(NCState.Decision.b, ncs.decision());
}

test {
    var ncs = NCState.init();
    const _______ = comptime NCState.input(false, false);
    const @"<== " = comptime NCState.input(true, false);
    const @" ==>" = comptime NCState.input(false, true);
    const @"<==>" = comptime NCState.input(true, true);

    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<==>", .none); // extremely rare case (no input followed by simultaneous inputs)
    try expectDecisionInPlace(&ncs, _______, .none);

    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<==>", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<==>", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<==>", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<==>", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<==>", .b);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<==>", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<==>", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<==>", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, .none);
}
