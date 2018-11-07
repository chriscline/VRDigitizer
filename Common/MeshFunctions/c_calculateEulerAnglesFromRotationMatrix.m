function eulerAngles = c_calculateEulerAnglesFromRotationMatrix(rotMat)
	numMats = size(rotMat,3);
	assert(size(rotMat,1)==3 && size(rotMat,2)==3);
	eulerAngles = nan(numMats,3);
	
	% based on http://nghiaho.com/?page_id=846
	eulerAngles(:,1) = atan2(rotMat(3,2,:),rotMat(3,3,:));
	eulerAngles(:,2) = atan2(-rotMat(3,1,:), sqrt(rotMat(3,2,:).^2 + rotMat(3,2,:).^2));
	eulerAngles(:,3) = atan2(rotMat(2,1,:), rotMat(1,1,:));
end