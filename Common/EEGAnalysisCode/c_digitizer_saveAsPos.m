function c_digitizer_saveAsPos(varargin)
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
p.addParameter('doConvertFromMToCm',true,@islogical);
p.parse(varargin{:});
s = p.Results;
raw = s.raw;

if length(s.outputPath)<5 || ~strcmpi(s.outputPath(end-3:end),'.pos')
	s.outputPath(end+1:end+4) = '.pos';
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

% first line is number of channels 
if c_isFieldAndNonEmpty(raw,'electrodes.electrodes')
	numCh = length(raw.electrodes.electrodes);
else
	numCh = 0;
end
fprintf(f,'%d\n',numCh);

if s.doConvertFromMToCm
	unitScalar = 1e2;
else
	unitScalar = 1;
end

% next numCh lines should be electrode labels and locations, with columns tab-delimited
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
	
	fprintf(f,'%d\t%s\t%.8f\t%.8f\t%.8f\n',...
		eNum,...
		strrep(raw.electrodes.electrodes(iN).label,' ','_'),...
		raw.electrodes.electrodes(iN).X*unitScalar,...
		raw.electrodes.electrodes(iN).Y*unitScalar,...
		raw.electrodes.electrodes(iN).Z*unitScalar);
end

% following lines should be head shape points with empty labels
if c_isFieldAndNonEmpty(raw,'shape.points') 
	numPts = length(raw.shape.points);
	for iP = 1:numPts
		fprintf(f,'%d\t%s\t%.8f\t%.8f\t%.8f\n',...
			numCh+iP,...
			'',...
			raw.shape.points(iP).X*unitScalar,...
			raw.shape.points(iP).Y*unitScalar,...
			raw.shape.points(iP).Z*unitScalar);
	end
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
	keyboard
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