function raw = c_digitizer_loadPolhemus(filepath)
	assert(exist(filepath,'file')>0);
	
	doConvertFromCmToM = true;
	
	f = fopen(filepath,'r');
	if f==-1
		error('Could not open file at %s',filepath);
	end
	
	% first line should be number of channels
	str = fgets_errOnEnd(f);
	[numCh, count] = sscanf(str,'%d');
	if count ~= 1, error('Issues reading number of channels'); end;
	
	% next numCh lines should be electrode labels and locations, with columns tab-delimited
	electrodes = struct();
	for iN = 1:numCh
		line = struct();
		
		str = fgets_errOnEnd(f);
		str = strsplit(str);
		if ~isempty(str) && isempty(str{end})
			% prune trailing empty token
			str = str(1:end-1);
		end
		if ~ismember(length(str),[4,5])
			error('Unexpected number of columns in line');
		end
		
		tokenIndex = 1;
		if length(str)==5
			% sample num included
			[line.sampleNum, count] = sscanf(str{tokenIndex},'%d');
			if count ~= 1, error('Issues reading sample num'); end;
			tokenIndex = tokenIndex + 1;
		end
		
		line.label = str{tokenIndex};
		tokenIndex = tokenIndex + 1;
		
		for iDim = 1:3
			[xyz(iDim), count] = sscanf(str{iDim+tokenIndex-1},'%f');
			if count ~= 1, error('Issues reading coord'); end;
		end
		
		if doConvertFromCmToM
			xyz = xyz/1e2; % convert from cm to m
		end
		
		line = c_array_mapToStruct(xyz,{'X','Y','Z'},line);
		
		if iN == 1
			electrodes = line;
		else
			electrodes(iN) = line;
		end
	end
	raw.electrodes.electrodes = electrodes;
	
	% remaining lines that begin with sampleNum should be head points, and points that begin with strings should be fiducials
	fiducials = struct();
	points = struct();
	numShapePoints = 0;
	numFiducials = 0;
	while true
		str = fgets(f);
		if str == -1 
			% reached end of file
			break;
		end
		str = strsplit(str,'\t');
		if length(str) ~= 4
			error('Unexpected number of columns in line');
		end
		
		[sampleNum, count] = sscanf(str{1},'%d');
		if count ~= 1
			% assume this line starts with a string instead, and thus describes a fiducial
			pt = struct('label',str{1});
			isFiducial = true;
		else
			pt = struct('sampleNum',sampleNum);
			isFiducial = false;
		end
		
		for iDim = 1:3
			[xyz(iDim), count] = sscanf(str{iDim+1},'%f');
			if count ~= 1, error('Issues reading coord'); end;
		end
		
		if doConvertFromCmToM
			xyz = xyz/1e2; % convert from cm to m
		end
		
		pt = c_array_mapToStruct(xyz,{'X','Y','Z'},pt);
		
		if isFiducial
			numFiducials = numFiducials+1;
			if numFiducials==1
				fiducials = pt;
			else
				fiducials(numFiducials) = pt;
			end
		else
			numShapePoints = numShapePoints+1;
			if numShapePoints==1
				points = pt;
			else
				points(numShapePoints) = pt;
			end
		end
	end
	raw.shape.points = points;
	
	% since some formats have fiducials copied in two separate files for electrodes and shape, copy here as well
	raw.electrodes.fiducials = fiducials;
	raw.shape.fiducials = fiducials;
	
	fclose(f);
end

function str = fgets_errOnEnd(f)
	str = fgets(f);
	if str == -1
		error('Reached end of file early');
	end
end