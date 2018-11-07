function [chanlocs, raw] = c_digitizer_loadBVEF(varargin)
% load XML-formatted BrainVision electrode file

if nargin==0, testfn(); return; end;

p = inputParser();
p.addRequired('filepath',@ischar);
p.parse(varargin{:});
s = p.Results;


assert(exist(s.filepath,'file')>0);

xmlNode = xmlread(s.filepath);

root = xmlNode.getDocumentElement;

electrodes = root.getChildNodes;
assert(strcmpi(electrodes.getNodeName,'Electrodes'));

node = electrodes.getFirstChild;

templateStruct = struct(...
	'Name','',...
	'Theta',NaN,...
	'Phi',NaN,...
	'Radius',NaN,...
	'Number',NaN);

elecs = templateStruct;
numElecs = 0;

while ~isempty(node)
	electrode = node;
	node = node.getNextSibling;
	
	if ~strcmpi(electrode.getNodeName,'Electrode')
		continue;
	end
	
	elec = templateStruct;
	
	subnode = electrode.getFirstChild;
	while ~isempty(subnode)
		field = subnode;
		subnode = subnode.getNextSibling;
		
		fieldName = char(field.getNodeName);
		
		if ~ismember(fieldName,fieldnames(templateStruct))
			continue;
		end
		
		fieldValue = char(field.getTextContent);
		
		if ~ischar(templateStruct.(fieldName))
			fieldValue = str2double(fieldValue);
		end
		
		elec.(fieldName) = fieldValue;
	end
	
	numElecs = numElecs + 1;
	elecs(numElecs) = elec;
end

channelNums = cell2mat({elecs.Number});
if length(channelNums)~=length(unique(channelNums))
	warning('Duplicate channel numbers detected.');
end
if any(diff(sort(channelNums))>1)
	warning('Skipped channel numbers detected.');
end

numChannels = max(channelNums);
numExtraChannels = 0;

chanlocs = struct('labels',{},'sph_theta_besa',{},'sph_phi_besa',{});
for e=1:length(elecs)
	c = elecs(e).Number;
	if isnan(c)
		numExtraChannels = numExtraChannels+1;
		c = numChannels+numExtraChannels;
	end
	assert(elecs(e).Radius==1); % assumed by sphbesa2all converison below
	chanlocs(c) = struct(...
		'labels',elecs(e).Name,...
		'sph_theta_besa',elecs(e).Theta,...
		'sph_phi_besa',elecs(e).Phi);
end

chanlocs = convertlocs(chanlocs,'sphbesa2all');

if nargout > 1
	dm = c_DigitizedMontage('initFromChanlocs',chanlocs);
	raw = dm.asRawDigitizedData();
end

end
