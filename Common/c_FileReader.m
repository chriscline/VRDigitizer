classdef c_FileReader < handle
% c_FileReader - class to encapsulate various functions for reading ascii and binary files
% Supports reading entire file into memory (cache) and using fgetl, etc. on the cached
%	version for (potentially) faster reads in some situations.

	properties
		cache = '';
		cacheIndex = 0;
		newlineChar = sprintf('\n');
	end
	
	properties(SetAccess=protected)
		doCache;
		fh;
	end
	
	methods
		function o = c_FileReader(varargin)
			p = inputParser();
			p.addRequired('filepath',@ischar);
			p.addParameter('doCache',false,@islogical);
			p.parse(varargin{:});
			s = p.Results;
			
			o.doCache = s.doCache;
			o.open(s.filepath);
		end
		
		function delete(o)
			o.close();
		
		end
		
		function open(o,filepath)
			fh = fopen(filepath);
			if fh==-1
				error('Problem opening file for reading.');
			end

			if o.doCache
				o.cache = fread(fh,'*uint8')';
				fclose(fh);
				o.cacheIndex = 1;
				o.fh = [];
				
			else
				o.fh = fh;
			end
		end
		
		function close(o)
			if ~o.doCache
				if ~isempty(o.fh)
					fclose(o.fh);
				end
			else
				o.cache = '';
				o.cacheIndex = 0;
			end
		end

		function str = fgetl(o)
			if ~o.doCache
				str = fgetl(o.fh);
			else
				cacheIndex = o.cacheIndex;
				
				if cacheIndex == length(o.cache)+1
					str = -1;
					return;
				end
				
				chunkSize = 1e4;
				while true
					if cacheIndex == length(o.cache)+1
						index = cacheIndex-1;
						break;
					end
					cacheIndices = cacheIndex:min(cacheIndex+chunkSize,length(o.cache));
					index = find(o.cache(cacheIndices)==o.newlineChar,1,'first');
					if ~isempty(index)
						index = cacheIndices(index);
						break;
					else
						cacheIndex = cacheIndices(end);
					end
				end
				str = char(o.cache((o.cacheIndex):(index-1)));
				o.cacheIndex = index+1;
			end
		end
		
		function str = fgetl_skipBlankLines(o)
			str = '';
			while isempty(str)
				str = o.fgetl();
			end
		end

		function [A, count] = fread(o,varargin)
			if ~o.doCache
				[A, count] = fread(o.fh,varargin{:});
			else
				if length(varargin) > 2
					error('Extra fread args not yet supported for cached reads');
				end
				
				cacheIndex = o.cacheIndex;
				cacheLength = length(o.cache);
				
				if ~isempty(varargin)
					sizeA = varargin{1};
					if length(sizeA) > 2
						error('Nonscalar/nonmatrix size arguments not yet supported for cached reads');
					end
				else
					sizeA = cacheLength - cacheIndex + 1;
				end
				origSizeA = sizeA;
				if ~isscalar(sizeA)
					sizeA = prod(sizeA);
				end
				
				if length(varargin) > 1
					inputType = varargin{2};
					if inputType(1)=='*'
						inputType = inputType(2:end);
						outputType = '';
					else
						outputType = 'double';
					end
				else
					inputType = 'uint8';
					outputType = 'double';
				end
				
				numBytesPerVal = getNumBytesForType(inputType);
				
				count = min(floor((cacheLength-cacheIndex + 1)/numBytesPerVal),sizeA);
				
				A = typecast(o.cache(cacheIndex - 1 + (1:count*numBytesPerVal)), inputType);
				
				if ~isempty(outputType) && ~strcmp(inputType,outputType)
					A = cast(A,outputType);
				end
				
				assert(length(A)==count); %TODO: debug, delete
				
				o.cacheIndex = cacheIndex + count*numBytesPerVal;
				
				if ~isscalar(origSizeA)
					A = reshape(A,origSizeA);
				end
			end
		end
		
		
		function pos = ftell(o)
			if ~o.doCache
				pos = ftell(o.fh);
			else
				pos = o.cacheIndex-1;
			end
		end
		
		function fseek(o, offset, origin)
			if ~o.doCache
				fseek(o.fh,offset,origin);
			else
				if strcmp(origin,'bof') || (isscalar(origin) && origin==-1)
					newPos = offset + 1;
				elseif strcmp(origin,'cof') || (isscalar(origin) && origin==0)
					newPos = o.cacheIndex + offset;
				elseif strcmp(origin,'eof') || (isscalar(origin) && origin==1)
					newPos = length(o.cache) + offset + 1;
				end
				if (newPos < 1 || newPos > length(o.cache) + 1)
					error('Invalid seek position: %d',newPos);
				else
					o.cacheIndex = newPos;
				end
			end
		end
		
		function varargout = freadBinaryArray(o,typesInRow,numRows)
			assert(iscell(typesInRow));
			assert(isscalar(numRows));
			
			% typesInRow can be simple cell array (e.g. {'uint8','double','uint32', 'uint32'})
			%  or can include cell arary entries specifying number of repeated types to be grouped
			%  into single output matrix (e.g. {'uint8','double',{'uint32',2}})
			
			expandedTypes = {};
			for iV = 1:length(typesInRow)
				if ~iscell(typesInRow{iV})
					expandedTypes = [expandedTypes, typesInRow{iV}];
				else
					assert(isscalar(typesInRow{iV}{2}));
					for iR = 1:typesInRow{iV}{2}
						expandedTypes = [expandedTypes, typesInRow{iV}{1}];
					end
				end
			end
			
			numValsInRow = length(expandedTypes);
			numBytesPerVal = nan(1,numValsInRow);
			for iV = 1:numValsInRow
				numBytesPerVal(iV) = getNumBytesForType(expandedTypes{iV});
			end
			
			numBytesPerRow = sum(numBytesPerVal);
			
			[rawData, count] = o.fread([numBytesPerRow, numRows], '*uint8');
			rawData = rawData';
			
			if count ~= numBytesPerRow*numRows
				error('FileReader:UnexpectedEOF','Reached EOF early');
			end
			
			outputVals = cell(1,numValsInRow);
			for iV = 1:numValsInRow
				indices = sum(numBytesPerVal(1:(iV-1)))+(1:numBytesPerVal(iV));
				outputVals{iV} = typecast(reshape(rawData(:,indices)',1,[]),expandedTypes{iV})';
			end
			
			valCounter = 0;
			varargout = cell(1,length(typesInRow));
			for iO = 1:length(typesInRow)
				if ~iscell(typesInRow{iO})
					varargout{iO} = outputVals{valCounter+1};
					valCounter = valCounter + 1;
				else
					varargout{iO} = cell2mat(outputVals(valCounter+(1:typesInRow{iO}{2})));
					valCounter = valCounter + typesInRow{iO}{2};
				end
			end
			
			if nargout ~= length(typesInRow)
				warning('Length of outputs does not match requested length of inputs');
			end
		end
		
	end
end

function numBytes = getNumBytesForType(type)
	switch(type)
		case 'uint8'
			numBytes = 1;
		case 'uint32'
			numBytes = 4;
		case 'double'
			numBytes = 8;
		otherwise
			error('Unsupported input type: %s',type);
	end
end