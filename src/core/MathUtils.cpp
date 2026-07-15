#include "MathUtils.hpp"

namespace MathUtils {

Vector3 BtToRl(const btVector3& v) {
    return {v.x(), v.y(), v.z()};
}

Vector3 BtForward(const btTransform& t) {
    btVector3 f = t.getBasis().getColumn(2);
    return {f.x(), f.y(), f.z()};
}

Vector3 BtUp(const btTransform& t) {
    btVector3 u = t.getBasis().getColumn(1);
    return {u.x(), u.y(), u.z()};
}

} // namespace MathUtils
