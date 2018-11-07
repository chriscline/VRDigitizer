function transf = c_calculateTransformationMatrixFromXYZAndQuaternion(origin, quaternion)
	assert(isvector(quaternion));
	assert(length(quaternion)==4);
	assert(isvector(origin));
	assert(length(origin)==3);
	
	transf = eye(4,4);
	transf(1:3,1:3) = c_calculateRotationMatrixFromQuaternionVector(quaternion);
	transf(1:3,4) = origin;
end