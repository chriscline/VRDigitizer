function transf = c_calculateTransformationMatrixFromXYZAndQuaternion(xyz, eulerAngles)
	assert(isvector(xyz));
	assert(length(xyz)==3);
	assert(isvector(eulerAngles));
	assert(length(eulerAngles)==3);
	
	transf = eye(4,4);
	transf(1:3,1:3) = c_calculateRotationMatrix(eulerAngles,3:-1:1);
	transf(1:3,4) = xyz;
end