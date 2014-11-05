package h3d.anim;
import hxd.Math.*;

private class SmoothObject extends Animation.AnimatedObject {
	public var tx : Float;
	public var ty : Float;
	public var tz : Float;
	public var sx : Float;
	public var sy : Float;
	public var sz : Float;
	public var q : h3d.Quat;
	public var tmpMatrix : h3d.Matrix;
	public function new(name) {
		super(name);
	}
}

class SmoothTarget extends Animation {

	public var target : Animation;
	public var blend : Float;
	var duration : Float;

	public function new( target : h3d.anim.Animation, duration = 0.5 ) {
		super("SmoothTarget(" + target.name+")", target.frameCount, target.sampling);
		this.blend = 0;
		this.target = target;
		this.duration = duration;
		this.frame = target.frame;
		this.frameCount = target.frameCount;
		if( !target.isInstance )
			throw "Target should be instance";
		this.isInstance = true;
		initObjects();
	}

	function initObjects() {
		objects = [];
		for( o in target.objects ) {
			var mat;
			var s = new SmoothObject(o.objectName);
			s.targetObject = o.targetObject;
			s.targetSkin = o.targetSkin;
			s.targetJoint = o.targetJoint;
			objects.push(s);
			if( o.targetSkin != null )
				mat = @:privateAccess o.targetSkin.currentRelPose[o.targetJoint];
			else
				mat = o.targetObject.defaultTransform;
			if( mat == null )
				continue;
			s.tx = mat.tx;
			s.ty = mat.ty;
			s.tz = mat.tz;
			var sc = mat.getScale();
			s.sx = sc.x;
			s.sy = sc.y;
			s.sz = sc.z;
			s.q = new h3d.Quat();
			s.q.initRotateMatrix(mat);
			s.tmpMatrix = new h3d.Matrix();
		}
	}

	override function update(dt:Float) {
		var rt = target.update(dt);
		var st = dt - rt;
		blend += st / duration;
		frame = target.frame;
		if( blend > 1 ) {
			blend = 1;
			onAnimEnd();
		}
		return rt;
	}

	override function setFrame(f) {
		target.setFrame(f);
		frame = target.frame;
	}

	override function sync( decompose = false ) {
		if( decompose ) throw "assert";
		var objects : Array<SmoothObject> = cast objects;
		var q1 = new h3d.Quat(), qout = new h3d.Quat();
		target.sync(true);
		for( o in objects ) {
			var m = @:privateAccess if( o.targetSkin != null ) o.targetSkin.currentRelPose[o.targetJoint] else o.targetObject.defaultTransform;
			var mout = o.tmpMatrix;

			if( mout == null ) {

				// only recompose
				q1.set(m._12, m._13, m._21, m._23);
				var sx = m._11, sy = m._22, sz = m._33;
				var tx = m.tx, ty = m.ty, tz = m.tz;
				q1.saveToMatrix(m);
				m._11 *= sx;
				m._12 *= sx;
				m._13 *= sx;
				m._21 *= sy;
				m._22 *= sy;
				m._23 *= sy;
				m._31 *= sz;
				m._32 *= sz;
				m._33 *= sz;

				m.tx = tx;
				m.ty = ty;
				m.tz = tz;

			} else {

				q1.set(m._12, m._13, m._21, m._23);
				qout.lerp(o.q, q1, 1 - blend, true);
				qout.normalize();
				qout.saveToMatrix(mout);

				var sx = lerp(o.sx, m._11, blend);
				var sy = lerp(o.sy, m._22, blend);
				var sz = lerp(o.sz, m._33, blend);
				mout._11 *= sx;
				mout._12 *= sx;
				mout._13 *= sx;
				mout._21 *= sy;
				mout._22 *= sy;
				mout._23 *= sy;
				mout._31 *= sz;
				mout._32 *= sz;
				mout._33 *= sz;

				mout.tx = lerp(o.tx, m.tx, blend);
				mout.ty = lerp(o.ty, m.ty, blend);
				mout.tz = lerp(o.tz, m.tz, blend);

				@:privateAccess if( o.targetSkin != null ) o.targetSkin.currentRelPose[o.targetJoint] = mout else o.targetObject.defaultTransform = mout;
			}
		}
	}

}