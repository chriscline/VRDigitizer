function raw = c_digitizer_loadTxt(filepath)
	assert(exist(filepath,'file')>0);
	
	%try 
		raw = c_digitizer_loadTxt_Brainsight(filepath);
% 	catch E
% 		% file was not in Brainsight format
% 		%TODO: add other .txt file parsers
% 		warning('Could not parse file');
% 		rethrow(E);
% 	end
end

function raw = c_digitizer_loadTxt_Brainsight(filepath)
	% .txt file in Brainsight format
	
	inputUnits = 'mm';
	outputUnits = 'm';
	
	f = fopen(filepath,'r');
	if f==-1
		error('Could not open file at %s',filepath);
	end
	
	r = struct();
	
	% first line should be version
	str = fgets_errOnEnd(f);
	[r.version, count] = sscanf(str,'# Version: %d');
	if count ~= 1, error('invalid read'); end;
	if r.version ~= 5 && r.version ~= 7
		error('Only version 5 and 7 of Brainsight files currently supported, not %d',r.version);
	end

	% second line should be coordinate system
	str = fgets_errOnEnd(f);
	[r.coordinateSystem, count] = sscanf(str,'# Coordinate system: %s');
	if count ~= 1, error('invalid read'); end;

	% header continues until next-to-last sequential line beginning with "#"
	str = '';
	r.headerStr = '';
	pos = ftell(f);
	while true
		prevStr = str;
		prevPos = pos;
		pos = ftell(f);
		str = fgets(f);
		if strcmp(str(1),'#')
			r.headerStr = [r.headerStr prevStr];
		else
			fseek(f,prevPos,'bof');
			break;
		end
	end

	% parse electrodes and head points
	r.electrodes = parseRowColumnSection(f,'# Electrode');
	
	% parse planned landmarks (if available)
	r.plannedLandmarks = parseRowColumnSection(f,'# Planned');
	
	% parse session (actual) landmarks (if available)
	r.sessionLandmarks = parseRowColumnSection(f,'# Session');
	
	fclose(f);
	
	% "high-level" parsing (e.g. converting strings of numbers to numbers)

	fieldsToConvertIfPresent = {'electrodes'};
	for i = 1:length(fieldsToConvertIfPresent)
		if ~isfield(r,fieldsToConvertIfPresent{i})
			continue;
		end
		if ~isempty(r.(fieldsToConvertIfPresent{i}))
			r.(fieldsToConvertIfPresent{i}) = convertFields(r.(fieldsToConvertIfPresent{i}));
		end
	end
	
	% store info in expected 'raw' struct format
	raw = struct();
	fieldMapFrom = {'Electrode_Name','Electrode_Type','Loc_X','Loc_Y','Loc_Z'};
	fieldMapTo   = {'label',			'type',			'X',	'Y',	'Z'	};
	args = cell(1,length(fieldMapTo)*2);
	args(1:2:end) = fieldMapTo;
	args(2:2:end) = repmat({{}},1,length(fieldMapTo));
	convertedElectrodes = struct(args{:});
	
	for iE = 1:length(r.electrodes)
		for iF = 1:length(fieldMapTo)
			convertedElectrodes(iE).(fieldMapTo{iF}) = r.electrodes(iE).(fieldMapFrom{iF});
		end
	end
	
	raw.electrodes.electrodes = struct(args{:});
	raw.electrodes.fiducials = struct(args{:});
	raw.shape.points = struct(args{:});
	for iE = 1:length(convertedElectrodes)
		switch(convertedElectrodes(iE).type)
			case 'EEG'
				raw.electrodes.electrodes(end+1) = convertedElectrodes(iE);
			case 'Nasion'
				raw.electrodes.fiducials(end+1) = convertedElectrodes(iE);
			case 'RPA'
				raw.electrodes.fiducials(end+1) = convertedElectrodes(iE);
			case 'LPA'
				raw.electrodes.fiducials(end+1) = convertedElectrodes(iE);
			case 'Other-Point'
				raw.shape.points(end+1) = convertedElectrodes(iE);
			otherwise
				error('Unrecognized point type: %s',convertedElectrodes(iE).type);
		end
	end
	
	fieldMapFrom = {'Loc_X','Loc_Y','Loc_Z','Planned_Landmark_Name','Session_Landmark_Name','Session_Name'};
	fieldMapTo = {		'X',	'Y',	'Z',	'label',				'label',				''};
	fiducialFields = {'plannedLandmarks','sessionLandmarks'};
	for iFidF = 1:length(fiducialFields)
		for iFid = 1:length(r.(fiducialFields{iFidF}))
			fiducial = struct();
			for iF = 1:length(fieldMapTo)
				if isempty(fieldMapTo{iF})
					continue; % ignore field
				end
				if ~isfield(r.(fiducialFields{iFidF}),fieldMapFrom{iF})
					continue; % field not present
				end
				fiducial.(fieldMapTo{iF}) = r.(fiducialFields{iFidF}).(fieldMapFrom{iF});
			end
			if strcmpi(fiducialFields{iFidF},'plannedLandmarks')
				if isempty(r.sessionLandmarks)
					% no session landmarks specified, so the planned landmarks are the only ones present
					% (don't change anything)
				else
					% both plannedLandmarks and sesisonLandmarks present. Rename planned landmarks to differentiate
					fiducial.label = ['Planned_' fiducial.label];
				end
			end
			fiducial.type = 'Fiducial';
			raw.electrodes.fiducials(end+1) = fiducial;
		end
	end
	
		
	
	% if present, use numbering contained in custom label strings to reorder to match recorded data order (instead of digitization order)
	renumberedOrder = zeros(1,length(raw.electrodes.electrodes));
	rawLabels = {raw.electrodes.electrodes.label};
	for iE = 1:length(raw.electrodes.electrodes)
		[raw.electrodes.electrodes(iE).label renumberedOrder(iE)] = convertBrainsightCustomLabel(raw.electrodes.electrodes(iE).label);
	end
	if any(isnan(renumberedOrder))
		if ~all(isnan(renumberedOrder))
			warning('Only subset of electrodes have numbers. Ignoring all numbers and using digitization order instead.');
		else
			c_saySingle('No electrode numbers detected. Numbering by digitization order.');
		end
		renumberedOrder = 1:length(renumberedOrder);
	end
			
	[newOrder,indices] = sort(renumberedOrder);
	orderDiff = diff(newOrder);
	if any(orderDiff~=1 & ~isnan(orderDiff)) || orderDiff(1)~=1
		error('Skipped electrode number. Current code assumes electrode numbers start at 1 and increment by 1');
		%TODO: could add code to insert invalid placeholder locations to mark skipped channels
	end
	raw.electrodes.electrodes = raw.electrodes.electrodes(indices);
	
	% remove extraneous fields
	raw.electrodes.fiducials = rmfield(raw.electrodes.fiducials,'type');
	raw.shape.points = rmfield(raw.shape.points,'type');
	raw.shape.points = rmfield(raw.shape.points,'label');
	
	raw.shape.fiducials = raw.electrodes.fiducials;
	
	% convert units
	scalarConverter = c_convertValuesFromUnitToUnit(1,inputUnits,outputUnits);
	if scalarConverter ~= 1
		fields = {'electrodes.electrodes','electrodes.fiducials','shape.fiducials','shape.points'};
		for iF = 1:length(fields)
			if iF == 2
				keyboard
			end
			XYZ = c_struct_mapToArray(c_getField(raw,fields{iF}),{'X','Y','Z'});
			XYZ = XYZ*scalarConverter;
			raw = c_setField(raw,fields{iF},c_array_mapToStruct(XYZ,{'X','Y','Z'},c_getField(raw,fields{iF}))); 
		end
	end
end


function [res] = parseRowColumnSection(f,expectedStart)
	% parse each table-like section of Brainsight data file
	% Returns empty struct if section is only a header.
	if nargin > 1
		% next line should start with expectedStart
		str = fgets(f);
		if ~strcmp(str(1:length(expectedStart)),expectedStart), error('invalid read'); end;
	end

	columnLabels = strsplit(str(3:end-1),sprintf('\t'));
	% modify labels to make valid struct field names
	for i=1:length(columnLabels)
		columnLabels{i} = strrep(columnLabels{i},' ','_'); % convert spaces to underscores
		columnLabels{i} = strrep(columnLabels{i},'-','_'); % convert dashes to underscores
		columnLabels{i} = strrep(columnLabels{i},'.',''); % remove periods
	end

	% until the next comment, each line should have length(columnLabels) columns with data in each
	numRows = 0;
	while true
		prevPos = ftell(f);
		str = fgetl(f);
		if strcmp(str(1),'#')  || (isnumeric(str) && str==-1)
			% reached end of section or EOF
			fseek(f,prevPos,'bof');
			break;
		end
		newRow = struct();
		rowEntries = strsplit(str,sprintf('\t'));
		if length(rowEntries) ~= length(columnLabels), error('invalid read'); end;
		for i=1:length(columnLabels)
			newRow.(columnLabels{i}) = rowEntries{i};
		end
		numRows = numRows+1;
		res(numRows) = newRow;
	end
	
	if numRows==0
		% create empty struct that still has field names extracted from header
		args = {};
		for i=1:length(columnLabels)
			args = [args, columnLabels{i},{{}}];
		end
		res = struct(args{:});
	end
end

function [label, num] = convertBrainsightCustomLabel(label)
	tmp = strsplit(label,' ');
	if isempty(tmp) || length(tmp)==1
		num = NaN; 
	else
		if strcmp(tmp{2}(1:2),'(n') % format example: Fp1_(n1) -> label=Fp1, urchan=1
			label = tmp{1};
			num = str2num(tmp{2}(3:(end-1)));
		else
			if strcmp(tmp{2},'(FCz)') || ...
					strcmp(tmp{2},'(AFz)') || ...
					strcmp(newE.label,'Tip_of_nose') || ...
					strcmp(newE.label,'Tip_of_nose_2')
				num = NaN;
			else
				error('Unrecognized channel label format: %s',label);
			end
		end
	end
end

function [res] = convertFields(res, fieldNames)
	if nargin < 2
		fieldNames = fieldnames(res);
	end
	if ~iscell(fieldNames)
		fieldNames = {fieldNames};
	end
	for j=1:length(fieldNames)
		for i=1:length(res)
			tmp = str2double(res(i).(fieldNames{j}));
			if ~isnan(tmp)
				% conversion was successful
				res(i).(fieldNames{j}) = tmp;
				continue;
			end
			if strcmp(res(i).(fieldNames{j})(end),';') % matrix ending in delimiter
			[tmp, matches] = strsplit(res(i).(fieldNames{j})(1:end-1),';');
				if ~isempty(matches)
					tmp2 = str2double(tmp);
					if all(~isnan(tmp2))
						% conversion was successful
						res(i).(fieldNames{j}) = tmp2;
						continue;
					end
				end
			end
			if strcmpi(fieldNames{j},'Date')
				[tmp, status] = sscanf(res(i).(fieldNames{j}), '%d-%d-%d'); % date format
				if status==3
					% conversion was successful
					res(i).(fieldNames{j}) = tmp;
					continue;
				end
			end
			if strcmpi(fieldNames{j},'Time')
				[tmp, status] = sscanf(res(i).(fieldNames{j}), '%d:%d:%d.%d'); % time format
				if status==4
					% conversion was successful
					res(i).(fieldNames{j}) = tmp;
					continue;
				end
			end
			if strcmp(res(i).(fieldNames{j}),'(null)')
				res(i).(fieldNames{j}) = '';
			end
			% else leave unchanged (as a string)
		end
	end
end

function str = fgets_errOnEnd(f)
	str = fgets(f);
	if str == -1
		error('Reached end of file early');
	end
end