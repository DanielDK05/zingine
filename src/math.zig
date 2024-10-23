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

        pub fn simd(self: Self) @Vector(2, T) {
            return .{ self.x, self.y };
        }

        pub fn fromArr(arr: [2]T) Self {
            return Self{ .x = arr[0], .y = arr[1] };
        }

        pub fn normalize(self: Self) Self {
            const len = self.length();
            return Self{ .x = self.x / len, .y = self.y / len };
        }

        pub fn length(self: Self) T {
            return @sqrt(self.x * self.x + self.y * self.y);
        }

        pub fn scale(self: Self, scale_: T) Self {
            return Self{ .x = self.x * scale_, .y = self.y * scale_ };
        }
    };

    return Vector2;
}
