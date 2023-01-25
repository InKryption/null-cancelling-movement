const std = @import("std");
const assert = std.debug.assert;

/// Monad-like enum representing the transformation of two boolean inputs, into a single
/// output with three possible values (as opposed to the original 4 possible permutations).
pub const NCState = enum(u3) {
    off,
    a_exclusive,
    a_transition,
    b_exclusive,
    b_transition,

    pub const Input = enum(u2) {
        none,
        only_a,
        only_b,
        both,
    };

    pub const Decision = enum(u2) { none, a, b };
    pub fn DecisionValMap(comptime T: type) type {
        return struct {
            none: T,
            a: T,
            b: T,
        };
    }

    pub inline fn init() NCState {
        return .off;
    }

    /// Use to initialise an input state.
    pub inline fn input(a: bool, b: bool) Input {
        const Bits = packed struct(u2) { a: bool, b: bool };
        const bits = @bitCast(u2, Bits{ .a = a, .b = b });
        return @intToEnum(Input, bits);
    }
    comptime {
        // zig fmt: off
        assert(input(false, false) == .none);
        assert(input(true,  false) == .only_a);
        assert(input(false, true ) == .only_b);
        assert(input(true,  true ) == .both);
        // zig fmt: on
    }

    /// Determines the next state based on the input.
    /// A bias can be specified for what decision
    /// to output in the case of simultaneous input
    /// following no input.
    pub fn decide(ncs: NCState, in: Input, comptime bias: Decision) NCState {
        return switch (in) {
            .none => .off,
            .only_a => .a_exclusive,
            .only_b => .b_exclusive,
            .both => switch (ncs) {
                .a_transition, .b_exclusive => .a_transition,
                .a_exclusive, .b_transition => .b_transition,
                .off => comptime switch (bias) {
                    .none => .off,
                    .a => .a_transition,
                    .b => .b_transition,
                },
            },
        };
    }

    /// Same as `decide`, but assigns the resulting state
    /// to the original location.
    pub fn decideInPlace(ncs: *NCState, in: Input, comptime bias: Decision) void {
        ncs.* = @call(.always_inline, decide, .{ ncs.*, in, bias });
    }

    /// Returns the decision determined by the last input.
    pub fn decision(ncs: NCState) Decision {
        return @call(.always_inline, decisionAs, .{ ncs, Decision, .{
            .a = .a,
            .b = .b,
            .none = .none,
        } });
    }

    /// Like `decision`, except the possible outputs are configurable.
    pub fn decisionAs(
        ncs: NCState,
        comptime T: type,
        comptime values: DecisionValMap(T),
    ) T {
        return switch (ncs) {
            .off => values.none,
            .a_exclusive, .a_transition => values.a,
            .b_exclusive, .b_transition => values.b,
        };
    }
};

fn expectDecisionInPlace(ncs: *NCState, input: NCState.Input, expected: NCState.Decision) !void {
    return expectDecisionWithBiasInPlace(ncs, input, .none, expected);
}
fn expectDecisionWithBiasInPlace(ncs: *NCState, input: NCState.Input, comptime bias: NCState.Decision, expected: NCState.Decision) !void {
    ncs.decideInPlace(input, bias);
    const actual = ncs.decision();
    return std.testing.expectEqual(expected, actual);
}

test "Example Usage" {
    var ncs = NCState.init();
    try std.testing.expectEqual(NCState.Decision.none, ncs.decision());

    ncs.decideInPlace(NCState.input(true, false), .none);
    try std.testing.expectEqual(NCState.Decision.a, ncs.decision());

    ncs.decideInPlace(NCState.input(true, true), .none);
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
    try expectDecisionWithBiasInPlace(&ncs, @"<==>", .a, .a); // simultaneous inputs can be handled with bias
    try expectDecisionWithBiasInPlace(&ncs, @"<==>", .a, .a);
    try expectDecisionWithBiasInPlace(&ncs, @"<==>", .b, .a); // <- bias doesn't affect the normal case
    try expectDecisionWithBiasInPlace(&ncs, @"<==>", .b, .a);
    try expectDecisionInPlace(&ncs, @"<==>", .a);
    try expectDecisionInPlace(&ncs, _______, .none);
    try expectDecisionWithBiasInPlace(&ncs, @"<==>", .b, .b); // ^
    try expectDecisionWithBiasInPlace(&ncs, @"<==>", .b, .b);
    try expectDecisionWithBiasInPlace(&ncs, @"<==>", .a, .b);
    try expectDecisionWithBiasInPlace(&ncs, @"<==>", .a, .b);
    try expectDecisionInPlace(&ncs, @"<==>", .b);
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
