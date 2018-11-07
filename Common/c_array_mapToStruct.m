function mappedStruct = c_array_mapToStruct(arrayToMap,fieldMap,initStruct)
% c_array_mapToStruct - convert an array of values to fields within a struct (or struct array)
%
% Examples:
%	a = [1 2 3];
%	a_struct = c_array_mapToStruct(a,{'X','Y','Z'})
%	b = [1 2 3; 4 5 6];
%	b_struct = c_array_mapToStruct(b,{'X','Y','Z'})
%
% See also: c_struct_mapToArray

if nargin == 0, testfn(); return; end;
assert(iscell(fieldMap));
extraDim = c_findFirstSingletonDimension(fieldMap);
nonExtraDims = 1:max(ndims(fieldMap),extraDim); nonExtraDims(extraDim) = [];
assert(all(paren(size(arrayToMap),nonExtraDims)==paren(size(fieldMap),nonExtraDims)));
assert(ndims(arrayToMap)<=8); % if higher dimensional, need to add more colons below...

tmp=arrayToMap;
if size(arrayToMap,extraDim)~=1
	% output will be array of structs, unless a single initStruct is included
	
	assert(...
		(ndims(arrayToMap)==(ndims(fieldMap)+1) && extraDim>ndims(fieldMap)) || ...
		(ndims(arrayToMap)==ndims(fieldMap) && extraDim<=ndims(fieldMap))); % currently don't support mapping of higher dimensional arrays
	
	% rearrange so that extraDim is first dimension
	arrayToMap = permute(arrayToMap,[extraDim, nonExtraDims]);
		
	if nargin >= 3 && length(initStruct)==1
		% if a single input struct is specified, assume we want to map extraDims to fields within that struct 
		% (e.g. single struct with vector fields) rather than mapping extraDims to multiple structs in an array
		% (e.g. vector structs with scalar fields)
		assert(isvector(fieldMap)) % for now, only support vector of fields
		mappedStruct = initStruct;
		for j=1:length(fieldMap)
			mappedStruct.(fieldMap{j}) = arrayToMap(:,j);
		end
	else
		for i=1:size(arrayToMap,extraDim)
			subarray = arrayToMap(i,:,:,:,:,:,:,:,:);

			if nargin < 3
				mappedSubstruct = c_array_mapToStruct(subarray,fieldMap);
			else
				mappedSubstruct = c_array_mapToStruct(subarray,fieldMap,initStruct(i));
			end
			if i==1
				mappedStruct = mappedSubstruct;
			else
				mappedStruct(i) = mappedSubstruct;
			end
		end
	end
	
	return;
end

if nargin < 3
	mappedStruct = struct();
else
	mappedStruct = initStruct;
end

numVars = numel(arrayToMap);
arrayToMap = reshape(arrayToMap,1,numVars);
fieldMap = reshape(fieldMap,1,numVars);


for i=1:numVars
	mappedStruct.(fieldMap{i}) = arrayToMap(i);
end
end

function testfn()

%% very simple
s = struct('Loc_X',1,'Loc_Y',2);
intermed = c_struct_mapToArray(s,{'Loc_X'});
expectedRes = rmfield(s,'Loc_Y');
res = c_array_mapToStruct(intermed,{'Loc_X'});
assert(isequal(res,expectedRes));

%% simple
s = struct('Loc_X',1,'Loc_Y',2,'Loc_Z',3);
intermed = c_struct_mapToArray(s,{'Loc_X','Loc_Y','Loc_Z'});
res = c_array_mapToStruct(intermed,{'Loc_X','Loc_Y','Loc_Z'});
expectedRes = s;
assert(isequal(res,expectedRes));

%% struct array of scalar values 
s1 = struct('Loc_X',1,'Loc_Y',2,'Loc_Z',3);
s2 = struct('Loc_X',4,'Loc_Y',5,'Loc_Z',6);
s = [s1, s2];
intermed = c_struct_mapToArray(s,{'Loc_X','Loc_Y','Loc_Z'});
res = c_array_mapToStruct(intermed,{'Loc_X','Loc_Y','Loc_Z'});
expectedRes = s;
assert(isequal(res,expectedRes));

%% struct array of vector values
% s1 = struct('Loc_X',[1 1],'Loc_Y',[2 2],'Loc_Z',[3 3]);
% s2 = struct('Loc_X',[4 4],'Loc_Y',[5 5],'Loc_Z',[6 6]);
% s = [s1, s2];
% intermed = c_struct_mapToArray(s,{'Loc_X';'Loc_Y';'Loc_Z'});
% res = c_array_mapToStruct(intermed,{'Loc_X';'Loc_Y';'Loc_Z'});
% expectedRes = s;
% assert(isequal(res,expectedRes));

% s1 = struct('Loc_X',[1 1]','Loc_Y',[2 2]','Loc_Z',[3 3]');
% s2 = struct('Loc_X',[4 4]','Loc_Y',[5 5]','Loc_Z',[6 6]');
% s = [s1, s2];
% intermed = c_struct_mapToArray(s,{'Loc_X','Loc_Y','Loc_Z'});
% res = c_array_mapToStruct(intermed,{'Loc_X','Loc_Y','Loc_Z'});
% expectedRes = s;
% assert(isequal(res,expectedRes));

%%
c_saySingle('Tests passed');





end