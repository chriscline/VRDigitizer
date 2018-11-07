function meshes = c_mesh_load_GMSHBinary(varargin)
if nargin == 0, testfn(); return; end;
p = inputParser();
p.addRequired('inputFilePath',@ischar);
p.addParameter('doDebug',false,@islogical);
p.addParameter('doKeepNodesIdenticalAcrossMeshes',false,@islogical);
p.parse(varargin{:});
s = p.Results;

if ~exist(s.inputFilePath,'file')
	error('File does not exist at %s',s.inputFilePath);
end

mesh = struct();

% based on mesh format described at http://gmsh.info/doc/texinfo/gmsh.html#MSH-binary-file-format

if s.doDebug
	c_say('Initializing file reader');
end
f = c_FileReader(s.inputFilePath,'doCache',false);
if s.doDebug
	c_sayDone();
end

%% read raw mesh info
str = f.fgetl();
assert(strcmp(str,'$MeshFormat'))
sectionHeader = str;

elementData = {};
elementDataLabels = {};

while(true)
	switch(sectionHeader)
		case '$MeshFormat'
			str = f.fgetl(); % version filetype datasize, e.g. 2.2 1 8
			[tmp, count] = sscanf(str,'%d.%d %d %d');
			assert(count==4);
			[versionMajor, versionMinor, fileType, dataSize] = c_mat_deal(tmp);
			assert(versionMajor == 2);
			assert(versionMinor == 2);
			assert(fileType == 1);
			
			switch(dataSize)
				case 8
					floatType = 'double';
				otherwise
					error('unsupported dataSize: %d',dataSize);
			end

			str = f.fgetl();
			if isequal(double(str),[1 0 0 0])
				% ignore extra line, not sure why this shows up
				str = f.fgetl();
			end
			assert(strcmp(str,'$EndMeshFormat'));
		case '$Nodes'
			if s.doDebug
				c_say('Parsing nodes');
			end
			% first line is number of nodes
			str = f.fgetl();
			[tmp, count] = sscanf(str,'%d');
			assert(count==1);
			numNodes = tmp;
			
			% for each node, the first 4 bytes contain the node number, and the next (3*dataSize) bytes contain the three floating point coordinates
			if 0
				prog = c_progress(numNodes,'Parsing node %d/%d',...
					'isDisabled',~s.doDebug,...
					'printEvery',1e4,...
					'waitToPrint',1);
				mesh.nodes = nan(numNodes,3);
				for iN = 1:numNodes
					prog.update(iN);
					nodeNum = f.fread(1,'*uint32');
					nodeCoord = f.fread(3,floatType);
					assert(nodeNum <= numNodes);
					mesh.nodes(nodeNum,:) = nodeCoord;
				end
				prog.stop();
			else
				[nodeNums, nodeCoords] = f.freadBinaryArray({'uint32',{floatType,3}},numNodes);
				mesh.nodes = nan(numNodes,3);
				mesh.nodes(nodeNums,:) = nodeCoords;
			end
			str = f.fgetl_skipBlankLines();
			assert(strcmp(str,'$EndNodes'));
			if s.doDebug
				c_sayDone();
			end
		case '$Elements'
			if s.doDebug
				c_say('Parsing elements');
			end
			% first line is number of elements
			str = f.fgetl();
			[tmp, count] = sscanf(str,'%d');
			assert(count==1);
			numElements = tmp;
			
			elemType = [];
			elems = [];
			elemTags = [];
			maxNumNodesPerElem = 0;
			maxNumTagsPerElement = 0;
			
			prog = c_progress(numElements,'Parsing element %d/%d',...
				'doAssumeUpdateAtEnd',true,...
				'isDisabled',~s.doDebug,...
				'printEvery',1e4,...
				'waitToPrint',5);
			numElementsRead = 0;
			numNodesPerElem = uint32(1);
			
			while numElementsRead < numElements
				% read elem header: a sequence of 3 integers, each 4 bytes, of elemType, numElementsOfType,numTagsPerElement
				startingPos = f.ftell();
				
				[tmp, count] = f.fread(3,'*uint32');
				assert(count==3);
				[elemType, numElementsOfType,numTagsPerElement] = c_mat_deal(tmp);
				
				switch(elemType)
					case 2 % triangles
						numNodesPerElem = uint32(3);
					case 4 % tetrahedra
						numNodesPerElem = uint32(4);
					otherwise
						error('Unsuppported element type: %d',elemType);
				end
				
				if numNodesPerElem > maxNumNodesPerElem
					% resize elems to hold additional node indices
					elems = cat(2,elems,nan(numElements,numNodesPerElem - maxNumNodesPerElem));
					maxNumNodesPerElem = numNodesPerElem;
				end
				
				if numTagsPerElement > maxNumTagsPerElement
					% resize elemTags to hold additional tags
					elemTags = cat(2,elemTags,nan(numElements,numTagsPerElement - maxNumTagsPerElement));
					maxNumTagsPerElement = numTagsPerElement;
				end
				
				assert(numElementsOfType==1); %TODO: will need to modify code below to handle cases where multiple elements share a single header
				
				maxNumElementsToTryRead = numElements - numElementsRead;
				
				if maxNumElementsToTryRead > 1
					numElementsToTryRead = maxNumElementsToTryRead;
					while numElementsToTryRead > 0
						%c_saySingle('Assuming identical headers and trying to read %d elements at a time',numElementsToTryRead);
						f.fseek(startingPos,'bof');
 						try 
							[theseHeaders, theseElemNums, theseElemTags, theseNodeIndices] = f.freadBinaryArray(...
								{{'uint32',3},'uint32',{'uint32',numTagsPerElement},{'uint32',numNodesPerElem}},...
								numElementsToTryRead);
						catch E
							if (strcmp(E.identifier,'FileReader:UnexpectedEOF'))
								% read failed, try reducing numElementsToTryRead
								numElementsToTryRead = floor(numElementsToTryRead/2);
								f.fseek(startingPos,'bof');
								continue;
							else
								rethrow(E);
							end
						end

						% if bulk reading assumption was correct, all headers should be identical
						if any(reshape(diff(theseHeaders(:,1),1,1),1,[])~=0) || ...
								~isequal([elemType, numElementsOfType, numTagsPerElement],theseHeaders(1,:))
							% assumption violated, try reducing numElementsToTryRead
							numElementsToTryRead = floor(numElementsToTryRead/2);
							f.fseek(startingPos,'bof');
							continue;
						end

						elems(theseElemNums,1:numNodesPerElem) = theseNodeIndices;
						elemTags(theseElemNums,1:numTagsPerElement) = theseElemTags;
						numElementsRead = numElementsRead + numElementsToTryRead;
						startingPos = f.ftell();
						
						%c_saySingle('numElementsRead: %d',numElementsRead);
						prog.update(numElementsRead);
						
						numElementsToTryRead = min(floor(numElementsToTryRead/2),numElements - numElementsRead);
					end
					f.fseek(startingPos,'bof');
					continue;
				else
					for iN = numElementsRead+(1:numElementsOfType)
						% first four bytes are element number
						% next numTagsPerElement*4 bytes are tags
						% next numNodesPerElem*4 bytes are node indices
						numNumsToRead = 1 + numTagsPerElement + numNodesPerElem;
						[tmp, count] = f.fread(numNumsToRead,'*uint32');
						assert(count==numNumsToRead);
						thisElemNum = tmp(1);
						assert(thisElemNum <= numElements);
						thisElemTags = tmp(1+(1:numTagsPerElement));
						thisElemIndices = tmp(1+numTagsPerElement+(1:numNodesPerElem));

						elems(thisElemNum,1:numNodesPerElem) = thisElemIndices;
						elemTags(thisElemNum,1:numTagsPerElement) = thisElemTags;
						
						prog.update(double(iN));
					end
					numElementsRead = numElementsRead + numElementsOfType;
				end
			end
			prog.stop();
			
			str = f.fgetl_skipBlankLines();
			assert(strcmp(str,'$EndElements'));
			if s.doDebug
				c_sayDone();
			end
			
		case '$ElementData'
			
			
			tags = readDataTags(f);
			
			if s.doDebug
				c_say('Reading element data: %s',tags.stringTags{1});
			end
			
			% from documentation: "By default the first integer-tag is interpreted as a time step 
			%	index (starting at 0), the second as the number of field components of the data in 
			%	the view (1, 3 or 9), the third as the number of entities (nodes or elements) in the
			%	view, and the fourth as the partition index for the view data (0 for no partition)."
			assert(length(tags.intTags)==4);
			[timeStepIndex, numFieldComponents, numDataElements, partitionIndex] = c_mat_deal(tags.intTags);
			assert(timeStepIndex==0); %TODO: could handle other values too
			assert(ismember(numFieldComponents,[1 3 9]));
			assert(numDataElements==numElements);
			assert(partitionIndex == 0); %TODO: could handle other values (i.e. partitioning) too 
			
			% element data
			thisElementData = nan(numElements,numFieldComponents);
			assert(isequal(floatType,'double')); % assume that both value type is 8 bytes each
			numBytesToRead = (4+8*numFieldComponents)*numElements;
			
			rawData = f.fread(numBytesToRead,'*uint8');
			rawData = reshape(rawData,4+8*numFieldComponents,numElements)';
			
			elementNums = typecast(reshape(rawData(:,1:4)',1,[]),'uint32');
			thisElementData(elementNums,:) = reshape(typecast(reshape(rawData(:,5:end)',1,[]),floatType),...
				numFieldComponents,numElements)';
			
			str = f.fgetl();
			assert(strcmp(str,'$EndElementData'));
			
			elementData{end+1} = thisElementData;
			elementDataLabels{end+1} = tags.stringTags{1};
			
			if s.doDebug
				c_sayDone();
			end
			
		case '$NodeData'
			
			keyboard %TODO 
			
		case -1
			if s.doDebug
				c_saySingle('Reached EOF');
			end
			break;
			
		otherwise
			error('Unrecognized section header: %s',sectionHeader);
	end
	
	sectionHeader = f.fgetl();
end

mesh.elems = elems;
mesh.elemTags = elemTags;
mesh.elemData = elementData;
mesh.elemDataLabels = elementDataLabels;

%% additional processing of imported info
% (conversion of raw gmsh-format mesh into my own Brainstorm-like mesh format)

% split meshes by tag
if s.doDebug
	c_say('Separating meshes by tag');
end
elemTags = mesh.elemTags(:,1); %TODO: look at other columns of tags if relevant
uniqueTags = unique(elemTags);

meshes = {};
meshLabels = {};

for iM = 1:length(uniqueTags)
	tag = uniqueTags(iM);
	m = struct();
	elemIndices = elemTags==tag;
	m.Vertices = mesh.nodes;
	elems = mesh.elems(elemIndices,:);
	elemData = cell(size(mesh.elemData));
	for iD = 1:length(elemData)
		elemData{iD} = mesh.elemData{iD}(elemIndices,:);
	end
	if all(isnan(elems(:,4)))
		% is triangular (surface) mesh
		m.Faces = elems(:,1:3);
		m.FaceData = elemData;
		m.FaceDataLabels = mesh.elemDataLabels;
	elseif all(~isnan(elems(:,4)))
		% is tetrahedral (volume) mesh
		assert(size(elems,2)==4);
		assert(all(~isnan(elems(:,4))));
		m.Elements = elems;
		m.ElementData = elemData;
		m.ElementDataLabels = mesh.elemDataLabels;
	else
		% is two meshes: surface and volume
		surfIndices = isnan(elems(:,4));
		volIndices = ~surfIndices;
		m.Faces = elems(surfIndices,1:3);
		m.Elements = elems(volIndices,:);
		m.FaceData = {};
		m.ElementData = {};
		for iD = 1:length(elemData)
			m.FaceData = elemData{iD}(surfIndices,:);
			m.ElementData = elemData{iD}(volIndices,:);
		end
		m.FaceDataLabels = mesh.elemDataLabels;
		m.ElementDataLabels = mesh.elemDataLabels;
	end
	
	if ~s.doKeepNodesIdenticalAcrossMeshes
		%TODO: prune unused nodes and renumber elements (and node data if needed)
	end
	if isfield(m,'Faces') && isfield(m,'Elements')
		mSurf = m;
		mSurf = rmfield(mSurf,{'Elements','ElementData','ElementDataLabels'});
		mSurf.Label = ['Surf' num2str(tag)];
		meshes{end+1} = mSurf;
		mVol = m;
		mVol = rmfield(mVol,{'Faces','FaceData','FaceDataLabels'});
		mVol.Label = ['Vol' num2str(tag)];
		meshes{end+1} = mVol;
		
	else
		m.Label = num2str(tag); %TODO: find more descriptive string in raw file data
		meshes{end+1} = m;
	end
end
if s.doDebug
	c_sayDone();
end

end

function tags = readDataTags(f)
	% string tags
	str = f.fgetl();
	[tmp, count] = sscanf(str,'%d');
	assert(count==1);
	numStringTags = tmp;
	stringTags = {};
	for iS = 1:numStringTags
		str = f.fgetl();
		assert(str(1)=='"' && str(end)=='"');
		stringTags{iS} = str(2:end-1);
	end

	% real (float) tags
	str = f.fgetl();
	[tmp, count] = sscanf(str,'%d');
	assert(count==1);
	numFloatTags = tmp;
	floatTags = [];
	for iF = 1:numFloatTags
		str = f.fgetl();
		[tmp, count] = sscanf(str,'%f');
		assert(count==1);
		floatTags(iF) = tmp;
	end

	% integer tags
	str = f.fgetl();
	[tmp, count] = sscanf(str,'%d');
	assert(count==1);
	numIntTags = tmp;
	intTags = [];
	for iI = 1:numIntTags
		str = f.fgetl();
		[tmp, count] = sscanf(str,'%d');
		assert(count==1);
		intTags(iI) = tmp;
	end
	
	tags = struct;
	tags.stringTags = stringTags;
	tags.floatTags = floatTags;
	tags.intTags = intTags;
end


%%

function testfn
testPath = 'example.msh';

meshes = c_mesh_load_GMSHBinary(testPath);

surfaceMeshIndices = cellfun(@(x) c_isFieldAndNonEmpty(x,'Faces'), meshes);
surfaceMeshes = meshes(surfaceMeshIndices);

dataFieldToPlot = 'normJ';

figure('name',sprintf('Surface meshes %s',dataFieldToPlot));
h = [];
for iM = 1:length(surfaceMeshes)
	mesh = surfaceMeshes{iM};
	h(end+1) = c_subplot(iM,length(surfaceMeshes));
	dataIndex = find(ismember(dataFieldToPlot,mesh.FaceDataLabels));
	if ~isempty(dataIndex)
		c_mesh_plot(mesh,'faceData',mesh.FaceData{dataIndex});
	else
		c_mesh_plot(mesh);
	end
end
c_plot_linkViews(h);


end