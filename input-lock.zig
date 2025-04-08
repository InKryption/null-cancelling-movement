const std = @import("std");
const assert = std.debug.assert;

pub const Input = enum(u2) { none, a, b, ab };
pub const Decision = enum(u2) { none, a, b };
pub const Lock = enum(u3) {
    inactive,
    stalemate,

    a_exclusive,
    a_contested,

    b_exclusive,
    b_contested,

    pub fn decision(inlock: Lock) Decision {
        return switch (inlock) {
            .inactive => .none,
            .stalemate => .none,

            .a_exclusive => .a,
            .a_contested => .a,

            .b_exclusive => .b,
            .b_contested => .b,
        };
    }

    pub fn update(inlock: Lock, inputs: Input, bias: Decision) Lock {
        return switch (inputs) {
            .none => .inactive,
            .a => .a_exclusive,
            .b => .b_exclusive,
            .ab => switch (inlock) {
                .inactive, .stalemate => switch (bias) {
                    .none => .stalemate,
                    .a => .a_contested,
                    .b => .b_contested,
                },
                .a_exclusive, .b_contested => .b_contested,
                .b_exclusive, .a_contested => .a_contested,
            },
        };
    }
};

test Lock {
    for (comptime std.enums.values(Lock)) |state| {
        inline for (.{ .none, .a, .b }) |bias| {
            try std.testing.expectEqual(Lock.inactive, Lock.update(state, .none, bias));
            try std.testing.expectEqual(Lock.a_exclusive, Lock.update(state, .a, bias));
            try std.testing.expectEqual(Lock.b_exclusive, Lock.update(state, .b, bias));
        }
    }
    try std.testing.expectEqual(Lock.stalemate, Lock.update(.inactive, .ab, .none));
    try std.testing.expectEqual(Lock.stalemate, Lock.update(.stalemate, .ab, .none));
    try std.testing.expectEqual(Lock.b_contested, Lock.update(.a_exclusive, .ab, .none));
    try std.testing.expectEqual(Lock.a_contested, Lock.update(.b_exclusive, .ab, .none));

    try std.testing.expectEqual(Lock.a_contested, Lock.update(.inactive, .ab, .a));
    try std.testing.expectEqual(Lock.a_contested, Lock.update(.stalemate, .ab, .a));
    try std.testing.expectEqual(Lock.b_contested, Lock.update(.a_exclusive, .ab, .a));
    try std.testing.expectEqual(Lock.a_contested, Lock.update(.b_exclusive, .ab, .a));

    try std.testing.expectEqual(Lock.b_contested, Lock.update(.inactive, .ab, .b));
    try std.testing.expectEqual(Lock.b_contested, Lock.update(.stalemate, .ab, .b));
    try std.testing.expectEqual(Lock.b_contested, Lock.update(.a_exclusive, .ab, .b));
    try std.testing.expectEqual(Lock.a_contested, Lock.update(.b_exclusive, .ab, .b));

    var ncs: Lock = .inactive;
    const _______: Input = .none;
    const @"<== ": Input = .a;
    const @" ==>": Input = .b;
    const @"<==>": Input = .ab;

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

fn expectDecisionWithBias(
    il: *Lock,
    inputs: Input,
    comptime bias: Decision,
    expected: Decision,
) !void {
    il.* = il.update(inputs, bias);
    const actual = il.decision();
    return std.testing.expectEqual(expected, actual);
}
fn expectDecision(
    il: *Lock,
    inputs: Input,
    expected: Decision,
) !void {
    return expectDecisionWithBias(il, inputs, .none, expected);
}
