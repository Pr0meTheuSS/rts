//using Godot;
//
//public partial class FollowCamera : Camera3D
//{
	//[Export] public Node3D Target { set; get; }
	//[Export] public float SpringStiffness = 5.0f;
	//[Export] public float Damping = 0.8f;
//
	//private Vector3 _currentPosition = Vector3.Zero;
	//private Vector3 _velocity = Vector3.Zero;
//
	//public override void _PhysicsProcess(double delta)
	//{
		//if (Target == null) return;
//
		//// Целевая позиция: чуть позади и выше машины
		//Vector3 targetPos = Target.GlobalTransform.Origin +
							//Target.GlobalTransform.Basis.Z * -4.0f +
							//Target.GlobalTransform.Basis.Y * 2.5f;
//
		//// Пружинно-демпферная модель (простая симуляция подвески для камеры)
		//Vector3 force = (targetPos - _currentPosition) * SpringStiffness;
		//_velocity = (_velocity + force * (float)delta) * Damping;
		//_currentPosition += _velocity * (float)delta;
//
		//GlobalTransform = new Transform3D(
			//GlobalTransform.Basis,
			//_currentPosition
		//);
//
		//// Камера всегда смотрит на машину
		//LookAt(Target.GlobalTransform.Origin);
	//}
//}
