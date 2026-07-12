#ifndef MATH_UTILS_HPP
#define MATH_UTILS_HPP

#include <btBulletDynamicsCommon.h>
#include <raylib.h>

namespace MathUtils {

Vector3 BtToRl(const btVector3& v);
Vector3 BtForward(const btTransform& t);
Vector3 BtUp(const btTransform& t);

} // namespace MathUtils

#endif // MATH_UTILS_HPP
#ifndef MATH_UTILS_HPP
#define MATH_UTILS_HPP

#include <btBulletDynamicsCommon.h>
#include <raylib.h>

namespace MathUtils {

Vector3 BtToRl(const btVector3& v);
Vector3 BtForward(const btTransform& t);
Vector3 BtUp(const btTransform& t);

} // namespace MathUtils

#endif // MATH_UTILS_HPP
