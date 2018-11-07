function values = c_convertValuesFromUnitToUnit(values,fromUnit,toUnit)
% c_convertValuesFromUnitToUnit - Convert values between units (e.g. mm to m)
% Can handle {km,m,cm,mm,um,pm,miles,feet}, {kV,V,mV,uV,pV,dBmV,dBuV}, or arbitrary relative scales
%
% Syntax:
%   convertedValues = c_convertValuesFromUnitToUnit(values,fromUnit,toUnit)
%
% Inputs:
%    values - scalar or vector/matrix of numeric values to convert
%    fromUnit - current unit of input values
%    toUnit - desired output unit of convertedValues
%
% Outputs:
%    convertedValues
%
% Examples: 
%   c_convertValuesFromUnitToUnit(0.123,'m','mm')
%   c_convertValuesFromUnitToUnit(0.123,'m','ft')
%   c_convertValuesFromUnitToUnit([1 2 3],'mV','uV')
%	c_convertValuesFromUnitToUnit(0.123,1,0.001)

	assert(isnumeric(values));
	
	if ~(ischar(fromUnit) || isscalar(fromUnit)) || ~(ischar(toUnit) || isscalar(toUnit))
		error('Unsupported unit type(s)');
	end
	
	if ~ischar(fromUnit) && isnan(fromUnit) && ~ischar(toUnit) && isnan(toUnit)
		% do not change values
		return;
	end
	
	if (~ischar(fromUnit) && isnan(fromUnit)) || (~ischar(toUnit) && isnan(toUnit))
		warning('Cannot convert units from %s to %s; returning unchanged values.',fromUnit,toUnit);
		return;
	end
	
	nonScalarUnits = {'dBmV','dBuV'};
	if (~isscalar(fromUnit) && ismember(fromUnit,nonScalarUnits)) || (~isscalar(toUnit) && ismember(toUnit,nonScalarUnits))
		% handle unit conversions such as fahrenheit to celsius that are not just a scale factor
		switch(toUnit)
			case 'dBmV'
				values = c_convertValuesFromUnitToUnit(values,fromUnit,'mV');
				values = 20*log10(values);
				return;
			case 'dBuV'
				values = c_convertValuesFromUnitToUnit(values,fromUnit,'uV');
				values = 20*log10(values);
				return;
		end
	end
	
	fromType = '';
	if ischar(fromUnit)
		[fromUnit, fromType] = strUnitAsNumUnit(fromUnit);
	end
	
	toType = '';
	if ischar(toUnit)
		[toUnit, toType] = strUnitAsNumUnit(toUnit);
	end
	
	% prevent attempts at conversion between, for example, voltage and distance
	if ~isempty(fromType) && ~isempty(toType) && ~strcmpi(fromType,toType)
		error('Converting from type %s to type %s not supported',fromType, toType);
	end
	
	scaleFactor = fromUnit/toUnit;
	
	if isnan(scaleFactor)
		% do not change values
		return;
	end
	
	values = values*scaleFactor;	
end

function [numUnit, unitType] = strUnitAsNumUnit(strUnit)
	if length(strUnit)==1 || length(strUnit)==2
		unitType = '';
		switch(strUnit(end))
			case 'm'
				unitType = 'distance';
			case 'V'
				unitType = 'voltage';
			case 's'
				unitType = 'time';
		end
		
		if ~isempty(unitType)
			if ismember(strUnit(end),{'m','V','s'})
				% unit is supported in SI format
				if length(strUnit)==1
					% e.g. 'm' or 'V'
					numUnit = 1;
					return;
				else
					% try as SI (prefix)(suffix) format, e.g. 'km'
					numUnit = nan;
					switch(strUnit(1))
						case 'k'
							numUnit = 1e3;
						case 'c'
							numUnit = 1e-2;
						case 'm'
							numUnit = 1e-3;
						case 'u'
							numUnit = 1e-6;
						case 'n'
							numUnit = 1e-9;
						case 'p'
							numUnit = 1e-12;
					end
					if ~isnan(numUnit)
						return;
					end
				end
			end
		end
	end
	
	switch(strUnit)
		case 'miles'
			numUnit = 1609.344;
			unitType = 'distance';
		case {'feet','ft'}
			numUnit = 0.3048;
			unitType = 'distance';
		case {'min','minutes'}
			numUnit = 60;
			unitType = 'time';
		case {'sec','seconds'}
			numUnit = 1;
			unitType = 'time';
		otherwise
			error('Unsupported unit: %s',strUnit);
	end
end