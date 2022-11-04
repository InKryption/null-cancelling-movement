const std = @import("std");

/// Monad-like struct used to implement null-cancelling input.
pub const NullCancel = packed struct(u4) {
    prev: Inputs = Inputs{ .a = false, .b = false },
    decision: Decision = .none,

    pub const Decision = enum(u2) { none, a, b };
    pub const Inputs = packed struct(u2) { a: bool, b: bool };

    pub inline fn decideInPlace(
        ncs: *NullCancel,
        inputs: Inputs,
    ) Decision {
        ncs.* = ncs.decide(inputs);
        return ncs.decision;
    }

    pub inline fn decide(
        old: NullCancel,
        inputs: Inputs,
    ) NullCancel {
        const a_was_held = old.prev.a;
        const b_was_held = old.prev.b;

        const a_is_held = inputs.a;
        const b_is_held = inputs.b;

        const a_was_active = old.decision == .a;
        const b_was_active = old.decision == .b;

        const a_is_active = a_is_held and (!b_is_held or (b_was_held and (!a_was_held or !b_was_active)));
        const b_is_active = b_is_held and (!a_is_held or (a_was_held and (!b_was_held or !a_was_active)));

        // should be safe, since there are no struct fields being aliased.
        return NullCancel{
            .prev = inputs,
            .decision = @intToEnum(Decision, @bitCast(u2, Inputs{
                .a = a_is_active,
                .b = b_is_active,
            })),
        };
    }
};

fn expectDecisionInPlace(ncs: *NullCancel, inputs: NullCancel.Inputs, expected: NullCancel.Decision) !void {
    const decision = ncs.decideInPlace(inputs);
    return std.testing.expectEqual(expected, decision);
}

test {
    var ncs = NullCancel{};
    const _______ = .{ .a = false, .b = false };
    const @"<== " = .{ .a = true, .b = false };
    const @" ==>" = .{ .a = false, .b = true };
    const @"<-->" = .{ .a = true, .b = true };

    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<-->", .none); // extremely rare case (no input followed by simultaneous inputs)
    try expectDecisionInPlace(&ncs, _______, .none);

    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<-->", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<-->", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<-->", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<-->", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<-->", .b);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<-->", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<-->", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<-->", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, .none);
}
