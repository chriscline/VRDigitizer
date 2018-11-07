function handles = c_plot_lineUsingColormap(varargin)
% c_plot_lineUsingColormap - similar to plot(), but line colors are intensities that change with the colormap

p = inputParser();
p.addRequired('X',@isvector);
p.addRequired('Y',@isvector);
p.addOptional('Z',[],@isvector);
p.addOptional('C',[],@isvector); % color intensities
p.addParameter('parent',[],@ishandle);
p.addParameter('ColorStyle','flat',@ischar); % color style (patch property 'EdgeColor')
p.addParameter('LineWidth',0.5,@isscalar);
p.parse(varargin{:});
s = p.Results;

if isempty(s.parent)
	s.parent = gca;
end

if isempty(s.Z)
	s.Z = zeros(size(s.X));
end

if isempty(s.C)
	s.C = zeros(size(s.X));
end

assert(c_allEqual(size(s.X),size(s.Y),size(s.Z)));

if length(s.C) == length(s.X)
	doColorByVertex = true;
elseif length(s.C) == length(s.X)-1
	doColorByVertex = false;
else
	error('Invalid size of C');
end

numLines = length(s.X)-1;
handles = nan(1,numLines);
for iL = 1:numLines
	if doColorByVertex
		C = s.C(iL:iL+1);
	else
		C = repmat(s.C(iL),1,2);
	end
	handles(iL) = patch(s.X(iL:iL+1),s.Y(iL:iL+1),s.Z(iL:iL+1),C,...
		'EdgeColor',s.ColorStyle,...
		'FaceColor','none',...
		'MarkerFaceColor','none',...
		'LineWidth',s.LineWidth);
end

end