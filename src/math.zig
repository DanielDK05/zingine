pub fn Vec2(comptime T: type) type {
    const Vector2 = struct {
        const Self = @This();

        x: T,
        y: T,

        pub const ZERO = Self.init(0, 0);

        pub fn init(x: T, y: T) Self {
            return Self{ .x = x, .y = y };
        }

        pub fn add(self: Self, rhs: Self) Self {
            return Self{ .x = self.x + rhs.x, .y = self.y + rhs.y };
        }

        pub fn eq(self: Self, rhs: Self) bool {
            return self.x == rhs.x and self.y == rhs.y;
        }
    };

    return Vector2;
}
