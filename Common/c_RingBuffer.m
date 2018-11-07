classdef c_RingBuffer < handle
% c_RingBuffer Class implementing a ring (circular) buffer
% Useful for keeping track of a recent portion of a datastream without constantly shifting data in memory
%
% Example:
%   b = c_RingBuffer(5,'bufferDimension',2)
% 	b.pushBack(1);
% 	b.pushBack(2);
% 	b.pushBack(3);
% 	b.pushBack(4);
% 	recentData = b.peekBack(3)
% 	oldestData = b.peekFront(3)
%
% See c_RingBuffer.testfn() for more examples

	properties
		size = []; 
		data = []; % first value is # of entries, extra dimensions are data-dependent but reshaped entirely into second dimension internally
		head = 1; % current position in buffer (next available location)
		numValid = 0; % equivalent to keeping track of tail position
		dataBufferDimension = 1;
		dataIsStruct;
	end
	
	properties(SetAccess=protected, Dependent)
		length
	end
	
	methods(Access=protected)
		function indices = getIndices(obj,num)
			% positive num = moving forward from head (e.g. adding new data)
			% negative num = moving forward from tail (e.g. retreiving old data)
			
			if num > obj.size(1)
				error('number of elements exceeds size of buffer');
			end
			
			if num >= 0
				% positive, indexing relative to head
				indices = obj.modBufferSize(obj.head:obj.head+num-1);
			else
				% negative, indexing relative to tail
				if num > obj.numValid
					warning('Accessing some elements outside of valid data range');
				end
				indices = obj.modBufferSize(obj.head+obj.size(1)+-obj.numValid + (1:-num)-1);
			end
		end
		
		function num = modBufferSize(obj,num)
			num = mod(num-1,obj.size(1))+1;
		end
		
		function num = unmodBufferSize(obj,num)
			% unwrap indices to be non-decreasing
			
			%TODO: rewrite; current implementation is very inefficient
			for i=2:length(num)
				while num(i-1) > num(i)
					%num(i) = num(i) + obj.size(1);
					num(i:end) = num(i:end) + obj.size(1); % assume that if current needs to be incremented, so do all later values
				end
			end
		end
			
		function num = getNumElements(obj,start,stop)
			startStop = obj.unmodBufferSize(obj.modBufferSize([start stop]));
			num = diff(startStop)+1;
		end
			
	end

	methods
		function obj = c_RingBuffer(varargin)
			if nargin == 0
				testfn();
				return;
			end
			p = inputParser();
			p.addRequired('maxLength',@isscalar);
			p.addParameter('bufferDimension',1,@isscalar); % dimension to concatenate along for input data / output data
			p.addParameter('dataIsStruct',false,@islogical);
			p.parse(varargin{:});
			
			obj.size = p.Results.maxLength; % do not define size of data-dependent dimensions for now
			obj.dataBufferDimension = p.Results.bufferDimension;
			obj.dataIsStruct = p.Results.dataIsStruct;
		end
		
		function numValid = getNumValid(obj)
			numValid = obj.numValid;
		end
		
		function pushBack(obj,data)
			% add new data to buffer
			
			permuteOrder = circshift(1:ndims(data),-obj.dataBufferDimension+1,2);
			
			dataSize = size(data);
			
			% assume first dimension of data is number of entries
			% (so if just inserting a single entry, first dimension should equal 1)
			
			if length(obj.size)==1
				% data size hasn't been defined yet, so define from data
				if length(dataSize)==1
					% handle special case where each entry is just a scalar
					obj.setDataSize(1);
				else
					obj.setDataSize(dataSize(permuteOrder(2:end)));
				end
			end
			
			% permute data if necessary according to obj.dataBufferDimension
			data = permute(data,permuteOrder);
			dataSize = size(data);
			
			if length(dataSize)==1
				if obj.size(2)~=1
					error('Data size does not match buffer size');
				end
			elseif any(dataSize(2:end) ~= obj.size(2:end))
				error('Data size does not match buffer size');
			end
			
			numNewEntries = dataSize(1);
			
			data = reshape(data,numNewEntries,prod(dataSize(2:end)));
			
			if numNewEntries > obj.size(1)
				warning('New data exceeds size of buffer, just keeping last %d entries',obj.size(1));
				data = data(end-obj.size(1)+1:end,:);
				numNewEntries = size(data,1);
			end
			
			if obj.numValid + numNewEntries > obj.size(1)
				%warning('Overwriting old data');
			end
			
			indicesToWrite = obj.getIndices(numNewEntries);
			if obj.dataIsStruct && c_isEmptyStruct(obj.data)
				% special case to handle addition of new fields in struct
				obj.data = repmat(data,size(obj.data,1),1);					
			else
				obj.data(indicesToWrite,:) = data;
			end
			obj.numValid = min(obj.numValid + numNewEntries,obj.size(1));
			obj.head = obj.modBufferSize(obj.head+numNewEntries);
			
		end
		
		function clear(obj)
			% reset data, but do not reset data size
			obj.head = 1;
			obj.numValid = 0;
		end
		
		function setDataSize(obj,dataSize)
			if length(obj.size) > 1
				warning('Size was already defined. Clearing buffer before resetting size.');
				obj.clear();
				obj.size = obj.size(1);
			end
			
			if isempty(dataSize)
				error('dataSize should not be empty');
			end
			
			obj.size(2:length(dataSize)+1) = dataSize;
			
			% allocate matrix for data
			if obj.dataIsStruct
				obj.data = repmat(struct(),obj.size(1),prod(obj.size(2:end)));
			else
				obj.data = nan(obj.size(1),prod(obj.size(2:end)));
			end
		end
		
		function data = peekBack(obj,numEntries)
			% get newest numEntries samples
			
			if nargin < 2
				numEntries = 1;
			end
			
			if isinf(numEntries)
				numEntries = obj.numValid;
			elseif numEntries > obj.numValid
				warning('Asked for %d values, but only %d are available.',numEntries,obj.numValid);
				numEntries = obj.numValid;
			end
			
			indicesToRead = obj.getIndices(-obj.numValid);
			indicesToRead = indicesToRead(end-numEntries+1:end); % look at most recent numEntries only
		
			if ~isempty(indicesToRead)
				data = obj.data(indicesToRead,:);

				data = reshape(data,[size(data,1) obj.size(2:end)]);

				permuteOrder = circshift(1:length(obj.size),-obj.dataBufferDimension+1,2);
				data = ipermute(data,permuteOrder);
			else
				data = [];
			end
		end
			
		
		function data = peekFront(obj,numEntries)
			% get oldest numEntries samples
			
			if nargin < 2
				numEntries = 1;
			end
			
			if isinf(numEntries)
				numEntries = obj.numValid;
			elseif numEntries > obj.numValid
				warning('Asked for %d values, but only %d are available.',numEntries,obj.numValid);
				numEntries = obj.numValid;
			end
			
			indicesToRead = obj.getIndices(-numEntries);
		
			data = obj.data(indicesToRead,:);
			
			data = reshape(data,[size(data,1) obj.size(2:end)]);

			permuteOrder = circshift(1:length(obj.size),-obj.dataBufferDimension+1,2);
			data = ipermute(data,permuteOrder);
			
		end
		
		function data = popFront(obj,numEntries)
			% get oldest numEntries samples and remove from queue
			
			if nargin < 2
				numEntries = 1;
			end
			
			data = obj.peekFront(numEntries);
			
			obj.numValid = obj.numValid - size(data,obj.dataBufferDimension);
		end
		
		function len = get.length(obj)
			len = obj.numValid;
		end
	end
	
	methods(Static)
		function testfn()
			b = c_RingBuffer(10);

			dataIn1 = rand(3,2);
			b.pushBack(dataIn1);
			dataOut1 = b.peekFront(3);
			assert(isequal(dataIn1,dataOut1));

			dataIn2 = rand(5,2);
			b.pushBack(dataIn2);
			dataOut1 = b.popFront(3);
			assert(isequal(dataIn1,dataOut1));
			dataOut2 = b.popFront(5);
			assert(isequal(dataIn2,dataOut2));

			dataIn3 = rand(9,2);
			b.pushBack(dataIn3);
			dataOut3 = b.peekFront(9);
			assert(isequal(dataIn3,dataOut3));


			b = c_RingBuffer(10,'bufferDimension',2);

			dataIn1 = rand(2,3);
			b.pushBack(dataIn1);
			dataOut1 = b.peekFront(3);
			assert(isequal(dataIn1,dataOut1));

			dataIn2 = rand(2,5);
			b.pushBack(dataIn2);
			dataOut1 = b.popFront(3);
			assert(isequal(dataIn1,dataOut1));
			dataOut2 = b.popFront(5);
			assert(isequal(dataIn2,dataOut2));

			dataIn3 = rand(2,9);
			b.pushBack(dataIn3);
			dataOut3 = b.peekFront(9);
			assert(isequal(dataIn3,dataOut3));


			b = c_RingBuffer(5,'bufferDimension',2);
			b.pushBack(1);
			b.pushBack(2);
			b.pushBack(3);
			b.pushBack(4);
			recentData = b.peekBack(3);
			assert(isequal(recentData, [2 3 4]));
			oldestData = b.peekFront(3);
			assert(isequal(oldestData, [1 2 3]));

			b.clear();
			assert(b.length==0);

			disp('Test successful');
			keyboard
		end
	end
end
