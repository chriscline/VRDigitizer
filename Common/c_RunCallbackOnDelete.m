classdef c_RunCallbackOnDelete < handle
% c_RunCallbackOnDelete - simple class for running a callback when a handle is deleted.
% Useful when wanting to automatically run some cleanup function when other variables are cleared

	properties
		callback = [];
	end
	
	methods
		function o = c_RunCallbackOnDelete(callback)
			assert(isa(callback,'function_handle'));
			o.callback = callback;
		end
		
		function delete(o)
			if ~isempty(o.callback)
				o.callback();
			end
		end
		
		function cancel(o)
			o.callback = [];
		end
	end
end