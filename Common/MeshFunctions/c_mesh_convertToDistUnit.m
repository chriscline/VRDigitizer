function mesh = c_mesh_convertToDistUnit(varargin)
% c_mesh_convertToDistUnit - convert distance units of a mesh

p = inputParser();
p.addRequired('mesh',@(x) c_mesh_isValid(x,'doAllowMultiple',true));
p.addRequired('toUnit',@(x) isscalar(x) || ischar(x));
p.addParameter('fromUnit',[],@(x) isscalar(x) || ischar(x));
p.parse(varargin{:});
s = p.Results;
mesh = s.mesh;

if iscell(s.mesh)
	% handle multiple meshes
	for iM = 1:length(s.mesh)
		mesh{iM} = c_mesh_convertToDistUnit(mesh{iM},varargin{2:end});
		% note this may cause some unexpected behavior if fromUnits are not specified and the
		% autounit estimation function chooses different units for different submeshes
	end
	return;
end

if isempty(s.fromUnit) 
	if ~c_isFieldAndNonEmpty(mesh,'distUnit')
		%warning('No starting dist unit specified');
		s.fromUnit = calculateMeshDistUnit(mesh);
		c_saySingle('Guessed mesh dist unit to be %s',c_toString(s.fromUnit));
	else
		s.fromUnit = mesh.distUnit;
	end
end

scaleFactor = c_convertValuesFromUnitToUnit(1,s.fromUnit,s.toUnit);

if scaleFactor == 1
	%do nothing
	return;
end

mesh.Vertices = mesh.Vertices*scaleFactor;

if isfield(mesh,'SphericalVertices')
	mesh.SphericalVertices = [];
end

if c_isFieldAndNonEmpty(mesh,'VertexAreas')
	mesh.VertexAreas = mesh.VertexAreas*scaleFactor^2;
end

if c_isFieldAndNonEmpty(mesh,'FaceAreas')
	mesh.FaceAreas = mesh.FaceAreas*scaleFactor^2;
end

end

function distUnit = calculateMeshDistUnit(mesh)
	distUnit = c_norm(diff(extrema(mesh.Vertices,[],1),1,2),2);
	% estimate whether in mm, cm, or m
	
	typicalHeadSize = 0.2; % m
	
	if distUnit < 0.5 * typicalHeadSize
		error('Unexpected scale');
	elseif distUnit < 5*typicalHeadSize 
		distUnit = 1; % m
	elseif distUnit < 500*typicalHeadSize
		distUnit = 0.01; % cm
	elseif distUnit < 5000*typicalHeadSize
		distUnit = 0.001; % mm
	else
		error('Unexpected scale');
	end
end