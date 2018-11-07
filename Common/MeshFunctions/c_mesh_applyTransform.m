function mesh = c_mesh_applyTransform(varargin)
% c_mesh_applyTransform - apply a spatial transformation to a mesh

p = inputParser();
p.addRequired('mesh',@isstruct);
p.addParameter('quaternion',[],@ismatrix);
p.parse(varargin{:});
s = p.Results;

mesh = s.mesh;

mesh.Vertices = c_pts_applyTransform(mesh.Vertices,'quaternion',s.quaternion);

%TODO: also update face orientations if present, etc.

end