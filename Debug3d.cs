using Godot;

public partial class VelocityDrawer : Control
{
	[Export] public float LineWidth = 3.0f;
	[Export] public float ArrowSize = 10.0f;
	 
	[Export] private VehicleBody3D? Car;
	[Export] private Camera3D? Camera;
	
	public override void _Draw()
	{
		Color color = Colors.Green;

		Vector3 playerPos = Car.GlobalTransform.Origin;

		Vector2 start = Camera.UnprojectPosition(playerPos);

		Vector2 end = Camera.UnprojectPosition(
			playerPos + Car.LinearVelocity
		);

		DrawLine(
			start,
			end,
			color,
			LineWidth
		);

		DrawTriangle(
			end,
			start.DirectionTo(end),
			ArrowSize,
			color
		);
	}


	private void DrawTriangle(
		Vector2 pos,
		Vector2 dir,
		float size,
		Color color)
	{
		Vector2 a = pos + dir * size;

		Vector2 b =
			pos +
			dir.Rotated(2 * Mathf.Pi / 3) *
			size;

		Vector2 c =
			pos +
			dir.Rotated(4 * Mathf.Pi / 3) *
			size;


		Vector2[] points =
		{
			a,
			b,
			c
		};


		DrawPolygon(
			points,
			new Color[]
			{
				color
			}
		);
	}
}
