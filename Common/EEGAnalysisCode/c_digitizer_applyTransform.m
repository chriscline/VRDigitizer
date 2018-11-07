function transformedRaw = c_digitizer_applyTransform(raw,transform)
assert(isstruct(raw));

%% dependencies
persistent pathModified;
if isempty(pathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'../MeshFunctions'));
	pathModified = true;
end

%%

if iscell(transform)
	transformedRaw = raw;
	for iT = 1:length(transform)
		transformedRaw = c_digitizer_applyTransform(transformedRaw,transform{iT});
	end
	return;
end

if ischar(transform)
	switch(transform)
		case 'flipY'
			transform = [
				1 0 0 0;
				0 -1 0 0;
				0 0 1 0 ;
				0 0 0 1];
		case 'flipZ'
			transform = [
				1 0 0 0;
				0 1 0 0;
				0 0 -1 0;
				0 0 0 1];
		otherwise
			error('Unsupported transform: %s',transform);
	end
end

fieldsWithXYZToTransform = {'electrodes.electrodes','electrodes.fiducials','shape.points','shape.fiducials'};
for iF = 1:length(fieldsWithXYZToTransform)
	field = fieldsWithXYZToTransform{iF};
	if ~c_isFieldAndNonEmpty(raw,field)
		c_saySingle('Not transforming %s',field);
		continue; % skip 
	end
	xyz = c_struct_mapToArray(c_getField(raw,field),{'X','Y','Z'});
	xyz = c_pts_applyRigidTransformation(xyz,transform);
	raw = c_setField(raw,field,c_array_mapToStruct(xyz,{'X','Y','Z'},c_getField(raw,field)));
end	

transformedRaw = raw;

end