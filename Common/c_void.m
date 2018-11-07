function varargout = c_void(f, varargin)
% adapted from http://www.mathworks.com/matlabcentral/fileexchange/39735-functional-programming-constructs
varargout = varargin;

if iscell(f)
	for iF = 1:length(f)
		f{iF}();
	end
else
	f();
end

end