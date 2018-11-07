function EEG = c_EEG_setChannelLabelsFromMontage(EEG,montage)

persistent didWarn;

if c_isFieldAndNonEmpty(EEG,'chanlocs') && isempty(didWarn)
	warning('Some montage information already exists. Overwriting with %s montage',montage);
	didWarn = true;
end

labelsBased = false;

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
		EEG = c_EEG_setChannelLabelsFromMontage(EEG,montage);
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
		EEG = c_EEG_setChannelLabelsFromMontage(EEG,montage);
		return;
		
	case 'BrainProducts64'
		labels = {'Fp1','Fp2','F3','F4','C3','C4','P3','P4','O1','O2','F7','F8','T7'   , 'T8'  ,  'P7' ,  'P8' ,  'Fz'  ,  'Cz'  ,  'Pz' ,   'Oz'   , 'FC1'  ,  'FC2'  ,  'CP1'  ,  'CP2' ,   'FC5'  ,  'FC6'  , 'CP5',    'CP6',  'TP9',    'TP10',    'POz',    'ECG',    'F1',    'F2',    'C1',    'C2',    'P1',    'P2',    'AF3',    'AF4',    'FC3',    'FC4',    'CP3',    'CP4',    'PO3',    'PO4',    'F5',    'F6',    'C5',    'C6',    'P5',    'P6',    'AF7',    'AF8',    'FT7', 'FT8',    'TP7',    'TP8',    'PO7',    'PO8',    'FT9',    'FT10',    'Fpz',    'CPz'};
		labelsBased = true;
	case 'BrainProducts64PlusEMGx8'
		labels = {'Fp1','Fp2','F3','F4','C3','C4','P3','P4','O1','O2','F7','F8','T7'   , 'T8'  ,  'P7' ,  'P8' ,  'Fz'  ,  'Cz'  ,  'Pz' ,   'Oz'   , 'FC1'  ,  'FC2'  ,  'CP1'  ,  'CP2' ,   'FC5'  ,  'FC6'  , 'CP5',    'CP6',  'TP9',    'TP10',    'POz',    'ECG',    'F1',    'F2',    'C1',    'C2',    'P1',    'P2',    'AF3',    'AF4',    'FC3',    'FC4',    'CP3',    'CP4',    'PO3',    'PO4',    'F5',    'F6',    'C5',    'C6',    'P5',    'P6',    'AF7',    'AF8',    'FT7', 'FT8',    'TP7',    'TP8',    'PO7',    'PO8',    'FT9',    'FT10',    'Fpz',    'CPz', 'EMG1',	'EMG2',	'EMG3',	'EMG4',	'EMG5',	'EMG6',	'EMG7',	'EMG8'};
		labelsBased = true;
	case 'BrainProductsTMS64'
		labels = {'Fp1','Fp2','F3','F4','C3','C4','P3','P4','O1','O2','F7','F8','T7'   , 'T8'  ,  'P7' ,  'P8' ,  'Fz'  ,  'Cz'  ,  'Pz' ,   'Iz'   , 'FC1'  ,  'FC2'  ,  'CP1'  ,  'CP2' ,   'FC5'  ,  'FC6'  , 'CP5',    'CP6',  'TP9',    'TP10',    'Ft9',    'Ft10',    'F1',    'F2',    'C1',    'C2',    'P1',    'P2',    'AF3',    'AF4',    'FC3',    'FC4',    'CP3',    'CP4',    'PO3',    'PO4',    'F5',    'F6',    'C5',    'C6',    'P5',    'P6',    'AF7',    'AF8',    'FT7', 'FT8',    'TP7',    'TP8',    'PO7',    'PO8',    'FPz',    'CPz',    'POz',    'Oz'};
		labelsBased = true;
	case 'BrainProductsTMS64PlusEMGx8'
		labels = {'Fp1','Fp2','F3','F4','C3','C4','P3','P4','O1','O2','F7','F8','T7'   , 'T8'  ,  'P7' ,  'P8' ,  'Fz'  ,  'Cz'  ,  'Pz' ,   'Iz'   , 'FC1'  ,  'FC2'  ,  'CP1'  ,  'CP2' ,   'FC5'  ,  'FC6'  , 'CP5',    'CP6',  'TP9',    'TP10',    'Ft9',    'Ft10',    'F1',    'F2',    'C1',    'C2',    'P1',    'P2',    'AF3',    'AF4',    'FC3',    'FC4',    'CP3',    'CP4',    'PO3',    'PO4',    'F5',    'F6',    'C5',    'C6',    'P5',    'P6',    'AF7',    'AF8',    'FT7', 'FT8',    'TP7',    'TP8',    'PO7',    'PO8',    'FPz',    'CPz',    'POz',    'Oz',	'EMG1',	'EMG2',	'EMG3',	'EMG4',	'EMG5',	'EMG6',	'EMG7',	'EMG8'};
		labelsBased = true;
	case 'BrainProductsTMS64PlusEMGx8Auxx1'
		labels = {'Fp1','Fp2','F3','F4','C3','C4','P3','P4','O1','O2','F7','F8','T7'   , 'T8'  ,  'P7' ,  'P8' ,  'Fz'  ,  'Cz'  ,  'Pz' ,   'Iz'   , 'FC1'  ,  'FC2'  ,  'CP1'  ,  'CP2' ,   'FC5'  ,  'FC6'  , 'CP5',    'CP6',  'TP9',    'TP10',    'Ft9',    'Ft10',    'F1',    'F2',    'C1',    'C2',    'P1',    'P2',    'AF3',    'AF4',    'FC3',    'FC4',    'CP3',    'CP4',    'PO3',    'PO4',    'F5',    'F6',    'C5',    'C6',    'P5',    'P6',    'AF7',    'AF8',    'FT7', 'FT8',    'TP7',    'TP8',    'PO7',    'PO8',    'FPz',    'CPz',    'POz',    'Oz',	'EMG1',	'EMG2',	'EMG3',	'EMG4',	'EMG5',	'EMG6',	'EMG7',	'EMG8','Aux1'};
		labelsBased = true;
	case 'BrainProductsMR128'
		labels = {'Fp1', 'Fp2', 'F3', 'F4', 'C3', 'C4', 'P3', 'P4', 'O1', 'O2', 'F7', 'F8', 'T7', 'T8', 'P7', 'P8', 'Fz', 'Cz', 'Pz', 'Oz', 'FC1', 'FC2', 'CP1', 'CP2', 'FC5', 'FC6', 'CP5', 'CP6', 'TP9', 'TP10', 'POz', 'ECG', 'F1', 'F2', 'C1', 'C2', 'P1', 'P2', 'AF3', 'AF4', 'FC3', 'FC4', 'CP3', 'CP4', 'PO3', 'PO4', 'F5', 'F6', 'C5', 'C6', 'P5', 'P6', 'AF7', 'AF8', 'FT7', 'FT8', 'TP7', 'TP8', 'PO7', 'PO8', 'FT9', 'FT10', 'Fpz', 'CPz', 'FFC1h', 'FFC2h', 'FCC1h', 'FCC2h', 'CCP1h', 'CCP2h', 'CPP1h', 'CPP2h', 'AFF1h', 'AFF2h', 'PPO1h', 'PPO2h', 'FFC3h', 'FFC4h', 'FCC3h', 'FCC4h', 'CCP3h', 'CCP4h', 'CPP3h', 'CPP4h', 'AFp1', 'AFp2', 'POO1', 'POO2', 'AFF5h', 'AFF6h', 'FFC5h', 'FFC6h', 'FCC5h', 'FCC6h', 'CCP5h', 'CCP6h', 'CPP5h', 'CPP6h', 'PPO5h', 'PPO6h', 'FFT7h', 'FFT8h', 'FTT7h', 'FTT8h', 'TTP7h', 'TTP8h', 'TPP7h', 'TPP8h', 'FFT9h', 'FFT10h', 'TPP9h', 'TPP10h', 'PPO9h', 'PPO10h', 'POO9h', 'POO10h', 'OI1h', 'OI2h', 'F9', 'F10', 'P9', 'P10', 'PO9', 'PO10', 'O9', 'O10', 'Iz'};
		labelsBased = true;
	case 'Neuroscan68'
		str = fileparts(mfilename('fullpath'));
		chanlocs = readlocs([str '/Resources/bci_fESI_neuroscan68.loc'],'filetype','loc');
	case 'Neuroscan132'
		str = fileparts(mfilename('fullpath'));
		chanlocs = readlocs([str '/Resources/bci_fESI_neuroscan132.loc'],'filetype','loc');
	case 'Biosemi128'
		labels = {'A1','A2','A3','A4','A5','A6','A7','A8','A9','A10','A11','A12','A13','A14','A15','A16','A17','A18','A19','A20','A21','A22','A23','A24','A25','A26','A27','A28','A29','A30','A31','A32','B1','B2','B3','B4','B5','B6','B7','B8','B9','B10','B11','B12','B13','B14','B15','B16','B17','B18','B19','B20','B21','B22','B23','B24','B25','B26','B27','B28','B29','B30','B31','B32','C1','C2','C3','C4','C5','C6','C7','C8','C9','C10','C11','C12','C13','C14','C15','C16','C17','C18','C19','C20','C21','C22','C23','C24','C25','C26','C27','C28','C29','C30','C31','C32','D1','D2','D3','D4','D5','D6','D7','D8','D9','D10','D11','D12','D13','D14','D15','D16','D17','D18','D19','D20','D21','D22','D23','D24','D25','D26','D27','D28','D29','D30','D31','D32'};
		labelsBased = true;
	otherwise 
		error('Unsupported montage specified');
end

if labelsBased
	if c_isFieldAndNonEmpty(EEG,'nbchan')
		numChannels = EEG.nbchan;
		if length(labels) ~= numChannels
			error('Number of channels in data (%d) does not match number of channels in specified montage (%d)',...
				numChannels, length(labels));
		end
	else
		EEG.nbchan = length(labels);
		numChannels = EEG.nbchan;
	end

	for c=1:numChannels
		EEG.chanlocs(c).labels = labels{c};
	end
else
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
	fieldsToCopy = {'labels'};
	for c=1:numChannels
		for iF = 1:length(fieldsToCopy)
			EEG.chanlocs(c).(fieldsToCopy{iF}) = chanlocs(c).(fieldsToCopy{iF});
		end
	end
end

end



