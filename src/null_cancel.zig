const std = @import("std");

/// Monad-like struct used to implement null-cancelling input.
pub const NullCancel = packed struct(u4) {
    /// only means anything if `active = true`
    maybe_decision: Decision = undefined,
    active: bool = false,
    prev: Inputs = Inputs{ .a = false, .b = false },

    pub const Decision = enum(u1) { a = 0, b = 1 };
    pub const Inputs = packed struct(u2) { a: bool, b: bool };

    pub inline fn decision(ncs: NullCancel) ?Decision {
        return if (ncs.active) ncs.maybe_decision else null;
    }

    pub inline fn decide(
        old: NullCancel,
        inputs: Inputs,
    ) NullCancel {
        const a_was_held = old.prev.a;
        const b_was_held = old.prev.b;

        const a_is_held = inputs.a;
        const b_is_held = inputs.b;

        const a_was_active = old.active and old.maybe_decision == .a;
        const b_is_active = b_is_held and (!a_is_held or (a_was_held and (!b_was_held or !a_was_active)));

        const maybe_decision = @intToEnum(Decision, @boolToInt(b_is_active));
        const active = a_is_held or b_is_held;

        // should be safe, since there are no struct fields being aliased.
        return NullCancel{
            .maybe_decision = maybe_decision,
            .active = active,
            .prev = inputs,
        };
    }

    pub inline fn decideInPlace(
        ncs: *NullCancel,
        inputs: Inputs,
    ) ?Decision {
        ncs.* = ncs.decide(inputs);
        return ncs.decision();
    }
};

fn expectDecisionInPlace(ncs: *NullCancel, inputs: NullCancel.Inputs, expected: ?NullCancel.Decision) !void {
    const decision = ncs.decideInPlace(inputs);
    return std.testing.expectEqual(expected, decision);
}

test {
    var ncs = NullCancel{};
    const _______ = .{ .a = false, .b = false };
    const @"<== " = .{ .a = true, .b = false };
    const @" ==>" = .{ .a = false, .b = true };
    const @"<-->" = .{ .a = true, .b = true };

    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, @"<-->", .a); // only single-tick bias for a, in event of simultaneous input immediately after no input
    try expectDecisionInPlace(&ncs, _______, null);

    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<-->", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<-->", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<-->", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<-->", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<-->", .b);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, @"<-->", .b);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<-->", .a);
    try expectDecisionInPlace(&ncs, @" ==>", .b);
    try expectDecisionInPlace(&ncs, @"<-->", .a);
    try expectDecisionInPlace(&ncs, @"<== ", .a);
    try expectDecisionInPlace(&ncs, _______, null);
}
