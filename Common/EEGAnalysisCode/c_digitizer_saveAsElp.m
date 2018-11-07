function c_digitizer_saveAsElp(varargin)
if nargin == 0
	%TODO: debug, delete
	keyboard
	raw = createRawFromMontageName(); 
	c_digitizer_saveAsPos(raw,'TemplateMontage.pos')
	return; 
end
p = inputParser();
p.addRequired('raw',@isstruct);
p.addRequired('outputPath',@ischar);
p.addParameter('doCheckBeforeOverwriting',true,@islogical);
p.addParameter('doConvertFromMToCm',false,@islogical);
p.parse(varargin{:});
s = p.Results;
raw = s.raw;

if length(s.outputPath)<5 || ~strcmpi(s.outputPath(end-3:end),'.elp')
	s.outputPath(end+1:end+4) = '.elp';
end


if s.doConvertFromMToCm
	unitScalar = 1e2;
else
	unitScalar = 1;
end


if exist(s.outputPath,'file')
	if s.doCheckBeforeOverwriting && ~c_dialog_verify(sprintf('File already exists at %s. Overwrite?',s.outputPath))
		% do not overwrite
		warning('File already exists at %s. Not overwriting.',s.outputPath);
		return;
	end
	c_saySingle('Overwriting file at %s',s.outputPath);
else
	c_saySingle('Creating new file at %s',s.outputPath);
end

f = fopen(s.outputPath,'w');
if f==-1
	error('Problem opening file for writing');
end

% header
fprintf(f,'3\t2\n');
fprintf(f,'//Electrode file\n');
fprintf(f,'//Minor Revision Number\n1\n');
fprintf(f,'//Subject Name\n');
fprintf(f,'%%N\tTmp\n');
fprintf(f,'//Electrode type, number of sensors\n');

if c_isFieldAndNonEmpty(raw,'electrodes.electrodes')
	numCh = length(raw.electrodes.electrodes);
else
	numCh = 0;
end
fprintf(f,'1\t%d\n',numCh);

% fiducials
fprintf(f,'//Position of fiducials X+, Y+, Y- on the subject\n');
if c_isFieldAndNonEmpty(raw,'electrodes.fiducials')
	numFids = length(raw.electrodes.fiducials); 
	% (ignore raw.shape.fiducials)
	for iF = 1:numFids
		fprintf(f,'%%F\t%.8f\t%.8f\t%.8f\n',...
			raw.electrodes.fiducials(iF).X*unitScalar,...
			raw.electrodes.fiducials(iF).Y*unitScalar,...
			raw.electrodes.fiducials(iF).Z*unitScalar);
	end
else
	% do nothing
	%TODO: verify correct way to encode no fiducials in file format
end

% electrodes
for iN = 1:numCh
	if c_isFieldAndNonEmpty(raw.electrodes.electrodes(iN),'number')
		eNum = raw.electrodes.electrodes(iN).number;
	else
		eNum = iN;
	end
	
	if isempty(raw.electrodes.electrodes(iN).label)
		warning('Label for electrode %d is empty. Labeling with number instead.')
		raw.electrodes.electrodes(iN).label = sprintf('Ch%d',eNum);
	end
	
	fprintf(f,'//Sensor type\n');
	fprintf(f,'%%S\t400\n');
	fprintf(f,'//Sensor name and data for sensor #%d\n',eNum);
	fprintf(f,'%%N\t%s\n',raw.electrodes.electrodes(iN).label);
	fprintf(f,'%.8f\t%.8f\t%.8f\n',...
		raw.electrodes.electrodes(iN).X*unitScalar,...
		raw.electrodes.electrodes(iN).Y*unitScalar,...
		raw.electrodes.electrodes(iN).Z*unitScalar);
	
end

% head points
if c_isFieldAndNonEmpty(raw,'shape.points') 
	warning('Head points not supported in ELP file. Ignoring.'); %TODO: optionally also export head points in .hsp file
end

% following lines should be fiducials
if c_isFieldAndNonEmpty(raw,'electrodes.fiducials')
	numFids = length(raw.electrodes.fiducials); 
	% (ignore raw.shape.fiducials)
	for iF = 1:numFids
		fprintf(f,'%s\t%.8f\t%.8f\t%.8f\n',...
			raw.electrodes.fiducials(iF).label,...
			raw.electrodes.fiducials(iF).X*unitScalar,...
			raw.electrodes.fiducials(iF).Y*unitScalar,...
			raw.electrodes.fiducials(iF).Z*unitScalar);
	end
end

fclose(f);

end


function raw = createRawFromMontageName()
	montageStr = 'BrainProductsMR128';
	EEG = struct();
	EEG.nbchan = 127;
	EEG.chanlocs = struct('labels',{},'sph_theta_besa',{},'sph_phi_besa',{},'type',{},'X',{},'Y',{},'Z',{});
	EEG = c_EEG_setChannelLocationsFromMontage(EEG,montageStr);
	EEG = c_EEG_setChannelLabelsFromMontage(EEG,montageStr);
	raw = convertChanlocsToRaw(EEG.chanlocs);
end


function raw = convertChanlocsToRaw(chanlocs)
raw = struct();
raw.electrodes = struct();
raw.electrodes.electrodes = struct(...
	'label',{},...
	'X',{},....
	'Y',{},....
	'Z',{});

unitScaleFactor = 10; % correct factor to get correct units 

for iE = 1:length(chanlocs)
	newE = struct(...
		'label',chanlocs(iE).labels,...
		'X',chanlocs(iE).X/unitScaleFactor,...
		'Y',chanlocs(iE).Y/unitScaleFactor,...
		'Z',chanlocs(iE).Z/unitScaleFactor);
	raw.electrodes.electrodes(iE) = newE;
end

% try to estimate landmarks from channel names
xyz = c_struct_mapToArray(chanlocs,{'X','Y','Z'});
xyz = xyz / unitScaleFactor;

indices = ismember(lower({chanlocs.labels}),lower({'FT9','TP9'}));
LPAxyz = mean(xyz(indices,:),1);
indices = ismember(lower({chanlocs.labels}),lower({'FT10','TP10'}));
RPAxyz = mean(xyz(indices,:),1);
indices = ismember(lower({chanlocs.labels}),lower({'FPZ'}));
NASxyz = mean(xyz(indices,:),1);
indices = ismember(lower({chanlocs.labels}),lower({'FZ'}));
FZxyz = mean(xyz(indices,:),1);
NASxyz(3) = NASxyz(3) - (FZxyz(3) - NASxyz(3))/2;

raw.electrodes.fiducials = struct(...
	'label',{'LPA','RPA','NAS'},...
	'X',{LPAxyz(1), RPAxyz(1), NASxyz(1)},...
	'Y',{LPAxyz(2), RPAxyz(2), NASxyz(2)},...
	'Z',{LPAxyz(3), RPAxyz(3), NASxyz(3)});

end

function raw = createRawFromEConnectomeLocations()
	tmp=load('eConnectome\models\10-X-Locations-On-ColinBemSkin.mat');
	locs = tmp.locations/1e3;
	
	tmp=load('eConnectome\models\10-X-Labels.mat');
	labels = tmp.labels;
	
	raw = struct();
	raw.electrodes = struct();
	
	electrodeTemplate = struct(...
		'label',{},...
		'X',{},...
		'Y',{},...
		'Z',{});
	
	raw.electrodes.electrodes = electrodeTemplate;
	for iE = 1:length(labels)
		newE = struct('label',labels{iE});
		newE = c_array_mapToStruct(locs(iE,:),{'X','Y','Z'},newE);
		raw.electrodes.electrodes(iE) = newE;
	end
end