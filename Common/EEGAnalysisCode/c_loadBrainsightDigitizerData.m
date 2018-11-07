function [chanlocs, raw] = c_loadBrainsightDigitizerData(varargin)

p = inputParser();
p.addRequired('filePath',@ischar);
p.addParameter('doPlot',false,@islogical);
p.addParameter('doConvertChanlocs',true,@islogical);
p.parse(varargin{:});

fp = p.Results.filePath;
if ~strcmp(fp((end-3):end),'.elp')
	fp = [fp '.elp'];
end
raw.electrodes = c_loadBrainsightElectrodes(fp);

hspPath = [fp(1:end-4) '.hsp'];
if exist(hspPath,'file')
	raw.shape = c_loadBrainsightShape(hspPath);
else
	c_saySingle('No head shape file found (not at %s)',hspPath);
	raw.shape = [];
end

indicesToDelete = [];

for i=1:length(raw.electrodes.electrodes)
	newE = raw.electrodes.electrodes(i);
	if isfield(newE,'number')
		newE = rmfield(newE,'number');
	end
	newE.type = '';
	for j='XYZ'
		newE.(j) = newE.(j)*1e3; % convert from m to mm
	end
	tmp = strsplit(newE.label,{'_',' '});
	if isempty(tmp) || length(tmp)==1
		% do not change newE.labels
		newE.urchan = i; 
	else
		if strcmp(tmp{2}(1:2),'(n') % format example: Fp1_(n1) -> label=Fp1, urchan=1
			newE.label = tmp{1};
			newE.urchan = str2num(tmp{2}(3:(end-1)));
		else
			if strcmp(tmp{2},'(FCz)') || ...
					strcmp(tmp{2},'(AFz)') || ...
					strcmp(newE.label,'Tip_of_nose') || ...
					strcmp(newE.label,'Tip_of_nose_2')
				indicesToDelete = [indicesToDelete, i];
				newE.urchan = 0;	
			else
				error('Unrecognized channel label format: %s',newE.label);
			end
		end
	end
	raw.electrodes.electrodes(i).number = newE.urchan;
	raw.electrodes.electrodes(i).label = newE.label;
	chanlocs(i) = newE;
end

raw.deletechanlocs = chanlocs(indicesToDelete);
chanlocs(indicesToDelete) = [];

if p.Results.doConvertChanlocs
	% use EEGLab to add other coordinate system values
	chanlocs = convertlocs(chanlocs,'cart2all');
end

if p.Results.doPlot
	X = cell2mat({chanlocs.X})';
	Y = cell2mat({chanlocs.Y})';
	Z = cell2mat({chanlocs.Z})';
	names = {chanlocs.label};
	plotchans3d([X,Y,Z],names)
end

end

function res = c_loadBrainsightElectrodes(varargin)
	p = inputParser();
	p.addRequired('filePath',@ischar);
	p.parse(varargin{:});

	fp = p.Results.filePath;

	if ~strcmp(fp((end-3):end),'.elp')
		error('File should have .elp extension');
	end

	if ~exist(fp,'file')
		error('File does not exist at %s',fp);
	end

	f = fopen(fp,'r');
	if f==-1
		error('Could not open file at %s', fp);
	end

	% first line should be version
	str = fgets(f);
	[vers, count] = sscanf(str,'%d %d');
	if length(vers)~=2 || vers(1)~=3 || vers(2) ~= 2
		error('Unexpected major version %s',str);
	end

	% next should be minor version
	seekPastAnyComments(f);
	str = fgets(f);
	[vers, count] = sscanf(str,'%d');
	if length(vers)~=1 || vers(1)~=1
		error('Unexpected minor version %s',str);
	end

	% subject name (optional)
	pos = ftell(f);
	seekPastAnyComments(f);
	str = fgets(f);
	[res.name, count] = sscanf(str,'%%N %s');
	if count == 0
		% no name present, rewind
		fseek(f,pos,'bof');
	end

	% electrode type, number of sensors
	seekPastAnyComments(f);
	str = fgets(f);
	[tmp, count] = sscanf(str,'%d %d');
	if count ~= 2 || tmp(1) ~= 1
		error('Unexpected electrode type,number: %s',str);
	end
	res.number = tmp(2);

	% fiducials
	seekPastAnyComments(f);
	fiducialLabels = {'X+','Y+','Y-'};
	for i=1:length(fiducialLabels)
		%TODO
		fiducial = struct();
		str = fgets(f);
		[tmp, count] = sscanf(str,'%%F %f %f %f');
		if count ~= 3
			error('Problem with parsing fiducial positoins');
		end
		fiducial.label = fiducialLabels{i};
		fiducial.X = tmp(1);
		fiducial.Y = tmp(2);
		fiducial.Z = tmp(3);
		res.fiducials(i) = fiducial;
	end
	
	% electrodes
	for i=1:res.number
		e = struct();

		% sensor type
		seekPastAnyComments(f);
		str = fgets(f);
		[tmp, count] = sscanf(str,'%%S %d');
		if count ~= 1 || tmp ~= 400
			error('Unexpected sensor type: %s',str);
		end

		% sensor name
		seekPastAnyComments(f);
		str = fgets(f);
		if 1
			assert(~isempty(regexp(str,'^%N\t')))
			assert(strcmp(str(end),sprintf('\n')));
			e.label = str(4:end-1);
		else
			[tmp, count] = sscanf(str,'%%N %s %s');
			if count ~= 1
				error('Unexpected sensor name: %s',str);
			end
			e.label = tmp;
		end
		
		% sensor position
		str = fgets(f);
		[tmp, count] = sscanf(str,'%f %f %f');
		if count ~= 3
			[tmp, count] = sscanf(str,'%%F %f %f %f'); % alternate position format from older files
			if count ~= 3
				error('Unexpected sensor position: %s',str);
			end
		end
		e.X = tmp(1);
		e.Y = tmp(2);
		e.Z = tmp(3);

		res.electrodes(i) = e;
	end
end

function res = c_loadBrainsightShape(varargin)
	p = inputParser();
	p.addRequired('filePath',@ischar);
	p.parse(varargin{:});

	fp = p.Results.filePath;

	if ~strcmp(fp((end-3):end),'.hsp')
		error('File should have .hsp extension');
	end

	if ~exist(fp,'file')
		error('File does not exist at %s',fp);
	end

	f = fopen(fp,'r');
	if f==-1
		error('Could not open file at %s', fp);
	end

	% first line should be version
	str = fgets(f);
	[vers, count] = sscanf(str,'%d %d');
	if length(vers)~=2 || vers(1)~=3 || vers(2) ~= 200
		error('Unexpected major version %s',str);
	end

	% next should be minor version
	seekPastAnyComments(f);
	str = fgets(f);
	[vers, count] = sscanf(str,'%d');
	if length(vers)~=1 || vers(1)~=2
		error('Unexpected minor version %s',str);
	end

	% subject name (optional)
	pos = ftell(f);
	seekPastAnyComments(f);
	str = fgets(f);
	[res.name, count] = sscanf(str,'%%N %s');
	if count == 0
		% no name present, rewind
		fseek(f,pos,'bof');
	end
	
	% shape code and number of points
	seekPastAnyComments(f);
	str = fgets(f);
	[tmp, count] = sscanf(str,'%d %d');
	if count ~= 2 || tmp(1) ~= 1
		error('Unexpected shape code: %s', str);
	end
	res.number = tmp(2);
	
	% fiducials
	seekPastAnyComments(f);
	fiducialLabels = {'X+','Y+','Y-'};
	for i=1:length(fiducialLabels)
		fiducial = struct();
		str = fgets(f);
		[tmp, count] = sscanf(str,'%%F %f %f %f');
		if count ~= 3
			error('Problem with parsing fiducial positoins');
		end
		fiducial.label = fiducialLabels{i};
		fiducial.X = tmp(1);
		fiducial.Y = tmp(2);
		fiducial.Z = tmp(3);
		res.fiducials(i) = fiducial;
	end

	% skip one line (a comment without comment prefix)
	str = fgets(f);
	
	% number of points, number of columns
	str = fgets(f);
	[tmp, count] = sscanf(str,'%d %d');
	if count ~= 2 || tmp(1) ~= res.number || tmp(2) ~= 3
		error('Problem with number of points, number of columns: %s',str);
	end
	
	% point coordinates
	for i=1:res.number
		pt = struct();
		
		str = fgets(f);
		[tmp, count] = sscanf(str,'%f %f %f');
		if count ~= 3
			error('Problem with line: %s',str);
		end
		
		pt.X = tmp(1);
		pt.Y = tmp(2);
		pt.Z = tmp(3);
		
		res.points(i) = pt;
	end
end

function varargout = seekPastAnyComments(f)
	comments = '';
	while true
		pos = ftell(f);
		str = fgets(f);
		if strcmp(str(1:2),'//')
			comments = [comments str];
		else
			fseek(f,pos,'bof');
			break;
		end
	end
	if nargout > 0
		varargout{1} = comments;
	end
end

