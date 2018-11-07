function dim = c_findFirstNonsingletonDimension(x)
	if isempty(x)
		dim = 0;
		return
	end

	sx = size(x);
	for i=1:length(sx)
		if sx(i)~=1
			dim = i;
			return
		end
	end
	dim = ndims(x)+1;
end