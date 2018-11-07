function pts = c_pts_applyTransform(varargin)
% originally based on https://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h

p = inputParser();
p.addRequired('pts',@(x) isnumeric(x) && ismatrix(x) && size(x,2)==3);
p.addParameter('quaternion',[],@(x) ismatrix(x) && isequal(size(x),[4 4]));
p.parse(varargin{:});
s = p.Results;

assert(~isempty(s.quaternion)); %TODO: add support for other transform inputs (e.g. rotation matrix)

if ~isempty(s.quaternion)
	if all(isnan(s.quaternion(:)))
		pts = nan(size(s.pts));
		return;
	end
	assert(isnumeric(s.quaternion));
	assert(all(abs(s.quaternion(4,1:3))<eps*1e2));
	assert(abs(abs(s.quaternion(4,4))-1)<eps*1e4);
end
	
pts = bsxfun(@plus,s.quaternion(1:3,1:3)*bsxfun(@times,s.pts,[1 1 s.quaternion(4,4)]).',s.quaternion(1:3,4)).';
end