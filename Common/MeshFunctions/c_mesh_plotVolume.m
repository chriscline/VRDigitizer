function h = c_mesh_plotVolume(varargin)
persistent pathModified;
if isempty(pathModified)
	c_AddIso2MeshToPath();
	pathModified = true;
end

p = inputParser();
p.addRequired('mesh',@c_mesh_isValid);
p.addParameter('nodeData',[],@isnumeric);
p.addParameter('elemData',[],@isnumeric);
p.addParameter('edgeColor','none',@(x) ischar(x) || isvector(x));
p.addParameter('axis',[],@ishandle);
p.addParameter('slices',{'y=0'},@iscell); % one or more 'cutat' values defining slice location/orientation (see qmeshcut for details)
p.addParameter('doPlotInvisibleNormal',true,@islogical); % when plotting a single slice on its own, this prevents the slice axis from rescaling strangely
p.addParameter('doSetViewNormalToSlice','auto',@islogical);
p.parse(varargin{:});
s = p.Results;

if isempty(s.axis)
	s.axis = gca;
end

if strcmpi(s.doSetViewNormalToSlice,'auto')
	s.doSetViewNormalToSlice = length(s.slices)==1;
end

h = gobjects();

prevHold = ishold(s.axis);
hold(s.axis,'on');

assert(size(s.mesh.Elements,2)==4); % only tetrahedral volume elements supported

assert(isempty(s.nodeData) || isempty(s.elemData)); % should not specify both

%assert(~isempty(s.nodeData) || ~isempty(s.elemData)); % should specify at least one
if isempty(s.nodeData) && isempty(s.elemData)
	s.nodeData = zeros(size(s.mesh.Vertices,1),1);
end


numSlices = length(s.slices);
for iS = 1:numSlices
	if ~isempty(s.nodeData)
		% 1 value per node
		[cutpos, cutvalue, cutfaces] = qmeshcut(s.mesh.Elements, s.mesh.Vertices, s.nodeData,s.slices{iS});
		h(end+1) = patch('Vertices',cutpos,'Faces',cutfaces,'FaceVertexCData',cutvalue,'FaceColor','interp','EdgeColor',s.edgeColor);
	else
		% 1 value per face
		[cutpos, cutvalue, cutfaces] = qmeshcut(s.mesh.Elements, s.mesh.Vertices, s.elemData,s.slices{iS});
		h(end+1) = patch('Vertices',cutpos,'Faces',cutfaces,'FaceVertexCData',cutvalue,'FaceColor','flat','EdgeColor',s.edgeColor);
	end
end

if ~isempty(s.slices) && (s.doPlotInvisibleNormal || s.doSetViewNormalToSlice)
% 	c_say('Calculating distances between points for normal calculations');
	ptIndices = [];
	pts = [];
	[~,ptIndices(1)] = max(c_norm(bsxfun(@minus,cutpos,cutpos(1,:)),2,2),[],1);
	pts(1,:) = cutpos(ptIndices(1),:);
	distsToPt1 = c_norm(bsxfun(@minus,cutpos,pts(1,:)),2,2);
	[~,ptIndices(2)] = max(distsToPt1,[],1);
	pts(2,:) = cutpos(ptIndices(2),:);
	[~,ptIndices(3)] = max(c_norm(bsxfun(@minus,cutpos,pts(2,:)),2,2) + distsToPt1,[],1);
	pts(3,:) = cutpos(ptIndices(3),:);
	exampleVectors = bsxfun(@minus,pts(1:2,:),pts(3,:));
	normalVec = cross(exampleVectors(1,:),exampleVectors(2,:));
	normalVec = normalVec / norm(normalVec) * distsToPt1(ptIndices(2),:)/2;
% 	c_sayDone();
	
	if s.doPlotInvisibleNormal
% 		c_say('Plotting invisible normal');
		scatter3(normalVec(1),normalVec(2),normalVec(3),'MarkerEdgeColor','none'); % arbitrary point to give more finite thickness to slice plot
% 		c_sayDone();
	end
	
	if s.doSetViewNormalToSlice
% 		c_say('Setting view normal to slice');
		view(normalVec);
% 		c_sayDone();
	end
end

if ~prevHold
% 	c_say('Disabling hold');
	hold(s.axis,'off');
% 	c_sayDone();
end

axis(s.axis,'equal')
axis(s.axis,'off')

end