#include <fmt/core.h>
#include <gtest/gtest.h>

#include <gtest/gtest.h>
#include "core/MathUtils.hpp"
#include "core/InputManager.hpp"

TEST(MathUtilsTest, BtToRl) {
    btVector3 v(1.0f, 2.0f, 3.0f);
    Vector3 result = MathUtils::BtToRl(v);
    EXPECT_FLOAT_EQ(result.x, 1.0f);
    EXPECT_FLOAT_EQ(result.y, 2.0f);
    EXPECT_FLOAT_EQ(result.z, 3.0f);
}

TEST(InputManagerTest, DefaultInput) {
    InputManager im;
    InputState state = im.getInput();
    EXPECT_FLOAT_EQ(state.engineForce, 0.0f);
    EXPECT_FLOAT_EQ(state.steering, 0.0f);
    EXPECT_FALSE(state.handbrake);
}

int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
}
