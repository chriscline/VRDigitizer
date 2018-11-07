function raw = c_digitizer_load3DD(varargin)
if nargin==0, testfn(); return; end;
p = inputParser;
p.addRequired('inputPath',@ischar);
p.addParameter('doConvertFromCmToM',true,@islogical);
p.parse(varargin{:});
s = p.Results;

landmarkLabels = {'Nasion','Left','Right'};
unusedPointLabels = {'Centroid'};

startLabel = landmarkLabels{1};
markerLabelWidth = 10;
markerTypeWidth = 2;
numberWidth = 4; % in single float format (4 bytes)
lineWidth = markerLabelWidth + markerTypeWidth + 3*numberWidth;

% marker types
fiducialTypes = [78, 76, 82];
electrodeTypes = [69,88];
shapeTypes = [32];
discardTypes = [67];

fid = fopen(s.inputPath);

% read entire file into string (could be rewritten to avoid loading
% everything into memory)
str = fread(fid);
str = char(str)';

% close file, since it's all loaded into str
fclose(fid);

expectedHeader = [164 134 1 0 0 0 0 0 205 204 76 63]; 
% similar, but not exactly the same as, header referenced in https://github.com/fieldtrip/fieldtrip/blob/a0ef7427e75931d5a432a5ac79689441ec77c7b7/external/biosig/private/getfiletype.m

header = uint8(str(1:length(expectedHeader)));

if ~isequal(expectedHeader,header)
	warning('Header does not match expected header. This may or may not matter.');
end

% read to start of coordinates (skipping over half the file, in general)
startIndex = strfind(str,startLabel);

if isempty(startIndex)
	error('Start label (%s) not found in file',startLabel);
end

numberOfLines = floor((length(str)-startIndex+1)/lineWidth);

electrodes = struct('label',{},'typeCode',{},'X',{},'Y',{},'Z',{});
fiducials = struct('label',{},'typeCode',{},'X',{},'Y',{},'Z',{});
shapePoints = struct('typeCode',{},'X',{},'Y',{},'Z',{});
for i=1:numberOfLines
	line = str(startIndex + (i-1)*lineWidth + (1:lineWidth) - 1);
	
	j = 0; % index within line
	
	label = readBinaryValue(line(j+(1:markerLabelWidth)),'str');
	j = j+markerLabelWidth;
	
	markerType = readBinaryValue(line(j+(1:markerTypeWidth)),'uint16');
	j = j+markerTypeWidth;
	
	coords = nan(1,3,'single');
	for k=1:3
		coords(k) = readBinaryValue(line(j+(1:numberWidth)),'single');
		j=j+numberWidth;
	end
	
	if s.doConvertFromCmToM
		coords = double(coords)/1e2; % convert from cm to m
	end
	
	marker = struct(...
		'label',label,...
		'typeCode',markerType,...
		'X',coords(1),...
		'Y',coords(2),...
		'Z',coords(3));
	
	if any(coords>10)
		warning('coord greater than 10 m, probably indicates an error with reading of binary data file');
	end
	
	if ismember(markerType,fiducialTypes)
		fiducials(end+1) = marker;
	elseif ismember(markerType,electrodeTypes)
		electrodes(end+1) = marker;
	elseif ismember(markerType,shapeTypes)
		marker = rmfield(marker,'label');
		shapePoints(end+1) = marker;
	elseif ismember(markerType,discardTypes)
		% do nothing
	else
		error('Unrecognized marker type');
	end
end

if length(fiducials) ~= 3
	warning('Unexpected number of fiducials (%d)',length(fiducials));
end

raw.electrodes.electrodes = electrodes;
raw.electrodes.fiducials = fiducials;
raw.shape.points = shapePoints;
raw.shape.fiducials = fiducials;

end

function val = readBinaryValue(charArray,finalType)
	numBytes = length(charArray);
	
	if strcmpi(finalType,'str')
		val = deblank(charArray(1:numBytes));
	else
		val = uint8(charArray(1:numBytes));
		val = typecast(val,finalType);
		%val = swapbytes(val);
	end
		
end