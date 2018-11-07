function allequal = c_allEqual(varargin)
% c_allEqual - similar to isequal() but allows arbitrary number of inputs instead of pairwise
%
% Examples:
%	c_allEqual(true,true,false)
%	c_allEqual(true,true,true)
%	c_allEqual([true,true,false])

	
	if length(varargin)==1
		tmp = true(1,length(varargin{1})-1);
		for i=2:length(varargin{1})
			tmp(i-1) = isequal(varargin{1}(1),varargin{1}(i));
		end
		allequal = all(tmp);
		return;
	end
	
	assert(length(varargin)>1);
	
	tmp = true(1,nargin-1);
	for i=2:nargin
		tmp(i-1) = isequal(varargin{1},varargin{i});
	end
	allequal = all(tmp);
end