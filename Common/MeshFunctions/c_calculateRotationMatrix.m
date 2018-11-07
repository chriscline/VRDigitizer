function rot = c_calculateRotationMatrix(theta, axis)
%from https://en.wikipedia.org/wiki/Rotation_matrix
	if nargin < 2
		axis = length(theta):-1:1;
	end
	if length(theta)>1
		assert(length(theta)==length(axis));
		% if multiple angles and axes specified, create a cumulative rotation matrix from applying each rotation in sequence
		rot = eye(3);
		for iA = 1:length(theta)
			rot = rot*c_calculateRotationMatrix(theta(iA),axis(iA));
		end
		return;
	end

	switch(axis)
		case 1
			rot = [		1			0			0			  ;
						0		cosd(theta)	-sind(theta)	  ;
						0		sind(theta)	cosd(theta)		]';
		case 2
			rot = [	cosd(theta)		0		sind(theta)		  ;
						0			1			0			  ;
					-sind(theta)	0		cosd(theta)		]';
		case 3
			rot = [	cosd(theta)	-sind(theta)	0			  ;
					sind(theta)	cosd(theta)		0			  ;
						0			0			1			]';
		otherwise
			error('unsupported axis');
	end
end