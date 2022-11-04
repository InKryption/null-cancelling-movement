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
        return old.decideBiased(inputs, .none);
    }

    pub inline fn decideInPlace(
        ncs: *NullCancel,
        inputs: Inputs,
    ) ?Decision {
        return ncs.decideInPlaceBiased(inputs, .none);
    }

    const Bias = enum { a, b, none };

    pub inline fn decideBiased(
        old: NullCancel,
        inputs: Inputs,
        comptime bias: Bias,
    ) NullCancel {
        const a_was_held = old.prev.a;
        const b_was_held = old.prev.b;

        const a_is_held = inputs.a;
        const b_is_held = inputs.b;

        const a_was_active = old.active and old.maybe_decision == .a;
        const b_was_active = switch (bias) {
            .a => {},
            .b => @compileError(""),
            .none => old.active and old.maybe_decision == .b,
        };

        const a_is_active = switch (bias) {
            .a => {},
            .b => @compileError(""),
            .none => a_is_held and (!b_is_held or (b_was_held and (!a_was_held or !b_was_active))),
        };
        const b_is_active = b_is_held and (!a_is_held or (a_was_held and (!b_was_held or !a_was_active)));

        const maybe_decision = @intToEnum(Decision, @boolToInt(b_is_active));
        const active = switch (bias) {
            .a => a_is_held or b_is_held,
            .b => @compileError(""),
            .none => a_is_active or b_is_active,
        };

        // should be safe, since there are no struct fields being aliased.
        return NullCancel{
            .maybe_decision = maybe_decision,
            .active = active,
            .prev = inputs,
        };
    }

    pub inline fn decideInPlaceBiased(
        ncs: *NullCancel,
        inputs: Inputs,
        comptime bias: Bias,
    ) ?Decision {
        ncs.* = ncs.decideBiased(inputs, bias);
        return ncs.decision();
    }
};

export fn decideInPlaceExport(
    ncs: *NullCancel,
    inputs: packed struct(usize) {
        value: NullCancel.Inputs,
        _pad: enum(u62) { unset = 0 } = .unset,
    },
) usize {
    const decision = ncs.decideInPlaceBiased(inputs.value, .none) orelse return std.math.maxInt(usize);
    return @bitCast(usize, packed struct(usize) {
        decision: NullCancel.Decision,
        _pad: enum(u63) { unset = 0 } = .unset,
    }{ .decision = decision });
}

fn expectDecisionInPlace(ncs: *NullCancel, inputs: NullCancel.Inputs, expected: ?NullCancel.Decision) !void {
    const decision = ncs.decideInPlace(inputs);
    return std.testing.expectEqual(expected, decision);
}

fn expectDecisionInPlaceBiased(ncs: *NullCancel, inputs: NullCancel.Inputs, comptime bias: NullCancel.Bias, expected: ?NullCancel.Decision) !void {
    const decision = ncs.decideInPlaceBiased(inputs, bias);
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
    try expectDecisionInPlace(&ncs, @"<-->", null); // extremely rare case (no input followed by simultaneous inputs)
    try expectDecisionInPlace(&ncs, _______, null);
    try expectDecisionInPlaceBiased(&ncs, @"<-->", .a, .a); // can handle said rare case using bias
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
