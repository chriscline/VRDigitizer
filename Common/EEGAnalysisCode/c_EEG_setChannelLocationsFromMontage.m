function EEG = c_EEG_setChannelLocationsFromMontage(EEG,montage)

if ismember(montage,{...
		'BrainProductsMRAuto','BrainProducts64','BrainProducts64PlusEMGx8',...
		'BrainProductsMR128',...
		'BrainProductsTMSAuto','BrainProductsTMS64','BrainProductsTMS64PlusEMGx8','BrainProductsTMS64PlusEMGx8Auxx1',...
		'Biosemi128'})
	numEMGChannels = 0; % assume any EMG channels are at the end of channel list
	numAuxChannels = 0; % assume any aux channels are after any EMG channels
	
	switch(montage)
		case 'BrainProductsMRAuto'
			switch(EEG.nbchan)
				case 64
					montage = 'BrainProducts64';
				case 72
					montage = 'BrainProducts64PlusEMGx8';
				otherwise
					error('Unsupported montage');
			end
			EEG = c_EEG_setChannelLocationsFromMontage(EEG,montage);
			return;

		case 'BrainProductsTMSAuto'
			switch(EEG.nbchan)
				case 64
					montage = 'BrainProductsTMS64';
				case 72
					montage = 'BrainProductsTMS64PlusEMGx8';
				case 73
					montage = 'BrainProductsTMS64PlusEMGx8Auxx1';
				otherwise
					error('Unsupported montage');
			end
			EEG = c_EEG_setChannelLocationsFromMontage(EEG,montage);
			return;
			
		case 'BrainProducts64'
			theta = [-90    90   -60    60   -45    45   -60    60   -90    90   -90    90   -90    90   -90    90    45     0    45    90   -31    31   -31    31   -69    69   -69    69  -113   113    67   NaN   -49    49   -23    23   -49    49   -74  74   -49    49   -49    49   -74    74   -74    74   -68    68   -74    74   -90    90   -90    90   -90    90   -90    90  -113   113    90    22];
			phi = [	 -72    72   -51    51     0     0    51   -51    72   -72   -36    36     0     0    36   -36    90     0   -90   -90   -46    46    46   -46   -21    21    21   -21    18   -18   -90   NaN   -68    68     0     0    68   -68   -68 68   -29    29    29   -29    68   -68   -41    41     0     0    41   -41   -54    54   -18    18    18   -18    54   -54   -18    18    90   -90];
		case 'BrainProducts64PlusEMGx8'
			theta = [-90    90   -60    60   -45    45   -60    60   -90    90   -90    90   -90    90   -90    90    45     0    45    90   -31    31   -31    31   -69    69   -69    69  -113   113    67   NaN   -49    49   -23    23   -49    49   -74  74   -49    49   -49    49   -74    74   -74    74   -68    68   -74    74   -90    90   -90    90   -90    90   -90    90  -113   113    90    22 NaN(1,8)];
			phi = [	 -72    72   -51    51     0     0    51   -51    72   -72   -36    36     0     0    36   -36    90     0   -90   -90   -46    46    46   -46   -21    21    21   -21    18   -18   -90   NaN   -68    68     0     0    68   -68   -68 68   -29    29    29   -29    68   -68   -41    41     0     0    41   -41   -54    54   -18    18    18   -18    54   -54   -18    18    90   -90 NaN(1,8)];
		case 'BrainProductsTMS64'
			theta = [-90    90   -60    60   -45    45   -60    60   -90    90   -90    90   -90    90   -90    90    45     0    45    112   -31    31   -31    31   -69    69   -69    69  -113   113   -113   113   -49    49   -23    23   -49    49   -74  74   -49    49   -49    49   -74    74   -74    74   -68    68   -74    74   -90    90   -90    90   -90    90   -90    90  90	  22    67    90];
			phi = [	 -72    72   -51    51     0     0    51   -51    72   -72   -36    36     0     0    36   -36    90     0   -90   -90   -46    46    46   -46   -21    21    21   -21    18   -18		-18   18   -68    68     0     0    68   -68   -68 68   -29    29    29   -29    68   -68   -41    41     0     0    41   -41   -54    54   -18    18    18   -18    54   -54   90    -90    -90   -90];
		case 'BrainProductsTMS64PlusEMGx8'
			numEMGChannels = 8;
			theta = [-90    90   -60    60   -45    45   -60    60   -90    90   -90    90   -90    90   -90    90    45     0    45    112   -31    31   -31    31   -69    69   -69    69  -113   113   -113   113   -49    49   -23    23   -49    49   -74  74   -49    49   -49    49   -74    74   -74    74   -68    68   -74    74   -90    90   -90    90   -90    90   -90    90  90	  22    67    90 nan(1,numEMGChannels)];
			phi = [	 -72    72   -51    51     0     0    51   -51    72   -72   -36    36     0     0    36   -36    90     0   -90   -90   -46    46    46   -46   -21    21    21   -21    18   -18		-18   18   -68    68     0     0    68   -68   -68 68   -29    29    29   -29    68   -68   -41    41     0     0    41   -41   -54    54   -18    18    18   -18    54   -54   90    -90    -90   -90 nan(1,numEMGChannels)];
		case 'BrainProductsTMS64PlusEMGx8Auxx1'
			numEMGChannels = 8;
			numAuxChannels = 1;
			theta = [-90    90   -60    60   -45    45   -60    60   -90    90   -90    90   -90    90   -90    90    45     0    45    112   -31    31   -31    31   -69    69   -69    69  -113   113   -113   113   -49    49   -23    23   -49    49   -74  74   -49    49   -49    49   -74    74   -74    74   -68    68   -74    74   -90    90   -90    90   -90    90   -90    90  90	  22    67    90 nan(1,numEMGChannels+numAuxChannels)];
			phi = [	 -72    72   -51    51     0     0    51   -51    72   -72   -36    36     0     0    36   -36    90     0   -90   -90   -46    46    46   -46   -21    21    21   -21    18   -18		-18   18   -68    68     0     0    68   -68   -68 68   -29    29    29   -29    68   -68   -41    41     0     0    41   -41   -54    54   -18    18    18   -18    54   -54   90    -90    -90   -90 nan(1,numEMGChannels+numAuxChannels)];
		case 'BrainProductsMR128'
			theta = [-90 90 -60 60 -45 45 -60 60 -90 90 -90 90 -90 90 -90 90 45 0 45 90 -31 31 -31 31 -69 69 -69 69 -113 113 67 NaN -49 49 -23 23 -49 49 -74 74 -49 49 -49 49 -74 74 -74 74 -68 68 -74 74 -90 90 -90 90 -90 90 -90 90 -113 113 90 22 -35 35 -16 16 -16 16 -35 35 -57 57 -57 57 -46 46 -35 35 -35 35 -46 46 -79 79 -79 79 -72 72 -62 62 -57 57 -57 57 -62 62 -72 72 -81 81 -79 79 -79 79 -81 81 -101 101 -101 101 -101 101 -101 101 -101 101 -113 113 -113 113 -113 113 -112 112 112];
			phi = [-72 72 -51 51 0 0 51 -51 72 -72 -36 36 0 0 36 -36 90 0 -90 -90 -46 46 46 -46 -21 21 21 -21 18 -18 -90 NaN -68 68 0 0 68 -68 -68 68 -29 29 29 -29 68 -68 -41 41 0 0 41 -41 -54 54 -18 18 18 -18 54 -54 -18 18 90 -90 -73 73 -45 45 45 -45 73 -73 -82 82 82 -82 -48 48 -19 19 19 -19 48 -48 -82 82 82 -82 -55 55 -35 35 -12 12 12 -12 35 -35 55 -55 -29 29 -10 10 10 -10 29 -29 -27 27 27 -27 45 -45 63 -63 81 -81 -36 36 36 -36 54 -54 72 -72 -90];
		case 'Biosemi128'
			theta = [0	11.5	23	34.5	-46	-46	-57.5	-69	-80.5	-92	-103.5	-115	-115	-103.5	-92	-80.5	-69	-57.5	46	57.5	69	80.5	92	103.5	115	115	103.5	92	80.5	69	57.5	46	11.5	23	46	57.5	69	80.5	92	103.5	115	103.5	92	80.5	69	92	80.5	69	57.5	46	34.5	23	34.5	46	57.5	69	80.5	92	92	80.5	69	57.5	46	34.5	11.5	23	46	57.5	69	80.5	92	92	80.5	69	34.5	46	57.5	69	80.5	92	92	80.5	69	57.5	46	34.5	23	-34.5	-46	-57.5	-69	-80.5	-92	-92	-80.5	-69	-11.5	-23	-46	-57.5	-69	-80.5	-92	-92	-80.5	-69	-57.5	-46	-34.5	-23	-11.5	-23	-34.5	-34.5	-46	-57.5	-69	-80.5	-92	-92	-80.5	-69	-57.5	-46	-69	-80.5	-92	-103.5];
			phi = [0	-90	-90	-90	67.5	45	45	54	54	54	54	54	72	72	72	72	72	67.5	-90	-90	-90	-90	-90	-90	-90	-72	-72	-72	-72	-72	-67.5	-67.5	-18	-45	-45	-45	-54	-54	-54	-54	-54	-36	-36	-36	-36	-18	-18	-18	-22.5	-22.5	-30	0	0	0	0	0	0	0	18	18	18	22.5	22.5	30	54	45	45	45	36	36	36	54	54	54	60	67.5	67.5	72	72	72	90	90	90	90	90	90	90	-60	-67.5	-67.5	-72	-72	-72	-54	-54	-54	-54	-45	-45	-45	-36	-36	-36	-18	-18	-18	-22.5	-22.5	-30	0	18	45	30	0	0	0	0	0	0	18	18	18	22.5	22.5	36	36	36	36];
		otherwise
			error('Invalid montage: %s',montage);
	end
			
	if c_isFieldAndNonEmpty(EEG,'nbchan')
		if length(theta) ~= EEG.nbchan
			error('Number of channels in data does not match number of channels in specified montage');
		end
	else
		EEG.nbchan = length(theta);
	end
	numChannels = EEG.nbchan;

	for c=1:numChannels
		EEG.chanlocs(c).sph_theta_besa = theta(c);
		EEG.chanlocs(c).sph_phi_besa = phi(c);
		if c > numChannels - numEMGChannels - numAuxChannels
			EEG.chanlocs(c).type = 'EMG';
		else
			EEG.chanlocs(c).type = 'EEG';
		end
	end
	
	if ~exist('convertlocs','file')
		addpath(fullfile(fileparts(which(mfilename)),'../ThirdParty/FromEEGLab/sigprocfunc'));
	end
	
	% convert spherical coordinates to other systems
	EEG.chanlocs = convertlocs(EEG.chanlocs,'sphbesa2all');
	
elseif ismember(montage,{...
		'Neuroscan68',...
		'Neuroscan132'})
	switch(montage)
		case 'Neuroscan68'
			str = fileparts(mfilename('fullpath'));
			chanlocs = readlocs([str '/Resources/bci_fESI_neuroscan68.loc'],'filetype','loc');
		case 'Neuroscan132'
			str = fileparts(mfilename('fullpath'));
			chanlocs = readlocs([str '/Resources/bci_fESI_neuroscan132.loc'],'filetype','loc');
		otherwise
			error('Invalid montage: %s',montage);
	end
	if c_isFieldAndNonEmpty(EEG,'nbchan')
		numChannels = EEG.nbchan;
		if length(chanlocs) ~= numChannels
			error('Number of channels in data (%d) does not match number of channels in specified montage (%d)',...
				numChannels, length(chanlocs));
		end
	else
		EEG.nbchan = length(chanlocs);
		numChannels = EEG.nbchan;
	end
	fieldsToCopy = {'theta','radius','sph_theta','sph_phi','sph_theta_besa','sph_phi_besa','X','Y','Z'};
	for c=1:numChannels
		for iF = 1:length(fieldsToCopy)
			EEG.chanlocs(c).(fieldsToCopy{iF}) = chanlocs(c).(fieldsToCopy{iF});
		end
	end
	
	
elseif strcmp('Lookup',montage)
	assert(exist('eeglab','file')>0);
	EEG=pop_chanedit(EEG, 'lookup',fullfile(fileparts(which('eeglab')),'/plugins/dipfit2.3/standard_BESA/standard-10-5-cap385.elp'));
	
elseif strcmp('Lookup_BP',montage)
	mfilepath=fileparts(which(mfilename));
	allLocations = load(fullfile(mfilepath,'./Resources/Brainstorm_BrainProducts_EasyCap_128.mat'));
	allLabels = {allLocations.Channel.Name};
	for c=1:EEG.nbchan
		channelIndex = find(strcmpi(allLabels,EEG.chanlocs(c).labels));
		if isempty(channelIndex)
			if length(EEG.chanlocs(c).labels)<3 || ~strcmp(EEG.chanlocs(c).labels(1:3),'EMG')
				warning('Channel %s is not in lookup file',EEG.chanlocs(c).labels);
			end
			EEG.chanlocs(c).X = nan;
			EEG.chanlocs(c).Y = nan;
			EEG.chanlocs(c).Z = nan;
		else
			xyz = allLocations.Channel(channelIndex).Loc*1000;
			EEG.chanlocs(c).X = xyz(1);
			EEG.chanlocs(c).Y = xyz(2);
			EEG.chanlocs(c).Z = xyz(3);
		end
	end
	EEG.chanlocs = convertlocs(EEG.chanlocs,'cart2all');
else
	error('Unsupported montage specified: %s',montage);
end



end