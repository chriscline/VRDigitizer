function str = c_str_toTitleCase(varargin)
% c_str_toTitleCase - convert a string to title case
% Can handle acronyms correctly if passed in with named argument 'acronyms', e.g. {'EEG','MRI'}

if nargin == 0, testfn(); return; end;

p = inputParser();
p.addRequired('str',@ischar);
p.addParameter('acronyms',{},@iscellstr);
p.addParameter('nonSpaceDelimiters',{',','-','.',':'});
p.parse(varargin{:});
s = p.Results;

str = s.str;

str = strtrim(str);
wordBreakIndices = isspace(str); %TODO: add support for hyphens to count as breaks, etc.
wordBreakIndices = wordBreakIndices | arrayfun(@(x) ismember(x,s.nonSpaceDelimiters),str);
indicesToUpper = [true wordBreakIndices(1:end-1)];
str(indicesToUpper) = upper(str(indicesToUpper));

if ~isempty(s.acronyms)
	for iA = 1:length(s.acronyms)
		startIndices = strfind(lower(str),lower(s.acronyms{iA}));
		for iI = 1:length(startIndices)
			startIndex = startIndices(iI);
			endIndex = startIndex + length(s.acronyms{iA}) - 1;
			if startIndex~=1 && ~wordBreakIndices(startIndex-1)
				continue; % only treat as acronym if match is at start of a word 
			end
			if endIndex~=length(str) && ~wordBreakIndices(endIndex+1)
				continue; % only treat as acronym if end of match is at end of a word
			end
			str(startIndex:endIndex) = s.acronyms{iA};
		end
	end
end

end

function testfn()

c_say('Testing %s',mfilename);

input = 'this is a test';
expectedOutput = 'This Is A Test';
actualOutput = c_str_toTitleCase(input);
assert(isequal(expectedOutput,actualOutput));

input = 'eeg, an fmri acronym test with interesting int';
acronyms = {'EEG','fMRI','INT'};
expectedOutput = 'EEG, An fMRI Acronym Test With Interesting INT';
actualOutput = c_str_toTitleCase(input,'acronyms',acronyms);
assert(isequal(expectedOutput,actualOutput));

c_sayDone('Tests passed');

end