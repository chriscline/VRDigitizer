function s = c_toString(c,varargin)
% c_toString Convert various data types to a string
% Handles reasonable printing of scalars, vectors, matrices, cells, etc.
%
% Examples:
%	c_toString(rand(2,3))
%	c_toString(rand(2,3),'doPreferMultiline',true)
%	c_saySingleMultiline('%s',c_toString(rand(2,3),'doPreferMultiline',true))
%   c_toString({'test',pi,[1 2 3]}')
%	c_toString({'test',pi,[1 2 3]}','precision',3)

	if nargin == 0, testfn(); s=''; return; end
	
	doPreferMultiline = false;
	precision = [];
	indentation = 0;
	printLimit = 100;
	
	if nargin > 1 
		p = inputParser();
		p.addParameter('doPreferMultiline',doPreferMultiline,@islogical);
		p.addParameter('printLimit',printLimit,@isscalar);
		p.addParameter('precision',precision,@isscalar);
		p.addParameter('indentation',indentation,@isscalar);
		p.parse(varargin{:});
		doPreferMultiline = p.Results.doPreferMultiline;
		printLimit = p.Results.printLimit;
		precision = p.Results.precision;
		indentation = p.Results.indentation;
	end

	num2strArgs = {};
	if ~isempty(precision)
		num2strArgs = {precision};
	end
	
	if iscell(c)
		s = c_cellToString(c,varargin{:},'indentation',indentation+1);
	elseif isempty(c) && isnumeric(c)
			s = '[]';
	elseif isempty(c) && ischar(c)
			s = '''''';
	elseif isscalar(c) && isnumeric(c)
		s = num2str(c,num2strArgs{:});
	elseif isnumeric(c)
		if isvector(c) && length(c) > 2 && all(diff(c)==1) && c_isinteger(c)
			s = ['[' num2str(c(1)) ':' num2str(c(end)) ']'];
			if size(c,1) > size(c,2)
				s = [s,'.'''];
			end
		else
			if numel(c) > printLimit
				%warning('Too many elements to print');
				s = sprintf('<Array of size %s>',c_toString(size(c)));
			else
				if size(c,1) > size(c,2) && ~doPreferMultiline
					c = c.';
					didTranspose = true;
				else
					didTranspose = false;
				end
				if ismatrix(c)
					s = '[';
					
					numStrs = arrayfun(@(x) num2str(x, num2strArgs{:}),c,'UniformOutput',false);
					
					if doPreferMultiline 
						% use less compact format
						% make all strings the same length to line up columns neatly
						maxStrLength = max(cellfun(@length,numStrs(:)));
						templateStr = repmat(' ',1,maxStrLength);
						for i=1:numel(numStrs)
							tmp = numStrs{i};
							numStrs{i} = templateStr;
							numStrs{i}(1:length(tmp)) = tmp;
						end
						withinLineDelim = sprintf('\t');
						betweenLineDelim = sprintf(';\n ');
					else
						withinLineDelim = ' ';
						betweenLineDelim = '; ';
					end
					for i=1:size(c,1)
						s = [s, strjoin(numStrs(i,:),withinLineDelim)];
						if i~=size(c,1)
							s = [s, betweenLineDelim];
						end
					end
					s = [s,']'];
				else
					s = sprintf('<Array of size %s>',c_toString(size(c)));
					%TODO: add support for showing values of arrays of higher dimensions
				end
				if didTranspose
					s = [s,'.'''];
				end
			end
		end
	elseif ischar(c)
		if numel(c) > length(c)
			s = sprintf('<Char array of size %s>',c_toString(size(c)));
		else
			s = ['''' c ''''];
		end
	elseif islogical(c)
		s = num2str(c);
		s = strrep(s,'0','false');
		s = strrep(s,'1','true');
	elseif isstruct(c)
		if length(c) > 1
			s = sprintf('<Struct array>:\n\t');
			if length(c) < printLimit
				for i=1:length(c)
					s = [s, sprintf('<Element %d>:\n\t',i)];
					s = [s, indentLines(c_toString(c(i),varargin{:}))];
					if i~=length(c)
						s = [s, sprintf('\n')];
					end
				end
			else
				s = [s, '<too long to print>'];
			end
		else
			fields = fieldnames(c);
			longestFieldLength = max(cellfun(@length,fields));
			if length(c) > 0
				s = sprintf('<Struct>:\n');
			else
				s = sprintf('<Empty struct>:\n');
			end
			for i=1:length(fields)
				if i~=length(fields)
					s = [s,' |'];
				else
					s = [s,' |'];
				end
				s = [s, repmat('_',1,longestFieldLength - length(fields{i}) + 1) ' '];
				s = [s, sprintf('%s',fields{i})];
				if length(c)>0
					s = [s, ': ', indentLines(c_toString(c.(fields{i}),varargin{:}))];
				end
				if i~=length(fields)
					s = [s, sprintf('\n')];
				end
			end
		end
	elseif isdatetime(c)
		s = strtrim(evalc('disp(c)'));
	elseif isobject(c)
		s = sprintf('[Object]:\n');
		tmp = indentLines(evalc('disp(c)'));
		if length(tmp(:)) > printLimit*10
			tmp = '<too long to print>';
		end
		s = [s, tmp];
	elseif isa(c,'function_handle')
		s = sprintf('[function_handle]: %s',char(c));
	else
		error('unsupported type');
	end
end

function s = indentLines(s)
	s = strrep(s,sprintf('\n'),sprintf('\n\t'));
end

function testfn()
	c_toString({'test',[1 2 3],'a1',{'test inner', 5}});
	c_toString(struct('parent1','child1','parent2',struct('child2',1,'child3','subchild')));
end