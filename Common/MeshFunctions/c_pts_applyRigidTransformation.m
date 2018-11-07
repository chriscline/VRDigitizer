function pts = c_pts_applyRigidTransformation(pts,quaternion)
	%TODO: add check that transform is actually rigid
	pts = c_pts_applyTransform(pts,'quaternion',quaternion);
end