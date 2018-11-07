function str = c_str_fromCamelCase(str,varargin)
	if nargin == 0, testfn(); return; end
	
	p = inputParser();
	p.addRequired('str',@ischar);
	p.addParameter('acronyms',{},@iscellstr);
	p.parse(str,varargin{:});
	s = p.Results;
	
	str = s.str;
	
	capIndices = str ~= lower(str);
	capIndices(1) = false; % ignore first character
	
	numericIndices = ismember(str,'0':'9');
	% only treat start of continuous number strings as boundaries
	numericIndices = numericIndices & [false diff(numericIndices) > 0];
	
	indicesToInsertSpace = capIndices | numericIndices;
	indicesToUncapitalize = capIndices;
	
	acronymStartIndices = false(1,length(str));
	acronymIndices = false(1,length(str));
	for iA = 1:length(s.acronyms)
		indices = strfind(str,s.acronyms{iA});
		prunedIndices = false(1,length(str));
		for iiA = 1:length(indices)
			nextCharIndex = indices(iiA) + length(s.acronyms{iA});
			if nextCharIndex > length(str) || capIndices(nextCharIndex) || numericIndices(nextCharIndex)
				prunedIndices(indices(iiA)) = true;
			end
		end
		acronymStartIndices = acronymStartIndices | prunedIndices;
		
		for iAC = 1:length(s.acronyms{iA})
			acronymIndices(find(acronymStartIndices)+iAC-1) = true;
		end
	end
	
	if any(acronymStartIndices)
		indicesToInsertSpace(acronymIndices) = false;
		indicesToInsertSpace(acronymStartIndices) = true;
		indicesToUncapitalize(acronymIndices) = false;
	end
	
	str(indicesToUncapitalize) = lower(str(indicesToUncapitalize));
	
	indicesToInsertSpace = find(indicesToInsertSpace);
	% assumes indicesToInsertSpace is sorted
	for iI=1:length(indicesToInsertSpace)
		iS = indicesToInsertSpace(iI);
		str = [str(1:iS-1) ' ' str(iS:end)];
		indicesToInsertSpace(iI+1:end) = indicesToInsertSpace(iI+1:end) + 1;
	end
end

function testfn()

inputOutputPairs = {...
	{'thisIsATest','this is a test'},...
	{'ThisIsATest','This is a test'},...
	{'WithNumbers2','With numbers 2'},...
	{'WithAnEEGAcronym','With an EEG acronym','acronyms',{'EEG'}},...
	{'WithoutAnEEGacronym','Without an e e gacronym','acronyms',{'EEG'}}' % if next character after acronym is lower case, it's not really an instance of the acronym
};

for iP = 1:length(inputOutputPairs)
	input = inputOutputPairs{iP}{1};
	desiredOutput = inputOutputPairs{iP}{2};
	extraArgs = inputOutputPairs{iP}(3:end);
	actualOutput = c_str_fromCamelCase(input,extraArgs{:});
	assert(isequal(desiredOutput,actualOutput),...
		'Failed:''%s'' converted to  ''%s'' instead of ''%s''',...
		input,actualOutput,desiredOutput);
	c_saySingle('''%s''->''%s''',input,actualOutput);
end
c_saySingle('All tests passed');
end