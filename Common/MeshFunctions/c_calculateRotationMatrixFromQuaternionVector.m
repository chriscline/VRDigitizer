function rot = c_calculateRotationMatrixFromQuaternionVector(quatVec)
	assert(isvector(quatVec));
	assert(length(quatVec)==4);
	assert(abs((norm(quatVec)-1))<eps*1e10);
	
	% from https://en.wikipedia.org/wiki/Rotation_matrix#Quaternion
	w = quatVec(1);
	x = quatVec(2);
	y = quatVec(3);
	z = quatVec(4);
	
	n = w * w + x * x + y * y + z * z;
	if n == 0 
		s = 0;
	else
		s = 2 / n;
	end
	
	wx = s * w * x; wy = s * w * y; wz = s * w * z;
	xx = s * x * x; xy = s * x * y; xz = s * x * z;
	yy = s * y * y; yz = s * y * z; zz = s * z * z;

	rot = [ 1 - (yy + zz)	xy + wz			xz - wy				;
			xy - wz			1 - (xx + zz)	yz + wx				;
			xz + wy			yz - wx			1 - (xx + yy)		];
end