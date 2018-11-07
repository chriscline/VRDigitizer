function res = c_isField(struct,field)
 % c_isField - like isfield(), but allows fields to be specified as nested strings 
	% (e.g. to check if struct.field1.field2.field3 exists, use c_isField(struct,'field1.field2.field3')
	if isstruct(struct)
		isf = @isfield;
	elseif istable(struct)
		isf = @(t,str) ismember(str,t.Properties.VariableNames);
	elseif isobject(struct)
		isf = @isprop;
	else
		if isempty(struct)
			res = false;
			return;
		else
			error('first input must be a struct or object');
		end
	end
	assert(ischar(field))
	i = find(field=='.',1,'first');
	if isempty(i)
		res = isf(struct,field);
	elseif ~isf(struct,field(1:i-1))
		res = false;
	else
		% recursive call
		res = c_isField(struct.(field(1:i-1)),field(i+1:end));
	end
end