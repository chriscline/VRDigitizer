function unreferencedNodeIndices = c_mesh_getUnreferencedNodeIndices(varargin)
% c_mesh_getUnreferencedNodeIndices - return indices of nodes not in any elements/faces of the mesh

p = inputParser();
p.addRequired('mesh',@c_mesh_isValid);
p.parse(varargin{:});
s = p.Results;

unreferencedNodeIndices = true(1,size(s.mesh.Vertices,1));

if c_isFieldAndNonEmpty(s.mesh,'Faces')
	unreferencedNodeIndices(s.mesh.Faces(:)) = false;
end

if c_isFieldAndNonEmpty(s.mesh,'Elements')
	unreferencedNodeIndices(s.mesh.Elements(:)) = false;
end

end