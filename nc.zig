const std = @import("std");

/// Monad-like enum representing the transformation of two boolean inputs, into a single
/// output with three possible values (as opposed to the original 4 possible permutations).
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

    pub const Bias = Decision;
    pub const Decision = enum(u2) { none, a, b };
    pub const Input = enum(u2) {
        none = @enumToInt(NCState.off),
        only_a = @enumToInt(NCState.a_exclusive),
        only_b = @enumToInt(NCState.b_exclusive),
        both_ab = 3,
    };
    pub fn DecisionCustomValues(comptime T: type) type {
        return struct {
            none: T,
            a: T,
            b: T,
        };
    }

    /// Use to initialise an input state.
    pub inline fn input(a: bool, b: bool) Input {
        const a_int: u2 = @boolToInt(a);
        const b_int: u2 = @as(u2, @boolToInt(b)) << 1;
        return @intToEnum(Input, a_int | b_int);
    }

    /// Determines the next state based on the input.
    pub inline fn decide(ncs: NCState, in: Input) NCState {
        return ncs.decideWithBias(in, .none);
    }

    /// Returns the decision determined by the last input.
    pub inline fn decision(ncs: NCState) Decision {
        return ncs.decisionCustom(Decision, .{
            .a = .a,
            .b = .b,
            .none = .none,
        });
    }

    // configurable functions

    /// Like `decide`, except a bias can be specified for what decision
    /// to output in the case of simultaneous input following no input.
    pub fn decideWithBias(
        ncs: NCState,
        in: Input,
        comptime bias: Bias,
    ) NCState {
        const is_transition_value = in == .both_ab;

        const exclusive_mask = @boolToInt(!is_transition_value) * @enumToInt(in);
        const transition_mask = @boolToInt(is_transition_value) * blk: {
            const bias_for_a = (comptime bias == .a) and ncs == .off;
            const bias_for_b = (comptime bias == .b) and ncs == .off;

            const enable_a_mask = bias_for_a or ncs.isEither(.b_exclusive, .a_transition);
            const enable_b_mask = bias_for_b or ncs.isEither(.a_exclusive, .b_transition);

            const trans_a_mask = @enumToInt(NCState.a_transition) * @boolToInt(enable_a_mask);
            const trans_b_mask = @enumToInt(NCState.b_transition) * @boolToInt(enable_b_mask);
            break :blk trans_a_mask | trans_b_mask;
        };

        return @intToEnum(NCState, exclusive_mask | transition_mask);
    }

    /// Like `decision`, except the possible outputs are configurable.
    pub fn decisionCustom(
        ncs: NCState,
        comptime T: type,
        comptime values: DecisionCustomValues(T),
    ) T {
        switch (@typeInfo(T)) {
            .Int, .Float, .Bool, .Enum, .ErrorSet => {},
            else => {
                const arr = [_]T{ values.none, values.a, values.b };
                const index = ncs.decisionCustom(std.math.IntFittingRange(0, arr.len), .{
                    .none = 0,
                    .a = 1,
                    .b = 2,
                });
                return arr[index];
            },
        }

        const a_bits = comptime toInt(values.a);
        const b_bits = comptime toInt(values.b);
        const none_bits = comptime toInt(values.none);

        const maybe_a = a_bits * @boolToInt(ncs.isEither(.a_exclusive, .a_transition));
        const maybe_b = b_bits * @boolToInt(ncs.isEither(.b_exclusive, .b_transition));
        const maybe_none = none_bits * @boolToInt(ncs == .off);
        return fromInt(T, maybe_a | maybe_b | maybe_none);
    }

    // normal function behaviour models

    /// Function whose behaviour the public `decision` function is intended to model
    inline fn decisionModel(ncs: NCState) Decision {
        return ncs.decisionCustomModel(Decision, .{
            .a = .a,
            .b = .b,
            .none = .none,
        });
    }

    /// Function whose behaviour the public `decide` function is intended to model
    inline fn decideModel(ncs: NCState, in: Input) NCState {
        return ncs.decideWithBiasModel(in, .none);
    }

    // configurable function behaviour models

    fn decisionCustomModel(
        ncs: NCState,
        comptime T: type,
        comptime values: DecisionCustomValues(T),
    ) T {
        return switch (ncs) {
            .off => values.none,
            .a_exclusive, .a_transition => values.a,
            .b_exclusive, .b_transition => values.b,
        };
    }

    fn decideWithBiasModel(
        ncs: NCState,
        in: Input,
        comptime bias: Bias,
    ) NCState {
        return switch (in) {
            .none => .off,
            .only_a => .a_exclusive,
            .only_b => .b_exclusive,
            .both_ab => switch (ncs) {
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

    // helper functions

    inline fn isEither(ncs: NCState, x: NCState, y: NCState) bool {
        return 0 != @enumToInt(ncs) & (@enumToInt(x) | @enumToInt(y));
    }
};

inline fn toInt(value: anytype) std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(value))) {
    const T = @TypeOf(value);
    const Int = std.meta.Int(.unsigned, @bitSizeOf(T));
    return @bitCast(Int, switch (@typeInfo(T)) {
        .ErrorSet => @errorToInt(value),
        .Bool => @boolToInt(value),
        .Enum => @enumToInt(value),
        else => value,
    });
}
inline fn fromInt(comptime T: type, value: std.meta.Int(.unsigned, @bitSizeOf(T))) T {
    return switch (@typeInfo(T)) {
        .ErrorSet => @errSetCast(T, @intToError(value)),
        .Bool => @bitCast(T, value),
        .Enum => |enumeration| @intToEnum(T, @bitCast(enumeration.tag_type, value)),
        else => @bitCast(T, value),
    };
}

comptime {
    var err_msg: []const u8 = "";
    defer if (err_msg.len != 0) @compileError(err_msg);

    const ncs_values = std.enums.values(NCState);
    const input_values = std.enums.values(NCState.Input);
    const bias_values = std.enums.values(NCState.Bias);

    for (ncs_values) |ncs| {
        const expected = ncs.decisionModel();
        const actual = ncs.decision();
        if (actual != expected) err_msg = err_msg ++ std.fmt.comptimePrint(
            "Expected for `{}.decision(.{s})` to evaluate to `{}`, instead evaluated to `{}`.\n",
            .{ @TypeOf(ncs), @tagName(ncs), expected, actual },
        );
    }

    for (ncs_values) |ncs| {
        for (input_values) |in| {
            {
                const expected = ncs.decideModel(in);
                const actual = ncs.decide(in);

                if (actual != expected) err_msg = err_msg ++ std.fmt.comptimePrint(
                    "Expected for `{}.decide(.{s}, {})` to evaluate to `{}`, instead evaluated to `{}`.\n",
                    .{ @TypeOf(ncs), @tagName(ncs), in, expected, actual },
                );
            }

            for (bias_values) |bias| {
                const expected = ncs.decideWithBiasModel(in, bias);
                const actual = ncs.decideWithBias(in, bias);

                if (actual != expected) err_msg = err_msg ++ std.fmt.comptimePrint(
                    "Expected for `{}.decideWithBias(.{s}, {})` to evaluate to `{}`, instead evaluated to `{}`.\n",
                    .{ @TypeOf(ncs), @tagName(ncs), in, expected, actual },
                );
            }
        }
    }
}

fn expectDecisionInPlace(ncs: *NCState, input: NCState.Input, expected: NCState.Decision) !void {
    ncs.* = ncs.decide(input);
    const actual = ncs.decision();
    return std.testing.expectEqual(expected, actual);
}
fn expectDecisionWithBiasInPlace(ncs: *NCState, input: NCState.Input, comptime bias: NCState.Bias, expected: NCState.Decision) !void {
    ncs.* = ncs.decideWithBias(input, bias);
    const actual = ncs.decision();
    return std.testing.expectEqual(expected, actual);
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
